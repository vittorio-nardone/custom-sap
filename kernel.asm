;
; Memory map
;
; 0x0000-0x3FFF (16k) - ROM
;       0x00FF-(?)  - reserved for interrupt routine
; 0x4000-0x5FFF (8k)  - free (6k for video?)
; 0x6000-0x7FFF (8k)  - free
; 0x8000-0xFFFF (32k) - RAM
;       0xFF00-0xFFFF (256) - reserved for stack

#include "ruledef.asm"
#include "tests.asm"

#const interruptCounter = 0x8F8F

#addr 0x0000
boot:
    tia
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
    ;tia
    cmp 0xfd
    bne interruptEnd
    inc interruptCounter
interruptEnd:
    RTI             ; 

