; Misura cicli di WAIT_10MS_APPROX con DMP (atteso ~0x2722 = 2+16+10000 tra i due DMP)
; @load-address 0x8400
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x100
    #outp 0
}

#bank ram
    dmp
    jsr WAIT_10MS_APPROX
    dmp
    hlt
