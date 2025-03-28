#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x2B00
    #outp 0
}

#bank ram   


; **********************************************************
; THE STARTING ADDRESS OF THE FORTH MEMORY
; when porting to kernel, it must be changed to a constant
#const F_MEMORY_START = 0xB000
; **********************************************************

FORTH_MAIN:
    jsr F_INIT
.loop:
    jsr F_INPUT
    lda F_INPUT_BUFFER_COUNT
    beq .loop
    jsr VT100_TEXT_REVERSE
    jsr F_ELABORATE
    jsr VT100_TEXT_RESET
    lda F_EXIT_INTERPRETER_FLAG
    beq .loop
    rts

F_INIT:
    ; init stack
    lda 0x00
    sta F_STACK_COUNT
    sta F_EXIT_INTERPRETER_FLAG
    ; init custom dict
    sta F_DICT_USER_START
    ; init status count
    sta F_STATUS_COUNT
    ; init built-in dict
    jsr F_REGISTER_ALL_BUILT_IN_FUNCTIONS
    ; reset fonts
    jsr VT100_TEXT_RESET
    rts

; **********************************************************
; MEMORY OFFSETS
#const F_INPUT_BUFFER_START = F_MEMORY_START + 0x0000
#const F_INPUT_BUFFER_END = F_MEMORY_START + 0x00FF
#const F_INPUT_BUFFER_COUNT = F_MEMORY_START + 0x0100
#const F_TOKEN_START = F_MEMORY_START + 0x0101
#const F_TOKEN_COUNT = F_MEMORY_START + 0x0102
#const F_TOKEN_VALUE= F_MEMORY_START + 0x0103
#const F_STACK_COUNT = F_MEMORY_START + 0x0104

#const F_DICT_ADD_BUFFER_START = F_MEMORY_START + 0x0105
#const F_DICT_ADD_BUFFER_END = F_MEMORY_START + 0x011A

#const F_DICT_ADD_BUILT_IN_LABEL_PTR_LSB = F_MEMORY_START + 0x011B
#const F_DICT_ADD_BUILT_IN_LABEL_PTR_MSB = F_MEMORY_START + 0x011C
#const F_DICT_ADD_BUILT_IN_PTR_LSB = F_MEMORY_START + 0x011D
#const F_DICT_ADD_BUILT_IN_PTR_MSB = F_MEMORY_START + 0x011E

#const F_DICT_EXEC_BUILT_IN_PTR_PAGE = F_MEMORY_START + 0x011F
#const F_DICT_EXEC_BUILT_IN_PTR_MSB  = F_MEMORY_START + 0x0120
#const F_DICT_EXEC_BUILT_IN_PTR_LSB  = F_MEMORY_START + 0x0121

#const F_EXIT_INTERPRETER_FLAG = F_MEMORY_START + 0x0122
#const F_EXECUTION_ERROR_FLAG = F_MEMORY_START + 0x0123

#const F_DICT_ADD_USER_START = F_MEMORY_START + 0x0124
#const F_DICT_ADD_USER_COUNT = F_MEMORY_START + 0x0125

#const F_DICT_EXEC_USER_ITEM = F_MEMORY_START + 0x0126
#const F_STATUS_COUNT = F_MEMORY_START + 0x0127

; TODO: reorganization of the memory layout

; Placing the stack at the end of the variable area
#const F_STACK_START = F_MEMORY_START + 0x1000

; Placing the dictionary at the enf of the stack area
#const F_DICT_BUILT_IN_START = F_MEMORY_START + 0x2000

; Placing the user dictionary at the enf of the built-in dictionary
#const F_DICT_USER_START = F_MEMORY_START + 0x3000

; Placing the status saving area at the end of the memory
#const F_STATUS_START = F_MEMORY_START + 0x4000

; **********************************************************

; INPUT COMMANDS
F_INPUT:
    jsr ACIA_SEND_NEWLINE
    lda 0x00    
    sta F_INPUT_BUFFER_COUNT
    ldd .prompt_msg[15:8]
    lde .prompt_msg[7:0]
    jsr ACIA_SEND_STRING

