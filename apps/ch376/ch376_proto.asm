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
    beq ch376_uart_send_str_term
    cmp 0x61
    bcc ch376_uart_send_str_put
    cmp 0x7B
    bcs ch376_uart_send_str_put
    sbc 0x1F
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
    jsr ch376_drain_rx
    jsr ch376_uart_sync
    pla
    jsr ch376_uart_cmd
    jsr ch376_wait_response_byte
    bcc ch376_wait_status_fail
    sta CH376_LAST_STATUS
    sec
    rts
ch376_wait_status_fail:
    lda 0x00
    sta CH376_LAST_STATUS
    clc
    rts

; UART: status byte on serial after command (Ch376msc readSerDataUSB).
; Drain stale RX first; optionally cross-check INT# via wait_response_byte.
ch376_cmd_interrupt:
    pha
    jsr ch376_drain_rx
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
    sec
    rts
ch376_interrupt_fail:
    lda 0x00
    sta CH376_LAST_STATUS
    clc
    rts

; SET_FILE_NAME: D:E -> null-terminated name. Waits for UART status (datasheet: IRQ when done).
ch376_cmd_set_file_name:
    jsr ch376_uart_sync
    lda CH376_CMD_SET_FILE_NAME
    jsr ch376_uart_cmd
    jsr ch376_uart_send_str
    jsr ch376_wait_response_byte
    bcc ch376_set_fname_fail
    sta CH376_LAST_STATUS
    sec
    rts
ch376_set_fname_fail:
    clc
    rts

; Ch376msc dirInfoRead: DIR_INFO_READ 0xFF then RD_USB_DATA0.
; Returns A = data length (0 on fail). C=1 if command byte received.
ch376_cmd_dir_info_read:
    jsr ch376_drain_rx
    jsr ch376_uart_sync
    lda CH376_CMD_DIR_INFO_READ
    jsr ch376_uart_cmd
    lda 0xFF
    jsr ch376_uart_param
    jsr ch376_wait_response_byte
    bcc ch376_dir_info_fail
    sta CH376_LAST_STATUS
    jmp ch376_rd_dir_entry
ch376_dir_info_fail:
    lda 0x00
    rts

; RD_USB_DATA0 for DISK_QUERY payload: read full wire length, store up to 9 bytes.
ch376_rd_disk_query:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x00
    sta CH376_PULL_MODE
    jsr ch376_uart_sync
    lda CH376_CMD_RD_USB_DATA0
    jsr ch376_uart_cmd
    jsr ch376_wait_response_byte
    bcc ch376_rdq_fail
    sta CH376_SCRATCH
    beq ch376_rdq_fail
    lda 0x00
    sta CH376_RD_LEN
    ldx 0x00
    ldy 0x00
ch376_rdq_loop:
    cpx CH376_SCRATCH
    bcs ch376_rdq_done
    jsr ch376_wait_byte
    bcc ch376_rdq_fail
    cpy CH376_DISK_QUERY_SIZE
    bcs ch376_rdq_skip_store
    sta CH376_BUF,y
    iny
    inc CH376_RD_LEN
ch376_rdq_skip_store:
    inx
    jmp ch376_rdq_loop
ch376_rdq_done:
    lda CH376_RD_LEN
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    sec
    rts
ch376_rdq_fail:
    lda 0x00
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    clc
    rts

; RD_USB_DATA0 only (after ST 0x14 disk query — Ch376msc rdDiskInfo).
ch376_read_usb_payload_rd:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x00
    sta CH376_PULL_MODE
    jsr ch376_uart_sync
    lda CH376_CMD_RD_USB_DATA0
    jsr ch376_uart_cmd
    jsr ch376_wait_response_byte
    bcc ch376_rup_fail
    sta CH376_RD_LEN
    beq ch376_rup_fail
    lda 0x52
    sta CH376_PULL_MODE
    jmp ch376_rup_read_body

; After ST 0x1D: poll UART for inline length, else RD_USB_DATA0.
ch376_read_usb_payload_dir:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x00
    sta CH376_PULL_MODE

    ldx 0x0C
ch376_rupd_wait_rx:
    jsr ch376_uart_rx_pending
    bcs ch376_rupd_inline_len
    jsr ch376_delay_short
    dex
    bne ch376_rupd_wait_rx

    jsr ch376_uart_sync
    lda CH376_CMD_RD_USB_DATA0
    jsr ch376_uart_cmd
    jsr ch376_wait_response_byte
    bcc ch376_rup_fail
    sta CH376_RD_LEN
    beq ch376_rup_fail
    lda 0x52
    sta CH376_PULL_MODE
    jmp ch376_rup_read_body

ch376_rupd_inline_len:
    jsr ch376_wait_response_byte
    bcc ch376_rup_fail
    sta CH376_RD_LEN
    beq ch376_rup_fail
    lda 0x49
    sta CH376_PULL_MODE
    jmp ch376_rup_read_body

ch376_rup_read_body:
    ldx 0x00
    ldy 0x00
ch376_rup_loop:
    cpx CH376_RD_LEN
    bcs ch376_rup_done
    jsr ch376_wait_byte
    bcc ch376_rup_fail
    cpy CH376_DIR_INFO_SIZE
    bcs ch376_rup_skip_store
    sta CH376_BUF,y
    iny
ch376_rup_skip_store:
    inx
    jmp ch376_rup_loop
ch376_rup_done:
    tya
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    sec
    rts
ch376_rup_fail:
    lda 0x00
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    clc
    rts

; FAT directory entry read (retries). Returns A = stored length.
ch376_rd_dir_entry:
    phx
    lda 0x04
    sta CH376_SCRATCH
ch376_rd_dir_retry:
    jsr ch376_read_usb_payload_dir
    bne ch376_rd_dir_done
    dec CH376_SCRATCH
    bne ch376_rd_dir_retry
    lda 0x00
ch376_rd_dir_done:
    plx
    rts

; Legacy single-shot RD command path (used by tests).
ch376_rd_usb_data0_once:
    jmp ch376_read_usb_payload_rd

; Discard pending FAT data after FILE_OPEN.
ch376_consume_pending:
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq ch376_consume_pull
    cmp CH376_INT_DISK_READ
    beq ch376_consume_pull
    rts
ch376_consume_pull:
    jmp ch376_rd_dir_entry

ch376_rd_usb_data0:
    phx
    jsr ch376_read_usb_payload_rd
    plx
    rts
