; Bank definition
#bankdef ram
{
    #addr 0x8400
    #size 0x2B00
    #outp 0
}
#bank ram   

; Include definitions, kernel symbols and Forth consts
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"
#include "forth/consts.asm"

; **********************************************************
; MAIN ENTRY POINT
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

; **********************************************************
; Include modules here
; **********************************************************
#include "forth/built-in.asm"
#include "forth/dict.asm"
#include "forth/stack.asm"
#include "forth/status.asm"
#include "forth/utils.asm"
#include "forth/loops.asm"
#include "forth/math.asm"

; **********************************************************
; Init vars
; **********************************************************
F_INIT:
    ; init stack & other vars
    lda 0x00
    sta F_STACK_COUNT
    sta F_EXIT_INTERPRETER_FLAG
    sta F_EXECUTION_ABORT_FLAG
    sta F_DICT_BUILT_IN_COUNT
    sta F_DICT_USER_COUNT
    sta F_STATUS_COUNT
    sta F_DO_LOOP_COUNT
    sta F_BEGIN_UNTIL_COUNT
    ; init built-in dict
    jsr F_REGISTER_ALL_BUILT_IN_FUNCTIONS
    ; reset fonts
    jsr VT100_TEXT_RESET
    rts

; **********************************************************
; Show welcome message
; **********************************************************
F_WELCOME:
    jsr VT100_ERASE_SCREEN
    jsr VT100_CURSOR_HOME
    ldd .welcome_msg[15:8]
    lde .welcome_msg[7:0]
    jsr ACIA_SEND_STRING
    ldd .exit_msg[15:8]
    lde .exit_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

.welcome_msg:
    #d "Forth compiler for OTTO - v1.0.0", 0x0A, 0x0D, 0x00
.exit_msg:
    #d "Use BYE to exit, FORTH to get info", 0x0A, 0x0D, 0x00

; **********************************************************
; Input
; **********************************************************
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

; **********************************************************
; Execution
; **********************************************************
F_ELABORATE:
    lda 0x00
    sta F_TOKEN_START
    sta F_EXECUTION_ERROR_FLAG
    sta F_EXECUTION_ABORT_FLAG

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
    ;jsr ACIA_SEND_NEWLINE
    jsr F_PRINT_TOKEN
    lda .token_error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .token_error_msg[7:0]
    sta F_ERROR_MSG_LSB
    jmp .error

.next_token:
    lda F_EXECUTION_ERROR_FLAG
    bne .error

    lda F_EXECUTION_ABORT_FLAG
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

.error:
    ldd F_ERROR_MSG_MSB
    lde F_ERROR_MSG_LSB
    jsr ACIA_SEND_STRING
    lda 0x00
    sta F_STACK_COUNT
    sta F_EXIT_INTERPRETER_FLAG
    sta F_EXECUTION_ABORT_FLAG
    sta F_STATUS_COUNT
    sta F_DO_LOOP_COUNT
    sta F_BEGIN_UNTIL_COUNT
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