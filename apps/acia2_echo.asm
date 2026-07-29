; @load-address 0x8400
; =====================================================
; ACIA #2 echo test (hardware smoke test)
; =====================================================
; Serial 2: control/status 0x6022, data 0x6023 (115200 8N1).
; Bidirectional echo: bytes from serial 1 or 2 go to both ports.
; Send '0' (0x30) on either port to exit.
; =====================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#const ACIA2_CONTROL_STATUS_ADDR = 0x6022
#const ACIA2_RW_DATA_ADDR = 0x6023
#const EXIT_CHAR = 0x30

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
    jsr .acia1_poll
    bcs .handle_char
    jsr .acia2_poll
    bcs .handle_char
    jmp .loop

.handle_char:
    cmp EXIT_CHAR
    beq .done
    jsr .echo_both
    jmp .loop

.done:
    rts

; C=1 and A=byte if serial 1 has input (buffer or hardware).
.acia1_poll:
    jsr ACIA_PULL_FROM_BUFFER
    bcs .acia1_poll_done
    lda ACIA_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    beq .acia1_poll_none
    lda ACIA_RW_DATA_ADDR
    sec
    rts
.acia1_poll_done:
    rts
.acia1_poll_none:
    clc
    rts

; C=1 and A=byte if serial 2 has input.
.acia2_poll:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    beq .acia2_poll_none
    lda ACIA2_RW_DATA_ADDR
    sec
    rts
.acia2_poll_none:
    clc
    rts

; A = byte to echo on both serial ports.
.echo_both:
    pha
    jsr .acia2_xmit
    pla
    jmp .acia1_xmit

.acia2_xmit:
    pha
.acia2_wait_tx:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .acia2_wait_tx
    pla
    sta ACIA2_RW_DATA_ADDR
    rts

.acia1_xmit:
    pha
.acia1_wait_tx:
    lda ACIA_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .acia1_wait_tx
    pla
    sta ACIA_RW_DATA_ADDR
    rts

; Master reset + 115200 8N1 (no RX interrupt).
.acia2_init:
    lda ACIA_INIT_MASTER_RESET
    sta ACIA2_CONTROL_STATUS_ADDR
    lda ACIA_INIT_115200_8N1
    sta ACIA2_CONTROL_STATUS_ADDR
    rts

.banner:
    #d 0x0A, 0x0D, "ACIA2 bridge (115200). Echo on Otto + port 2. Send 0 to exit.", 0x0A, 0x0D, 0x00
