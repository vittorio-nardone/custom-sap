; =====================================================
; Brainfuck interpreter for Otto
; =====================================================
; Description:
;   Brainfuck is an esoteric programming language created in 1993 by Swiss student Urban Müller.
;   Designed to be extremely minimalistic, the language consists of only eight simple commands, 
;   a data pointer, and an instruction pointer.
;
;   https://en.wikipedia.org/wiki/Brainfuck
;
; Created: 31/12/2024
; Author: Vittorio Nardone
; =====================================================

; Include necessary definitions and symbols
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

; Define RAM bank starting at 0x8400 with size 0x6C00
#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    sei                         ; Disable interrupts
    ldd WELCOME_MSG[15:8]      ; Load high byte of welcome message address
    lde WELCOME_MSG[7:0]       ; Load low byte of welcome message address
    jsr ACIA_SEND_STRING       ; Display welcome message

MAIN:
    jsr ACIA_SEND_NEWLINE      ; Print newline
    ldd PROMPT_MSG[15:8]       ; Load high byte of prompt message
    lde PROMPT_MSG[7:0]        ; Load low byte of prompt message
    jsr ACIA_SEND_STRING       ; Display prompt

    lda 0x00                   ; Initialize input buffer counter
    sta INPUT_BUFFER_COUNT
    sta INPUT_BUFFER_COUNT+1
    ldd INPUT_BUFFER[15:8]     ; Initialize input buffer PTR  
    lde INPUT_BUFFER[7:0] 

.loop:                         ; Input reading loop
    jsr ACIA_READ_CHAR
    cmp 0x0D  
    beq .loop_send_newline
    jsr ACIA_SEND_CHAR                            ; Echo character back                              ;
    tao                                           ; Transfer A to O register
    cmp 0x09                                      ; Check for TAB key
    beq RUN                                       ; If TAB, start execution
    ldx INPUT_BUFFER_COUNT+1                      ; Get current buffer position
    sta de,x                                    ; Store character in buffer
    inc INPUT_BUFFER_COUNT+1                      ; Increment buffer counter
    bne .loop                                     ; Buffer not full, continue reading input
    inc INPUT_BUFFER_COUNT                        ; Increment buffer counter (MSB)
    ind                                           ; Increment buffer pointer (MSB)
    cpd 0xB0                                      ; Check if buffer is full
    beq RUN                                       ; If full, start execution
    jmp .loop                                     ; Continue reading input

.loop_send_newline:
    jsr ACIA_SEND_NEWLINE      ; Print newline
    jmp .loop  

RUN:
    lda 0x00                   ; Initialize run position 
    sta PRG_RUN_POS
    sta PRG_RUN_POS+1
    sta PRG_MEMORY_PTR         ; Initialize data pointer
    ldd INPUT_BUFFER[15:8]     ; Initialize input buffer PTR  
    lde INPUT_BUFFER[7:0] 
    jsr ACIA_SEND_NEWLINE      ; Print newline
    jsr .clean_memory          ; Initialize program memory

.cmd_loop:                     ; Main interpretation loop
    jsr .cmd_check_eof         ; Check if we've reached end of input   
    bcs END                    ; If yes, return to main prompt

    lda ACIA_CONTROL_STATUS_ADDR                   ; Check serial port status
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; Wait for data
    beq .cmd_loop_next                             ; If no data, continue
    lda ACIA_RW_DATA_ADDR                          ; Read character from serial port
    cmp 0x1B                    ; Check for ESC key
    beq END                     ; If ESC, stop execution

.cmd_loop_next:
    ldx PRG_RUN_POS+1
    lda de,x                 ; Load next command
    jsr .cmd_inc_prg_run_pos   ; Increment program counter

    ; Compare with each Brainfuck command
    cmp ">"                    ; Increment pointer command
    beq .cmd_inc_ptr
    cmp "<"                    ; Decrement pointer command
    beq .cmd_dec_ptr
    cmp "+"                    ; Increment value command
    beq .cmd_inc_value
    cmp "-"                    ; Decrement value command
    beq .cmd_dec_value
    cmp "["                    ; Start loop command
    beq .cmd_start_loop
    cmp "]"                    ; End loop command
    beq .cmd_end_loop
    cmp ","                    ; Input command
    beq .cmd_read_char
    cmp "."                    ; Output command
    beq .cmd_print_char
    cmp "q"                    ; Quit command
    bne .cmd_loop              ; If not recognized, ignore and continue
    cli                        ; Enable interrupts
    rts                        ; Return from subroutine

; Compare the two 16bit values
.cmd_check_eof:
    lda PRG_RUN_POS
    cmp INPUT_BUFFER_COUNT
    bne .cmd_check_eof_false
    lda PRG_RUN_POS+1
    cmp INPUT_BUFFER_COUNT+1
    bne .cmd_check_eof_false
    sec
    rts
.cmd_check_eof_false:
    clc
    rts

.cmd_inc_prg_run_pos:
    inc PRG_RUN_POS+1
    bne .cmd_inc_prg_run_pos_end
    inc PRG_RUN_POS
    ind
.cmd_inc_prg_run_pos_end:
    rts

.cmd_dec_prg_run_pos:
    lda PRG_RUN_POS+1
    bne .cmd_dec_prg_run_pos_end
    dec PRG_RUN_POS
    ded
.cmd_dec_prg_run_pos_end:
    dec PRG_RUN_POS+1
    rts

