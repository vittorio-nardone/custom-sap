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
    ldd F_TOKEN_START_LSB
    std F_DO_LOOP_START, x  ;do token start LSB
    inx
    ldd F_TOKEN_START_MSB
    std F_DO_LOOP_START, x  ;do token start MSB
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
    sta F_TOKEN_START_MSB
    dex
    lda F_DO_LOOP_START, x 
    sta F_TOKEN_START_LSB
    sec
    rts

.do_end:
    dex
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
    sta F_TOKEN_START_MSB
    dex
    lda F_DO_LOOP_START, x 
    sta F_TOKEN_START_LSB
    sec
    rts

.do_end:
    dex
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
    sta F_TOKEN_COUNT_LSB
    lda 0x00
    sta F_TOKEN_COUNT_MSB
    rts

F_BI_PLUS_LOOP_LABEL:
    #d "+LOOP", 0x00
F_BI_PLUS_LOOP:
    jsr F_DO_LOOP_INC_INDEX_FROM_STACK
    bcs .back_to_do
    rts
.back_to_do:
    lda 0x02
    sta F_TOKEN_COUNT_LSB
    lda 0x00
    sta F_TOKEN_COUNT_MSB
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
    lda 0x00
    sta F_FIND_TOKEN_START_LIMIT_LSB
    sta F_FIND_TOKEN_START_LIMIT_MSB

    ; search for LOOP
    lda F_BI_LOOP_LABEL[15:8]
    sta F_FIND_TOKEN_MSB
    lda F_BI_LOOP_LABEL[7:0]
    sta F_FIND_TOKEN_LSB
    jsr F_FIND_TOKEN

    lda F_FIND_TOKEN_START_MSB
    sta F_FIND_TOKEN_START_LIMIT_MSB
    pha
    lda F_FIND_TOKEN_START_LSB
    sta F_FIND_TOKEN_START_LIMIT_LSB
    pha
    lda F_FIND_TOKEN_COUNT_MSB
    pha
    lda F_FIND_TOKEN_COUNT_LSB
    pha

.search_plusloop:
    ; search for +LOOP
    lda F_BI_PLUS_LOOP_LABEL[15:8]
    sta F_FIND_TOKEN_MSB
    lda F_BI_PLUS_LOOP_LABEL[7:0]
    sta F_FIND_TOKEN_LSB
    jsr F_FIND_TOKEN
    bcc .use_loop
    
.use_plusloop:
    pla
    pla
    pla
    pla

    lda F_FIND_TOKEN_START_LSB
    sta F_TOKEN_START_LSB
    lda F_FIND_TOKEN_START_MSB
    sta F_TOKEN_START_MSB
    lda F_FIND_TOKEN_COUNT_LSB
    sta F_TOKEN_COUNT_LSB
    lda F_FIND_TOKEN_COUNT_MSB
    sta F_TOKEN_COUNT_MSB
    jmp .exit_loop

.use_loop:
    pla
    beq .not_found
    sta F_TOKEN_COUNT_LSB
    pla
    sta F_TOKEN_COUNT_MSB
    pla
    sta F_TOKEN_START_LSB
    pla
    sta F_TOKEN_START_MSB

.exit_loop:
    ldx F_DO_LOOP_COUNT
    dex
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



; BEGIN UNTIL
F_BEGIN_UNTIL_PUSH:
    ; TODO: check max size
    ldx F_BEGIN_UNTIL_COUNT    
    lda F_TOKEN_START_LSB
    sta F_BEGIN_UNTIL_START, x  ;begin token start
    inx
    lda F_TOKEN_START_MSB
    sta F_BEGIN_UNTIL_START, x  
    inx
    stx F_BEGIN_UNTIL_COUNT 
.end:
    rts


F_CHECK_BEGIN_UNTIL_STACK_EMPTY:
    lda F_BEGIN_UNTIL_COUNT
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
    #d "BEGIN-UNTIL stack empty" 
    #d 0x00

