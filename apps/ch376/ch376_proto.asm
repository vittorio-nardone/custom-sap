; CH376S UART protocol (sync header + command packets).

ch376_uart_sync:
    lda CH376_SYNC1
    jsr ch376_uart_putc
    lda CH376_SYNC2
    jmp ch376_uart_putc

ch376_uart_cmd:
    jmp ch376_uart_putc

ch376_uart_param:
    jmp ch376_uart_putc

ch376_uart_send_str:
    pha
    phx
    ldx 0x00
ch376_uart_send_str_loop:
    lda de,x
    beq ch376_uart_send_str_done
    jsr ch376_uart_putc
    inx
    bne ch376_uart_send_str_loop
    ind
    jmp ch376_uart_send_str_loop
ch376_uart_send_str_done:
    plx
    pla
    rts

ch376_wait_byte:
    jmp ch376_uart_getc_tmo

ch376_get_status:
    jsr ch376_uart_sync
    lda CH376_CMD_GET_STATUS
    jsr ch376_uart_cmd
    jmp ch376_wait_byte

ch376_cmd_get_ic_ver:
    jsr ch376_uart_flush
    jsr ch376_uart_sync
    lda CH376_CMD_GET_IC_VER
    jsr ch376_uart_cmd
    jmp ch376_wait_byte

ch376_cmd_check_exist:
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_LAST_STATUS
    jsr ch376_uart_flush
    jsr ch376_uart_sync
    lda CH376_CMD_CHECK_EXIST
    jsr ch376_uart_cmd
    lda CH376_SCRATCH
    jsr ch376_uart_param
    jsr ch376_wait_byte
    bcc ch376_check_exist_fail
    sta CH376_LAST_STATUS
    eor 0xFF
    cmp CH376_SCRATCH
    bne ch376_check_exist_fail
    sec
    rts
ch376_check_exist_fail:
    clc
    rts

ch376_cmd_set_usb_mode:
    sta CH376_SCRATCH
    jsr ch376_uart_flush
    jsr ch376_uart_sync
    lda CH376_CMD_SET_USB_MODE
    jsr ch376_uart_cmd
    lda CH376_SCRATCH
    jsr ch376_uart_param
    jsr ch376_wait_byte
    bcc ch376_set_mode_fail
    sta CH376_LAST_STATUS
    jsr ch376_drain_rx
    lda CH376_LAST_STATUS
    sec
    rts
ch376_set_mode_fail:
    clc
    rts

ch376_cmd_wait_status:
    pha
    jsr ch376_uart_flush
    jsr ch376_uart_sync
    pla
    jsr ch376_uart_cmd
    jsr ch376_wait_byte
    bcc ch376_wait_status_fail
    sta CH376_LAST_STATUS
    sec
    rts
ch376_wait_status_fail:
    clc
    rts

; Like ch376_cmd_wait_status but does not flush RX (file enum chain).
ch376_cmd_interrupt:
    pha
    jsr ch376_uart_sync
    pla
    jsr ch376_uart_cmd
    jsr ch376_wait_byte
    bcc ch376_interrupt_fail
    sta CH376_LAST_STATUS
    sec
    rts
ch376_interrupt_fail:
    clc
    rts

ch376_cmd_set_file_name:
    jsr ch376_uart_flush
    jsr ch376_uart_sync
    lda CH376_CMD_SET_FILE_NAME
    jsr ch376_uart_cmd
    jmp ch376_uart_send_str

ch376_rd_usb_data0:
    phx
    jsr ch376_uart_sync
    lda CH376_CMD_RD_USB_DATA0
    jsr ch376_uart_cmd
    jsr ch376_wait_byte
    bcc ch376_rd_fail
    sta CH376_SCRATCH
    beq ch376_rd_done_len
    ldx 0x00
ch376_rd_loop:
    jsr ch376_wait_byte
    bcc ch376_rd_fail
    sta CH376_BUF,x
    inx
    cpx CH376_SCRATCH
    bne ch376_rd_loop
ch376_rd_done_len:
    lda CH376_SCRATCH
    plx
    rts
ch376_rd_fail:
    lda 0x00
    plx
    rts
