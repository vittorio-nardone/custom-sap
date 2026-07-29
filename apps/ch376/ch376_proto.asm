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

; UART interrupt response: one status byte (Ch376msc readSerDataUSB).
; No GET_STATUS on serial — that is SPI-only in the reference library.
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
    lda 0x00
    sta CH376_LAST_STATUS
    clc
    rts

ch376_cmd_set_file_name:
    jsr ch376_uart_sync
    lda CH376_CMD_SET_FILE_NAME
    jsr ch376_uart_cmd
    jmp ch376_uart_send_str

; Ch376msc dirInfoRead: DIR_INFO_READ 0xFF then RD_USB_DATA0.
; Returns A = data length (0 on fail). C=1 if command byte received.
ch376_cmd_dir_info_read:
    jsr ch376_uart_sync
    lda CH376_CMD_DIR_INFO_READ
    jsr ch376_uart_cmd
    lda 0xFF
    jsr ch376_uart_param
    jsr ch376_wait_byte
    bcc ch376_dir_info_fail
    sta CH376_LAST_STATUS
    jmp ch376_rd_dir_entry
ch376_dir_info_fail:
    lda 0x00
    rts

; RD_USB_DATA0 for a FAT directory entry (max 32 B). Retries with USB timeout.
; Returns A = bytes stored (0 on fail).
ch376_rd_dir_entry:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x08
    sta CH376_SCRATCH
ch376_rd_dir_retry:
    jsr ch376_delay_long
    jsr ch376_rd_usb_data0_once
    bne ch376_rd_dir_done
    dec CH376_SCRATCH
    bne ch376_rd_dir_retry
    lda 0x00
ch376_rd_dir_done:
    pha
    jsr ch376_usb_timeout_off
    pla
    ply
    plx
    rts

; Single RD_USB_DATA0 attempt. Stores up to CH376_DIR_INFO_SIZE bytes in CH376_BUF.
; Uses CH376_RD_LEN for device packet length (does not clobber CH376_SCRATCH).
; Returns A = stored length (0 on fail), C=1 on success.
ch376_rd_usb_data0_once:
    phx
    phy
    jsr ch376_uart_sync
    lda CH376_CMD_RD_USB_DATA0
    jsr ch376_uart_cmd
    jsr ch376_wait_byte
    bcc ch376_rd_once_fail
    sta CH376_RD_LEN
    beq ch376_rd_once_fail
    ldx 0x00
    ldy 0x00
ch376_rd_once_loop:
    jsr ch376_wait_byte
    bcc ch376_rd_once_fail
    cpy CH376_DIR_INFO_SIZE
    bcs ch376_rd_once_skip
    sta CH376_BUF,y
    iny
ch376_rd_once_skip:
    inx
    cpx CH376_RD_LEN
    bne ch376_rd_once_loop
    tya
    ply
    plx
    sec
    rts
ch376_rd_once_fail:
    lda 0x00
    ply
    plx
    clc
    rts

; Discard pending FAT data after FILE_OPEN (RD_USB_DATA0 only, like DISK_QUERY).
ch376_consume_pending:
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq ch376_consume_pull
    cmp CH376_INT_DISK_READ
    beq ch376_consume_pull
    cmp 0x20
    beq ch376_consume_pull
    rts
ch376_consume_pull:
    jmp ch376_rd_dir_entry

ch376_rd_usb_data0:
    phx
    jsr ch376_usb_timeout_on
    jsr ch376_delay_long
    jsr ch376_uart_sync
    lda CH376_CMD_RD_USB_DATA0
    jsr ch376_uart_cmd
    jsr ch376_wait_byte
    bcc ch376_rd_fail
    sta CH376_RD_LEN
    beq ch376_rd_done_len
    ldx 0x00
ch376_rd_loop:
    jsr ch376_wait_byte
    bcc ch376_rd_fail
    sta CH376_BUF,x
    inx
    cpx CH376_RD_LEN
    bne ch376_rd_loop
ch376_rd_done_len:
    lda CH376_RD_LEN
    pha
    jsr ch376_usb_timeout_off
    pla
    plx
    rts
ch376_rd_fail:
    lda 0x00
    pha
    jsr ch376_usb_timeout_off
    pla
    plx
    rts
