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
boot:
    sei             ; disable int
    lda 0x00
    sta interruptCounter
    cli             ; enable int
loop:
    ;jmp loop
    jsr tests
main:
    lda interruptCounter
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
    inc interruptCounter
interrupt_return:
    pla
    rti             

keyboard_scan:
    txa
    pha 
    ldx 0x01
    txa
keyboard_scan_loop:   
    eor 0xff
    sta 0x6008
    lda 0x6009
    eor 0xff
    bne keyboard_scan_keypressed
keyboard_scan_next:    
    txa
    cmp 0x80
    beq keyboard_scan_end 
    asl A
    tax
    jmp keyboard_scan_loop
keyboard_scan_keypressed:
    tao
    jmp keyboard_scan_next
keyboard_scan_end:
    pla
    tax
    jmp interrupt_timer_check