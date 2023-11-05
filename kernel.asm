#include "ruledef.asm"
#include "tests.asm"

#const interruptCounter = 0x8F8F

#addr 0x0000
boot:
    lda 0x00
    sta interruptCounter
    cli
    jsr tests
main:
    lda interruptCounter
    tao
    hlt

#addr 0x00FF        ; default interrupt handler routine
interrupt:
    inc interruptCounter
    RTI             ; 