; Command implementations
.cmd_inc_ptr:                  ; Increment data pointer
    inc PRG_MEMORY_PTR
    jmp .cmd_loop

.cmd_dec_ptr:                  ; Decrement data pointer
    dec PRG_MEMORY_PTR
    jmp .cmd_loop

.cmd_inc_value:                ; Increment value at pointer
    ldy PRG_MEMORY_PTR
    lda PRG_MEMORY,y
    clc                        ; Clear carry flag
    adc 0x01                   ; Add 1
    sta PRG_MEMORY,y
    jmp .cmd_loop

.cmd_dec_value:                ; Decrement value at pointer
    ldy PRG_MEMORY_PTR
    lda PRG_MEMORY,y
    sec                        ; Set carry flag
    sbc 0x01                   ; Subtract 1
    sta PRG_MEMORY,y
    jmp .cmd_loop

.cmd_start_loop:               ; Handle loop start '['
    ldy PRG_MEMORY_PTR
    lda PRG_MEMORY,y          ; Check value at pointer
    beq .cmd_skip             ; If zero, skip to matching ]
    lda PRG_RUN_POS+1         ; Push current position for later
    pha
    lda PRG_RUN_POS
    pha
    phd
    jmp .cmd_loop

.cmd_skip:                     ; Skip loop if value is zero
    jsr .cmd_skip_loop
    jmp .cmd_loop

.cmd_skip_loop:                ; Find matching ] bracket
    jsr .cmd_check_eof         ; Check if we've reached end of input   
    bcs END                    ; If yes, return to main prompt
    ldx PRG_RUN_POS+1
    lda de,x
    jsr .cmd_inc_prg_run_pos
    cmp "["                    ; Handle nested loops
    beq .cmd_skip_recurse
    cmp "]"
    bne .cmd_skip_loop
    rts

.cmd_skip_recurse:             ; Handle nested loop skipping
    jsr .cmd_skip_loop
    jmp .cmd_skip_loop

.cmd_end_loop:                 ; Handle loop end ']'
    pld                        ; Restore position from start of loop
    pla
    sta PRG_RUN_POS
    pla
    sta PRG_RUN_POS+1                     
    jsr .cmd_dec_prg_run_pos   ; Go back one to reprocess [
    jmp .cmd_loop

.cmd_read_char:                ; Read input character
    jsr ACIA_READ_CHAR
    ldy PRG_MEMORY_PTR
    sta PRG_MEMORY,y           ; Store in memory
    jmp .cmd_loop

.cmd_print_char:               ; Output character
    ldy PRG_MEMORY_PTR
    lda PRG_MEMORY,y  
    jsr ACIA_SEND_CHAR         ; Send to serial port
    cmp 0x0A
    bne .cmd_loop
    lda 0x0D
    jsr ACIA_SEND_CHAR         ; Send to serial port
    jmp .cmd_loop  

.clean_memory:                 ; Initialize program memory to zeros
    lda 0x00
    ldx 0x00
.clean_memory_loop:
    sta PRG_MEMORY,x
    inx
    bne .clean_memory_loop
    rts

END:
    jsr ACIA_SEND_NEWLINE      ; Print newline
    ldd PROMPT_MSG_2[15:8]       ; Load high byte of prompt message
    lde PROMPT_MSG_2[7:0]        ; Load low byte of prompt message
    jsr ACIA_SEND_STRING       ; Display prompt
    jsr ACIA_READ_CHAR
    cmp 0x09
    bne MAIN
    jmp RUN


; Message section
WELCOME_MSG:                   ; Welcome message text
    #d 0x0A, 0x0D             
    #d "Welcome to Brainfuck interpreter for Otto", 0x0A, 0x0D
    #d 0x0A, 0x0D
    #d "Valid commands:", 0x0A, 0x0D
    #d "   >	increment pointer", 0x0A, 0x0D
    #d "   <	decrement pointer", 0x0A, 0x0D
    #d "   +	increment value at pointer", 0x0A, 0x0D
    #d "   -	decrement value at pointer", 0x0A, 0x0D
    #d "   [	begin loop (continues while value at pointer is non-zero)", 0x0A, 0x0D
    #d "   ]	end loop", 0x0A, 0x0D
    #d "   ,	read one character from input into value at pointer", 0x0A, 0x0D
    #d "   .	print value at pointer to output as a character", 0x0A, 0x0D
    #d "   q    quit interpreter", 0x0A, 0x0D
    #d "   Any other characters are ignored", 0x0A, 0x0D
    #d "More info: https://en.wikipedia.org/wiki/Brainfuck", 0x0A, 0x0D
    #d 0x00    

PROMPT_MSG:                    ; Prompt message text
    #d "Ready: write your code and press TAB. Press ESC to interrupt execution.", 0x0A, 0x0D, 0x00

PROMPT_MSG_2:                  ; Prompt message text
    #d "Execution completed: press TAB to run again or any other key to enter a new program.", 0x0A, 0x0D, 0x00

; Data section
; Program buffers and variables
PRG_RUN_POS:                   ; Current command in execution
    #d 0x00, 0x00

PRG_MEMORY_PTR:                ; Program memory pointer
    #d 0x00

PRG_MEMORY:                    ; Program memory space (256 bytes)
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

INPUT_BUFFER_COUNT:            ; Counter for characters in input buffer
    #d 0x00, 0x00
INPUT_BUFFER:                  ; Buffer for storing input program (max 4K bytes)
    #d 0x00