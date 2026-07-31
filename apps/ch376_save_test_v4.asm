; @load-address 0x8400
; =====================================================
; CH376S save round-trip smoke test (kernel v1.2.101)
; =====================================================
; Fixed test (no prompts):
;   1. Init ACIA2 + mount USB (before any long RAM loops)
;   2. Fill 1 KB pattern at 0xC000, clear verify @ 0xC400
;   3. Create/overwrite /OTSAVE.BIN
;   4. Write 1 KB from 0xC000
;   5. Re-open and read into 0xC400
;   6. Byte-compare; print PASS or first mismatch
;
; Upload: u / F10  →  run with r
;
; No EXTINT1 — UART status polling only (same as ch376_loader).
; =====================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"
#include "ch376/ch376_const.asm"

#const CH376_BURST_IMG = 0x8400 + CH376_BURST_OUTP
#const SAVE_SRC = 0xC000
#const SAVE_DST = 0xC400
#const SAVE_LEN_LO = 0x00
#const SAVE_LEN_HI = 0x04

#bankdef ram
{
    #addr 0x8400
    #size 0x1800
    #outp 0
}

#bankdef ch376_burst_lo
{
    #addr 0x82B0
    #size 0x120
    #outp 8 * 0x1800
}

#bank ram

    jsr .set_timeout

    ; Match loader: TIMER only, never enable EXTINT1.
    sei
    lda INT_TIMER
    tai
    cli

    ldy CH376_BURST_IMG[23:16]
    ldd CH376_BURST_IMG[15:8]
    lde CH376_BURST_IMG[7:0]
    jsr ch376_install_burst

    ldd .msg_boot[15:8]
    lde .msg_boot[7:0]
    jsr ACIA_SEND_STRING

    jsr ch376_acia2_init
    jsr ch376_drain_rx
    jsr ch376_delay_short

    ; Mount first (same order as working loader) — do not burn time
    ; filling RAM before talking to the chip.
    jsr .mount_usb
    bcc .fail

    jsr .fill_pattern
    jsr .clear_dst

    jsr .create_file
    bcc .fail

    jsr .write_file
    bcc .fail

    lda 0x01
    jsr ch376_cmd_file_close
    bcc .fail_close
    ldd .msg_closed[15:8]
    lde .msg_closed[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl

    jsr .read_back
    bcc .fail

    jsr .compare
    bcc .fail_cmp

    ldd .msg_pass[15:8]
    lde .msg_pass[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    rts

.fail_close:
    ldd .msg_close_fail[15:8]
    lde .msg_close_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    jmp .fail

.fail_cmp:
    ldd .msg_mismatch[15:8]
    lde .msg_mismatch[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_CMP_HI
    jsr ch376_print_hex8
    lda CH376_CMP_LO
    jsr ch376_print_hex8
    ldd .msg_mismatch_tail[15:8]
    lde .msg_mismatch_tail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_CMP_EXP
    jsr ch376_print_hex8
    lda 0x2F
    jsr ACIA_SEND_CHAR
    lda CH376_CMP_GOT
    jsr ch376_print_hex8
    jsr ch376_print_nl

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
    sta CH376_TMO+1
    rts

; Pattern at 0xC000: byte[i] = (addr_lo XOR 0xA5)
.fill_pattern:
    ldd .msg_fill[15:8]
    lde .msg_fill[7:0]
    jsr ACIA_SEND_STRING
    ldy 0x00
    ldd 0xC0
    lde 0x00
    lda 0x00
    sta CH376_REMAIN_LO
    lda SAVE_LEN_HI
    sta CH376_REMAIN_HI
.fill_loop:
    lda CH376_REMAIN_LO
    ora CH376_REMAIN_HI
    beq .fill_done
    tea
    eor 0xA5
    ldx 0x00
    sta yde,x
    ine
    bne .fill_dec
    ind
.fill_dec:
    lda CH376_REMAIN_LO
    bne .fill_dec_lo
    dec CH376_REMAIN_HI
.fill_dec_lo:
    dec CH376_REMAIN_LO
    jmp .fill_loop
.fill_done:
    ldd .msg_ok_short[15:8]
    lde .msg_ok_short[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    rts

.clear_dst:
    ldy 0x00
    ldd 0xC4
    lde 0x00
    lda 0x00
    sta CH376_REMAIN_LO
    lda SAVE_LEN_HI
    sta CH376_REMAIN_HI
.clr_loop:
    lda CH376_REMAIN_LO
    ora CH376_REMAIN_HI
    beq .clr_done
    lda 0x00
    ldx 0x00
    sta yde,x
    ine
    bne .clr_dec
    ind
.clr_dec:
    lda CH376_REMAIN_LO
    bne .clr_dec_lo
    dec CH376_REMAIN_HI
.clr_dec_lo:
    dec CH376_REMAIN_LO
    jmp .clr_loop
.clr_done:
    rts

.mount_usb:
    ldd .msg_mounting[15:8]
    lde .msg_mounting[7:0]
    jsr ACIA_SEND_STRING

    ldd .msg_acia2[15:8]
    lde .msg_acia2[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_acia2_read_status
    jsr ch376_print_hex8
    jsr ch376_print_nl

    jsr .set_timeout_long
    jsr ch376_cmd_get_ic_ver
    bcc .mount_fail_ic
    sta CH376_SCRATCH2
    ldd .msg_ic[15:8]
    lde .msg_ic[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_SCRATCH2
    jsr ch376_print_hex8
    jsr ch376_print_nl

    lda 0x03
    sta CH376_RETRIES
.ce_retry:
    jsr ch376_drain_rx
    lda 0xAA
    jsr ch376_cmd_check_exist
    bcs .ce_ok
    dec CH376_RETRIES
    beq .mount_fail_ce
    jsr ch376_delay_short
    jmp .ce_retry
.ce_ok:
    ldd .msg_ce_ok[15:8]
    lde .msg_ce_ok[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl

    lda CH376_USB_MODE_HOST_RESET
    jsr ch376_cmd_set_usb_mode
    bcc .mount_fail_mode
    lda CH376_USB_MODE_HOST
    jsr ch376_cmd_set_usb_mode
    bcc .mount_fail_mode

    lda CH376_CMD_DISK_CONNECT
    jsr ch376_cmd_wait_status
    bcc .mount_fail_conn

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
    bne .mount_fail_mnt
    ldd .msg_mount_ok[15:8]
    lde .msg_mount_ok[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    sec
    rts
.mount_fail_ic:
    ldd .msg_fail_ic[15:8]
    lde .msg_fail_ic[7:0]
    jmp .mount_fail_print
.mount_fail_ce:
    ldd .msg_fail_ce[15:8]
    lde .msg_fail_ce[7:0]
    jmp .mount_fail_print
.mount_fail_mode:
    ldd .msg_fail_mode[15:8]
    lde .msg_fail_mode[7:0]
    jmp .mount_fail_print
.mount_fail_conn:
    ldd .msg_fail_conn[15:8]
    lde .msg_fail_conn[7:0]
    jmp .mount_fail_print
.mount_fail_mnt:
    ldd .msg_fail_mnt[15:8]
    lde .msg_fail_mnt[7:0]
.mount_fail_print:
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

; SET name; OPEN; if miss → CREATE; if exists → CLOSE + CREATE (truncate).
.create_file:
    ldd .msg_create[15:8]
    lde .msg_create[7:0]
    jsr ACIA_SEND_STRING

    jsr .set_fname
    jsr .set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .create_fail
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq .create_trunc
    cmp CH376_ERR_MISS_FILE
    beq .create_new
    jmp .create_fail

.create_trunc:
    lda 0x00
    jsr ch376_cmd_file_close
    jsr .set_fname
.create_new:
    jsr ch376_cmd_file_create
    bcc .create_fail
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    bne .create_fail
    jsr .set_timeout
    ldd .msg_ok_short[15:8]
    lde .msg_ok_short[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    sec
    rts
.create_fail:
    jsr .set_timeout
    ldd .msg_create_fail[15:8]
    lde .msg_create_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

.set_fname:
    ldy 0x00
    ldd .fn_save[15:8]
    lde .fn_save[7:0]
    jmp ch376_cmd_set_file_name

.write_file:
    ldd .msg_write[15:8]
    lde .msg_write[7:0]
    jsr ACIA_SEND_STRING
    lda SAVE_LEN_LO
    sta CH376_REMAIN_LO
    lda SAVE_LEN_HI
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd 0xC0
    lde 0x00
    jsr .set_timeout_long
    jsr ch376_file_write_from
    bcc .write_fail
    jsr .set_timeout
    ldd .msg_wrote[15:8]
    lde .msg_wrote[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LOADED_HI
    jsr ch376_print_hex8
    lda CH376_LOADED_LO
    jsr ch376_print_hex8
    jsr ch376_print_nl
    ; Expect exactly 0x0400
    lda CH376_LOADED_LO
    cmp SAVE_LEN_LO
    bne .write_fail
    lda CH376_LOADED_HI
    cmp SAVE_LEN_HI
    bne .write_fail
    sec
    rts
.write_fail:
    jsr .set_timeout
    ldd .msg_write_fail[15:8]
    lde .msg_write_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda CH376_WIRE_LEN
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

.read_back:
    ldd .msg_read[15:8]
    lde .msg_read[7:0]
    jsr ACIA_SEND_STRING
    jsr .set_fname
    jsr .set_timeout_long
    lda CH376_CMD_FILE_OPEN
    jsr ch376_cmd_interrupt
    bcc .read_fail
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    bne .read_fail

    lda SAVE_LEN_LO
    sta CH376_REMAIN_LO
    lda SAVE_LEN_HI
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd 0xC4
    lde 0x00
    jsr ch376_file_read_to
    bcc .read_fail

    lda 0x00
    jsr ch376_cmd_file_close
    jsr .set_timeout

    ldd .msg_read_ok[15:8]
    lde .msg_read_ok[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LOADED_HI
    jsr ch376_print_hex8
    lda CH376_LOADED_LO
    jsr ch376_print_hex8
    jsr ch376_print_nl
    lda CH376_LOADED_LO
    cmp SAVE_LEN_LO
    bne .read_fail
    lda CH376_LOADED_HI
    cmp SAVE_LEN_HI
    bne .read_fail
    sec
    rts
.read_fail:
    jsr .set_timeout
    ldd .msg_read_fail[15:8]
    lde .msg_read_fail[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    clc
    rts

; Compare SAVE_SRC vs SAVE_DST for SAVE_LEN bytes. C=1 match.
.compare:
    ldd .msg_cmp[15:8]
    lde .msg_cmp[7:0]
    jsr ACIA_SEND_STRING
    lda 0x00
    sta CH376_CMP_LO
    sta CH376_CMP_HI
    sta CH376_REMAIN_LO
    lda SAVE_LEN_HI
    sta CH376_REMAIN_HI
.cmp_loop:
    lda CH376_REMAIN_LO
    ora CH376_REMAIN_HI
    beq .cmp_ok
    ; src byte
    ldy 0x00
    clc
    lda SAVE_SRC[7:0]
    adc CH376_CMP_LO
    tae
    lda SAVE_SRC[15:8]
    adc CH376_CMP_HI
    tad
    ldx 0x00
    lda yde,x
    sta CH376_CMP_EXP
    ; dst byte
    clc
    lda SAVE_DST[7:0]
    adc CH376_CMP_LO
    tae
    lda SAVE_DST[15:8]
    adc CH376_CMP_HI
    tad
    ldx 0x00
    lda yde,x
    sta CH376_CMP_GOT
    cmp CH376_CMP_EXP
    bne .cmp_bad
    ; advance index
    inc CH376_CMP_LO
    bne .cmp_dec
    inc CH376_CMP_HI
.cmp_dec:
    lda CH376_REMAIN_LO
    bne .cmp_dec_lo
    dec CH376_REMAIN_HI
.cmp_dec_lo:
    dec CH376_REMAIN_LO
    jmp .cmp_loop
.cmp_ok:
    ldd .msg_ok_short[15:8]
    lde .msg_ok_short[7:0]
    jsr ACIA_SEND_STRING
    jsr ch376_print_nl
    sec
    rts
.cmp_bad:
    clc
    rts

.msg_boot:
    #d 0x0A, 0x0D, "CH376 save test v4", 0x0A, 0x0D, 0x00
.msg_fill:
    #d "Fill 1K @ C000... ", 0x00
.msg_mounting:
    #d "Mounting USB...", 0x0A, 0x0D, 0x00
.msg_acia2:
    #d "ACIA2 ST ", 0x00
.msg_ic:
    #d "IC/FW ", 0x00
.msg_ce_ok:
    #d "CHECK_EXIST OK", 0x00
.msg_mount_ok:
    #d "Mount OK", 0x00
.msg_fail_ic:
    #d "GET_IC_VER fail ST ", 0x00
.msg_fail_ce:
    #d "CHECK_EXIST fail ST ", 0x00
.msg_fail_mode:
    #d "SET_USB_MODE fail ST ", 0x00
.msg_fail_conn:
    #d "DISK_CONNECT fail ST ", 0x00
.msg_fail_mnt:
    #d "DISK_MOUNT fail ST ", 0x00
.msg_create:
    #d "Create /OTSAVE.BIN... ", 0x00
.msg_create_fail:
    #d "create fail ST ", 0x00
.msg_write:
    #d "Writing 0x0400... ", 0x00
.msg_wrote:
    #d "wrote 0x", 0x00
.msg_write_fail:
    #d "write fail ST ", 0x00
.msg_closed:
    #d "Closed (size update).", 0x00
.msg_close_fail:
    #d "close fail ST ", 0x00
.msg_read:
    #d "Read back @ C400... ", 0x00
.msg_read_ok:
    #d "read 0x", 0x00
.msg_read_fail:
    #d "read fail ST ", 0x00
.msg_cmp:
    #d "Compare... ", 0x00
.msg_pass:
    #d "PASS: 1K save/read match.", 0x00
.msg_mismatch:
    #d "MISMATCH @ ", 0x00
.msg_mismatch_tail:
    #d " exp/got ", 0x00
.msg_fail:
    #d "CH376 save test FAILED.", 0x00
.msg_ok_short:
    #d "OK", 0x00
.fn_save:
    #d "/OTSAVE.BIN", 0x00

CH376_TMO:
    #d 0x00, 0x00
CH376_TMO_SAVE:
    #d 0x00, 0x00
CH376_SCRATCH:
    #d 0x00
CH376_SCRATCH2:
    #d 0x00
CH376_RETRIES:
    #d 0x00
CH376_LAST_STATUS:
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
CH376_CMP_LO:
    #d 0x00
CH376_CMP_HI:
    #d 0x00
CH376_CMP_EXP:
    #d 0x00
CH376_CMP_GOT:
    #d 0x00

#include "ch376/ch376_io.asm"
#include "ch376/ch376_proto.asm"

#bank ch376_burst_lo
#include "ch376/ch376_burst.asm"
