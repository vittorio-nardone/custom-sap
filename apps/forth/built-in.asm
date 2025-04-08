#once

; **********************************************************
; All built-in related stuff
; **********************************************************

F_REGISTER_ALL_BUILT_IN_FUNCTIONS:
    lda 0x00
    sta F_DICT_BUILT_IN_START

    _MACRO_REGISTER_BUILT_IN F_BI_FORTH_LABEL, F_BI_FORTH
    _MACRO_REGISTER_BUILT_IN F_BI_EMIT_LABEL, F_BI_EMIT
    _MACRO_REGISTER_BUILT_IN F_BI_BYE_LABEL, F_BI_BYE
    _MACRO_REGISTER_BUILT_IN F_BI_DISPLAY_LABEL, F_BI_DISPLAY
    _MACRO_REGISTER_BUILT_IN F_BI_SUM_LABEL, F_BI_SUM
    _MACRO_REGISTER_BUILT_IN F_BI_CR_LABEL, F_BI_CR
    _MACRO_REGISTER_BUILT_IN F_BI_SPACE_LABEL, F_BI_SPACE
    _MACRO_REGISTER_BUILT_IN F_BI_SPACES_LABEL, F_BI_SPACES
    _MACRO_REGISTER_BUILT_IN F_BI_DOT_QUOTE_LABEL, F_BI_DOT_QUOTE
    _MACRO_REGISTER_BUILT_IN F_BI_NEW_DEF_LABEL, F_BI_NEW_DEF
    _MACRO_REGISTER_BUILT_IN F_BI_IF_LABEL, F_BI_IF
    rts

; ****** START of built-in functions defition ******

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

F_BI_EMIT_LABEL:
    #d "EMIT", 0x00
F_BI_EMIT:
    jsr F_STACK_PULL
    bcc .end
    lda F_TOKEN_VALUE
    jsr ACIA_SEND_CHAR
.end:
    rts

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

F_BI_CR_LABEL:
    #d "CR", 0x00
F_BI_CR:
    jsr ACIA_SEND_NEWLINE
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
.loop:
    lda F_INPUT_BUFFER_START,x
    inx
    cmp 0x22
    beq .end
    jsr ACIA_SEND_CHAR
    cpx F_INPUT_BUFFER_COUNT
    bne .loop
.error:
    ldd .error_msg[15:8]
    lde .error_msg[7:0]
    jsr ACIA_SEND_STRING
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    rts
.end:
    stx F_TOKEN_COUNT
    rts

.error_msg:
    #d "CLOSING QUOTE EXPECTED"
    #d 0x00

F_BI_NEW_DEF_LABEL:
    #d ":", 0x00 
F_BI_NEW_DEF:
    lda F_TOKEN_COUNT
    sec
    adc F_TOKEN_START
    tax
    ldy 0x00
.label_loop:
    lda F_INPUT_BUFFER_START,x
    inx
    cmp 0x20
    beq .label_end
    sta F_DICT_ADD_BUFFER_START, y
    iny
    cpx F_INPUT_BUFFER_COUNT
    bcc .label_loop
    jmp .error

.label_end:
    lda 0x00
    sta F_DICT_ADD_BUFFER_START, y

.find_cmd_loop:
    lda F_INPUT_BUFFER_START,x
    stx F_DICT_ADD_USER_START
    inx
    cmp 0x20 
    bne .cmd_read  
    cpx F_INPUT_BUFFER_COUNT
    bcc .find_cmd_loop
    jmp .error
.cmd_read:
    lda 0x00
    sta F_DICT_ADD_USER_COUNT
.cmd_loop:
    lda F_INPUT_BUFFER_START,x
    inc F_DICT_ADD_USER_COUNT
    inx
    cmp ";" 
    beq .add  
    cpx F_INPUT_BUFFER_COUNT
    bne .cmd_loop
    jmp .error

.add:
    stx F_TOKEN_COUNT
    jsr F_DICTIONARY_USER_ADD
    rts

.error:
    ldd .error_msg[15:8]
    lde .error_msg[7:0]
    jsr ACIA_SEND_STRING
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    rts

.error_msg:
    #d "ERROR IN DEFINITION"
    #d 0x00


F_BI_IF_LABEL:
    #d "IF", 0x00 
F_BI_IF:
    ; search for THEN
    lda .then_msg[15:8]
    sta F_FIND_TOKEN_MSB
    lda .then_msg[7:0]
    sta F_FIND_TOKEN_LSB
    jsr F_FIND_TOKEN

    lda F_FIND_TOKEN_COUNT
    beq .then_not_found_error

    clc
    adc F_FIND_TOKEN_START
    sta F_BI_IF_THEN_START

    ; search for ELSE
    lda 0x00
    sta F_BI_IF_ELSE_START

    lda .else_msg[15:8]
    sta F_FIND_TOKEN_MSB
    lda .else_msg[7:0]
    sta F_FIND_TOKEN_LSB
    jsr F_FIND_TOKEN

    lda F_FIND_TOKEN_COUNT
    beq .check_condition

    clc
    adc F_FIND_TOKEN_START
    sta F_BI_IF_ELSE_START


.check_condition:
    ; store the real end of the full token
    lda F_BI_IF_THEN_START
    sec
    sbc F_TOKEN_START
    sta F_TOKEN_COUNT

    jsr F_STACK_PULL
    bcc .end 

    lda F_TOKEN_VALUE
    beq .condition_false

    ;execute IF
    jsr F_PUSH_STATUS

    ldx F_TOKEN_START
    inx
    inx
    ldy 0x00
    sty F_INPUT_BUFFER_COUNT

