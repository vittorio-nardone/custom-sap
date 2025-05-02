#once

; **********************************************************
; All built-in related stuff
; **********************************************************

F_DICT_BUILT_IN_START:
    #d F_BI_EMARK_LABEL[7:0], F_BI_EMARK_LABEL[15:8], F_BI_EMARK[7:0], F_BI_EMARK[15:8] ; "!"
    #d F_BI_AT_LABEL[7:0], F_BI_AT_LABEL[15:8], F_BI_AT[7:0], F_BI_AT[15:8] ; "@"
    #d F_BI_QMARK_LABEL[7:0], F_BI_QMARK_LABEL[15:8], F_BI_QMARK[7:0], F_BI_QMARK[15:8] ; "?"
    #d F_BI_PLUS_EMARK_LABEL[7:0], F_BI_PLUS_EMARK_LABEL[15:8], F_BI_PLUS_EMARK[7:0], F_BI_PLUS_EMARK[15:8] ; "+!"
    #d F_BI_SUM_LABEL[7:0], F_BI_SUM_LABEL[15:8], F_BI_SUM[7:0], F_BI_SUM[15:8] ; "+"
    #d F_BI_SUB_LABEL[7:0], F_BI_SUB_LABEL[15:8], F_BI_SUB[7:0], F_BI_SUB[15:8] ; "-"
    #d F_BI_MUL_LABEL[7:0], F_BI_MUL_LABEL[15:8], F_BI_MUL[7:0], F_BI_MUL[15:8] ; "*"
    #d F_BI_DIV_LABEL[7:0], F_BI_DIV_LABEL[15:8], F_BI_DIV[7:0], F_BI_DIV[15:8] ; "/"
    #d F_BI_COMMENT_LABEL[7:0], F_BI_COMMENT_LABEL[15:8], F_BI_COMMENT[7:0], F_BI_COMMENT[15:8] ; "("
    #d F_BI_SLASH_MOD_LABEL[7:0], F_BI_SLASH_MOD_LABEL[15:8], F_BI_SLASH_MOD[7:0], F_BI_SLASH_MOD[15:8] ; "/MOD"
    #d F_BI_DISPLAY_LABEL[7:0], F_BI_DISPLAY_LABEL[15:8], F_BI_DISPLAY[7:0], F_BI_DISPLAY[15:8] ; "."
    #d F_BI_DOT_QUOTE_LABEL[7:0], F_BI_DOT_QUOTE_LABEL[15:8], F_BI_DOT_QUOTE[7:0], F_BI_DOT_QUOTE[15:8] ; ".""
    #d F_BI_DISPLAY_STACK_LABEL[7:0], F_BI_DISPLAY_STACK_LABEL[15:8], F_BI_DISPLAY_STACK[7:0], F_BI_DISPLAY_STACK[15:8] ; ".S"
    #d F_BI_IS_MORE_THAN_ZERO_LABEL[7:0], F_BI_IS_MORE_THAN_ZERO_LABEL[15:8], F_BI_IS_MORE_THAN_ZERO[7:0], F_BI_IS_MORE_THAN_ZERO[15:8] ; "0>"
    #d F_BI_IS_ZERO_LABEL[7:0], F_BI_IS_ZERO_LABEL[15:8], F_BI_IS_ZERO[7:0], F_BI_IS_ZERO[15:8] ; "0="
    #d F_BI_ONE_PLUS_LABEL[7:0], F_BI_ONE_PLUS_LABEL[15:8], F_BI_ONE_PLUS[7:0], F_BI_ONE_PLUS[15:8] ; "1+"
    #d F_BI_ONE_LESS_LABEL[7:0], F_BI_ONE_LESS_LABEL[15:8], F_BI_ONE_LESS[7:0], F_BI_ONE_LESS[15:8] ; "1-"
    #d F_BI_TWO_PLUS_LABEL[7:0], F_BI_TWO_PLUS_LABEL[15:8], F_BI_TWO_PLUS[7:0], F_BI_TWO_PLUS[15:8] ; "2+"
    #d F_BI_TWO_LESS_LABEL[7:0], F_BI_TWO_LESS_LABEL[15:8], F_BI_TWO_LESS[7:0], F_BI_TWO_LESS[15:8] ; "2-"
    #d F_BI_TWO_MUL_LABEL[7:0], F_BI_TWO_MUL_LABEL[15:8], F_BI_TWO_MUL[7:0], F_BI_TWO_MUL[15:8] ; "2*"
    #d F_BI_TWO_DIV_LABEL[7:0], F_BI_TWO_DIV_LABEL[15:8], F_BI_TWO_DIV[7:0], F_BI_TWO_DIV[15:8] ; "2/"
    #d F_BI_2DUP_LABEL[7:0], F_BI_2DUP_LABEL[15:8], F_BI_2DUP[7:0], F_BI_2DUP[15:8] ; "2DUP"
    #d F_BI_2DROP_LABEL[7:0], F_BI_2DROP_LABEL[15:8], F_BI_2DROP[7:0], F_BI_2DROP[15:8] ; "2DROP"
    #d F_BI_ABORT_QUOTE_LABEL[7:0], F_BI_ABORT_QUOTE_LABEL[15:8], F_BI_ABORT_QUOTE[7:0], F_BI_ABORT_QUOTE[15:8] ; "ABORT""
    #d F_BI_AGAIN_LABEL[7:0], F_BI_AGAIN_LABEL[15:8], F_BI_AGAIN[7:0], F_BI_AGAIN[15:8] ; "AGAIN"
    #d F_BI_AND_LABEL[7:0], F_BI_AND_LABEL[15:8], F_BI_AND[7:0], F_BI_AND[15:8] ; "AND"
    #d F_BI_BEGIN_LABEL[7:0], F_BI_BEGIN_LABEL[15:8], F_BI_BEGIN[7:0], F_BI_BEGIN[15:8] ; "BEGIN"
    #d F_BI_BYE_LABEL[7:0], F_BI_BYE_LABEL[15:8], F_BI_BYE[7:0], F_BI_BYE[15:8] ; "BYE"
    #d F_BI_CONSTANT_LABEL[7:0], F_BI_CONSTANT_LABEL[15:8], F_BI_CONSTANT[7:0], F_BI_CONSTANT[15:8] ; "CONSTANT"
    #d F_BI_CR_LABEL[7:0], F_BI_CR_LABEL[15:8], F_BI_CR[7:0], F_BI_CR[15:8] ; "CR"
    #d F_BI_DISEQUAL_LABEL[7:0], F_BI_DISEQUAL_LABEL[15:8], F_BI_DISEQUAL[7:0], F_BI_DISEQUAL[15:8] ; "<>"
    #d F_BI_SMALLER_LABEL[7:0], F_BI_SMALLER_LABEL[15:8], F_BI_SMALLER[7:0], F_BI_SMALLER[15:8] ; "<"
    #d F_BI_DO_LABEL[7:0], F_BI_DO_LABEL[15:8], F_BI_DO[7:0], F_BI_DO[15:8] ; "DO"
    #d F_BI_DROP_LABEL[7:0], F_BI_DROP_LABEL[15:8], F_BI_DROP[7:0], F_BI_DROP[15:8] ; "DROP"
    #d F_BI_DUP_LABEL[7:0], F_BI_DUP_LABEL[15:8], F_BI_DUP[7:0], F_BI_DUP[15:8] ; "DUP"
    #d F_BI_EQUAL_LABEL[7:0], F_BI_EQUAL_LABEL[15:8], F_BI_EQUAL[7:0], F_BI_EQUAL[15:8] ; "="
    #d F_BI_ELSE_LABEL[7:0], F_BI_ELSE_LABEL[15:8], F_BI_ELSE[7:0], F_BI_ELSE[15:8] ; "ELSE"
    #d F_BI_EMIT_LABEL[7:0], F_BI_EMIT_LABEL[15:8], F_BI_EMIT[7:0], F_BI_EMIT[15:8] ; "EMIT"
    #d F_BI_FORGET_LABEL[7:0], F_BI_FORGET_LABEL[15:8], F_BI_FORGET[7:0], F_BI_FORGET[15:8] ; "FORGET"
    #d F_BI_FORTH_LABEL[7:0], F_BI_FORTH_LABEL[15:8], F_BI_FORTH[7:0], F_BI_FORTH[15:8] ; "FORTH"
    #d F_BI_GREATER_LABEL[7:0], F_BI_GREATER_LABEL[15:8], F_BI_GREATER[7:0], F_BI_GREATER[15:8] ; ">"
    #d F_BI_I_LABEL[7:0], F_BI_I_LABEL[15:8], F_BI_I[7:0], F_BI_I[15:8] ; "I"
    #d F_BI_IF_LABEL[7:0], F_BI_IF_LABEL[15:8], F_BI_IF[7:0], F_BI_IF[15:8] ; "IF"
    #d F_BI_IF_DUP_LABEL[7:0], F_BI_IF_DUP_LABEL[15:8], F_BI_IF_DUP[7:0], F_BI_IF_DUP[15:8] ; "?DUP"
    #d F_BI_LEAVE_LABEL[7:0], F_BI_LEAVE_LABEL[15:8], F_BI_LEAVE[7:0], F_BI_LEAVE[15:8] ; "LEAVE"
    #d F_BI_LOOP_LABEL[7:0], F_BI_LOOP_LABEL[15:8], F_BI_LOOP[7:0], F_BI_LOOP[15:8] ; "LOOP"
    #d F_BI_PLUS_LOOP_LABEL[7:0], F_BI_PLUS_LOOP_LABEL[15:8], F_BI_PLUS_LOOP[7:0], F_BI_PLUS_LOOP[15:8] ; "+LOOP"
    #d F_BI_MAX_LABEL[7:0], F_BI_MAX_LABEL[15:8], F_BI_MAX[7:0], F_BI_MAX[15:8] ; "MAX"
    #d F_BI_MIN_LABEL[7:0], F_BI_MIN_LABEL[15:8], F_BI_MIN[7:0], F_BI_MIN[15:8] ; "MIN"
    #d F_BI_MOD_LABEL[7:0], F_BI_MOD_LABEL[15:8], F_BI_MOD[7:0], F_BI_MOD[15:8] ; "MOD"
    #d F_BI_NEW_DEF_LABEL[7:0], F_BI_NEW_DEF_LABEL[15:8], F_BI_NEW_DEF[7:0], F_BI_NEW_DEF[15:8] ; ":"
    #d F_BI_OR_LABEL[7:0], F_BI_OR_LABEL[15:8], F_BI_OR[7:0], F_BI_OR[15:8] ; "OR"
    #d F_BI_OVER_LABEL[7:0], F_BI_OVER_LABEL[15:8], F_BI_OVER[7:0], F_BI_OVER[15:8] ; "OVER"
    #d F_BI_PAGE_LABEL[7:0], F_BI_PAGE_LABEL[15:8], F_BI_PAGE[7:0], F_BI_PAGE[15:8] ; "PAGE"
    #d F_BI_REPEAT_LABEL[7:0], F_BI_REPEAT_LABEL[15:8], F_BI_REPEAT[7:0], F_BI_REPEAT[15:8] ; "REPEAT"
    #d F_BI_ROT_LABEL[7:0], F_BI_ROT_LABEL[15:8], F_BI_ROT[7:0], F_BI_ROT[15:8] ; "ROT"
    #d F_BI_SPACE_LABEL[7:0], F_BI_SPACE_LABEL[15:8], F_BI_SPACE[7:0], F_BI_SPACE[15:8] ; "SPACE"
    #d F_BI_SPACES_LABEL[7:0], F_BI_SPACES_LABEL[15:8], F_BI_SPACES[7:0], F_BI_SPACES[15:8] ; "SPACES"
    #d F_BI_SWAP_LABEL[7:0], F_BI_SWAP_LABEL[15:8], F_BI_SWAP[7:0], F_BI_SWAP[15:8] ; "SWAP"
    #d F_BI_THEN_LABEL[7:0], F_BI_THEN_LABEL[15:8], F_BI_THEN[7:0], F_BI_THEN[15:8] ; "THEN"
    #d F_BI_UNTIL_LABEL[7:0], F_BI_UNTIL_LABEL[15:8], F_BI_UNTIL[7:0], F_BI_UNTIL[15:8] ; "UNTIL"
    #d F_BI_VARIABLE_LABEL[7:0], F_BI_VARIABLE_LABEL[15:8], F_BI_VARIABLE[7:0], F_BI_VARIABLE[15:8] ; "VARIABLE"
    #d F_BI_WHILE_LABEL[7:0], F_BI_WHILE_LABEL[15:8], F_BI_WHILE[7:0], F_BI_WHILE[15:8] ; "WHILE"
