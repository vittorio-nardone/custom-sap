; @load-address 0x8400
; =====================================================
; CH376S USB storage smoke test (kernel v1.2.101)
; =====================================================
; Hardware (assumed):
;   CH376S UART <-> Otto ACIA #2 @ 0x6022/0x6023 (115200 8N1)
;   CH376S INT#  -> Otto EXTINT1 (active low)
; Console on ACIA #1.
;
; Tests: IC version, CHECK_EXIST, USB host init, disk mount,
;        root directory listing (FILE_OPEN + FILE_ENUM_GO).
;
; Layout is split into apps/ch376/*.asm for future kernel module.
; =====================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"
#include "ch376/ch376_const.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    jsr .set_timeout

    ldd .msg_boot[15:8]
    lde .msg_boot[7:0]
    jsr ACIA_SEND_STRING

    jsr ch376_acia2_init
    jsr ch376_int_enable

    ldd .msg_title[15:8]
    lde .msg_title[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl

    jsr .test_link
    bcc .fail

    jsr .test_get_ic_ver
    bcc .fail
    jsr .test_check_exist
    bcc .fail
    jsr .test_usb_storage
    bcc .fail

    ldd .msg_ok[15:8]
    lde .msg_ok[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    rts

.fail:
    ldd .msg_fail[15:8]
    lde .msg_fail[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    rts

.set_timeout:
    lda 0xFF
    sta CH376_TMO
    lda 0x10
    sta CH376_TMO+1
    rts

.set_timeout_long:
    lda 0xFF
    sta CH376_TMO
    lda 0xFF
    sta CH376_TMO+1
    rts

.test_link:
    ldd .msg_acia2_st[15:8]
    lde .msg_acia2_st[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_acia2_read_status
    jsr ch376_print_hex8
    jsr ch376_print_nl

    ldd .msg_int_pin[15:8]
    lde .msg_int_pin[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_int_pin_char
    jsr ACIA_SEND_CHAR
    jsr ch376_print_nl

    lda 0xAA
    jsr ch376_cmd_check_exist
    bcc .test_link_fail
    ldd .msg_ce_aa[15:8]
    lde .msg_ce_aa[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl

    jsr ch376_cmd_get_ic_ver
    bcc .test_link_fail
    sta CH376_SCRATCH
    jsr ch376_cmd_get_ic_ver
    bcc .test_link_fail
    cmp CH376_SCRATCH
    bne .test_link_fail
    ldd .msg_ic_twice[15:8]
    lde .msg_ic_twice[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    sec
    rts
.test_link_fail:
    ldd .msg_link_fail[15:8]
    lde .msg_link_fail[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    clc
    rts

.test_get_ic_ver:
    ldd .msg_ic_ver[15:8]
    lde .msg_ic_ver[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_cmd_get_ic_ver
    bcc .test_get_ic_ver_to
    jsr ch376_print_hex8
    jsr ch376_print_nl
    sec
    rts
.test_get_ic_ver_to:
    ldd .msg_timeout[15:8]
    lde .msg_timeout[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    clc
    rts

.test_check_exist:
    ldd .msg_check[15:8]
    lde .msg_check[7:0]
    jsr ACIA_SEND_STRING
    lda 0x65
    jsr ch376_cmd_check_exist
    bcc .test_check_exist_fail
    ldd .msg_ok_short[15:8]
    lde .msg_ok_short[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    sec
    rts
.test_check_exist_fail:
    lda CH376_LAST_STATUS
    bne .test_check_exist_bad
    ldd .msg_timeout[15:8]
    lde .msg_timeout[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    clc
    rts
.test_check_exist_bad:
    ldd .msg_bad[15:8]
    lde .msg_bad[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

.test_usb_storage:
    ldd .msg_usb_mode[15:8]
    lde .msg_usb_mode[7:0]
    jsr ACIA_SEND_STRING

    ldd .msg_usb_reset[15:8]
    lde .msg_usb_reset[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_USB_MODE_HOST_RESET
    jsr ch376_cmd_set_usb_mode
    bcc .test_usb_to
    jsr ch376_print_status

    lda CH376_USB_MODE_HOST
    jsr ch376_cmd_set_usb_mode
    bcc .test_usb_to
    jsr ch376_print_status

    lda CH376_CMD_DISK_CONNECT
    jsr ch376_cmd_wait_status
    bcc .test_usb_to
    jsr ch376_print_status

    jsr ch376_drain_rx
    jsr ch376_delay_short

    ldd .msg_mount[15:8]
    lde .msg_mount[7:0]
    jsr ACIA_SEND_STRING
    jsr .set_timeout_long
    lda 0x08
    sta CH376_SCRATCH
.test_disk_mount_loop:
    lda CH376_CMD_DISK_MOUNT
    jsr ch376_cmd_wait_status
    bcs .test_disk_mount_check
    dec CH376_SCRATCH
    beq .test_disk_mount_done
    jsr ch376_delay_short
    jmp .test_disk_mount_loop
.test_disk_mount_check:
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq .test_disk_mount_done
    dec CH376_SCRATCH
    beq .test_disk_mount_done
    jsr ch376_delay_short
    jmp .test_disk_mount_loop
.test_disk_mount_done:
    jsr .set_timeout
    lda CH376_LAST_STATUS
    beq .test_usb_to
    cmp CH376_INT_SUCCESS
    bne .test_usb_fail
    lda CH376_LAST_STATUS
    jsr ch376_print_status

    jsr ch376_delay_short
    jsr ch376_drain_count
    sta CH376_DRAIN_CNT
    ldd .msg_post_mount[15:8]
    lde .msg_post_mount[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_DRAIN_CNT
    jsr ch376_print_hex8
    jsr ch376_print_nl
    ldd .msg_int_pin[15:8]
    lde .msg_int_pin[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_int_pin_char
    jsr ACIA_SEND_CHAR
    jsr ch376_print_nl

    jsr .list_root
    bcc .test_list_fail
    jsr .read_disk_id
    sec
    rts
.test_usb_to:
    ldd .msg_timeout[15:8]
    lde .msg_timeout[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    clc
    rts
.test_usb_fail:
    ldd .msg_fail_st[15:8]
    lde .msg_fail_st[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

.test_list_fail:
    ldd .msg_list_fail[15:8]
    lde .msg_list_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

.read_disk_id:
    jsr .set_timeout_long
    lda CH376_CMD_DISK_QUERY
    jsr ch376_cmd_interrupt
    jsr .set_timeout
    ldd .msg_disk_q[15:8]
    lde .msg_disk_q[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    lda CH376_LAST_STATUS
    beq .read_disk_id_done
    cmp CH376_INT_SUCCESS
    bne .read_disk_id_done
    jsr .set_timeout_long
    jsr ch376_rd_disk_query
    jsr .set_timeout
    bne .read_disk_id_ok
    ldd .msg_disk_rd_fail[15:8]
    lde .msg_disk_rd_fail[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    jsr .print_rd_tail
    jmp .read_disk_id_done
.read_disk_id_ok:
    pha
    ldd .msg_disk_id[15:8]
    lde .msg_disk_id[7:0]
    jsr ACIA_SEND_STRING
    pla
    jsr ch376_print_hex8
    jsr ch376_print_nl
.read_disk_id_done:
    jsr ch376_drain_count
    sta CH376_DRAIN_CNT
    lda CH376_DRAIN_CNT
    beq .read_disk_id_out
    ldd .msg_post_disk[15:8]
    lde .msg_post_disk[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_DRAIN_CNT
    jsr ch376_print_hex8
    jsr ch376_print_nl
.read_disk_id_out:
    rts

.print_rd_tail:
    ldd .msg_rd_tail[15:8]
    lde .msg_rd_tail[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_drain_count
    jmp ch376_print_hex8

.list_root:
    lda 0x00
    sta CH376_FILE_COUNT
    lda 0x40
    sta CH376_ENUM_LEFT

    ldd .msg_listing[15:8]
    lde .msg_listing[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl

    ; Ch376msc listDir: SET_FILE_NAME("*") then FILE_OPEN only.
    ldd .fn_star[15:8]
    lde .fn_star[7:0]
    jsr ch376_cmd_set_file_name
    bcc .list_root_fail
    ldd .msg_fn_st[15:8]
    lde .msg_fn_st[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl

    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .list_root_fail
    lda CH376_LAST_STATUS
    sta CH376_OPEN_ST
    cmp CH376_ERR_MISS_FILE
    beq .list_root_finish

.list_root_loop:
    lda CH376_LAST_STATUS
    cmp CH376_ERR_MISS_FILE
    beq .list_root_finish
    cmp CH376_INT_DISK_READ
    bne .list_root_fail

    jsr ch376_rd_dir_entry
    sta CH376_RD_LEN
    beq .list_root_finish
    jsr .list_emit_entry

    dec CH376_ENUM_LEFT
    beq .list_root_finish

    lda CH376_CMD_FILE_ENUM_GO
    jsr ch376_cmd_interrupt
    bcc .list_root_fail
    jmp .list_root_loop

.list_root_finish:
    lda CH376_FILE_COUNT
    bne .list_root_done
    ldd .msg_open_st[15:8]
    lde .msg_open_st[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_OPEN_ST
    jsr ch376_print_hex8
    jsr ch376_print_nl
    ldd .msg_rd_len[15:8]
    lde .msg_rd_len[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_RD_LEN
    jsr ch376_print_hex8
    jsr ch376_print_nl
    ldd .msg_rd_tail[15:8]
    lde .msg_rd_tail[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_drain_count
    jsr ch376_print_hex8
    jsr ch376_print_nl
    ldd .msg_int_pin[15:8]
    lde .msg_int_pin[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_int_pin_char
    jsr ACIA_SEND_CHAR
    jsr ch376_print_nl
    ldd .msg_pull[15:8]
    lde .msg_pull[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_PULL_MODE
    beq .list_no_pull
    jsr ACIA_SEND_CHAR
.list_no_pull:
    jsr ch376_print_nl
.list_root_done:
    ldd .msg_entries[15:8]
    lde .msg_entries[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_FILE_COUNT
    jsr ch376_print_hex8
    jsr ch376_print_nl
    sec
    rts
.list_root_fail:
    ldd .msg_open_st[15:8]
    lde .msg_open_st[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    ldd .msg_int_pin[15:8]
    lde .msg_int_pin[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_int_pin_char
    jsr ACIA_SEND_CHAR
    jsr ch376_print_nl
    ldd .msg_post_open[15:8]
    lde .msg_post_open[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_drain_count
    jsr ch376_print_hex8
    jsr ch376_print_nl
    jsr ch376_uart_rx_pending
    bcc .list_no_b1
    ldd .msg_open_b1[15:8]
    lde .msg_open_b1[7:0]
    jsr ACIA_SEND_STRING
    lda ACIA2_RW_DATA_ADDR
    jsr ch376_print_hex8
    jsr ch376_print_nl
.list_no_b1:
    clc
    rts

; Print CH376_BUF when it is a printable 8.3 short-name slot.
.list_emit_entry:
    lda CH376_BUF
    beq .lem_skip
    cmp 0xE5
    beq .lem_skip
    jsr .list_is_dot_entry
    bcc .lem_skip
    lda CH376_BUF+11
    cmp 0x0F
    beq .lem_skip
    lda CH376_BUF+11
    and 0x08
    bne .lem_skip
    jsr .print_direntry
    jsr ch376_print_nl
    inc CH376_FILE_COUNT
.lem_skip:
    rts

; C=1 printable, C=0 skip "." or ".." only.
.list_is_dot_entry:
    lda CH376_BUF
    cmp 0x2E
    bne .lide_ok
    lda CH376_BUF+1
    cmp 0x20
    beq .lide_dot
    cmp 0x2E
    bne .lide_ok
    lda CH376_BUF+2
    cmp 0x20
    beq .lide_dot
.lide_ok:
    sec
    rts
.lide_dot:
    clc
    rts

.print_direntry:
    ldx 0x00
.print_name:
    cpx 0x08
    bcs .print_ext
    lda CH376_BUF,x
    cmp 0x20
    beq .skip_name
    jsr ACIA_SEND_CHAR
.skip_name:
    inx
    jmp .print_name
.print_ext:
    lda CH376_BUF+8
    cmp 0x20
    beq .print_tag
    lda 0x2E
    jsr ACIA_SEND_CHAR
    ldx 0x08
.print_ext_loop:
    cpx 0x0B
    bcs .print_tag
    lda CH376_BUF,x
    cmp 0x20
    beq .next_ext
    jsr ACIA_SEND_CHAR
.next_ext:
    inx
    jmp .print_ext_loop
.print_tag:
    lda CH376_BUF+11
    and CH376_DIR_ATTR_DIRECTORY
    beq .print_tag_done
    ldd .tag_dir[15:8]
    lde .tag_dir[7:0]
    jmp ACIA_SEND_STRING
.print_tag_done:
    rts

.msg_boot:
    #d 0x0A, 0x0D, "CH376 test v28", 0x0A, 0x0D, 0x00
.msg_title:
    #d "--- CH376S test v28 (ACIA2) ---", 0x0A, 0x0D, 0x00
.msg_ok:
    #d "CH376 tests done.", 0x00
.msg_fail:
    #d "CH376 test failed.", 0x00
.msg_timeout:
    #d "TIMEOUT", 0x00
.msg_bad:
    #d "BAD rsp ", 0x00
.msg_ic_ver:
    #d "IC/FW ver: ", 0x00
.msg_check:
    #d "CHECK_EXIST: ", 0x00
.msg_ok_short:
    #d "OK", 0x00
.msg_usb_mode:
    #d "SET_USB_MODE host: ", 0x00
.msg_usb_reset:
    #d "SET_USB_MODE reset: ", 0x00
.msg_mount:
    #d "DISK_MOUNT: ", 0x00
.msg_disk_id:
    #d "Disk id len: ", 0x00
.msg_disk_rd_fail:
    #d "Disk RD fail", 0x00
.msg_disk_q:
    #d "DISK_QUERY ST ", 0x00
.msg_acia2_st:
    #d "ACIA2 ST ", 0x00
.msg_int_pin:
    #d "INT pin ", 0x00
.msg_ce_aa:
    #d "CHECK_EXIST AA OK", 0x00
.msg_ic_twice:
    #d "IC ver stable", 0x00
.msg_link_fail:
    #d "Link test fail", 0x00
.msg_post_mount:
    #d "Post-mount drain ", 0x00
.msg_post_disk:
    #d "Post-disk drain ", 0x00
.msg_post_open:
    #d "Post-open drain ", 0x00
.msg_fail_st:
    #d "USB fail ST ", 0x00
.msg_list_fail:
    #d "List fail ST ", 0x00
.msg_open_st:
    #d "OPEN ST ", 0x00
.msg_fn_st:
    #d "FN ST ", 0x00
.msg_open_b1:
    #d "OPEN b1 ", 0x00
.msg_rd_len:
    #d "RD len ", 0x00
.msg_rd_tail:
    #d "RD tail ", 0x00
.msg_pull:
    #d "pull ", 0x00
.msg_listing:
    #d "Root listing (*):", 0x00
.msg_entries:
    #d "Entries: ", 0x00
.fn_star:
    #d "*", 0x00
.tag_dir:
    #d " <DIR>", 0x00

CH376_TMO:
    #d 0x00, 0x00
CH376_TMO_SAVE:
    #d 0x00, 0x00
CH376_SCRATCH:
    #d 0x00
CH376_OPEN_ST:
    #d 0x00
CH376_DRAIN_CNT:
    #d 0x00
CH376_RD_LEN:
    #d 0x00
CH376_PULL_MODE:
    #d 0x00
CH376_ENUM_LEFT:
    #d 0x00
CH376_LAST_STATUS:
    #d 0x00
CH376_FILE_COUNT:
    #d 0x00
CH376_BUF:
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

#include "ch376/ch376_io.asm"
#include "ch376/ch376_proto.asm"
