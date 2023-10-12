#include "ruledef.asm"

begin:
    lda 0x00
inc:
    adc 0x05
    jmp inc
