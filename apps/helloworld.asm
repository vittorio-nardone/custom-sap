#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram
    jsr VT100_ERASE_SCREEN
    jsr VT100_BG_RED
    ldd .hello_msg[15:8]
    lde .hello_msg[7:0]
    jsr ACIA_SEND_STRING
    jsr VT100_TEXT_RESET
    ldo 0xAA
    rts

.hello_msg:
    #d 0x0A, 0x0D, "Greetings Professor Falken, shall we play a game?", 0x0A, 0x0D, 0x00    