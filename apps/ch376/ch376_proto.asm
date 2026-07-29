; CH376S UART protocol (sync header + command packets).
; Reference: Ch376msc (UART path) — status on serial, RD_USB_DATA0 for payloads.
; Critical: ACIA2 has 1-byte RX; bulk RD must run under SEI with no delays.

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
    beq ch376_uart_send_str_term
    cmp 0x61
    bcc ch376_uart_send_str_put
    cmp 0x7B
    bcs ch376_uart_send_str_put
    sec
    sbc 0x20
ch376_uart_send_str_put:
    jsr ch376_uart_putc
    inx
    bne ch376_uart_send_str_loop
    ind
    jmp ch376_uart_send_str_loop
ch376_uart_send_str_term:
    lda 0x00
    jsr ch376_uart_putc
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
    jmp ch376_wait_response_byte

ch376_cmd_get_ic_ver:
    jsr ch376_drain_rx
    jsr ch376_uart_sync
    lda CH376_CMD_GET_IC_VER
    jsr ch376_uart_cmd
    jmp ch376_wait_response_byte

ch376_cmd_check_exist:
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_LAST_STATUS
    jsr ch376_drain_rx
    jsr ch376_uart_sync
    lda CH376_CMD_CHECK_EXIST
    jsr ch376_uart_cmd
    lda CH376_SCRATCH
    jsr ch376_uart_param
    jsr ch376_wait_response_byte
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
    jsr ch376_drain_rx
    jsr ch376_uart_sync
    lda CH376_CMD_SET_USB_MODE
    jsr ch376_uart_cmd
    lda CH376_SCRATCH
    jsr ch376_uart_param
    jsr ch376_wait_response_byte
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
    lda 0x00
    sta CH376_INT_FLAG
    jsr ch376_drain_rx
    jsr ch376_uart_sync
    pla
    jsr ch376_uart_cmd
    jsr ch376_wait_response_byte
    bcc ch376_wait_status_fail
    sta CH376_LAST_STATUS
    jsr ch376_clear_int
    sec
    rts
ch376_wait_status_fail:
    lda 0x00
    sta CH376_LAST_STATUS
    clc
    rts

; Interrupt-style command: no RX drain (Ch376msc). Clear INT# after status.
ch376_cmd_interrupt:
    pha
    lda 0x00
    sta CH376_INT_FLAG
    jsr ch376_uart_sync
    pla
    jsr ch376_uart_cmd
    jsr ch376_wait_response_byte
    bcc ch376_interrupt_fail
    cmp CH376_CMD_RET_SUCCESS
    bne ch376_interrupt_store
    jsr ch376_wait_response_byte
    bcc ch376_interrupt_fail
ch376_interrupt_store:
    sta CH376_LAST_STATUS
    jsr ch376_clear_int
    sec
    rts
ch376_interrupt_fail:
    lda 0x00
    sta CH376_LAST_STATUS
    clc
    rts

; SET_FILE_NAME: D:E null-terminated. No UART status (Ch376msc).
ch376_cmd_set_file_name:
    jsr ch376_uart_sync
    lda CH376_CMD_SET_FILE_NAME
    jsr ch376_uart_cmd
    jsr ch376_uart_send_str
    sec
    rts

; DISK_QUERY payload under SEI (short, but same path as FAT).
ch376_rd_disk_query:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x00
    sta CH376_PULL_MODE
    sei
    jsr ch376_uart_sync
    lda CH376_CMD_RD_USB_DATA0
    jsr ch376_uart_cmd
    jsr ch376_uart_getc_tmo
    bcc ch376_rdq_fail_cli
    sta CH376_SCRATCH
    beq ch376_rdq_fail_cli
    lda 0x52
    sta CH376_PULL_MODE
    ldx 0x00
    ldy 0x00
ch376_rdq_loop:
    cpx CH376_SCRATCH
    bcs ch376_rdq_done
    jsr ch376_uart_getc_tmo
    bcc ch376_rdq_fail_cli
    cpy 0x09
    bcs ch376_rdq_skip
    sta CH376_BUF,y
    iny
ch376_rdq_skip:
    inx
    jmp ch376_rdq_loop
ch376_rdq_done:
    cli
    tya
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    sec
    rts
ch376_rdq_fail_cli:
    cli
    lda 0x00
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    clc
    rts

; Ch376msc rdFatInfo: RD_USB_DATA0 immediately under SEI (no delay, no poll).
; Returns A = bytes stored (0..32). C=1 on success.
ch376_read_usb_payload_rd:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x00
    sta CH376_PULL_MODE
    sei
    jsr ch376_uart_sync
    lda CH376_CMD_RD_USB_DATA0
    jsr ch376_uart_cmd
    jsr ch376_uart_getc_tmo
    bcc ch376_rup_fail_cli
    sta CH376_RD_LEN
    sta CH376_WIRE_LEN
    beq ch376_rup_fail_cli
    lda 0x52
    sta CH376_PULL_MODE
    ldx 0x00
    ldy 0x00
ch376_rup_loop:
    cpx CH376_RD_LEN
    bcs ch376_rup_done
    jsr ch376_uart_getc_tmo
    bcc ch376_rup_fail_cli
    cpy 0x20
    bcs ch376_rup_skip
    sta CH376_BUF,y
    iny
ch376_rup_skip:
    inx
    jmp ch376_rup_loop
ch376_rup_done:
    cli
    tya
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    sec
    rts
ch376_rup_fail_cli:
    cli
    lda 0x00
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    clc
    rts

; After ST 0x1D: same as Ch376msc — always RD_USB_DATA0 (no inline guess).
ch376_read_usb_payload_dir:
    jmp ch376_read_usb_payload_rd

; Single-shot FAT entry read. A = stored length (0 = fail).
ch376_rd_dir_entry:
    jmp ch376_read_usb_payload_dir

ch376_rd_usb_data0_once:
    jmp ch376_read_usb_payload_rd

ch376_rd_usb_data0:
    jmp ch376_read_usb_payload_rd

ch376_consume_pending:
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq ch376_consume_pull
    cmp CH376_INT_DISK_READ
    beq ch376_consume_pull
    rts
ch376_consume_pull:
    jmp ch376_rd_dir_entry