F_DICT_BUILT_IN_END:
    #d 0x00 ; end of dict

#const F_DICT_BUILT_IN_COUNT = (F_DICT_BUILT_IN_END - F_DICT_BUILT_IN_START) / 4

; ****** START of built-in functions defition ******

F_BI_ABORT_QUOTE_LABEL:
    #d "ABORT", 0x22, 0x00
F_BI_ABORT_QUOTE:
    jsr F_STACK_PULL
    bcc .end 
    lda F_TOKEN_VALUE
    sta F_EXECUTION_ABORT_FLAG

    lda F_TOKEN_COUNT
    sec
    adc F_TOKEN_START
    tax
    ldy F_TOKEN_COUNT
    iny
.loop:
    lda (F_INPUT_BUFFER_START_LSB),x
    inx
    iny
    cmp 0x22
    beq .abort_if_needed
    ldd F_EXECUTION_ABORT_FLAG
    beq .skip_send
    jsr ACIA_SEND_CHAR
.skip_send:    
    cpx F_INPUT_BUFFER_COUNT
    bne .loop
.error:
    lda .error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda 0x01
    sta F_EXECUTION_ERROR_FLAG
    lda 0x00
    sta F_EXECUTION_ABORT_FLAG
    rts
.abort_if_needed:
    sty F_TOKEN_COUNT
    lda F_EXECUTION_ABORT_FLAG
    beq .end
    lda 0x00
    sta F_STACK_COUNT
    sta F_EXIT_INTERPRETER_FLAG
    sta F_STATUS_COUNT
    sta F_DO_LOOP_COUNT
