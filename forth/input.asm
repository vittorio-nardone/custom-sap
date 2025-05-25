#once

; **********************************************************
; All input related stuff
; **********************************************************

F_16_RESET_INPUT:
    lda 0x00
    sta F_INPUT_BUFFER_COUNT_LSB
    sta F_INPUT_BUFFER_COUNT_MSB
    jsr F_16_RESET_BUFFER_PTR
    rts

F_16_INC_INPUT_COUNT:
    inc F_INPUT_BUFFER_COUNT_LSB
    bne .end
    inc F_INPUT_BUFFER_COUNT_MSB
.end:
    rts

F_16_DEC_INPUT_COUNT:
    dec F_INPUT_BUFFER_COUNT_LSB
    lda F_INPUT_BUFFER_COUNT_LSB
    cmp 0xFF
    bne .end
    dec F_INPUT_BUFFER_COUNT_MSB
.end:
    rts

F_16_CHECK_INPUT_COUNT_IS_ZERO:
    lda F_INPUT_BUFFER_COUNT_LSB
    bne .no
    lda F_INPUT_BUFFER_COUNT_MSB
    bne .no
    sec
    rts
.no:
    clc
    rts 

F_16_CHECK_MAX_INPUT_SIZE:
    lda F_MAX_INPUT_SIZE[7:0]
    cmp F_INPUT_BUFFER_COUNT_LSB
    bne .no
    lda F_MAX_INPUT_SIZE[15:8]
    cmp F_INPUT_BUFFER_COUNT_MSB
    bne .no
    sec
    rts
.no:
    clc
    rts 

#ruledef
{
    F_MACRO_16_GET_INPUT_BYTE => asm 
    {
        lda (F_INPUT_BUFFER_PTR_LSB)
    }
}


F_16_SET_INPUT_BYTE:
    sta (F_INPUT_BUFFER_PTR_LSB)
    rts

F_16_ADD_INPUT_BYTE:
    sta (F_INPUT_BUFFER_PTR_LSB)
    jsr F_16_INC_BUFFER_PTR
    jsr F_16_INC_INPUT_COUNT
    rts

F_16_DEL_INPUT_BYTE:
    jsr F_16_DEC_BUFFER_PTR
    jsr F_16_DEC_INPUT_COUNT
    rts

; **********************************************************
; All tokens related stuff
; **********************************************************

F_16_RESET_TOKEN_ALL:
    jsr F_16_RESET_TOKEN_COUNT
    jsr F_16_RESET_TOKEN_START
    jsr F_16_RESET_TOKEN_POS

F_16_RESET_TOKEN_COUNT:
    lda 0x00
    sta F_TOKEN_COUNT_LSB
    sta F_TOKEN_COUNT_MSB
    rts

F_16_INC_TOKEN_COUNT:
    inc F_TOKEN_COUNT_LSB
    bne .end
    inc F_TOKEN_COUNT_MSB
.end:
    rts

F_16_CHECK_TOKEN_COUNT_IS_ZERO:
    lda F_TOKEN_COUNT_LSB
    ora F_TOKEN_COUNT_MSB
    bne .no
    sec
    rts
.no:
    clc
    rts

F_16_RESET_TOKEN_START:
    lda 0x00
    sta F_TOKEN_START_LSB
    sta F_TOKEN_START_MSB
    rts

F_16_INC_TOKEN_START:
    inc F_TOKEN_START_LSB
    bne .end
    inc F_TOKEN_START_MSB
.end:
    rts

F_16_ADD_COUNT_TO_TOKEN_START:
    clc
    lda F_TOKEN_START_LSB
    adc F_TOKEN_COUNT_LSB
    sta F_TOKEN_START_LSB
    lda F_TOKEN_START_MSB
    adc F_TOKEN_COUNT_MSB
    sta F_TOKEN_START_MSB
    rts

F_16_RESET_TOKEN_POS:
    lda 0x00
    sta F_TOKEN_POS_LSB
    sta F_TOKEN_POS_MSB
    jsr F_16_RESET_BUFFER_PTR
    rts

F_16_INC_TOKEN_POS:
    inc F_TOKEN_POS_LSB
    bne .end
    inc F_TOKEN_POS_MSB
.end:
    jsr F_16_INC_BUFFER_PTR
    rts

F_16_SET_TOKEN_POS_TO_START:
    lda F_TOKEN_START_LSB
    sta F_TOKEN_POS_LSB
    lda F_TOKEN_START_MSB
    sta F_TOKEN_POS_MSB
    jsr F_16_SET_BUFFER_PTR_TO_TOKEN_POS
    rts

F_16_SET_TOKEN_POS_TO_START_PLUS_COUNT:
    clc
    lda F_TOKEN_START_LSB
    adc F_TOKEN_COUNT_LSB
    sta F_TOKEN_POS_LSB
    lda F_TOKEN_START_MSB
    adc F_TOKEN_COUNT_MSB
    sta F_TOKEN_POS_MSB
    jsr F_16_SET_BUFFER_PTR_TO_TOKEN_POS
    rts

F_16_CHECK_END_OF_TOKEN:
    sec
    lda F_TOKEN_POS_LSB
    sbc F_TOKEN_START_LSB
    cmp F_TOKEN_COUNT_LSB
    bne .no
    lda F_TOKEN_POS_MSB 
    sbc F_TOKEN_START_MSB
    cmp F_TOKEN_COUNT_MSB
    bne .no
    sec
    rts
.no:
    clc
    rts

F_16_CHECK_POS_END_OF_FILE:
    lda F_TOKEN_POS_LSB
    cmp F_INPUT_BUFFER_COUNT_LSB
    bne .no
    lda F_TOKEN_POS_MSB 
    cmp F_INPUT_BUFFER_COUNT_MSB
    bne .no
    sec
    rts
.no:
    clc
    rts

F_16_CHECK_START_END_OF_FILE:
    lda F_TOKEN_START_LSB
    cmp F_INPUT_BUFFER_COUNT_LSB
    bne .no
    lda F_TOKEN_START_MSB 
    cmp F_INPUT_BUFFER_COUNT_MSB
    bne .no
    sec
    rts
.no:
    clc
    rts

; .. token PTR is internally managed by other routines

F_16_INC_BUFFER_PTR:
    inc F_INPUT_BUFFER_PTR_LSB
    bne .end
    inc F_INPUT_BUFFER_PTR_MSB
.end:
    rts

F_16_DEC_BUFFER_PTR:
    dec F_INPUT_BUFFER_PTR_LSB
    lda F_INPUT_BUFFER_PTR_LSB
    cmp 0xFF
    bne .end
    dec F_INPUT_BUFFER_PTR_MSB
.end:
    rts

F_16_RESET_BUFFER_PTR:
    lda F_INPUT_BUFFER_START_LSB
    sta F_INPUT_BUFFER_PTR_LSB
    lda F_INPUT_BUFFER_START_MSB
    sta F_INPUT_BUFFER_PTR_MSB
    rts

F_16_SET_BUFFER_PTR_TO_TOKEN_POS:
    clc
    lda F_INPUT_BUFFER_START_LSB
    adc F_TOKEN_POS_LSB
    sta F_INPUT_BUFFER_PTR_LSB
    lda F_INPUT_BUFFER_START_MSB
    adc F_TOKEN_POS_MSB
    sta F_INPUT_BUFFER_PTR_MSB
    rts
