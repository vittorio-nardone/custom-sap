; OT application header helpers.
;
; Layout (same as scripts/python/add_header.py and the XMODEM loader):
;   0x4F 0x54 0x01 <page> <high> <low>

#once
#bank kernel

; **********************************************************
; SUBROUTINE: STORAGE_OT_CHECK
;
; DESCRIPTION:
;   Test the 6 bytes at Y:DE for an OT header.
;
; INPUTS:
;   Y D E   pointer to the candidate header
;
; OUTPUTS:
;   C=1 header found and STORAGE_LOAD_PTRP/H/PTR updated from it
;   C=0 no header (STORAGE_LOAD_* untouched)
;
; DESTROY:
;   A X
; **********************************************************

STORAGE_OT_CHECK:
    ldx 0x00
    lda yde,x
    cmp STORAGE_OT_MAGIC0
    bne .no_header
    ldx 0x01
    lda yde,x
    cmp STORAGE_OT_MAGIC1
    bne .no_header
    ldx 0x03
    lda yde,x
    sta STORAGE_LOAD_PTRP
    inx
    lda yde,x
    sta STORAGE_LOAD_PTRH
    inx
    lda yde,x
    sta STORAGE_LOAD_PTR
    sec
    rts
.no_header:
    clc
    rts

; **********************************************************
; SUBROUTINE: STORAGE_OT_WRITE_HDR
;
; DESCRIPTION:
;   Build an OT header for CH376_SAVE_* and write it to the open file.
;
; INPUTS:
;   CH376_SAVE_PAGE/MSB/LSB   address to record in the header
;
; OUTPUTS:
;   C=1 written, C=0 failed
;
; DESTROY:
;   A X Y D E, CH376_BUF (first 6 bytes), CH376_REMAIN_*, CH376_LOADED_*
; **********************************************************

STORAGE_OT_WRITE_HDR:
    lda STORAGE_OT_MAGIC0
    sta CH376_BUF
    lda STORAGE_OT_MAGIC1
    sta CH376_BUF+1
    lda STORAGE_OT_VER
    sta CH376_BUF+2
    lda CH376_SAVE_PAGE
    sta CH376_BUF+3
    lda CH376_SAVE_MSB
    sta CH376_BUF+4
    lda CH376_SAVE_LSB
    sta CH376_BUF+5
    lda STORAGE_OT_SIZE
    sta CH376_REMAIN_LO
    lda 0x00
    sta CH376_REMAIN_HI
    ldy 0x00
    ldd CH376_BUF[15:8]
    lde CH376_BUF[7:0]
    jmp ch376_file_write_from
