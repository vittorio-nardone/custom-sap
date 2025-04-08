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
#const F_MEMORY_START = 0xB000
; THE MAX SIZE OF A SINGLE INPUT (64 bytes -> up to 256)
#const F_MAX_INPUT_SIZE = 0x40
; THE MAX SIZE OF THE STACK
#const F_MAX_STACK_SIZE = 0xFF
; THE MAX SIZE OF THE DICTIONARY (built-in + user)
#const F_MAX_DICT_SIZE = 0x1000 ; 4K
; **********************************************************

FORTH_MAIN:
    jsr F_INIT
    jsr F_WELCOME
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
    sta F_DICT_BUILT_IN_COUNT
    sta F_DICT_USER_COUNT
    ; init status
    sta F_STATUS_COUNT
    ; init built-in dict
    jsr F_REGISTER_ALL_BUILT_IN_FUNCTIONS
    ; reset fonts
    jsr VT100_TEXT_RESET
    rts

F_WELCOME:
    jsr VT100_ERASE_SCREEN
    jsr VT100_CURSOR_HOME
    ldd .welcome_msg[15:8]
    lde .welcome_msg[7:0]
    jsr ACIA_SEND_STRING
    jsr F_STATUS
    ldd .exit_msg[15:8]
    lde .exit_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

.welcome_msg:
    #d "Forth compiler for OTTO - v1.0.0", 0x0A, 0x0D, 0x00
.exit_msg:
    #d "Use BYE to exit", 0x0A, 0x0D, 0x00

F_STATUS:
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
    #d "-> Memory start at address 0x", 0x00 
.dictionary_msg:
    #d "-> Dictionary definitions: ", 0x00 
.dictionary_separator:
    #d " / ", 0x00 
.dictionary_suffix:
    #d " (built-in / user) ", 0x00   

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

#const F_FIND_TOKEN_MSB = F_MEMORY_START + 0x0128
#const F_FIND_TOKEN_LSB = F_MEMORY_START + 0x0129
#const F_FIND_TOKEN_START = F_MEMORY_START + 0x012A
#const F_FIND_TOKEN_COUNT = F_MEMORY_START + 0x012B

#const F_BI_IF_THEN_START = F_MEMORY_START + 0x012C
#const F_BI_IF_ELSE_START = F_MEMORY_START + 0x012D

#const F_DICT_BUILT_IN_COUNT = F_MEMORY_START + 0x012E
#const F_DICT_USER_START_LSB = F_MEMORY_START + 0x012F
#const F_DICT_USER_START_MSB = F_MEMORY_START + 0x0130
#const F_DICT_USER_COUNT = F_MEMORY_START + 0x0131

; Placing the stack at the end of the variable area
#const F_STACK_START = F_MEMORY_START + 0x0200

; Placing the dictionary at the end of the stack area 
; The user dictionary is placed at the end of the buil-in dictionary
#const F_DICT_BUILT_IN_START = F_STACK_START + F_MAX_STACK_SIZE

; Placing the status saving area at the end of the dictionary 
#const F_STATUS_START = F_DICT_BUILT_IN_START + F_MAX_DICT_SIZE 

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
    cmp 0x7F
    beq .backspace
    jsr ACIA_SEND_CHAR
    ldx F_INPUT_BUFFER_COUNT
    sta F_INPUT_BUFFER_START,x
    inc F_INPUT_BUFFER_COUNT
    cpx F_MAX_INPUT_SIZE
    beq .show_too_long_error
    jmp .loop

.backspace:
    jsr VT100_CURSOR_LEFT
    jsr VT100_CLEAR_LINE_END
    lda  F_INPUT_BUFFER_COUNT
    beq .loop
    dec F_INPUT_BUFFER_COUNT
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

F_FIND_TOKEN:
    ldd F_FIND_TOKEN_MSB
    lde F_FIND_TOKEN_LSB

    ; save in stack 
    lda F_TOKEN_START
    pha
    lda F_TOKEN_COUNT
    pha

