#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#const TEST_VALUE_LSB = 0x8080
#const TEST_VALUE_MSB = 0x8081

#bank ram   

    lda 0xFF
    sta TEST_VALUE_LSB
    lda 0x05
    sta TEST_VALUE_MSB

    inw TEST_VALUE_LSB

    lda TEST_VALUE_LSB
    cmp 0x00
    bne .fail

    lda TEST_VALUE_MSB
    cmp 0x06
    bne .fail

    dew TEST_VALUE_LSB

    lda TEST_VALUE_LSB
    cmp 0xFF
    bne .fail

    lda TEST_VALUE_MSB
    cmp 0x05
    bne .fail
    
    ldo 0x00
    rts

.fail:
    ldo 0xFA
    rts