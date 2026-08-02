; @load-address 0x8400
; =====================================================
; Kernel USB storage round-trip smoke test
; =====================================================
; Uses only the kernel STORAGE_* API.
;
;   mount -> fill 1 KB pattern at 0xC000 -> create /OTSMOKE.BIN
;   -> write 0x400 raw bytes -> close(1) -> open -> read to 0xC400
;   -> compare -> PASS / FAIL
;
; Requires a CH376 module on ACIA #2 and a FAT formatted stick.
; =====================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#const SMOKE_SRC_MSB = 0xC0
#const SMOKE_DST_MSB = 0xC4
#const SMOKE_PAGES   = 0x04

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    ldd .msg_banner[15:8]
    lde .msg_banner[7:0]
    jsr ACIA_SEND_STRING

    jsr STORAGE_MOUNT
    bcc .fail_mount
    ldd .msg_mounted[15:8]
    lde .msg_mounted[7:0]
    jsr ACIA_SEND_STRING

    jsr .fill_pattern

    ; --- create and write ---
    jsr .set_name
    jsr STORAGE_CREATE
    bcc .fail_create

    jsr .set_length
    ldy 0x00
    ldd SMOKE_SRC_MSB
    lde 0x00
    jsr STORAGE_WRITE
    bcc .fail_write
    lda 0x01
    jsr STORAGE_CLOSE

    ldd .msg_written[15:8]
    lde .msg_written[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LOADED_HI
    jsr ACIA_SEND_HEX
    lda CH376_LOADED_LO
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE

    ; --- reopen and read back ---
    jsr .set_name
    jsr STORAGE_OPEN
    bcc .fail_open

    jsr .set_length
    ldy 0x00
    ldd SMOKE_DST_MSB
    lde 0x00
    jsr STORAGE_READ
    bcc .fail_read
    lda 0x00
    jsr STORAGE_CLOSE

    ldd .msg_read[15:8]
    lde .msg_read[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LOADED_HI
    jsr ACIA_SEND_HEX
    lda CH376_LOADED_LO
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE

    jsr .compare
    bcc .fail_compare

    ldd .msg_pass[15:8]
    lde .msg_pass[7:0]
    jsr ACIA_SEND_STRING
    rts

; ---- helpers ----

.set_name:
    ldy 0x00
    ldd .fname[15:8]
    lde .fname[7:0]
    jmp STORAGE_SET_NAME

.set_length:
    lda 0x00
    sta CH376_REMAIN_LO
    lda SMOKE_PAGES
    sta CH376_REMAIN_HI
    rts

; 0xC000..0xC3FF = (index xor page)
.fill_pattern:
    ldd SMOKE_SRC_MSB
    lde 0x00
    ldy SMOKE_PAGES
.fill_page:
    ldx 0x00
.fill_byte:
    txa
    eor d
    sta de,x
    inx
    bne .fill_byte
    ind
    dey
    bne .fill_page
    rts

; C=1 if the two 1 KB buffers match.
.compare:
    ldy 0x00
.cmp_page:
    ldx 0x00
.cmp_byte:
    tya
    clc
    adc SMOKE_SRC_MSB
    tad
    lde 0x00
    lda de,x
    sta .cmp_tmp
    tya
    clc
    adc SMOKE_DST_MSB
    tad
    lde 0x00
    lda de,x
    cmp .cmp_tmp
    bne .cmp_fail
    inx
    bne .cmp_byte
    iny
    cpy SMOKE_PAGES
    bne .cmp_page
    sec
    rts
.cmp_fail:
    clc
    rts

; ---- failure exits ----

.fail_mount:
    ldd .msg_no_usb[15:8]
    lde .msg_no_usb[7:0]
    jmp .fail_status

.fail_create:
    ldd .msg_no_create[15:8]
    lde .msg_no_create[7:0]
    jmp .fail_status

.fail_write:
    lda 0x01
    jsr STORAGE_CLOSE
    ldd .msg_no_write[15:8]
    lde .msg_no_write[7:0]
    jmp .fail_status

.fail_open:
    ldd .msg_no_open[15:8]
    lde .msg_no_open[7:0]
    jmp .fail_status

.fail_read:
    lda 0x00
    jsr STORAGE_CLOSE
    ldd .msg_no_read[15:8]
    lde .msg_no_read[7:0]
    jmp .fail_status

.fail_compare:
    ldd .msg_mismatch[15:8]
    lde .msg_mismatch[7:0]
    jmp .fail_status

.fail_status:
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
    ldd .msg_fail[15:8]
    lde .msg_fail[7:0]
    jsr ACIA_SEND_STRING
    rts

.cmp_tmp:
    #d 0x00

.fname:
    #d "/OTSMOKE.BIN", 0x00

.msg_banner:
    #d 0x0A, 0x0D, "USB storage smoke test", 0x0A, 0x0D, 0x00
.msg_mounted:
    #d "Mounted.", 0x0A, 0x0D, 0x00
.msg_written:
    #d "Written 0x", 0x00
.msg_read:
    #d "Read    0x", 0x00
.msg_no_usb:
    #d "Mount failed ST ", 0x00
.msg_no_create:
    #d "Create failed ST ", 0x00
.msg_no_write:
    #d "Write failed ST ", 0x00
.msg_no_open:
    #d "Open failed ST ", 0x00
.msg_no_read:
    #d "Read failed ST ", 0x00
.msg_mismatch:
    #d "Data mismatch ST ", 0x00
.msg_pass:
    #d "PASS", 0x0A, 0x0D, 0x00
.msg_fail:
    #d "FAIL", 0x0A, 0x0D, 0x00
