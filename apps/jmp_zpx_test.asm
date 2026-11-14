; @load-address 0x8400
; JMP (zp,X) smoke test — MSB-first word table, A preserved

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    ldd .banner[15:8]
    lde .banner[7:0]
    jsr ACIA_SEND_STRING

    lda 0xA5
    ldx 0x00
    jmp (.table,x)              ; → .h0

.fail:
    ldd .fail_msg[15:8]
    lde .fail_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

.h0:
    cmp 0xA5                    ; A must survive JMP
    bne .fail
    lda 0x5A
    ldx 0x02
    jmp (.table,x)              ; → .h1

.h1:
    cmp 0x5A
    bne .fail
    ldx 0x04
    jmp (.table,x)              ; → .h2

.h2:
    ldd .ok_msg[15:8]
    lde .ok_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

; MSB-first words (matches JMP (zp,X) / JMPindp pointer layout)
.table:
    #d .h0[15:8], .h0[7:0]
    #d .h1[15:8], .h1[7:0]
    #d .h2[15:8], .h2[7:0]

.banner:
    #d "jmp_zpx_test", 0x0A, 0x0D, 0x00
.ok_msg:
    #d "OK", 0x0A, 0x0D, 0x00
.fail_msg:
    #d "FAIL", 0x0A, 0x0D, 0x00