.loop:
    lda ACIA_CONTROL_STATUS_ADDR  ; read serial 1 status
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; check if Receive Data Register is full
    beq .loop
    lda ACIA_RW_DATA_ADDR  ; read serial 1 data
    tao
    cmp 0x0D
    beq .cmd_entered
    jsr ACIA_SEND_CHAR
    ldx F_INPUT_BUFFER_COUNT
    sta F_INPUT_BUFFER_START,x
    inc F_INPUT_BUFFER_COUNT
    cpx 0xFF
    beq .show_too_long_error
    jmp .loop

.cmd_entered:
    rts

.show_too_long_error:
    ldd .too_long_msg[15:8]
    lde .too_long_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp F_INPUT

.too_long_msg:
    #d 0x0A, 0x0D
    #d "TOO LONG" 
    #d 0x00

.prompt_msg:
    #d "F> " 
    #d 0x00


F_ELABORATE:
    lda 0x00
    sta F_TOKEN_START
    sta F_EXECUTION_ERROR_FLAG

.loop:
    jsr F_TOKENIZE
    lda F_TOKEN_COUNT
    beq .send_ok

.check_number:
    jsr F_TOKEN_IS_NUMBER
    bcc .check_builtin  
    jsr F_TOKEN_TO_NUMBER
    jsr F_STACK_PUSH
    jmp .next_token

.check_builtin:
    jsr F_TOKEN_IS_BUILTIN
    bcc .check_dictionary

    ;jsr (F_DICT_EXEC_BUILT_IN_PTR_PAGE)
    #d 0x93, 0x00, F_DICT_EXEC_BUILT_IN_PTR_PAGE[15:8],  F_DICT_EXEC_BUILT_IN_PTR_PAGE[7:0]
    jmp .next_token

.check_dictionary:
    jsr F_TOKEN_IS_DICTIONARY
    bcc .token_error
    jsr F_EXECUTE_DICTIONARY
    jmp .next_token

.token_error:
    jsr ACIA_SEND_NEWLINE
    jsr F_PRINT_TOKEN
    ldd .token_error_msg[15:8]
    lde .token_error_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .end

.next_token:
    lda F_EXECUTION_ERROR_FLAG
    bne .end

    lda F_TOKEN_COUNT
    clc
    adc F_TOKEN_START
    sta F_TOKEN_START
    cmp F_INPUT_BUFFER_COUNT
    bne .loop
.send_ok:
    lda F_STATUS_COUNT
    bne .restore_status
    ldd .execution_ok_msg[15:8]
    lde .execution_ok_msg[7:0]
    jsr ACIA_SEND_STRING
.end:
    rts
.restore_status:
    jsr F_PULL_STATUS
    jmp .next_token

.token_error_msg:
    #d " ?" 
    #d 0x00

.execution_ok_msg:
    #d " ok" 
    #d 0x00

F_TOKENIZE:
    lda 0x00
    sta F_TOKEN_COUNT
    ldx F_TOKEN_START
.skip_spaces:
    lda F_INPUT_BUFFER_START,x
    cmp 0x20
    bne .loop
    inx
    inc F_TOKEN_START
    cpx F_INPUT_BUFFER_COUNT
    bne .skip_spaces
    jmp .end
.loop:
    lda F_INPUT_BUFFER_START,x
    cmp 0x20
    beq .end
    inc F_TOKEN_COUNT
    inx
    cpx F_INPUT_BUFFER_COUNT
    bne .loop
.end:
    rts

F_PRINT_TOKEN:
    ldy F_TOKEN_COUNT
    ldx F_TOKEN_START
.loop:
    lda F_INPUT_BUFFER_START,x
    jsr ACIA_SEND_CHAR
    inx
    dey
    bne .loop
    rts

F_TOKEN_IS_NUMBER:
    ldy F_TOKEN_COUNT
    ldx F_TOKEN_START
.loop:
    lda F_INPUT_BUFFER_START,x
    cmp 0x30
    bcc .end
    cmp 0x3A
    bcs .end
    inx
    dey
    bne .loop
    sec
    rts
.end:
    clc
    rts

F_TOKEN_TO_NUMBER:
    ldy F_TOKEN_COUNT
    ldx F_TOKEN_START
    lda #0x00
    sta F_TOKEN_VALUE
.loop:
    lda F_TOKEN_VALUE
    beq .add
    asl a
    tad
    asl a
    asl a
    clc
    adc D
    sta F_TOKEN_VALUE
