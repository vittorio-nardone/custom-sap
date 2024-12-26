#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

; Memory bank definition for RAM
#bankdef ram
{
    #addr 0x010000   ; Starting address of RAM
    #size 0x1000     ; Size of RAM bank (4096 bytes)
    #outp 0          ; Output configuration
}

#bank ram
    ldx 0x05
loop:
    txa
    tao
    sta 0x011000,x
    inx
    bne loop
    rts