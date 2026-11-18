; @load-address 0x8400
; REN — rename file via copy + delete (Otto OS).
;   ren OLD.TXT NEW.TXT
;
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#const RN_MSB = 0xC0
#const RN_CHUNK_HI = 0x04

#bank ram

    jsr os_take_arg
    bcc .bad
    jsr os_split_args
    bcc .bad
    lda OS_TMP
    beq .bad

    jsr os_set_name1
    bcc .usb
    jsr STORAGE_OPEN
    bcc .usb

    lda 0x00
    sta OS_MATCH_LO
    sta OS_MATCH_HI

.rd:
    lda 0x00
    sta CH376_REMAIN_LO
    lda RN_CHUNK_HI
    sta CH376_REMAIN_HI
    ldy 0x00
    lda OS_MATCH_HI
    clc
    adc RN_MSB
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
    cmp 0x20
    bcs .rdone
    lda CH376_LOADED_HI
    cmp RN_CHUNK_HI
    bcc .rdone
    jmp .rd

.rdone:
    lda 0x00
    jsr STORAGE_CLOSE

    jsr os_set_name2
    bcc .usb
    jsr STORAGE_CREATE
    bcc .usb
    lda OS_MATCH_LO
    sta CH376_REMAIN_LO
    lda OS_MATCH_HI
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd RN_MSB
    lde 0x00
    jsr STORAGE_WRITE
    bcc .usb
    lda 0x01
    jsr STORAGE_CLOSE

    ; delete old
    jsr os_set_name1
    bcc .usb
    jsr STORAGE_DELETE
    bcc .usb
    jsr os_ok
    rts

.bad:
    jsr os_err_arg
    rts
.usb:
    jsr os_err_usb
    rts

#include "os_lib.asm"
