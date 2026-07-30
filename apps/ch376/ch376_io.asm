; CH376S low-level I/O on Otto ACIA #2 (0x6022/0x6023).
; Console on ACIA #1.
;
; INT model (hardware microcode + kernel ISR):
;   TAI = write MASK; TIA = read PENDING (not mask). Never RMW mask via TIA.
;   EXTINT1 handler must clear CH376 INT# (GET_STATUS) or level-IRQ storms.
;   Auto UART status byte may already be in ACIA when IRQ fires — drain it first.

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

ch376_drain_count:
    phy
    ldy 0x00
ch376_drain_count_loop:
    jsr ch376_uart_rx_pending
    bcc ch376_drain_count_done
    lda ACIA2_RW_DATA_ADDR
    iny
    jmp ch376_drain_count_loop
ch376_drain_count_done:
    tya
    ply
    rts

ch376_acia2_read_status:
    lda ACIA2_CONTROL_STATUS_ADDR
    rts

; Install EXTINT1 handler; mask = TIMER|EXTINT1 (absolute).
ch376_int_install:
    sei
    lda INT_EXTINT1_HANDLER_POINTER
    sta CH376_SAVED_H
    lda INT_EXTINT1_HANDLER_POINTER + 1
    sta CH376_SAVED_H + 1
    lda ch376_extint1_handler[15:8]
    sta INT_EXTINT1_HANDLER_POINTER
    lda ch376_extint1_handler[7:0]
    sta INT_EXTINT1_HANDLER_POINTER + 1
    lda 0x00
    sta CH376_INT_FLAG
    sta CH376_INT_STATUS
    lda INT_TIMER
    ora INT_EXTINT1
    tai
    cli
    rts

ch376_int_restore:
    sei
    lda CH376_SAVED_H
    sta INT_EXTINT1_HANDLER_POINTER
    lda CH376_SAVED_H + 1
    sta INT_EXTINT1_HANDLER_POINTER + 1
    lda INT_TIMER
    tai
    cli
    rts

; EXTINT1 ISR: capture auto UART status if present, GET_STATUS to clear INT#.
ch376_extint1_handler:
    pha
    phx
    phy
    lda 0x01
    sta CH376_INT_FLAG
    ; Auto-sent status may already be in ACIA2.
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    beq ch376_e1h_gst
    lda ACIA2_RW_DATA_ADDR
    sta CH376_INT_STATUS
ch376_e1h_gst:
    ; Cancel INT# (datasheet); drain response (may duplicate status).
    lda CH376_SYNC1
    jsr ch376_uart_putc
    lda CH376_SYNC2
    jsr ch376_uart_putc
    lda CH376_CMD_GET_STATUS
    jsr ch376_uart_putc
    ldx 0xFF
    ldy 0x40
ch376_e1h_wait:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne ch376_e1h_got
    dex
    bne ch376_e1h_wait
    dey
    bne ch376_e1h_wait
    jmp ch376_e1h_done
ch376_e1h_got:
    lda ACIA2_RW_DATA_ADDR
    ldx CH376_INT_STATUS
    bne ch376_e1h_keep
    sta CH376_INT_STATUS
ch376_e1h_keep:
ch376_e1h_done:
    ply
    plx
    pla
    rts

ch376_int_flagged:
    lda CH376_INT_FLAG
    beq ch376_int_flag_no
    sec
    rts
ch376_int_flag_no:
    clc
    rts

ch376_int_pending:
    tia
    and INT_EXTINT1
    beq ch376_int_pend_no
    sec
    rts
ch376_int_pend_no:
    clc
    rts

ch376_int_pin_char:
    jsr ch376_int_flagged
    bcs ch376_int_pin_act
    jsr ch376_int_pending
    bcs ch376_int_pin_act
    lda 0x49
    sec
    rts
ch376_int_pin_act:
    lda 0x41
    sec
    rts

; Wait for UART status byte (Ch376msc). Also accept handler-captured status.
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

; Release CH376 INT# after we already consumed the UART status in main.
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

ch376_uart_rx_pending:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    beq ch376_uart_rx_no
    sec
    rts
ch376_uart_rx_no:
    clc
    rts

ch376_print_nl:
    jmp ACIA_SEND_NEWLINE

ch376_print_hex8:
    jmp ACIA_SEND_HEX

; Null-terminated string at Y:DE (works above 64 KB; ABI v1.2.101 has no STRING24).
ch376_print_str:
    phx
    ldx 0x00
ch376_print_str_loop:
    lda yde,x
    beq ch376_print_str_done
    jsr ACIA_SEND_CHAR
    inx
    bne ch376_print_str_loop
    ind
    jmp ch376_print_str_loop
ch376_print_str_done:
    plx
    rts

ch376_print_status:
    sta CH376_LAST_STATUS
    ldy ch376_msg_st[23:16]
    ldd ch376_msg_st[15:8]
    lde ch376_msg_st[7:0]
    jsr ch376_print_str
    lda CH376_LAST_STATUS
    jsr ch376_print_hex8
    jsr ch376_print_nl
    rts

ch376_msg_st:
    #d "ST ", 0x00
