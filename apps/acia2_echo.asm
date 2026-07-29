; @load-address 0x8400
; =====================================================
; ACIA #2 echo test (hardware smoke test)
; =====================================================
; Serial 2: control/status 0x6022, data 0x6023 (115200 8N1).
; Echoes every byte received on port 2 back to port 2 and serial 1 (Otto).
; Byte value 0x00 ends the app (Ctrl+@ on minicom).
; =====================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#const ACIA2_CONTROL_STATUS_ADDR = 0x6022
#const ACIA2_RW_DATA_ADDR = 0x6023

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

    jsr .acia2_init

.loop:
    jsr .acia2_read_char
    cmp 0x00
    beq .done
    jsr .acia2_send_char
    jsr ACIA_SEND_CHAR
    jmp .loop

.done:
    rts

; Master reset + 115200 8N1 (no RX interrupt).
.acia2_init:
    lda ACIA_INIT_MASTER_RESET
    sta ACIA2_CONTROL_STATUS_ADDR
    lda ACIA_INIT_115200_8N1
    sta ACIA2_CONTROL_STATUS_ADDR
    rts

; A = received byte.
.acia2_read_char:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    beq .acia2_read_char
    lda ACIA2_RW_DATA_ADDR
    rts

; A = byte to send.
.acia2_send_char:
    pha
.wait_tx:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .wait_tx
    pla
    sta ACIA2_RW_DATA_ADDR
    rts

.banner:
    #d 0x0A, 0x0D, "ACIA2 echo (115200). Bytes echoed on Otto + port 2. Send 0x00 to exit.", 0x0A, 0x0D, 0x00