.add:
    lda F_INPUT_BUFFER_START,x
    sec 
    sbc #0x30   
    clc
    adc F_TOKEN_VALUE
    sta F_TOKEN_VALUE
    inx
    dey
    bne .loop
    rts

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
    ldd .stack_is_empty_msg[15:8]
    lde .stack_is_empty_msg[7:0]
    jsr ACIA_SEND_STRING
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    clc
    rts    

.stack_is_empty_msg:
    #d "Stack empty" 
    #d 0x00

F_TOKEN_IS_BUILTIN:
    ldd F_DICT_BUILT_IN_START[15:8]
    lde F_DICT_BUILT_IN_START[7:0]

.check_if_match:   
    ldx 0x00
    ldy F_TOKEN_START
    lda de,x
    beq .dictionary_end

.check_char_match:
    cmp F_INPUT_BUFFER_START,y
    bne .check_next_dictionary_item 
    inx
    iny

    lda de,x 
    beq .end_of_dictionary_item
    cmp 0x1B ; 1B (ESC) is a special terminator meaning "begin with"
    beq .match
    jmp .check_char_match

.end_of_dictionary_item:
    cpx F_TOKEN_COUNT
    bne .check_next_dictionary_item

.match:    
    ldx 14
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
    lda #16
    clc
    adc e
    tae
    lda 0x00
    adc d
    tad
    jmp .check_if_match    

.dictionary_end:
    clc
    rts

F_TOKEN_IS_DICTIONARY:
    ldd F_DICT_USER_START[15:8]
    lde F_DICT_USER_START[7:0]
    lda 0x00
    sta F_DICT_EXEC_USER_ITEM

.check_if_match:   
    ldx 0x00
    ldy F_TOKEN_START
    lda de,x
    beq .dictionary_end

.check_char_match:
    cmp F_INPUT_BUFFER_START,y
    bne .check_next_dictionary_item 
    inx
    iny

    lda de,x 
    beq .end_of_dictionary_item
    jmp .check_char_match

.end_of_dictionary_item:
    cpx F_TOKEN_COUNT
    bne .check_next_dictionary_item

.match:    
    sec
    rts

.check_next_dictionary_item:
    ind ; 256 bytes each
    inc F_DICT_EXEC_USER_ITEM
    jmp .check_if_match    

.dictionary_end:
    clc
    rts

F_EXECUTE_DICTIONARY:
    jsr F_PUSH_STATUS

    ldd F_DICT_USER_START[15:8]
    lde F_DICT_USER_START[7:0]

.go_to_item_loop:
    lda F_DICT_EXEC_USER_ITEM
    beq .copy_cmd
    dec F_DICT_EXEC_USER_ITEM
    ind ; 256 bytes each
    jmp .go_to_item_loop
.copy_cmd:
    ldx 14
    ldy 0x00
    sty F_INPUT_BUFFER_COUNT
.copy_cmd_loop:   
    lda de,x
    beq .copy_cmd_end
    sta F_INPUT_BUFFER_START, y
    inx
    iny
    inc F_INPUT_BUFFER_COUNT
    jmp .copy_cmd_loop
.copy_cmd_end:
    ; iny
    ; lda 0x20
    ; sta F_INPUT_BUFFER_START, y
    ; iny
    ; inc F_INPUT_BUFFER_COUNT
    ; lda 0x1B ; ESC (restore status)
    ; sta F_INPUT_BUFFER_START, y
    ; inc F_INPUT_BUFFER_COUNT
    lda 0x00
    sta F_TOKEN_START
    sta F_TOKEN_COUNT
    rts

; DICT user records
; - label (14 bytes, 0x00 terminated, empty if last)
; - cmd (242 bytes)
F_DICTONARY_USER_ADD:
    ldd F_DICT_USER_START[15:8]
    lde F_DICT_USER_START[7:0]
    ldx 0x00
.check_if_free:
    lda de, x
    beq .add
    ind ; 256 bytes each
    jmp .check_if_free
.add:
    lda F_DICT_ADD_BUFFER_START, x
    sta de, x
    beq .copy_cmd
    inx
    jmp .add
.copy_cmd:
    ldx 14
    ldy F_DICT_ADD_USER_START
