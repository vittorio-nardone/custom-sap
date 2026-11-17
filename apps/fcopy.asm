; @load-address 0x8400
; FCOPY — copy file to file on USB (Otto OS).
;   fcopy SRC.TXT DST.TXT
; Uses a bounce buffer at 0xC000 (away from this app at 0x8400).
;
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#const FC_PAGE = 0x00
#const FC_MSB  = 0xC0
#const FC_LSB  = 0x00
#const FC_CHUNK = 0x00   ; lo
#const FC_CHUNK_HI = 0x04 ; 1 KB chunks

#bank ram

    jsr os_take_arg
    bcc .bad
    jsr os_split_args
    bcc .bad
    lda OS_TMP
    beq .bad

    ; open source
    jsr os_set_name1
    bcc .usb
    jsr STORAGE_OPEN
    bcc .usb

    ; create dest — must close source first, remember we need both
    ; Strategy: read all to 0xC000 (cap 8KB), close, create, write.
    lda 0x00
    sta OS_MATCH_LO
    sta OS_MATCH_HI

.rd:
    lda 0x00
    sta CH376_REMAIN_LO
    lda FC_CHUNK_HI
    sta CH376_REMAIN_HI
    ; dest = 0xC000 + total
    ldy FC_PAGE
    lda OS_MATCH_HI
    clc
    adc FC_MSB
    tad
    lda OS_MATCH_LO
    tae
    jsr STORAGE_READ
    bcc .rdone
    lda CH376_LOADED_LO
    ora CH376_LOADED_HI
    beq .rdone
    clc
    lda OS_MATCH_LO
    adc CH376_LOADED_LO
    sta OS_MATCH_LO
    lda OS_MATCH_HI
    adc CH376_LOADED_HI
    sta OS_MATCH_HI
    ; stop at 8 KB
    cmp 0x20
    bcs .rdone
    lda CH376_LOADED_HI
    cmp FC_CHUNK_HI
    bcc .rdone
    jmp .rd

.rdone:
    lda 0x00
    jsr STORAGE_CLOSE

    lda OS_MATCH_LO
    ora OS_MATCH_HI
    beq .empty

    jsr os_set_name2
    bcc .usb
    jsr STORAGE_CREATE
    bcc .usb

    lda OS_MATCH_LO
    sta CH376_REMAIN_LO
    lda OS_MATCH_HI
    sta CH376_REMAIN_HI
    ldy FC_PAGE
    ldd FC_MSB
    lde FC_LSB
    jsr STORAGE_WRITE
    bcc .usb
    lda 0x01
    jsr STORAGE_CLOSE
    jsr os_ok
    rts

.empty:
    ; create empty dest
    jsr os_set_name2
    bcc .usb
    jsr STORAGE_CREATE
    bcc .usb
    lda 0x01
    jsr STORAGE_CLOSE
    jsr os_ok
    rts

.bad:
    jsr os_err_arg
    rts
.usb:
    jsr os_err_usb
    rts

#include "os_lib.asm"
