#once
; **********************************************************
; All stack-related stuff
; **********************************************************

F_STACK_PUSH:
    ; TODO: check max stack size
    lda F_TOKEN_VALUE
    ldx F_STACK_COUNT
    sta F_STACK_START, x
    inc F_STACK_COUNT 
    rts

F_STACK_PULL:
    ldx F_STACK_COUNT
    beq .stack_is_empty
    dex 
    stx F_STACK_COUNT
    lda F_STACK_START, x
    sta F_TOKEN_VALUE 
    sec
    rts

.stack_is_empty:
    lda .stack_is_empty_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .stack_is_empty_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    clc
    rts    

.stack_is_empty_msg:
    #d "Stack empty" 
    #d 0x00


F_STACK_PUSH_TRUE:
    lda 0xFF
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
    rts

F_STACK_PUSH_FALSE:
    lda 0x00
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
    rts

F_STACK_PRINT:
    ldx 0x00
.loop:
    cpx F_STACK_COUNT
    beq .end 
    lda F_STACK_START, x
    phx
    jsr ACIA_SEND_DECIMAL
    plx
    lda 0x20
    jsr ACIA_SEND_CHAR
    inx
    jmp .loop
.end:
    rts