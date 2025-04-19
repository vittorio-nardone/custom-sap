#once

; **********************************************************
; All math related stuff
; **********************************************************

F_BI_SUM_LABEL:
    #d "+", 0x00
F_BI_SUM:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    clc
    adc F_TOKEN_VALUE
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_SUB_LABEL:
    #d "-", 0x00
F_BI_SUB:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pld
    bcc .end
    sec
    lda F_TOKEN_VALUE
    sbc d
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_MUL_LABEL:
    #d "*", 0x00
F_BI_MUL:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    ldx F_TOKEN_VALUE
    jsr MULTIPLY_INT
 
    stx F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_DIV_LABEL:
    #d "/", 0x00
F_BI_DIV:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    ply
    bcc .end
    ldx F_TOKEN_VALUE
    jsr DIVIDE_INT
 
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_MOD_LABEL:
    #d "MOD", 0x00
F_BI_MOD:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    ply
    bcc .end
    ldx F_TOKEN_VALUE
    jsr DIVIDE_INT
 
    stx F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_SLASH_MOD_LABEL:
    #d "/MOD", 0x00
F_BI_SLASH_MOD:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    ply
    bcc .end
    ldx F_TOKEN_VALUE
    jsr DIVIDE_INT
    pha
    stx F_TOKEN_VALUE
    jsr F_STACK_PUSH
    pla
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_ONE_PLUS_LABEL:
    #d "1+", 0x00
F_BI_ONE_PLUS: 
    lda 0x01
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
    jsr F_BI_SUM
    rts

F_BI_TWO_PLUS_LABEL:
    #d "2+", 0x00
F_BI_TWO_PLUS: 
    lda 0x02
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
    jsr F_BI_SUM
    rts

F_BI_ONE_LESS_LABEL:
    #d "1-", 0x00
F_BI_ONE_LESS: 
    lda 0x01
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
    jsr F_BI_SUB
    rts

F_BI_TWO_LESS_LABEL:
    #d "2-", 0x00
F_BI_TWO_LESS: 
    lda 0x02
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
    jsr F_BI_SUB
    rts

F_BI_TWO_MUL_LABEL:
    #d "2*", 0x00
F_BI_TWO_MUL: 
    lda 0x02
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
    jsr F_BI_MUL
    rts

F_BI_TWO_DIV_LABEL:
    #d "2/", 0x00
F_BI_TWO_DIV: 
    lda 0x02
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
    jsr F_BI_DIV
    rts

F_BI_MAX_LABEL:
    #d "MAX", 0x00
F_BI_MAX:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    cmp F_TOKEN_VALUE
    bcc .push_second
    sta F_TOKEN_VALUE
.push_second:
    jsr F_STACK_PUSH
.end:
    rts

F_BI_MIN_LABEL:
    #d "MIN", 0x00
F_BI_MIN:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    cmp F_TOKEN_VALUE
    bcs .push_second
    sta F_TOKEN_VALUE
.push_second:
    jsr F_STACK_PUSH
.end:
    rts

F_BI_EQUAL_LABEL:
    #d "=", 0x00
F_BI_EQUAL:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    cmp F_TOKEN_VALUE
    beq .push_true
    jsr F_STACK_PUSH_FALSE 
    rts
.push_true:
    jsr F_STACK_PUSH_TRUE 
.end:
    rts

F_BI_DISEQUAL_LABEL:
    #d "<>", 0x00
F_BI_DISEQUAL:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    cmp F_TOKEN_VALUE
    bne .push_true
    jsr F_STACK_PUSH_FALSE 
    rts
.push_true:
    jsr F_STACK_PUSH_TRUE 
.end:
    rts

F_BI_GREATER_LABEL:
    #d "<", 0x00
F_BI_GREATER:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    cmp F_TOKEN_VALUE
    beq .push_false
    bcc .push_false
    jsr F_STACK_PUSH_TRUE
    rts
.push_false:
    jsr F_STACK_PUSH_FALSE 
.end:
    rts

F_BI_SMALLER_LABEL:
    #d ">", 0x00
F_BI_SMALLER:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    cmp F_TOKEN_VALUE
    beq .push_false
    bcs .push_false
    jsr F_STACK_PUSH_TRUE
    rts
.push_false:
    jsr F_STACK_PUSH_FALSE 
.end:
    rts

F_BI_IS_ZERO_LABEL:
    #d "0=", 0x00
F_BI_IS_ZERO:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    beq .push_true
    jsr F_STACK_PUSH_FALSE 
    rts
.push_true:
    jsr F_STACK_PUSH_TRUE 
.end:
    rts

F_BI_IS_MORE_THAN_ZERO_LABEL:
    #d "0>", 0x00
F_BI_IS_MORE_THAN_ZERO:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    bne .push_true
    jsr F_STACK_PUSH_FALSE 
    rts
.push_true:
    jsr F_STACK_PUSH_TRUE 
.end:
    rts

F_BI_AND_LABEL:
    #d "AND", 0x00
F_BI_AND:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    and F_TOKEN_VALUE
    beq .push_false
    jsr F_STACK_PUSH_TRUE
    rts
.push_false:
    jsr F_STACK_PUSH_FALSE 
.end:
    rts

F_BI_OR_LABEL:
    #d "OR", 0x00
F_BI_OR:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    jsr F_STACK_PULL
    pla
    bcc .end
    ora F_TOKEN_VALUE
    beq .push_false
    jsr F_STACK_PUSH_TRUE
    rts
.push_false:
    jsr F_STACK_PUSH_FALSE 
.end:
    rts