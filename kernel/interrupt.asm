; **********************************************************
; INTERRUPT HANDLER Routine
;

#once
#bank low_kernel
#include "serial.asm"

#const INT_EXTINT1  = 0x01
#const INT_EXTINT2  = 0x02
#const INT_TIMER    = 0x04
#const INT_KEYBOARD = 0x08

#const INT_TIMER_COUNTER_MSB        = 0x83F6 ;
#const INT_TIMER_COUNTER_LSB        = 0x83F7 ;

#const INT_EXTINT1_HANDLER_POINTER  = 0x83F8 ; -0x83F9  - pointer to INT1 interrupt handler 
#const INT_EXTINT2_HANDLER_POINTER  = 0x83FA ; -0x83FB  - pointer to INT2 interrupt handler
#const INT_TIMER_HANDLER_POINTER    = 0x83FC ; -0x83FD  - pointer to TIMER interrupt handler
#const INT_KEYBOARD_HANDLER_POINTER = 0x83FE ; -0x83FF  - pointer to KEYB interrupt handler

#addr 0x00FF  
INTERRUPT_HANDLER:
    pha
    tia
.int1_check:
    bit INT_EXTINT1
    beq .int2_check
    jsr (INT_EXTINT1_HANDLER_POINTER)
.int2_check:
    bit INT_EXTINT2
    beq .int_timer_check
    jsr (INT_EXTINT2_HANDLER_POINTER)
.int_timer_check:
    bit INT_TIMER
    beq .int_keyboard_check
    jsr (INT_TIMER_HANDLER_POINTER)
.int_keyboard_check:
    bit INT_KEYBOARD
    beq .int_end
    jsr (INT_KEYBOARD_HANDLER_POINTER)
.int_end:
    pla
    rti

; **********************************************************
; SUBROUTINE: INTERRUPT_INIT
;
; DESCRIPTION:
;
; INPUTS:
;   A : interrupt mask 
;           (1) (1) (1) (1) key timer ext2 ext1
;
; OUTPUTS:
;
; DESTROY:
;   D, E 
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 13/10/2024
; **********************************************************

INTERRUPT_INIT:
    sei
    tai

    ldd INTERRUPT_DUMMY_HANDLER[15:8] 
    lde INTERRUPT_DUMMY_HANDLER[7:0] 
    std INT_EXTINT1_HANDLER_POINTER
    ste INT_EXTINT1_HANDLER_POINTER + 1
    std INT_KEYBOARD_HANDLER_POINTER
    ste INT_KEYBOARD_HANDLER_POINTER + 1

    ldd INTERRUPT_SERIAL_HANDLER[15:8] 
    lde INTERRUPT_SERIAL_HANDLER[7:0] 
    std INT_EXTINT2_HANDLER_POINTER
    ste INT_EXTINT2_HANDLER_POINTER + 1

    ldd INTERRUPT_TIMER_HANDLER[15:8] 
    lde INTERRUPT_TIMER_HANDLER[7:0]     
    std INT_TIMER_HANDLER_POINTER
    ste INT_TIMER_HANDLER_POINTER + 1
    ldd 0x00
    std INT_TIMER_COUNTER_LSB
    std INT_TIMER_COUNTER_MSB

    rts

INTERRUPT_DUMMY_HANDLER:
    rts

INTERRUPT_TIMER_HANDLER:
    inc INT_TIMER_COUNTER_LSB
    bne .interrupt_timer_handler_end
    inc INT_TIMER_COUNTER_MSB
.interrupt_timer_handler_end:
    rts

INTERRUPT_SERIAL_HANDLER:
    phx
    phd
    phe
    jsr ACIA_READ_TO_BUFFER
    ple
    pld
    plx
    rts