.end:
    rts
.error_msg:
    #d "CLOSING QUOTE EXPECTED"
    #d 0x00

F_BI_DISPLAY_LABEL:
    #d ".", 0x00
F_BI_DISPLAY:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    jsr ACIA_SEND_DECIMAL
    lda 0x20
    jsr ACIA_SEND_CHAR
.end:
    rts

F_BI_DISPLAY_STACK_LABEL:
    #d ".S", 0x00
F_BI_DISPLAY_STACK:
    lda "<"
    jsr ACIA_SEND_CHAR
    lda F_STACK_COUNT
    jsr ACIA_SEND_DECIMAL
    lda ">"
    jsr ACIA_SEND_CHAR    
    lda " "
    jsr ACIA_SEND_CHAR   
    jsr F_STACK_PRINT
.end:
    rts

F_BI_EMIT_LABEL:
    #d "EMIT", 0x00
F_BI_EMIT:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    jsr ACIA_SEND_CHAR
.end:
    rts

F_BI_SWAP_LABEL:
    #d "SWAP", 0x00
F_BI_SWAP:
    jsr F_STACK_PULL
    bcc .end
    ldd F_TOKEN_VALUE
    jsr F_STACK_PULL
    bcc .end
    lde F_TOKEN_VALUE
    std F_TOKEN_VALUE
    jsr F_STACK_PUSH
    ste F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_DUP_LABEL:
    #d "DUP", 0x00
