; Destination / source range validation for USB transfers.
;
; Transfers are limited to a 16-bit length (max 65535 bytes, ~64 KB) and must
; not touch the device I/O aperture (0x6000-0x67FF) or the video RAM window
; (0x6800-0x7FFF), both of which only exist in page 0.

#once
#bank kernel

; **********************************************************
; SUBROUTINE: STORAGE_CHECK_RANGE
;
; INPUTS:
;   Y D E                  start address (page, high, low)
;   CH376_REMAIN_LO/HI     length in bytes (1..65535)
;
; OUTPUTS:
;   C=1 range usable, C=0 rejected
;
; DESTROY:
;   A X, CH376_CMP_*
; **********************************************************

STORAGE_CHECK_RANGE:
    phy
    phd
    phe
    lda CH376_REMAIN_LO
    ora CH376_REMAIN_HI
    beq .reject

    ; CH376_CMP_MSB:CH376_CMP_LSB = last byte address (start + length - 1)
    sec
    lda CH376_REMAIN_LO
    sbc 0x01
    sta CH376_CMP_LSB
    lda CH376_REMAIN_HI
    sbc 0x00
    sta CH376_CMP_MSB
    clc
    tea
    adc CH376_CMP_LSB
    sta CH376_CMP_LSB
    tda
    adc CH376_CMP_MSB
    sta CH376_CMP_MSB
    bcs .reject                 ; wraps past 0xFFFF into another page

    tya
    bne .accept                 ; expansion pages have no I/O aperture

    tda
    cmp 0x80
    bcs .accept                 ; starts above the reserved window
    lda CH376_CMP_MSB
    cmp 0x60
    bcs .reject                 ; ... and runs into 0x6000-0x7FFF

.accept:
    ple
    pld
    ply
    sec
    rts

.reject:
    ple
    pld
    ply
    clc
    rts
