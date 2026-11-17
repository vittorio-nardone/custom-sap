; @load-address 0x8400
; MORE — page through a text file (Otto OS).
;   more FILE.TXT
; Space/Enter = next page, Q = quit.
;
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#const MORE_PAGE_LINES = 0x14

#bank ram

    jsr os_take_arg
    bcc .bad
    jsr os_split_args
    bcc .bad
    jsr os_set_name1
    bcc .usb
    jsr STORAGE_OPEN
    bcc .usb

    lda 0x00
    sta OS_LINES

.rd:
    lda 0x20
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
.pr:
    cpx CH376_LOADED_LO
    bcs .next
    lda OS_BUF,x
    cmp 0x0A
    beq .nl
    cmp 0x0D
    beq .nx
    cmp 0x20
    bcc .dot
    cmp 0x7F
    bcs .dot
    jsr ACIA_SEND_CHAR
    jmp .nx
.nl:
    jsr ACIA_SEND_NEWLINE
    inc OS_LINES
    lda OS_LINES
    cmp MORE_PAGE_LINES
    bcc .nx
    jsr .pause
    bcs .quit
    lda 0x00
    sta OS_LINES
    jmp .nx
.dot:
    lda 0x2E
    jsr ACIA_SEND_CHAR
.nx:
    inx
    jmp .pr
.next:
    lda CH376_LOADED_LO
    cmp 0x20
    bcc .eof
    jmp .rd

.eof:
    lda 0x00
    jsr STORAGE_CLOSE
    jsr ACIA_SEND_NEWLINE
    rts

.quit:
    lda 0x00
    jsr STORAGE_CLOSE
    jsr ACIA_SEND_NEWLINE
    rts

.pause:
    ldd .more[15:8]
    lde .more[7:0]
    jsr ACIA_SEND_STRING
.wait:
    jsr ACIA_READ_CHAR
    cmp 0x71
    beq .pq
    cmp 0x51
    beq .pq
    cmp 0x20
    beq .pok
    cmp 0x0D
    beq .pok
    cmp 0x0A
    beq .pok
    jmp .wait
.pok:
    clc
    rts
.pq:
    sec
    rts

.bad:
    jsr os_err_arg
    rts
.usb:
    jsr os_err_usb
    rts

.more:
    #d "-- more --", 0x0D, 0x00

#include "os_lib.asm"
