#once

; **********************************************************
; All loops related stuff
; **********************************************************

F_DO_LOOP_PUSH_FROM_STACK:
    ; TODO: check max size
    jsr F_STACK_PULL
    bcc .end    
    lda F_TOKEN_VALUE
    tay
    
    jsr F_STACK_PULL
    bcc .end    
    lda F_TOKEN_VALUE

    ldx F_DO_LOOP_COUNT    
    ldd F_TOKEN_START
    std F_DO_LOOP_START, x  ;do token start
    inx
    sta F_DO_LOOP_START, x  ;limit
    inx
    sty F_DO_LOOP_START, x  ;index
    inx
    stx F_DO_LOOP_COUNT 
.end:
    rts

F_DO_LOOP_INC_INDEX:
    jsr F_CHECK_DO_LOOP_STACK_EMPTY
    bcc .end
    ldx F_DO_LOOP_COUNT
    dex
    ldy F_DO_LOOP_START, x 
    iny
    sty F_DO_LOOP_START, x 
    tya
    dex
    cmp F_DO_LOOP_START, x
    beq .do_end
    bcs .do_end
    dex
    lda F_DO_LOOP_START, x 
    sta F_TOKEN_START
    sec
    rts

.do_end:
    dex
    stx F_DO_LOOP_COUNT
    clc
.end:
    rts

F_DO_LOOP_INC_INDEX_FROM_STACK:
    jsr F_STACK_PULL
    bcc .end    

    jsr F_CHECK_DO_LOOP_STACK_EMPTY
    bcc .end

    ldx F_DO_LOOP_COUNT
    dex

    clc
    lda F_DO_LOOP_START, x 
    adc F_TOKEN_VALUE
    sta F_DO_LOOP_START, x 

    dex
    cmp F_DO_LOOP_START, x
    beq .do_end
    bcs .do_end
    dex
    lda F_DO_LOOP_START, x 
    sta F_TOKEN_START
    sec
    rts

.do_end:
    dex
    stx F_DO_LOOP_COUNT
    clc
.end:
    rts


F_CHECK_DO_LOOP_STACK_EMPTY:
    lda F_DO_LOOP_COUNT
    beq .stack_is_empty
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
    #d "DO-LOOP stack empty" 
    #d 0x00

F_BI_DO_LABEL:
    #d "DO", 0x00
F_BI_DO:
    jsr F_DO_LOOP_PUSH_FROM_STACK
    rts

F_BI_LOOP_LABEL:
    #d "LOOP", 0x00
F_BI_LOOP:
    jsr F_DO_LOOP_INC_INDEX
    bcs .back_to_do
    rts
.back_to_do:
    lda 0x02
    sta F_TOKEN_COUNT
    rts

F_BI_PLUS_LOOP_LABEL:
    #d "+LOOP", 0x00
F_BI_PLUS_LOOP:
    jsr F_DO_LOOP_INC_INDEX_FROM_STACK
    bcs .back_to_do
    rts
.back_to_do:
    lda 0x02
    sta F_TOKEN_COUNT
    rts

F_BI_I_LABEL:
    #d "I", 0x00
F_BI_I:
    jsr F_CHECK_DO_LOOP_STACK_EMPTY
    bcc .end
    ldx F_DO_LOOP_COUNT
    dex
    lda F_DO_LOOP_START, x 
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_LEAVE_LABEL:
    #d "LEAVE", 0x00
F_BI_LEAVE:
    jsr F_CHECK_DO_LOOP_STACK_EMPTY
    bcc .end

.search_loop:
    ; search for LOOP
    lda F_BI_LOOP_LABEL[15:8]
    sta F_FIND_TOKEN_MSB
    lda F_BI_LOOP_LABEL[7:0]
    sta F_FIND_TOKEN_LSB
    jsr F_FIND_TOKEN

    lda F_FIND_TOKEN_COUNT
    pha
    lda F_FIND_TOKEN_START
    pha

.search_plusloop:
    ; search for +LOOP
    lda F_BI_PLUS_LOOP_LABEL[15:8]
    sta F_FIND_TOKEN_MSB
    lda F_BI_PLUS_LOOP_LABEL[7:0]
    sta F_FIND_TOKEN_LSB
    jsr F_FIND_TOKEN

    lda F_FIND_TOKEN_COUNT
    beq .use_loop
    pla
    cmp F_FIND_TOKEN_START
    pha
    bcc .use_loop
    pla
    pla
    lda F_FIND_TOKEN_START
    sta F_TOKEN_START
    lda F_FIND_TOKEN_COUNT
    sta F_TOKEN_COUNT
    jmp .exit_loop

.use_loop:
    plx
    pla
    beq .not_found
    stx F_TOKEN_START
    sta F_TOKEN_COUNT

.exit_loop:
    ldx F_DO_LOOP_COUNT
    dex
    dex
    dex
    stx F_DO_LOOP_COUNT
    rts

.not_found:
    lda F_STATUS_COUNT
    beq .not_found_error
    jsr F_PULL_STATUS
    jmp .search_loop

.not_found_error:
    lda .not_found_error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .not_found_error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
.end:
    rts    

.not_found_error_msg:
    #d "LOOP/+LOOP not found" 
    #d 0x00
