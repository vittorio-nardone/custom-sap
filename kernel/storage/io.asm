; CH376S low-level I/O on ACIA #2 (0x6022/0x6023). Console stays on ACIA #1.
;
; Polling only: the kernel never installs an EXTINT1 handler for the CH376.
; Every command waits for the UART status byte, and CH376_INT_FLAG is kept
; (always zero) so the driver logic matches the proven application version.

#once
#bank kernel

#include "const.asm"

ch376_acia2_init:
    lda ACIA_INIT_MASTER_RESET
    sta ACIA2_CONTROL_STATUS_ADDR
    lda ACIA_INIT_115200_8N1
    sta ACIA2_CONTROL_STATUS_ADDR
    rts

; C=1 byte sent; C=0 if the TX register never became ready (CH376_TMO).
ch376_uart_putc:
    phy
    phx
    pha
    ldx CH376_TMO
    ldy CH376_TMO+1
ch376_uart_putc_wait:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    bne ch376_uart_putc_send
    dex
    bne ch376_uart_putc_wait
    dey
    bne ch376_uart_putc_wait
    pla
    plx
    ply
    clc
    rts
ch376_uart_putc_send:
    pla
    sta ACIA2_RW_DATA_ADDR
    plx
    ply
    sec
    rts

; C=1 A=byte. Uses CH376_TMO as loop reload (X=lo, Y=hi).
ch376_uart_getc_tmo:
    ldx CH376_TMO
    ldy CH376_TMO+1
ch376_uart_getc_loop:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne ch376_uart_getc_got
    dex
    bne ch376_uart_getc_loop
    dey
    bne ch376_uart_getc_loop
    clc
    rts
ch376_uart_getc_got:
    lda ACIA2_RW_DATA_ADDR
    sec
    rts

ch376_uart_flush:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    beq ch376_uart_flush_done
    lda ACIA2_RW_DATA_ADDR
    jmp ch376_uart_flush
ch376_uart_flush_done:
    rts

ch376_drain_rx:
    jmp ch376_uart_flush

ch376_acia2_read_status:
    lda ACIA2_CONTROL_STATUS_ADDR
    rts

ch376_uart_rx_pending:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    beq ch376_uart_rx_no
    sec
    rts
ch376_uart_rx_no:
    clc
    rts

; Wait for the UART status byte (Ch376msc model).
ch376_wait_response_byte:
    phx
    phy
    ldx CH376_TMO
    ldy CH376_TMO+1
ch376_wrb_loop:
    jsr ch376_uart_rx_pending
    bcs ch376_wrb_got
    lda CH376_INT_FLAG
    bne ch376_wrb_via_int
    dex
    bne ch376_wrb_loop
    dey
    bne ch376_wrb_loop
    clc
    ply
    plx
    rts
ch376_wrb_via_int:
    lda 0x00
    sta CH376_INT_FLAG
    lda CH376_INT_STATUS
    sec
    ply
    plx
    rts
ch376_wrb_got:
    jsr ch376_uart_getc_tmo
    ply
    plx
    rts

; Release CH376 INT# after the UART status byte was already consumed.
ch376_clear_int:
    pha
    phx
    phy
    sei
    jsr ch376_uart_sync
    lda CH376_CMD_GET_STATUS
    jsr ch376_uart_cmd
    ldx 0xFF
    ldy 0x20
ch376_ci_wait:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne ch376_ci_got
    dex
    bne ch376_ci_wait
    dey
    bne ch376_ci_wait
    jmp ch376_ci_done
ch376_ci_got:
    lda ACIA2_RW_DATA_ADDR
ch376_ci_done:
    lda 0x00
    sta CH376_INT_FLAG
    cli
    ply
    plx
    pla
    rts

ch376_delay_short:
    phx
    phy
    ldx 0x00
    ldy 0xC0
ch376_delay_outer:
    dex
    bne ch376_delay_outer
    dey
    bne ch376_delay_outer
    ply
    plx
    rts

ch376_delay_long:
    phx
    phy
    ldx 0x00
    ldy 0x08
ch376_delay_long_outer:
    dex
    bne ch376_delay_long_outer
    dey
    bne ch376_delay_long_outer
    ply
    plx
    rts

; Default UART timeout (short) and the long variant used while the chip
; talks to the USB device.
ch376_set_timeout:
    lda 0xFF
    sta CH376_TMO
    lda 0x10
    sta CH376_TMO+1
    rts

ch376_set_timeout_long:
    lda 0xFF
    sta CH376_TMO
    sta CH376_TMO+1
    rts

ch376_usb_timeout_on:
    lda CH376_TMO
    sta CH376_TMO_SAVE
    lda CH376_TMO+1
    sta CH376_TMO_SAVE+1
    lda 0xFF
    sta CH376_TMO
    sta CH376_TMO+1
    rts

ch376_usb_timeout_off:
    lda CH376_TMO_SAVE
    sta CH376_TMO
    lda CH376_TMO_SAVE+1
    sta CH376_TMO+1
    rts

ch376_print_nl:
    jmp ACIA_SEND_NEWLINE

ch376_print_hex8:
    jmp ACIA_SEND_HEX

; Null-terminated string at D:E (kernel strings live in the 16-bit space).
ch376_print_str:
    jmp ACIA_SEND_STRING

ch376_print_status:
    sta CH376_LAST_STATUS
    ldd .msg_st[15:8]
    lde .msg_st[7:0]
    jsr ch376_print_str
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jmp ch376_print_nl

.msg_st:
    #d "ST ", 0x00