F_BEGIN_UNTIL_CHECK:
    jsr F_CHECK_BEGIN_UNTIL_STACK_EMPTY
    bcc .end

    jsr F_STACK_PULL
    bcc .end   

    lda F_TOKEN_VALUE
    bne .check_true

    ldx F_BEGIN_UNTIL_COUNT
    dex
    lda F_BEGIN_UNTIL_START, x  
    sta F_TOKEN_START_MSB
    dex
    lda F_BEGIN_UNTIL_START, x  
    sta F_TOKEN_START_LSB
    sec
    rts
.check_true:
    dec F_BEGIN_UNTIL_COUNT
    dec F_BEGIN_UNTIL_COUNT
    clc
.end:
    rts

F_BEGIN_WHILE_CHECK:
    jsr F_CHECK_BEGIN_UNTIL_STACK_EMPTY
    bcc .end
    
    jsr F_STACK_PULL
    bcc .end  
    
    lda F_TOKEN_VALUE
    bne .end

    ; remove loop from stack
    dec F_BEGIN_UNTIL_COUNT
    dec F_BEGIN_UNTIL_COUNT
    lda 0x00
    sta F_FIND_TOKEN_START_LIMIT_LSB
    sta F_FIND_TOKEN_START_LIMIT_MSB
    
    ; search for REPEAT
    lda .repeat_msg[15:8]
    sta F_FIND_TOKEN_MSB
    lda .repeat_msg[7:0]
    sta F_FIND_TOKEN_LSB
    jsr F_FIND_TOKEN
    bcc .repeat_not_found_error

    lda F_FIND_TOKEN_START_LSB
    sta F_TOKEN_START_LSB
    lda F_FIND_TOKEN_START_MSB
    sta F_TOKEN_START_MSB
    lda F_FIND_TOKEN_COUNT_LSB
    sta F_TOKEN_COUNT_LSB
    lda F_FIND_TOKEN_COUNT_MSB
    sta F_TOKEN_COUNT_MSB

.end:
    rts

.repeat_not_found_error:
    lda .repeat_not_found_error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .repeat_not_found_error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    rts

.repeat_msg:
    #d "REPEAT", 0x00
.repeat_not_found_error_msg:
    #d "REPEAT EXPECTED"
    #d 0x00

F_BI_BEGIN_LABEL:
    #d "BEGIN", 0x00
F_BI_BEGIN:
    jsr F_BEGIN_UNTIL_PUSH
    rts

F_BI_UNTIL_LABEL:
    #d "UNTIL", 0x00
F_BI_UNTIL:
    jsr F_BEGIN_UNTIL_CHECK
    bcs .back_to_begin
    rts
.back_to_begin:
    lda 0x05
    sta F_TOKEN_COUNT_LSB
    lda 0x00
    sta F_TOKEN_COUNT_MSB
    rts

F_BI_WHILE_LABEL:
    #d "WHILE", 0x00
F_BI_WHILE:
    jsr F_BEGIN_WHILE_CHECK
    rts

F_BI_AGAIN_LABEL:
    #d "AGAIN", 0x00
F_BI_AGAIN:
    jsr F_CHECK_BEGIN_UNTIL_STACK_EMPTY
    bcc .end
    ldx F_BEGIN_UNTIL_COUNT
    dex
    lda F_BEGIN_UNTIL_START, x  
    sta F_TOKEN_START_MSB
    dex
    lda F_BEGIN_UNTIL_START, x  
    sta F_TOKEN_START_LSB
    lda 0x05
    sta F_TOKEN_COUNT_LSB
    lda 0x00
    sta F_TOKEN_COUNT_MSB
.end:
    rts

F_BI_REPEAT_LABEL:
    #d "REPEAT", 0x00
F_BI_REPEAT:
    jsr F_CHECK_BEGIN_UNTIL_STACK_EMPTY
    bcc .end
    ldx F_BEGIN_UNTIL_COUNT
    dex
    lda F_BEGIN_UNTIL_START, x  
    sta F_TOKEN_START_MSB
    dex
    lda F_BEGIN_UNTIL_START, x  
    sta F_TOKEN_START_LSB
    lda 0x05
    sta F_TOKEN_COUNT_LSB
    lda 0x00
    sta F_TOKEN_COUNT_MSB
.end:
    rts