#include "ruledef.asm"
#include "tests.asm"

#addr 0x0000
boot:
    cli
    jmp tests
main:
    hlt

#addr 0x00FF        ; default interrupt handler routine
interrupt:
    ldo 0x27        ; TODO
    RTI             ; 

