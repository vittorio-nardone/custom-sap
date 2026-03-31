; @load-address 0x9000
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x9000
    #size 0x6000
    #outp 0
}

#bank ram
    jsr VT100_FG_GREEN
    ldd .msg1[15:8]
    lde .msg1[7:0]
    jsr ACIA_SEND_STRING

    ldd .msg2[15:8]
    lde .msg2[7:0]
    jsr ACIA_SEND_STRING

    jsr VT100_TEXT_RESET
    ldo 0x42
    rts

.msg1:
    #d 0x0A, 0x0D, "OT Header Test - loaded at 0x9000!", 0x0A, 0x0D, 0x00

.msg2:
    #d "If you see this, auto-load worked!", 0x0A, 0x0D, 0x00
