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

; Null-terminated string at Y:DE (Y=page). Needed for apps above 0xFFFF.
ch376_uart_send_str:
    pha
    phx
    ldx 0x00
ch376_uart_send_str_loop:
    lda yde,x
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
    ; USB_INT_DISK_READ/WRITE: data still in chip — do NOT GET_STATUS yet
    ; (Ch376msc UART goes straight to RD_USB_DATA0).
    cmp CH376_INT_DISK_READ
    beq ch376_interrupt_ok
    cmp CH376_INT_DISK_WRITE
    beq ch376_interrupt_ok
    jsr ch376_clear_int
ch376_interrupt_ok:
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

; BYTE_READ: A = request length (high byte 0). Status in CH376_LAST_STATUS.
ch376_cmd_byte_read:
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_INT_FLAG
    jsr ch376_uart_sync
    lda CH376_CMD_BYTE_READ
    jsr ch376_uart_cmd
    lda CH376_SCRATCH
    jsr ch376_uart_param
    lda 0x00
    jsr ch376_uart_param
    jsr ch376_wait_response_byte
    bcc ch376_byte_read_fail
    cmp CH376_CMD_RET_SUCCESS
    bne ch376_byte_read_store
    jsr ch376_wait_response_byte
    bcc ch376_byte_read_fail
ch376_byte_read_store:
    sta CH376_LAST_STATUS
    cmp CH376_INT_DISK_READ
    beq ch376_byte_read_ok
    jsr ch376_clear_int
ch376_byte_read_ok:
    sec
    rts
ch376_byte_read_fail:
    lda 0x00
    sta CH376_LAST_STATUS
    clc
    rts

; BYTE_RD_GO — continue multi-chunk read.
ch376_cmd_byte_rd_go:
    lda CH376_CMD_BYTE_RD_GO
    jmp ch376_cmd_interrupt

; FILE_CLOSE: A = 0 (no size update) or 1 (update).
ch376_cmd_file_close:
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_INT_FLAG
    jsr ch376_uart_sync
    lda CH376_CMD_FILE_CLOSE
    jsr ch376_uart_cmd
    lda CH376_SCRATCH
    jsr ch376_uart_param
    jsr ch376_wait_response_byte
    bcc ch376_file_close_fail
    sta CH376_LAST_STATUS
    jsr ch376_clear_int
    sec
    rts
ch376_file_close_fail:
    lda 0x00
    sta CH376_LAST_STATUS
    clc
    rts

; Read open file into Y:DE destination.
; Inputs: Y=page, D:E=addr, CH376_REMAIN_LO/HI = max bytes to accept.
; Outputs: CH376_LOADED_LO/HI updated; C=1 OK, C=0 fail.
; After BYTE_READ: on 1D, RD + BYTE_RD_GO; GO may return another 1D (more
; data for same request) or 14 (request done — issue next BYTE_READ if remain).
ch376_file_read_to:
    lda 0x00
    sta CH376_LOADED_LO
    sta CH376_LOADED_HI
    sty CH376_DST_PAGE
    std CH376_DST_MSB
    ste CH376_DST_LSB
ch376_frt_loop:
    lda CH376_REMAIN_LO
    ora CH376_REMAIN_HI
    bne ch376_frt_req
    sec
    rts
ch376_frt_req:
    lda CH376_REMAIN_HI
    bne ch376_frt_chunk_max
    lda CH376_REMAIN_LO
    cmp CH376_READ_CHUNK
    bcc ch376_frt_chunk_use
ch376_frt_chunk_max:
    lda CH376_READ_CHUNK
ch376_frt_chunk_use:
    sta CH376_SCRATCH
    jsr ch376_usb_timeout_on
    lda CH376_SCRATCH
    jsr ch376_cmd_byte_read
    bcc ch376_frt_fail
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq ch376_frt_done
    cmp CH376_INT_DISK_READ
    bne ch376_frt_fail
ch376_frt_data:
    lda CH376_RDB_MODE_DST
    sta CH376_RDB_MODE
    ldy CH376_DST_PAGE
    ldd CH376_DST_MSB
    lde CH376_DST_LSB
    jsr ch376_rd_usb_burst
    bcc ch376_frt_fail
    lda CH376_WIRE_LEN
    beq ch376_frt_fail
    sta CH376_SCRATCH
    clc
    lda CH376_LOADED_LO
    adc CH376_SCRATCH
    sta CH376_LOADED_LO
    lda CH376_LOADED_HI
    adc 0x00
    sta CH376_LOADED_HI
    sec
    lda CH376_REMAIN_LO
    sbc CH376_SCRATCH
    sta CH376_REMAIN_LO
    lda CH376_REMAIN_HI
    sbc 0x00
    sta CH376_REMAIN_HI
    lda CH376_CMD_BYTE_RD_GO
    jsr ch376_cmd_interrupt
    bcc ch376_frt_fail
    lda CH376_LAST_STATUS
    cmp CH376_INT_DISK_READ
    beq ch376_frt_data
    cmp CH376_INT_SUCCESS
    beq ch376_frt_loop
    jmp ch376_frt_fail
ch376_frt_done:
    sec
    rts
ch376_frt_fail:
    clc
    rts

; DISK_QUERY / FAT payload: ultra-tight RX under SEI (ACIA2 is 1-byte FIFO).
; No JSR / stack traffic in the byte loop — 115200 needs a read every ~87us.
ch376_rd_disk_query:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x00
    sta CH376_PULL_MODE
    sta CH376_RDB_MODE
    lda 0x09
    sta CH376_CAP
    jsr ch376_rd_usb_burst
    bcc ch376_rdq_out
    pha
    lda CH376_WIRE_LEN
    sta CH376_SCRATCH
    pla
    sec
ch376_rdq_out:
    ply
    plx
    rts

; Ch376msc rdFatInfo after ST 1D.
ch376_read_usb_payload_rd:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x00
    sta CH376_PULL_MODE
    sta CH376_RDB_MODE
    lda 0x20
    sta CH376_CAP
    jsr ch376_rd_usb_burst
    ply
    plx
    rts

; RD_USB_DATA0 burst lives in ch376_burst.asm @ CH376_BURST_ENTRY.
; Apps must jsr ch376_install_burst before any FAT/file RD.

ch376_read_usb_payload_dir:
    jmp ch376_read_usb_payload_rd

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
