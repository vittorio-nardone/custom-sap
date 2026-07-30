; @load-address 0x020000
; =====================================================
; CH376S USB file loader (kernel v1.2.101)
; =====================================================
; Runs from expansion RAM page 2 so loading into 0x8400
; does not overwrite this code.
;
; Upload: u020000  (raw binary — ABI v1.2.101 has no OT header)
; Run:    r020000
;
; Flow: mount USB → numbered root file list → select
;   0 = quit (RTS)
;   N = open file, reject if > 27 KB (0x6C00), else load @ 0x8400, RTS
; User then runs the loaded app with `r` / `r8400`.
;
; No EXTINT1 handler (ISR pointers are 16-bit; code lives above 64 KB).
; UART status path only (same as successful v35 listing).
; =====================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"
#include "ch376/ch376_const.asm"

#bankdef ch376_loader
{
    #addr 0x020000
    #size 0x10000
    #outp 0
}

#bank ch376_loader

    jsr .set_timeout

    ; Do not enable EXTINT1 — handler cannot live above 0xFFFF.
    sei
    lda INT_TIMER
    tai
    cli

    ldy .msg_boot[23:16]
    ldd .msg_boot[15:8]
    lde .msg_boot[7:0]
    jsr ch376_print_str

    jsr ch376_acia2_init

    jsr .mount_usb
    bcc .fail

    jsr .list_root
    bcc .fail

    lda CH376_FILE_COUNT
    bne .menu
    ldy .msg_empty[23:16]
    ldd .msg_empty[15:8]
    lde .msg_empty[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl
    rts

.menu:
    ldy .msg_prompt[23:16]
    ldd .msg_prompt[15:8]
    lde .msg_prompt[7:0]
    jsr ch376_print_str
    jsr .read_selection
    bcc .menu_bad
    lda CH376_SELECT
    beq .quit
    cmp CH376_FILE_COUNT
    beq .do_load
    bcc .do_load
    jmp .menu_bad
.do_load:
    jsr .load_selected
    bcc .fail
    ldy .msg_loaded[23:16]
    ldd .msg_loaded[15:8]
    lde .msg_loaded[7:0]
    jsr ch376_print_str
    lda CH376_LOADED_HI
    jsr ch376_print_hex8
    lda CH376_LOADED_LO
    jsr ch376_print_hex8
    ldy .msg_loaded_tail[23:16]
    ldd .msg_loaded_tail[15:8]
    lde .msg_loaded_tail[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl
    rts

.quit:
    ldy .msg_bye[23:16]
    ldd .msg_bye[15:8]
    lde .msg_bye[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl
    rts

.menu_bad:
    ldy .msg_bad_sel[23:16]
    ldd .msg_bad_sel[15:8]
    lde .msg_bad_sel[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl
    jmp .menu

.fail:
    ldy .msg_fail[23:16]
    ldd .msg_fail[15:8]
    lde .msg_fail[7:0]
    jsr ch376_print_str
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
    sta CH376_TMO+1
    rts

; ---- Mount USB host storage ----
.mount_usb:
    ldy .msg_mounting[23:16]
    ldd .msg_mounting[15:8]
    lde .msg_mounting[7:0]
    jsr ch376_print_str

    lda 0xAA
    jsr ch376_cmd_check_exist
    bcc .mount_fail

    lda CH376_USB_MODE_HOST_RESET
    jsr ch376_cmd_set_usb_mode
    bcc .mount_fail
    lda CH376_USB_MODE_HOST
    jsr ch376_cmd_set_usb_mode
    bcc .mount_fail

    lda CH376_CMD_DISK_CONNECT
    jsr ch376_cmd_wait_status
    bcc .mount_fail

    jsr ch376_drain_rx
    jsr ch376_delay_short

    jsr .set_timeout_long
    lda 0x08
    sta CH376_SCRATCH
.mount_loop:
    lda CH376_CMD_DISK_MOUNT
    jsr ch376_cmd_wait_status
    bcs .mount_check
    dec CH376_SCRATCH
    beq .mount_done
    jsr ch376_delay_short
    jmp .mount_loop
.mount_check:
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq .mount_done
    dec CH376_SCRATCH
    beq .mount_done
    jsr ch376_delay_short
    jmp .mount_loop
.mount_done:
    jsr .set_timeout
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    bne .mount_fail
    ldy .msg_ok_short[23:16]
    ldd .msg_ok_short[15:8]
    lde .msg_ok_short[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl
    sec
    rts
.mount_fail:
    ldy .msg_mount_fail[23:16]
    ldd .msg_mount_fail[15:8]
    lde .msg_mount_fail[7:0]
    jsr ch376_print_str
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

; ---- Root listing with numbered selectable files ----
.list_root:
    lda 0x00
    sta CH376_FILE_COUNT
    sta CH376_WIRE_LEN
    sta CH376_RD_LEN
    sta CH376_PULL_MODE
    lda 0x40
    sta CH376_ENUM_LEFT

    ldy .msg_listing[23:16]
    ldd .msg_listing[15:8]
    lde .msg_listing[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl

    ldy .fn_slash_star[23:16]
    ldd .fn_slash_star[15:8]
    lde .fn_slash_star[7:0]
    jsr ch376_cmd_set_file_name
    jsr .set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .list_fail
    lda CH376_LAST_STATUS
    sta CH376_OPEN_ST

.list_loop:
    lda CH376_LAST_STATUS
    cmp CH376_ERR_MISS_FILE
    beq .list_ok
    cmp CH376_INT_DISK_READ
    beq .list_read
    cmp CH376_INT_SUCCESS
    beq .list_enum
    jmp .list_fail

.list_read:
    jsr .set_timeout_long
    jsr ch376_rd_dir_entry
    sta CH376_RD_LEN
    lda CH376_RD_LEN
    beq .list_rd_fail
    jsr .list_emit
    dec CH376_ENUM_LEFT
    beq .list_ok

.list_enum:
    jsr .set_timeout_long
    lda CH376_CMD_FILE_ENUM_GO
    jsr ch376_cmd_interrupt
    bcc .list_fail
    jmp .list_loop

.list_ok:
    jsr .set_timeout
    ldy .msg_entries[23:16]
    ldd .msg_entries[15:8]
    lde .msg_entries[7:0]
    jsr ch376_print_str
    lda CH376_FILE_COUNT
    jsr ACIA_SEND_DECIMAL
    jsr ch376_print_nl
    sec
    rts

.list_rd_fail:
    jsr .set_timeout
    ldy .msg_rd_fail[23:16]
    ldd .msg_rd_fail[15:8]
    lde .msg_rd_fail[7:0]
    jsr ch376_print_str
    lda CH376_WIRE_LEN
    jsr ch376_print_hex8
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda CH376_RD_LEN
    jsr ch376_print_hex8
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda CH376_OVERRUN
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

.list_fail:
    jsr .set_timeout
    ldy .msg_list_fail[23:16]
    ldd .msg_list_fail[15:8]
    lde .msg_list_fail[7:0]
    jsr ch376_print_str
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

; Store printable file (not dir/LFN/vol/./..) and print "N. name"
.list_emit:
    lda CH376_BUF
    beq .lem_skip
    cmp 0xE5
    beq .lem_skip
    jsr .list_is_dot
    bcc .lem_skip
    lda CH376_BUF+11
    cmp 0x0F
    beq .lem_skip
    lda CH376_BUF+11
    and 0x08
    bne .lem_skip
    lda CH376_BUF+11
    and CH376_DIR_ATTR_DIRECTORY
    bne .lem_skip
    lda CH376_FILE_COUNT
    cmp CH376_MAX_FILES
    bcs .lem_skip
    jsr .store_entry
    lda CH376_FILE_COUNT
    clc
    adc 0x01
    jsr ACIA_SEND_DECIMAL
    lda 0x2E
    jsr ACIA_SEND_CHAR
    lda 0x20
    jsr ACIA_SEND_CHAR
    jsr .print_name83
    jsr ch376_print_nl
    inc CH376_FILE_COUNT
.lem_skip:
    rts

.list_is_dot:
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

; Copy FAT 8.3 (11) + size LE (4) into NAMES[FILE_COUNT * 15]
.store_entry:
    jsr .entry_ptr_count
    ldx 0x00
.se_name:
    cpx 0x0B
    bcs .se_size
    lda CH376_BUF,x
    phx
    ldx 0x00
    sta yde,x
    plx
    ine
    bne .se_name_next
    ind
.se_name_next:
    inx
    jmp .se_name
.se_size:
    ldx 0x00
.se_size_loop:
    cpx 0x04
    bcs .se_done
    lda CH376_BUF+0x1C,x
    phx
    ldx 0x00
    sta yde,x
    plx
    ine
    bne .se_size_next
    ind
.se_size_next:
    inx
    jmp .se_size_loop
.se_done:
    rts

; Y:DE = &NAMES[FILE_COUNT * 15]
.entry_ptr_count:
    lda CH376_FILE_COUNT
    jmp .entry_ptr_a

; Y:DE = &NAMES[(A-1) * 15]  — A is 1-based select
.entry_ptr_select:
    lda CH376_SELECT
    sec
    sbc 0x01
.entry_ptr_a:
    ; offset = A * 15 = (A << 4) - A
    sta CH376_SCRATCH
    asl a
    asl a
    asl a
    asl a
    sec
    sbc CH376_SCRATCH
    sta CH376_SCRATCH
    ldy CH376_NAMES[23:16]
    ldd CH376_NAMES[15:8]
    lde CH376_NAMES[7:0]
    clc
    tea
    adc CH376_SCRATCH
    tae
    tda
    adc 0x00
    tad
    bcc .ep_ok
    iny
.ep_ok:
    rts

.print_name83:
    ldx 0x00
.pn_name:
    cpx 0x08
    bcs .pn_ext
    lda CH376_BUF,x
    cmp 0x20
    beq .pn_name_skip
    jsr ACIA_SEND_CHAR
.pn_name_skip:
    inx
    jmp .pn_name
.pn_ext:
    lda CH376_BUF+8
    cmp 0x20
    beq .pn_done
    lda 0x2E
    jsr ACIA_SEND_CHAR
    ldx 0x08
.pn_ext_loop:
    cpx 0x0B
    bcs .pn_done
    lda CH376_BUF,x
    cmp 0x20
    beq .pn_ext_skip
    jsr ACIA_SEND_CHAR
.pn_ext_skip:
    inx
    jmp .pn_ext_loop
.pn_done:
    rts

; Read decimal selection into CH376_SELECT (0..N). C=1 ok.
.read_selection:
    lda 0x00
    sta CH376_SELECT
.rs_loop:
    jsr ACIA_READ_CHAR
    cmp 0x0D
    beq .rs_done
    cmp 0x0A
    beq .rs_done
    cmp 0x30
    bcc .rs_loop
    cmp 0x3A
    bcs .rs_loop
    jsr ACIA_SEND_CHAR
    sec
    sbc 0x30
    sta CH376_SCRATCH
    lda CH376_SELECT
    asl a
    sta CH376_SELECT
    asl a
    asl a
    clc
    adc CH376_SELECT
    clc
    adc CH376_SCRATCH
    sta CH376_SELECT
    jmp .rs_loop
.rs_done:
    jsr ch376_print_nl
    sec
    rts

; Open selected file, size-check, read to 0x8400.
.load_selected:
    jsr .entry_ptr_select
    ; Copy size (entry+11..+14) and check <= 0x6C00
    ldx 0x00
    lda yde,x
    ; wait — need offset 11 into entry. Advance DE by 11 first for size,
    ; or read name into FNBUF then size.
    jsr .build_open_name
    bcc .load_name_fail

    ; Size bytes were left in CH376_SIZE_* by build_open_name
    lda CH376_SIZE_3
    ora CH376_SIZE_2
    bne .load_too_big
    lda CH376_SIZE_1
    cmp CH376_LOAD_MAX_HI
    bcc .load_size_ok
    bne .load_too_big
    lda CH376_SIZE_0
    beq .load_size_ok
    jmp .load_too_big

.load_size_ok:
    ldy .msg_loading[23:16]
    ldd .msg_loading[15:8]
    lde .msg_loading[7:0]
    jsr ch376_print_str
    ldy CH376_FNBUF[23:16]
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl

    ldy CH376_FNBUF[23:16]
    ldd CH376_FNBUF[15:8]
    lde CH376_FNBUF[7:0]
    jsr ch376_cmd_set_file_name
    jsr .set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .load_open_fail
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    bne .load_open_fail

    lda CH376_SIZE_0
    sta CH376_REMAIN_LO
    lda CH376_SIZE_1
    sta CH376_REMAIN_HI
    ; empty file: still OK
    lda CH376_REMAIN_LO
    ora CH376_REMAIN_HI
    beq .load_empty

    ldy 0x00
    ldd 0x84
    lde 0x00
    jsr ch376_file_read_to
    bcc .load_read_fail

.load_close:
    lda 0x00
    jsr ch376_cmd_file_close
    jsr .set_timeout
    sec
    rts

.load_empty:
    lda 0x00
    sta CH376_LOADED_LO
    sta CH376_LOADED_HI
    jmp .load_close

.load_too_big:
    ldy .msg_too_big[23:16]
    ldd .msg_too_big[15:8]
    lde .msg_too_big[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl
    clc
    rts

.load_name_fail:
.load_open_fail:
    ldy .msg_open_fail[23:16]
    ldd .msg_open_fail[15:8]
    lde .msg_open_fail[7:0]
    jsr ch376_print_str
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

.load_read_fail:
    lda 0x00
    jsr ch376_cmd_file_close
    ldy .msg_read_fail[23:16]
    ldd .msg_read_fail[15:8]
    lde .msg_read_fail[7:0]
    jsr ch376_print_str
    jsr ch376_print_nl
    clc
    rts

; Y:DE = entry (11 name + 4 size). Build "/NAME.EXT\0" in FNBUF.
; Also copies size into CH376_SIZE_0..3. C=1 ok.
.build_open_name:
    ; leading '/'
    lda 0x2F
    sta CH376_FNBUF
    lda 0x01
    sta CH376_SCRATCH2
    ; name (8), skip trailing spaces
    ldx 0x00
.bon_name:
    cpx 0x08
    bcs .bon_ext
    lda yde,x
    cmp 0x20
    beq .bon_name_next
    phx
    ldx CH376_SCRATCH2
    sta CH376_FNBUF,x
    inx
    stx CH376_SCRATCH2
    plx
.bon_name_next:
    inx
    jmp .bon_name
.bon_ext:
    lda yde,x
    ; X=8 here — check if any ext char non-space
    lda 0x00
    sta CH376_SCRATCH
    ldx 0x08
.bon_ext_check:
    cpx 0x0B
    bcs .bon_ext_maybe
    lda yde,x
    cmp 0x20
    beq .bon_ext_check_next
    lda 0x01
    sta CH376_SCRATCH
.bon_ext_check_next:
    inx
    jmp .bon_ext_check
.bon_ext_maybe:
    lda CH376_SCRATCH
    beq .bon_size
    lda 0x2E
    ldx CH376_SCRATCH2
    sta CH376_FNBUF,x
    inx
    stx CH376_SCRATCH2
    ldx 0x08
.bon_ext_copy:
    cpx 0x0B
    bcs .bon_size
    lda yde,x
    cmp 0x20
    beq .bon_ext_skip
    phx
    ldx CH376_SCRATCH2
    sta CH376_FNBUF,x
    inx
    stx CH376_SCRATCH2
    plx
.bon_ext_skip:
    inx
    jmp .bon_ext_copy
.bon_size:
    ldx CH376_SCRATCH2
    lda 0x00
    sta CH376_FNBUF,x
    ; size at entry+11
    ldx 0x0B
    lda yde,x
    sta CH376_SIZE_0
    inx
    lda yde,x
    sta CH376_SIZE_1
    inx
    lda yde,x
    sta CH376_SIZE_2
    inx
    lda yde,x
    sta CH376_SIZE_3
    sec
    rts

.msg_boot:
    #d 0x0A, 0x0D, "CH376 USB loader v2", 0x0A, 0x0D, 0x00
.msg_mounting:
    #d "Mounting USB... ", 0x00
.msg_ok_short:
    #d "OK", 0x00
.msg_mount_fail:
    #d "mount fail ST ", 0x00
.msg_listing:
    #d "Root files:", 0x00
.msg_entries:
    #d "Files: ", 0x00
.msg_list_fail:
    #d "List fail ST ", 0x00
.msg_rd_fail:
    #d "RD fail wire/rd/ov ", 0x00
.msg_empty:
    #d "No files.", 0x00
.msg_prompt:
    #d "Select (0=quit): ", 0x00
.msg_bad_sel:
    #d "Bad selection.", 0x00
.msg_bye:
    #d "Bye.", 0x00
.msg_loading:
    #d "Loading ", 0x00
.msg_loaded:
    #d "Loaded 0x", 0x00
.msg_loaded_tail:
    #d " bytes @ 8400. Use r to run.", 0x00
.msg_too_big:
    #d "File too big (>27KB).", 0x00
.msg_open_fail:
    #d "Open fail ST ", 0x00
.msg_read_fail:
    #d "Read fail.", 0x00
.msg_fail:
    #d "Loader failed.", 0x00
.fn_slash_star:
    #d "/*", 0x00

CH376_TMO:
    #d 0x00, 0x00
CH376_TMO_SAVE:
    #d 0x00, 0x00
CH376_SCRATCH:
    #d 0x00
CH376_SCRATCH2:
    #d 0x00
CH376_OPEN_ST:
    #d 0x00
CH376_ENUM_LEFT:
    #d 0x00
CH376_LAST_STATUS:
    #d 0x00
CH376_FILE_COUNT:
    #d 0x00
CH376_INT_FLAG:
    #d 0x00
CH376_INT_STATUS:
    #d 0x00
CH376_SAVED_H:
    #d 0x00, 0x00
CH376_REMAIN_LO:
    #d 0x00
CH376_REMAIN_HI:
    #d 0x00
CH376_LOADED_LO:
    #d 0x00
CH376_LOADED_HI:
    #d 0x00
CH376_SELECT:
    #d 0x00
CH376_SIZE_0:
    #d 0x00
CH376_SIZE_1:
    #d 0x00
CH376_SIZE_2:
    #d 0x00
CH376_SIZE_3:
    #d 0x00
CH376_FNBUF:
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
; Hot RX vars (BUF/CAP/…) live at 0x8284 — see ch376_const.asm
; 40 entries * 15 bytes
CH376_NAMES:
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

#include "ch376/ch376_io.asm"
#include "ch376/ch376_proto.asm"
