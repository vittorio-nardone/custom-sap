;
; Memory map ( TODO use #bankdef )
;
; 0x0000-0x5FFF (24k) - ROM
;       0x00FF-(?)  - reserved for interrupt routine
; 0x6000-0x67FF (2K) - device I/O
;       0x600? - keyboard (8 locations, lda) 
;       0x601? - xorshift random generator (lda)
;           0x6010 - low random byte
;           0x6011 - high random byte
;           0x6012 - random init (call N times for seeding)
; 0x6800-0x7FFF (6K) - 6k for video 
; 0x8000-0xFFFF (32k) - RAM
;       0x8000-0x8400 (1k) - reserved for kernel operations
;       0xF000-0xFFFF (4k) - reserved for stack
;
;
; Memory expansion board (64k) - RAM
; 0x010000 - 0x01FFFF
; 
;  Interrupt register / mask register bits
;  (1) (1) (1) (1) key timer ext2 ext1
;
;  Flag register
;  N x x x Z C x x

#include "ruledef.asm"
#include "tests.asm"
#include "math.asm"

#const keyInterruptCounter = 0x8F8E
#const timerInterruptCounter = 0x8F8F
#const int1InterruptCounter = 0x8F8B

#addr 0x0000
boot:
    ldo 0x00
    scf
    sei             ; disable int
    lda 0x00
    sta keyInterruptCounter
    sta timerInterruptCounter
    sta int1InterruptCounter
    lda 0x04        ; set int mask
    tai
    ; jsr MICROCODE_test
    jsr MATH_test

main:
    
    cli

.loop:
    ldo timerInterruptCounter
    jsr MATH_test
    jmp .loop

;     ldx 0x00
;     ldy 0x00
;     lda 0x00

; loop:
;     inx
;     cpx 0xFF
;     bne loop
;     jmp loop_2

; #addr 0x1000     
; loop_2:
;     ldx 0x00
;     iny
;     cpy 0xFF
;     bne loop
;     ldy 0x00
;     clc
;     adc 0x01
;     tao
;     jmp loop

;
; default interrupt handler routine
;
#addr 0x00FF  
interrupt:
    pha
interrupt_keyboard_check:
    tia
    and 0x08
    bne keyboard_scan
interrupt_timer_check:
    tia
    and 0x04
    beq interrupt_return
    inc timerInterruptCounter
interrupt_return:
    pla
    rti             


keyboard_scan:
    txa
    pha
    ldx 0x07
keyboard_scan_loop:
    lda 0x6000,x            ; key ROW
    cmp 0xFF
    bne keyboard_scan_keypressed
    cpx 0x00
    beq interrupt_timer_end
    dex
    jmp keyboard_scan_loop
keyboard_scan_keypressed:
    inc keyInterruptCounter
    txa
    tao
interrupt_timer_end:
    pla
    tax
    jmp interrupt_timer_check