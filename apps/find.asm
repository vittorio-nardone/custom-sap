; @load-address 0x8400
; FIND — search a string in a text file (Otto OS).
;   find NEEDLE FILE.TXT
; Prints "FOUND" + count, or "NONE".
;
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    jsr os_take_arg
    bcc .bad
    jsr os_split_args
    bcc .bad
    lda OS_TMP
    beq .bad

    ; NAME1 = needle, NAME2 = file
    ldx 0x00
.nlen:
    lda OS_NAME1,x
    beq .ngot
    inx
    cpx 0x10
    bcc .nlen
.ngot:
    stx OS_NEED
    lda OS_NEED
    beq .bad

    ; swap: bind file from NAME2
    jsr os_set_name2
    bcc .usb
    jsr STORAGE_OPEN
    bcc .usb

    lda 0x00
    sta OS_MATCH_LO
    sta OS_MATCH_HI
    sta OS_HAVE

.rd:
    lda 0x30
    sta CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd OS_BUF[15:8]
    lde OS_BUF[7:0]
    jsr STORAGE_READ
    bcc .eof
    lda CH376_LOADED_LO
    beq .eof
    ldx 0x00
.scan:
    cpx CH376_LOADED_LO
    bcs .next
    lda OS_BUF,x
    jsr os_upcase
    sta OS_TMP2
    ; compare against needle[OS_HAVE]
    ldy OS_HAVE
    lda OS_NAME1,y
    cmp OS_TMP2
    beq .hit
    ; mismatch: restart if current equals needle[0]
    lda 0x00
    sta OS_HAVE
    lda OS_NAME1
    cmp OS_TMP2
    bne .nx
    lda 0x01
    sta OS_HAVE
    jmp .nx
.hit:
    iny
    sty OS_HAVE
    cpy OS_NEED
    bcc .nx
    ; full match
    lda 0x00
    sta OS_HAVE
    inc OS_MATCH_LO
    bne .nx
    inc OS_MATCH_HI
.nx:
    inx
    jmp .scan
.next:
    lda CH376_LOADED_LO
    cmp 0x30
    bcc .eof
    jmp .rd

.eof:
    lda 0x00
    jsr STORAGE_CLOSE
    lda OS_MATCH_LO
    ora OS_MATCH_HI
    beq .none
    ldd .found[15:8]
    lde .found[7:0]
    jsr ACIA_SEND_STRING
    lda OS_MATCH_LO
    jsr ACIA_SEND_DECIMAL
    jsr ACIA_SEND_NEWLINE
    rts
.none:
    ldd .nomsg[15:8]
    lde .nomsg[7:0]
    jsr ACIA_SEND_STRING
    rts

.bad:
    jsr os_err_arg
    rts
.usb:
    jsr os_err_usb
    rts

.found:
    #d "FOUND ", 0x00
.nomsg:
    #d "NONE", 0x0A, 0x0D, 0x00

#include "os_lib.asm"
