; CH376S low-level I/O on Otto ACIA #2 (0x6022/0x6023).
; Console output uses kernel ACIA #1 routines.

ch376_acia2_init:
    lda ACIA_INIT_MASTER_RESET
    sta ACIA2_CONTROL_STATUS_ADDR
    lda ACIA_INIT_115200_8N1
    sta ACIA2_CONTROL_STATUS_ADDR
    rts

ch376_uart_putc:
    pha
ch376_uart_putc_wait:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq ch376_uart_putc_wait
    pla
    sta ACIA2_RW_DATA_ADDR
    rts

; C=1 and A=byte on success. Uses CH376_TMO (16-bit down-counter).
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

; Drain any pending CH376 bytes (e.g. extra connect/disconnect status).
ch376_drain_rx:
    jsr ch376_uart_flush
    rts

; Rough ~50ms busy-wait at 1 MHz (tune if needed).
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

; ~300ms busy-wait at 1 MHz — USB stick may need time before RD_USB_DATA0.
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

; Save/restore CH376_TMO around slow USB reads (Ch376msc ANSWTIMEOUT ~1s).
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

ch376_print_status:
    sta CH376_LAST_STATUS
    ldd ch376_msg_st[15:8]
    lde ch376_msg_st[7:0]
    jsr ACIA_SEND_STRING
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    rts

ch376_msg_st:
    #d "ST ", 0x00