F_BI_DUP:
    jsr F_STACK_PULL
    bcc .end
    jsr F_STACK_PUSH
    jsr F_STACK_PUSH
.end:
    rts

F_BI_IF_DUP_LABEL:
    #d "?DUP", 0x00
F_BI_IF_DUP:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    beq .condition_false
    jsr F_STACK_PUSH
.condition_false:
    jsr F_STACK_PUSH
.end:
    rts

F_BI_2DUP_LABEL:
    #d "2DUP", 0x00
F_BI_2DUP:
    jsr F_STACK_PULL
    bcc .end
    ldd F_TOKEN_VALUE
    jsr F_STACK_PULL
    bcc .end    
    jsr F_STACK_PUSH
    jsr F_STACK_PUSH
    std F_TOKEN_VALUE
    jsr F_STACK_PUSH
    jsr F_STACK_PUSH
.end:
    rts

F_BI_2DROP_LABEL:
    #d "2DROP", 0x00
F_BI_2DROP:
    jsr F_STACK_PULL
    bcc .end
    jsr F_STACK_PULL    
.end:
    rts

F_BI_OVER_LABEL:
    #d "OVER", 0x00
F_BI_OVER:
    jsr F_STACK_PULL
    bcc .end
    ldd F_TOKEN_VALUE
    jsr F_STACK_PULL
    bcc .end
    lde F_TOKEN_VALUE
    jsr F_STACK_PUSH
    std F_TOKEN_VALUE
    jsr F_STACK_PUSH
    ste F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_ROT_LABEL:
    #d "ROT", 0x00
