; @load-address 0x8400
; =========================================================
; BINDEC16 / ACIA_SEND_DECIMAL16S regression + cycle harness
;
; Prints a fixed suite of signed 16-bit values (one per line).
; Output must match scripts/python/test_bindec16.py expectations.
; =========================================================

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

    ; --- table of LE signed words, ended by 0x0000 sentinel after last? ---
    ; Use explicit count instead (0 is a valid test value).
    ldx 0x00
.loop:
    cpx .nvalues
    beq .done

    ; load MATH16_A from table (LE): X = value index
    txa
    asl a                 ; word offset
    tay
    lda .values,y
    sta MATH16_A
    iny
    lda .values,y
    sta MATH16_A+1

    phx                   ; ACIA_SEND_DECIMAL16S destroys X/Y
    jsr ACIA_SEND_DECIMAL16S
    jsr ACIA_SEND_NEWLINE
    plx

    inx
    jmp .loop

.done:
    ldd .done_msg[15:8]
    lde .done_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

.nvalues:
    #d 0x10

; little-endian signed 16-bit test vectors
.values:
    #d 0x00, 0x00           ; 0
    #d 0x01, 0x00           ; 1
    #d 0x09, 0x00           ; 9
    #d 0x0A, 0x00           ; 10
    #d 0x63, 0x00           ; 99
    #d 0x64, 0x00           ; 100
    #d 0xE7, 0x03           ; 999
    #d 0xE8, 0x03           ; 1000
    #d 0x0F, 0x27           ; 9999
    #d 0x10, 0x27           ; 10000
    #d 0xFF, 0x7F           ; 32767
    #d 0x00, 0x80           ; -32768
    #d 0xFF, 0xFF           ; -1
    #d 0xD6, 0xFF           ; -42
    #d 0x2A, 0x00           ; 42
    #d 0x70, 0x17           ; 6000

.banner:
    #d "bindec16_test", 0x0A, 0x0D, 0x00

.done_msg:
    #d "OK", 0x0A, 0x0D, 0x00
