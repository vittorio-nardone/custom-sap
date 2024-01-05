;
; Memory map ( TODO use #bankdef )
;
; 0x0000-0x5FFF (24k) - ROM
;       0x00FF-(?)  - reserved for interrupt routine
; 0x6000-0x67FF (2K) - device I/O
;       0x600? - keyboard
;         0x6008 - keyboard COL out
;         0x6009 - keyboard ROW in  
; 0x6800-0x7FFF (6K) - 6k for video 
; 0x8000-0xFFFF (32k) - RAM
;       0xFF00-0xFFFF (256) - reserved for stack
;
;
;  Int register bits
;  (1) (1) (1) (1) key timer ext2 ext1

#include "ruledef.asm"
#include "tests.asm"

#const interruptCounter = 0x8F8F

#addr 0x0000

sei
start:
    ldx 0x01
    txa
loop:   
    eor 0xff
    sta 0x6008
    lda 0x6009
    cmp 0xff
    bne keypressed
next:    
    txa
    cmp 0x80
    beq start 
    asl A
    tax
    jmp loop

keypressed:
    tao
    jmp next

boot:
    sei             ; disable int
    lda 0x00
    sta interruptCounter
    cli             ; enable int
    jsr tests
main:
    lda interruptCounter
    tao
    hlt

#addr 0x00FF        ; default interrupt handler routine
interrupt:
    pha
    tia
    cmp 0xf4
    beq interrupt_ret
    inc interruptCounter
interrupt_ret:
    pla
    rti             