F_BI_ROT:
    jsr F_STACK_PULL
    bcc .end
    ldd F_TOKEN_VALUE
    
    jsr F_STACK_PULL
    bcc .end
    lde F_TOKEN_VALUE

    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    pha
    
    ste F_TOKEN_VALUE
    jsr F_STACK_PUSH

    std F_TOKEN_VALUE
    jsr F_STACK_PUSH

    pla
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
.end:
    rts

F_BI_DROP_LABEL:
    #d "DROP", 0x00
F_BI_DROP:
    jsr F_STACK_PULL
.end:
    rts

F_BI_CR_LABEL:
    #d "CR", 0x00
F_BI_CR:
    jsr ACIA_SEND_NEWLINE
    rts

F_BI_PAGE_LABEL:
    #d "PAGE", 0x00
F_BI_PAGE:
    jsr VT100_ERASE_SCREEN
    jsr VT100_CURSOR_HOME
    rts

F_BI_SPACE_LABEL:
    #d "SPACE", 0x00
F_BI_SPACE:
    lda 0x20
    jsr ACIA_SEND_CHAR
    rts

F_BI_SPACES_LABEL:
    #d "SPACES", 0x00
F_BI_SPACES:
    jsr F_STACK_PULL
    bcc .end
    lda 0x20
    ldx F_TOKEN_VALUE
.loop:
    beq .end
    jsr ACIA_SEND_CHAR
    dec F_TOKEN_VALUE
    jmp .loop
.end:
    rts

F_BI_BYE_LABEL:
    #d "BYE", 0x00
F_BI_BYE:
    lda 0x01
    sta F_EXIT_INTERPRETER_FLAG
    rts

F_BI_DOT_QUOTE_LABEL:
    #d ".", 0x22, 0x00 
F_BI_DOT_QUOTE:
    lda F_TOKEN_COUNT
    sec
    adc F_TOKEN_START
    tax
    ldy F_TOKEN_COUNT
    iny
.loop:
    lda (F_INPUT_BUFFER_START_LSB),x
    inx
    iny
    cmp 0x22
    beq .end
    jsr ACIA_SEND_CHAR
    cpx F_INPUT_BUFFER_COUNT
    bne .loop
.error:
    lda .error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    rts
.end:
    sty F_TOKEN_COUNT
    rts

.error_msg:
    #d "CLOSING QUOTE EXPECTED"
    #d 0x00


