#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram   
    
    ldo 0x02            ; Test #2: LDA & CMP & BEQ
    lda 0x34            ; Load dummy value
    cmp 0x34
    bne .fail

    ldo 0x03            ; Test #3: CMP x,y indexed
    ldx 0x34
    ldy 0x05
    lda 0x05
    sta 0x8001
    cmp 0x7fcd,x
    bne .fail
    cmp 0x7ffc,y
    bne .fail
    lda 0x20
    cmp 0x7fcd,x
    beq .fail
    cmp 0x7ffc,y
    beq .fail

    rts

.fail:
    ldo 0xFA
    hlt