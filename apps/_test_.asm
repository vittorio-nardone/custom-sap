#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram   
    
    ldo 0x34
    
    lda .value[7:0]
    sta .ptr
    lda .value[15:8]
    sta .ptr +1
    
    lda 0x27
    sta (.ptr)
    
    lda 0x10

    lda (.ptr)
    tao

    cmp 0x27
    bne .fail

    ldx 0x02
    lda (.ptr),x
    tao

    rts

.ptr:
    #d 0x00, 0x00

.value:
    #d 0x00
    #d 0x15
    #d 0x17

.fail:
    ldo 0xFA
    rts