F_BI_COMMENT_LABEL:
    #d "(", 0x00
F_BI_COMMENT:
    lda F_TOKEN_COUNT
    sec
    adc F_TOKEN_START
    tax
    ldy F_TOKEN_COUNT
    iny
.loop:
    lda (F_INPUT_BUFFER_START_LSB),x
    inx
    iny
    cmp ")"
    beq .end
    cpx F_INPUT_BUFFER_COUNT
    bne .loop
.error:
    lda .error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    rts
.end:
    sty F_TOKEN_COUNT
    rts

.error_msg:
    #d "CLOSED PARENTHESIS EXPECTED"
    #d 0x00    

F_BI_IF_LABEL:
    #d "IF", 0x00 
F_BI_IF:
    
    ; save in stack 
    lda F_TOKEN_START
    pha
    lda F_TOKEN_COUNT
    pha
    
    ; search for THEN/ELSE
    lda 0x00
    sta F_BI_IF_DEPTH
    sta F_BI_IF_ELSE_START

.next_token:
    ; set new start
    clc
    lda F_TOKEN_COUNT
    adc F_TOKEN_START
    sta F_TOKEN_START
    cmp F_INPUT_BUFFER_COUNT
    beq .then_not_found_error

    jsr F_TOKENIZE

    ;compare IF
    lda F_BI_IF_LABEL[15:8]
    sta F_CMP_TOKEN_MSB
    lda F_BI_IF_LABEL[7:0]
    sta F_CMP_TOKEN_LSB
    jsr F_COMPARE_TOKEN
    bcs .if_found

    ;compare THEN
    lda .then_msg[15:8]
    sta F_CMP_TOKEN_MSB
    lda .then_msg[7:0]
    sta F_CMP_TOKEN_LSB
    jsr F_COMPARE_TOKEN
    bcs .then_found

    ;compare ELSE
    lda F_BI_ELSE_LABEL[15:8]
    sta F_CMP_TOKEN_MSB
    lda F_BI_ELSE_LABEL[7:0]
    sta F_CMP_TOKEN_LSB
    jsr F_COMPARE_TOKEN
    bcs .else_found

    jmp .next_token


.if_found:
    inc F_BI_IF_DEPTH
    jmp .next_token

.then_found:
    lda F_BI_IF_DEPTH
    beq .then_save
    dec F_BI_IF_DEPTH
    jmp .next_token

.then_save:
    lda F_TOKEN_START
    sta F_BI_IF_THEN_START   
    jmp .restore_current_token

.else_found:
    lda F_BI_IF_DEPTH
    bne .next_token      
    lda F_TOKEN_START
    sta F_BI_IF_ELSE_START
    jmp .next_token

.restore_current_token:
    ; restore from stack 
    pla
    sta F_TOKEN_COUNT
    pla
    sta F_TOKEN_START

.check_condition:
    jsr F_STACK_PULL
    bcc .end 

    lda F_TOKEN_VALUE
    beq .condition_false
    jsr .push_if_then_stack
    jmp .end

.condition_false:
    lda F_BI_IF_ELSE_START
    bne .go_to_else

    lda F_BI_IF_THEN_START
    sta F_TOKEN_START
    lda 0x04
    sta F_TOKEN_COUNT
    jmp .end    

.go_to_else:
    lda F_BI_IF_ELSE_START
    sta F_TOKEN_START
    lda 0x04
    sta F_TOKEN_COUNT
    jmp .end

.push_if_then_stack:
    ldx F_IF_THEN_COUNT
    lda F_BI_IF_THEN_START
    sta F_IF_THEN_START,x
    inc F_IF_THEN_COUNT
    rts

.then_not_found_error:
    pla 
    pla
    lda .then_not_found_error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .then_not_found_error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG

.end:
    rts

.then_not_found_error_msg:
    #d "THEN EXPECTED"
    #d 0x00

.then_msg:
    #d "THEN", 0x00

F_BI_ELSE_LABEL:
    #d "ELSE", 0x00 