.if_copy_loop:   
    lda F_INPUT_BUFFER_START, x
    sta F_INPUT_BUFFER_START, y
    inx
    iny
    inc F_INPUT_BUFFER_COUNT
    cpx F_BI_IF_THEN_START
    beq .copy_end
    cpx F_BI_IF_ELSE_START
    beq .copy_end
    jmp .if_copy_loop

.condition_false:
    lda F_BI_IF_ELSE_START
    beq .end

    ;execute ELSE
    jsr F_PUSH_STATUS

    ldx F_BI_IF_ELSE_START
    ldy 0x00
    sty F_INPUT_BUFFER_COUNT

.else_copy_loop:   
    lda F_INPUT_BUFFER_START, x
    sta F_INPUT_BUFFER_START, y
    inx
    iny
    inc F_INPUT_BUFFER_COUNT
    cpx F_BI_IF_THEN_START
    beq .copy_end
    jmp .else_copy_loop

.copy_end:
    sec
    lda F_INPUT_BUFFER_COUNT
    sbc 0x04 ; remove THEN/ELSE
    sta F_INPUT_BUFFER_COUNT
    lda 0x00
    sta F_TOKEN_START
    sta F_TOKEN_COUNT
    jmp .end

.then_not_found_error:
    ldd .then_not_found_error_msg[15:8]
    lde .then_not_found_error_msg[7:0]
    jsr ACIA_SEND_STRING
    lda #1
    sta F_EXECUTION_ERROR_FLAG

.end:
    rts

.then_not_found_error_msg:
    #d "THEN EXPECTED"
    #d 0x00

.then_msg:
    #d "THEN", 0x00

.else_msg:
    #d "ELSE", 0x00

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
    #d " / ", 0x00 
.dictionary_suffix:
    #d " (built-in / user) ", 0x00   


; ****** END of built-in functions defition ******

F_REGISTER_BUILT_IN_FUNCTION:
    ldd F_DICT_ADD_BUILT_IN_LABEL_PTR_MSB
    lde F_DICT_ADD_BUILT_IN_LABEL_PTR_LSB
    ldx 0x00
.loop:
    lda de, x
    sta F_DICT_ADD_BUFFER_START, x
    beq .label_end
    inx
    jmp .loop
.label_end:
    jsr F_DICTONARY_BUILT_IN_ADD
    rts

#ruledef
{
    _MACRO_REGISTER_BUILT_IN {label_ptr}, {function_ptr} => asm 
    {
        lda {label_ptr}[15:8]
        sta F_DICT_ADD_BUILT_IN_LABEL_PTR_MSB
        lda {label_ptr}[7:0]
        sta F_DICT_ADD_BUILT_IN_LABEL_PTR_LSB
        lda {function_ptr}[15:8]
        sta F_DICT_ADD_BUILT_IN_PTR_MSB
        lda {function_ptr}[7:0]
        sta F_DICT_ADD_BUILT_IN_PTR_LSB
        jsr F_REGISTER_BUILT_IN_FUNCTION
    }
}

F_TOKEN_IS_BUILTIN:
    ldd F_DICT_BUILT_IN_START[15:8]
    lde F_DICT_BUILT_IN_START[7:0]
    ldy F_DICT_BUILT_IN_COUNT
    beq .dictionary_end
    
.check_if_match:   
    ldx 0x01
    phy
    ldy F_TOKEN_START

.check_char_match:
    lda de,x
    beq .end_of_dictionary_item
    cmp F_INPUT_BUFFER_START,y
    bne .check_next_dictionary_item 
    inx
    iny
    jmp .check_char_match

.end_of_dictionary_item:
    dex
    cpx F_TOKEN_COUNT
    bne .check_next_dictionary_item
    ply 

.match:    
    inx
    inx
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
    dey
    beq .dictionary_end

    ldx 0x00
    lda de, x
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    jmp .check_if_match    

.dictionary_end:
    clc
    rts

; DICT built-in records
; - TOTAL SIZE
;   - label (0x00 terminated)
;   - ptr to built in LSB  (1 byte)
;   - ptr to built in MSB  (1 byte)
F_DICTONARY_BUILT_IN_ADD:
    ldd F_DICT_BUILT_IN_START[15:8]
    lde F_DICT_BUILT_IN_START[7:0]
    ldy F_DICT_BUILT_IN_COUNT
    beq .add
    ldx 0x00
.go_to_record_loop:
    lda de,x
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    dey
    bne .go_to_record_loop
.add:
    ldx 0x01
    ldy 0x00
.add_loop:
    lda F_DICT_ADD_BUFFER_START, y 
    sta de, x
    beq .set_ptr
    inx
    iny
    jmp .add_loop
.set_ptr:
    inx
    lda F_DICT_ADD_BUILT_IN_PTR_LSB
    sta de, x
    inx
    lda F_DICT_ADD_BUILT_IN_PTR_MSB
    sta de, x   
    inx
    ; set record size
    txa
    ldx 0x00
    sta de, x
    ; set initial position of USER dictonary
    clc
    adc e
    sta F_DICT_USER_START_LSB
    tda
    adc 0x00
    sta F_DICT_USER_START_MSB
    ; inc # of built it functions
    inc F_DICT_BUILT_IN_COUNT 
    rts