.next_token:
    ; set new start
    clc
    lda F_TOKEN_COUNT
    adc F_TOKEN_START
    sta F_TOKEN_START
    cmp F_INPUT_BUFFER_COUNT
    beq .not_found

    jsr F_TOKENIZE

    ;compare
    ldy F_TOKEN_START
    ldx 0x00

.cmp_loop:
    lda de,x
    beq .check_token_length 
    cmp F_INPUT_BUFFER_START,y
    bne .next_token
    inx
    iny
    jmp .cmp_loop

.check_token_length:
    cpx F_TOKEN_COUNT
    bne .next_token

.found:
    lda F_TOKEN_START
    sta F_FIND_TOKEN_START
    lda F_TOKEN_COUNT
    sta F_FIND_TOKEN_COUNT    
    jmp .done

.not_found:
    lda 0x00
    sta F_FIND_TOKEN_START
    sta F_FIND_TOKEN_COUNT ; not found
    
.done:
    pla 
    sta F_TOKEN_COUNT
    pla 
    sta F_TOKEN_START
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

F_TOKEN_IS_DICTIONARY:
    ldd F_DICT_USER_START_MSB
    lde F_DICT_USER_START_LSB
    lda 0x00
    sta F_DICT_EXEC_USER_ITEM
    ldy F_DICT_USER_COUNT
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
    inc F_DICT_EXEC_USER_ITEM
    jmp .check_if_match    

.dictionary_end:
    clc
    rts

F_EXECUTE_DICTIONARY:
    jsr F_PUSH_STATUS

    ldd F_DICT_USER_START_MSB
    lde F_DICT_USER_START_LSB

.go_to_item_loop:
    lda F_DICT_EXEC_USER_ITEM
    beq .find_cmd
    dec F_DICT_EXEC_USER_ITEM

    ldx 0x00
    lda de, x
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    jmp .go_to_item_loop

.find_cmd:
    ldx 0x01
.find_cmd_loop:
    lda de, x
    beq .copy_cmd
    inx
    jmp .find_cmd_loop

.copy_cmd:
    inx
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
    lda 0x00
    sta F_TOKEN_START
    sta F_TOKEN_COUNT
    rts

; DICT user records
; - TOTAL SIZE
;   - label (0x00 terminated)
;   - cmd   (0x00 terminated)
F_DICTIONARY_USER_ADD:
    ldd F_DICT_USER_START_MSB
    lde F_DICT_USER_START_LSB
    ldy F_DICT_USER_COUNT
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
    beq .copy_cmd
    inx
    iny
    jmp .add_loop
.copy_cmd:
    ldy F_DICT_ADD_USER_START
    inx
.copy_cmd_loop:
    lda F_INPUT_BUFFER_START, y
    sta de, x
    iny
    inx
    dec F_DICT_ADD_USER_COUNT
    bne .copy_cmd_loop
    lda 0x00
    sta de, x 
    ; set record size
    inx
    txa
    ldx 0x00
    sta de, x    
    ; inc # of user functions
    inc F_DICT_USER_COUNT 
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
    _MACRO_REGISTER_BUILT_IN F_BI_IF_LABEL, F_BI_IF
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
; - TOTAL SIZE   
;    - F_INPUT_BUFFER_COUNT 
;    - F_TOKEN_START 
;    - F_TOKEN_COUNT 
;    - INPUT_BUFFER 

F_PUSH_STATUS:
    ldd F_STATUS_START[15:8]
    lde F_STATUS_START[7:0]
    ldy F_STATUS_COUNT
    beq .push_vars
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

.push_vars:
    ldx 0x01
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
    txa
    ldx 0x00
    sta de, x
    rts

F_PULL_STATUS:
    dec F_STATUS_COUNT
    ldd F_STATUS_START[15:8]
    lde F_STATUS_START[7:0]
    ldy F_STATUS_COUNT
    beq .pull_vars
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
.pull_vars:
    ldx 0x01
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