F_BI_ELSE:
    jsr F_CHECK_IF_THEN_STACK_EMPTY
    bcc .end
    dec F_IF_THEN_COUNT
    ldx F_IF_THEN_COUNT
    lda F_IF_THEN_START,x
    sta F_TOKEN_START
    lda 0x04
    sta F_TOKEN_COUNT
.end:
    rts

F_BI_THEN_LABEL:
    #d "THEN", 0x00 
F_BI_THEN:
    rts

F_CHECK_IF_THEN_STACK_EMPTY:
    lda F_IF_THEN_COUNT
    beq .if_then_stack_empty
    sec
    rts

.if_then_stack_empty:
    lda .if_then_stack_empty_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .if_then_stack_empty_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    clc
    rts

.if_then_stack_empty_msg:
    #d "IF-THEN stack empty"
    #d 0x00

F_BI_FORTH_LABEL:
    #d "FORTH", 0x00 
F_BI_FORTH:
    jsr ACIA_SEND_NEWLINE
    ldd .memory_start_msg[15:8]
    lde .memory_start_msg[7:0]
    jsr ACIA_SEND_STRING
    lda F_MEMORY_START[15:8]
    jsr ACIA_SEND_HEX
    lda F_MEMORY_START[7:0]
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE

    ldd .dictionary_msg[15:8]
    lde .dictionary_msg[7:0]
    jsr ACIA_SEND_STRING
    lda F_DICT_BUILT_IN_COUNT
    jsr ACIA_SEND_DECIMAL

    ldd .dictionary_separator[15:8]
    lde .dictionary_separator[7:0]
    jsr ACIA_SEND_STRING
    lda F_DICT_USER_COUNT
    jsr ACIA_SEND_DECIMAL

    ldd .dictionary_suffix[15:8]
    lde .dictionary_suffix[7:0]
    jsr ACIA_SEND_STRING   
    jsr ACIA_SEND_NEWLINE
    rts

.memory_start_msg:
    #d "Memory start at address 0x", 0x00 
.dictionary_msg:
    #d "Dictionary definitions: ", 0x00 
.dictionary_separator:
    #d "/", 0x00 
.dictionary_suffix:
    #d " (built-in/user) ", 0x00   


; ****** END of built-in functions defition ******

; DICT built-in records
;   - ptr to label LSB (1 byte)
;   - ptr to label MSB (1 byte)
;   - ptr to built in LSB  (1 byte)
;   - ptr to built in MSB  (1 byte)
F_TOKEN_IS_BUILTIN:
    ldd F_DICT_BUILT_IN_START[15:8]
    lde F_DICT_BUILT_IN_START[7:0]
    ldy F_DICT_BUILT_IN_COUNT
    beq .dictionary_end
.check_if_match:   
    phd ; save record address
    phe
    phy
    ldy F_TOKEN_START

    ldx 0x00 ; get label address
    lda de, x
    pha
    inx
    lda de, x
    tad
    ple
    ldx 0x00

.check_char_match:
    lda de,x
    beq .end_of_dictionary_item
    cmp (F_INPUT_BUFFER_START_LSB),y
    bne .check_next_dictionary_item 
    inx
    iny
    jmp .check_char_match

.end_of_dictionary_item:
    cpx F_TOKEN_COUNT
    bne .check_next_dictionary_item
    ply 
    ple ; restore record address
    pld

.match:    
    ldx 0x02
    lda de,x 
    sta F_DICT_EXEC_BUILT_IN_PTR_LSB
    inx
    lda de,x 
    sta F_DICT_EXEC_BUILT_IN_PTR_MSB    
    lda 0x00
    sta F_DICT_EXEC_BUILT_IN_PTR_PAGE
    sec
    rts

.check_next_dictionary_item:
    ply
    ple ; restore record address
    pld
    dey
    beq .dictionary_end

    clc
    lda 0x04 ; record size
    adc e
    tae
    tda
    adc 0x00
    tad
    jmp .check_if_match    

.dictionary_end:
    clc
    rts