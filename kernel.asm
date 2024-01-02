;
; Memory map
;
; 0x0000-0x5FFF (24k) - ROM
;       0x00FF-(?)  - reserved for interrupt routine
; 0x6000-0x67FF (2K) - device I/O
;       0x6000-0x6001 - key pressed buffer
; 0x6800-0x7FFF (6K) - 6k for video 
; 0x8000-0xFFFF (32k) - RAM
;       0xFF00-0xFFFF (256) - reserved for stack

#include "ruledef.asm"
#include "tests.asm"

#const interruptCounter = 0x8F8F

#addr 0x0000
boot:
    sei             ; disable int
    lda 0x00
    sta interruptCounter
    cli             ; enable int
loop:
    jmp loop
    jsr tests
main:
    lda interruptCounter
    tao
    hlt

#addr 0x00FF        ; default interrupt handler routine
interrupt:
    pha
    ldo 0xAA
    tia
    ; cmp 0xFC
    ; beq interrupt_ret
    ; inc interruptCounter
    ; ldo interruptCounter
    tao
interrupt_ret:
    pla
    rti             

