; Bank definition
#bankdef rom3
{
    #addr 0x4000
    #size 0x2000
    #outp 0
}
#bank rom3   

#const FORTH_VERSION = "v1.1.153"
#const FORTH_BUILDDATE = "05/26/2025"

; Include definitions, kernel symbols and Forth consts
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"
#include "consts.asm"

; **********************************************************
; MAIN ENTRY POINT
; **********************************************************
FORTH_MAIN:
    jsr F_INIT
    jsr F_WELCOME
.loop:
    jsr F_INPUT
    jsr F_16_CHECK_INPUT_COUNT_IS_ZERO
    bcs .loop
    jsr VT100_TEXT_REVERSE
    jsr F_ELABORATE
    jsr VT100_TEXT_RESET
    lda F_EXIT_INTERPRETER_FLAG
    beq .loop
    rts

; **********************************************************
; Include modules here
; **********************************************************
#include "built-in.asm"
#include "dict.asm"
#include "dict-cache.asm"
#include "stack.asm"
#include "status.asm"
#include "utils.asm"
#include "loops.asm"
#include "math.asm"
#include "input.asm"

; **********************************************************
; Init vars
; **********************************************************
F_INIT:
    ; init stack & other vars
    lda 0x00
    sta F_STACK_COUNT
    sta F_EXIT_INTERPRETER_FLAG
    sta F_EXECUTION_ABORT_FLAG
    sta F_DICT_USER_COUNT
    sta F_STATUS_COUNT
    sta F_DO_LOOP_COUNT
    sta F_BEGIN_UNTIL_COUNT
    sta F_IF_THEN_COUNT  
    ; Init pointer to input buffer
    lda F_USER_INPUT_BUFFER_START[15:8]
    sta F_INPUT_BUFFER_START_MSB
    lda F_USER_INPUT_BUFFER_START[7:0]
    sta F_INPUT_BUFFER_START_LSB
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
    #d "Forth Interpreter for OTTO - ", FORTH_VERSION, " (", FORTH_BUILDDATE, ")", 0x0A, 0x0D, 0x00
.exit_msg:
    #d "Use BYE to exit, FORTH to get info", 0x0A, 0x0D, 0x00

; **********************************************************
; Input
; **********************************************************
F_INPUT:
    jsr ACIA_SEND_NEWLINE
    lda 0x00    
    sta F_INPUT_COL_COUNT
    jsr F_16_RESET_INPUT
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
    inc F_INPUT_COL_COUNT
    jsr F_16_ADD_INPUT_BYTE
    jsr F_16_CHECK_MAX_INPUT_SIZE
    bcs .show_too_long_error
    jmp .loop

.backspace:
    lda F_INPUT_COL_COUNT
    beq .loop
    dec F_INPUT_COL_COUNT 
    jsr F_16_DEL_INPUT_BYTE
    jsr VT100_CURSOR_LEFT
    jsr VT100_CLEAR_LINE_END
    jmp .loop

.newline:
    jsr ACIA_SEND_NEWLINE
    lda 0x00    
    sta F_INPUT_COL_COUNT 
    lda 0x0D 
    jsr F_16_ADD_INPUT_BYTE
    jsr F_16_CHECK_MAX_INPUT_SIZE
    bcs .show_too_long_error  
    ldd .prompt2_msg[15:8]
    lde .prompt2_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .loop

.cmd_entered:
    lda F_INPUT_COL_COUNT
    bne .newline
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

.prompt2_msg:
    #d ".. " 
    #d 0x00

; **********************************************************
; Execution
; **********************************************************
F_ELABORATE:
    lda 0x00
    sta F_EXECUTION_ERROR_FLAG
    sta F_EXECUTION_ABORT_FLAG
    jsr F_16_RESET_TOKEN_START

    ; Init cache area
    jsr F_INIT_DICT_CACHE

.loop:
    jsr F_TOKENIZE
    jsr F_16_CHECK_TOKEN_COUNT_IS_ZERO
    bcs .send_ok
    jsr F_TOKEN_TO_UPPERCASE

.check_cached:
    ; jmp .check_number ; skip cache

    jsr F_IS_DICT_CACHED
    bcc .check_number
    lda F_DICT_CACHE_TYPE
    cmp F_DICT_CACHE_RECORD_TYPE_BUILT_IN
    beq .exec_builtin
    cmp F_DICT_CACHE_RECORD_TYPE_USER_DICT_CMD
    beq .cached_dictionary
    jmp .check_number

.cached_dictionary:
    jsr F_EXECUTE_CACHED_USER_DICT_CMD
    jmp .next_token
    
.check_number:
    jsr F_TOKEN_IS_NUMBER
    bcc .check_builtin  
    jsr F_TOKEN_TO_NUMBER
    jsr F_STACK_PUSH
    jmp .next_token

.check_builtin:
    jsr F_TOKEN_IS_BUILTIN
    bcc .check_dictionary
    jsr F_ADD_BUILT_IN_TO_DICT_CACHE
.exec_builtin:
    #d 0x93, 0x00, F_DICT_EXEC_BUILT_IN_PTR_PAGE[15:8],  F_DICT_EXEC_BUILT_IN_PTR_PAGE[7:0]
    jmp .next_token

.check_dictionary:
    jsr F_TOKEN_IS_USER_DICTIONARY
    bcc .token_error
    jsr F_EXECUTE_USER_DICTIONARY
    jmp .next_token

.token_error:
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

    jsr F_16_ADD_COUNT_TO_TOKEN_START
    jsr F_16_CHECK_START_END_OF_FILE
    bcc .loop
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
    sta F_IF_THEN_COUNT
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