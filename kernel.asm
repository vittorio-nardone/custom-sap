;
; Memory map ( TODO use #bankdef )
;
; 0x0000-0x5FFF (24k) - ROM
;       0x00FF-(?)  - reserved for interrupt routine
; 0x6000-0x67FF (2K) - device I/O
;       0x600? - keyboard (8 locations, in) 
; 0x6800-0x7FFF (6K) - 6k for video 
; 0x8000-0xFFFF (32k) - RAM
;       0xFF00-0xFFFF (256) - reserved for stack
;
;
;  Interrupt register / mask register bits
;  (1) (1) (1) (1) key timer ext2 ext1

#include "ruledef.asm"
#include "tests.asm"

#const keyInterruptCounter = 0x8F8E
#const timerInterruptCounter = 0x8F8F

#addr 0x0000
boot:
    sei             ; disable int
    lda 0x00
    sta keyInterruptCounter
    sta timerInterruptCounter
    lda 0x08
    tai
    cli             ; enable int
loop:
    lda keyInterruptCounter
    tao
    ;jmp loop
    jsr tests
main:
    lda keyInterruptCounter
    tao
    hlt

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
    lda 0x6000,x
    bne keyboard_scan_keypressed
    cpx 0x00
    beq interrupt_timer_end
    dex
    jmp keyboard_scan_loop
keyboard_scan_keypressed:
    inc keyInterruptCounter
    tao
interrupt_timer_end:
    pla
    tax
    jmp interrupt_timer_check