.copy_cmd_loop:
    lda F_INPUT_BUFFER_START, y
    sta de, x
    iny
    inx
    dec F_DICT_ADD_USER_COUNT
    bne .copy_cmd_loop
    lda 0x00
    sta de, x 
    rts

; DICT built-in records
; - label (14 bytes, 0x00 terminated, empty if last)
; - ptr to built in LSB  (1 byte)
; - ptr to built in MSB  (1 byte)
F_DICTONARY_BUILT_IN_ADD:
    ldd F_DICT_BUILT_IN_START[15:8]
    lde F_DICT_BUILT_IN_START[7:0]
    ldx 0x00
.check_if_free:
    lda de, x
    beq .add
    lda #16
    clc
    adc e
    tae
    lda 0x00
    adc d
    tad
    jmp .check_if_free
.add:
    lda F_DICT_ADD_BUFFER_START, x
    sta de, x
    beq .set_ptr
    inx
    jmp .add
.set_ptr:
    ldx #14
    lda F_DICT_ADD_BUILT_IN_PTR_LSB
    sta de, x
    inx
    lda F_DICT_ADD_BUILT_IN_PTR_MSB
    sta de, x    
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

F_REGISTER_ALL_BUILT_IN_FUNCTIONS:
    lda 0x00
    sta F_DICT_BUILT_IN_START

    _MACRO_REGISTER_BUILT_IN F_BI_EMIT_LABEL, F_BI_EMIT
    _MACRO_REGISTER_BUILT_IN F_BI_BYE_LABEL, F_BI_BYE
    _MACRO_REGISTER_BUILT_IN F_BI_DISPLAY_LABEL, F_BI_DISPLAY
    _MACRO_REGISTER_BUILT_IN F_BI_SUM_LABEL, F_BI_SUM
    _MACRO_REGISTER_BUILT_IN F_BI_CR_LABEL, F_BI_CR
    _MACRO_REGISTER_BUILT_IN F_BI_SPACE_LABEL, F_BI_SPACE
    _MACRO_REGISTER_BUILT_IN F_BI_SPACES_LABEL, F_BI_SPACES
    _MACRO_REGISTER_BUILT_IN F_BI_DOT_QUOTE_LABEL, F_BI_DOT_QUOTE
    _MACRO_REGISTER_BUILT_IN F_BI_NEW_DEF_LABEL, F_BI_NEW_DEF
    rts

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

; ****** STATUS functions ******


; STATUS records
; - F_INPUT_BUFFER_COUNT 
; - F_TOKEN_START 
; - F_TOKEN_COUNT 
; - INPUT_BUFFER (253 bytes)

F_PUSH_STATUS:
    ldd F_STATUS_START[15:8]
    lde F_STATUS_START[7:0]
    ldx F_STATUS_COUNT
.find_status_record_loop:
    beq .push_vars
    ind ; 256 bytes each
    dex
    jmp .find_status_record_loop
.push_vars:
    ldx 0x00
    lda F_INPUT_BUFFER_COUNT
    sta de, x
    inx
    lda F_TOKEN_START
    sta de, x
    inx
    lda F_TOKEN_COUNT
    sta de, x
    inx
    ldy 0x00
.push_input_loop:
    lda F_INPUT_BUFFER_START, y
    sta de, x
    inx
    iny
    cpy F_INPUT_BUFFER_COUNT
    bne .push_input_loop
    inc F_STATUS_COUNT
    rts

F_PULL_STATUS:
    dec F_STATUS_COUNT
    ldd F_STATUS_START[15:8]
    lde F_STATUS_START[7:0]
    ldx F_STATUS_COUNT
.find_status_record_loop:
    beq .pull_vars
    ind ; 256 bytes each
    dex
    jmp .find_status_record_loop
.pull_vars:
    ldx 0x00
    lda de, x
    sta F_INPUT_BUFFER_COUNT
    inx
    lda de, x
    sta F_TOKEN_START
    inx
    lda de, x
    sta F_TOKEN_COUNT
    inx
    ldy 0x00
.pull_input_loop:
    lda de, x
    sta F_INPUT_BUFFER_START, y
    inx
    iny
    cpy F_INPUT_BUFFER_COUNT
    bne .pull_input_loop
    rts

; ****** START of built-in functions ******

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
    jsr F_DICTONARY_USER_ADD
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
