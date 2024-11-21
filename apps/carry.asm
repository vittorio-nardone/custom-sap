#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x9000
    #size 0x1000
    #outp 0
}

#bank ram

; A >= op --> C = 1 else C = 0

test:
    
    LDA 0x20
    CMP 0x01
    BCC .fail

    CMP 0x20
    BCC .fail

    CMP 0x21
    BCS .fail

    LDA 0x01
    CLC
    ADC 0x02
    ADC 0x02
    CMP 0x05
    BNE .fail

    LDA 0x08
    SEC
    SBC 0x05
    SBC 0x02
    CMP 0x01
    BNE .fail

    LDA 0xFE
    CLC
    ADC 0x03
    BCC .fail

    LDA 0x08
    CLC
    SBC 0x05
    SBC 0x02
    BNE .fail

    LDO 0x00
    rts

.fail:
    LDO 0xFA
    rts
