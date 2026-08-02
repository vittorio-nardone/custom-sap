; CH376S UART protocol (sync header + command packets).
; Reference: Ch376msc (UART path) — status on serial, RD_USB_DATA0 for payloads.
; Critical: ACIA #2 has a 1-byte RX FIFO, so bulk reads go through
; ch376_rd_usb_burst (storage/burst.asm) with interrupts disabled.

#once
#bank kernel

ch376_uart_sync:
    lda CH376_SYNC1
    jsr ch376_uart_putc
    bcc ch376_uart_io_fail
    lda CH376_SYNC2
    jsr ch376_uart_putc
    bcc ch376_uart_io_fail
    sec
    rts

ch376_uart_cmd:
    jmp ch376_uart_putc

ch376_uart_param:
    jmp ch376_uart_putc

ch376_uart_io_fail:
    clc
    rts

; Null-terminated string at Y:DE (Y=page), upper-cased on the fly.
; Page 0 uses lda de,x (same as ACIA_SEND_STRING) so ROM path strings work;
; lda yde,x is only needed for expansion RAM (Y != 0).
ch376_uart_send_str:
    pha
    phx
    ldx 0x00
ch376_uart_send_str_loop:
    lda CH376_SCRATCH2
    bne ch376_uart_send_str_yde
    lda de,x
    jmp ch376_uart_send_str_got
ch376_uart_send_str_yde:
    ldy CH376_SCRATCH2
    lda yde,x
ch376_uart_send_str_got:
    beq ch376_uart_send_str_term
    cmp 0x61
    bcc ch376_uart_send_str_put
    cmp 0x7B
    bcs ch376_uart_send_str_put
    sec
    sbc 0x20
ch376_uart_send_str_put:
    jsr ch376_uart_putc
    bcc ch376_uart_send_str_fail
    inx
    bne ch376_uart_send_str_loop
    ind
    jmp ch376_uart_send_str_loop
ch376_uart_send_str_term:
    lda 0x00
    jsr ch376_uart_putc
    bcc ch376_uart_send_str_fail
    plx
    pla
    sec
    rts
ch376_uart_send_str_fail:
    plx
    pla
    clc
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
    bcc ch376_check_exist_fail
    lda CH376_CMD_CHECK_EXIST
    jsr ch376_uart_cmd
    bcc ch376_check_exist_fail
    lda CH376_SCRATCH
    jsr ch376_uart_param
    bcc ch376_check_exist_fail
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
    bcc ch376_set_mode_fail
    lda CH376_CMD_SET_USB_MODE
    jsr ch376_uart_cmd
    bcc ch376_set_mode_fail
    lda CH376_SCRATCH
    jsr ch376_uart_param
    bcc ch376_set_mode_fail
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
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_INT_FLAG
    jsr ch376_drain_rx
    jsr ch376_uart_sync
    bcc ch376_wait_status_fail
    lda CH376_SCRATCH
    jsr ch376_uart_cmd
    bcc ch376_wait_status_fail
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
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_INT_FLAG
    jsr ch376_uart_sync
    bcc ch376_interrupt_fail
    lda CH376_SCRATCH
    jsr ch376_uart_cmd
    bcc ch376_interrupt_fail
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

; SET_FILE_NAME: Y:DE null-terminated. No UART status (Ch376msc).
ch376_cmd_set_file_name:
    sty CH376_SCRATCH2
    jsr ch376_uart_sync
    bcc ch376_set_name_fail
    lda CH376_CMD_SET_FILE_NAME
    jsr ch376_uart_cmd
    bcc ch376_set_name_fail
    jsr ch376_uart_send_str
    bcc ch376_set_name_fail
    sec
    rts
ch376_set_name_fail:
    clc
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

; FILE_CREATE — truncates if exists. Expect INT_SUCCESS after SET_FILE_NAME.
ch376_cmd_file_create:
    lda CH376_CMD_FILE_CREATE
    jmp ch376_cmd_interrupt

; BYTE_WRITE: A = request length (high byte 0). Status in CH376_LAST_STATUS.
ch376_cmd_byte_write:
    sta CH376_SCRATCH
    lda 0x00
    sta CH376_INT_FLAG
    jsr ch376_uart_sync
    lda CH376_CMD_BYTE_WRITE
    jsr ch376_uart_cmd
    lda CH376_SCRATCH
    jsr ch376_uart_param
    lda 0x00
    jsr ch376_uart_param
    jsr ch376_wait_response_byte
    bcc ch376_byte_write_fail
    cmp CH376_CMD_RET_SUCCESS
    bne ch376_byte_write_store
    jsr ch376_wait_response_byte
    bcc ch376_byte_write_fail
ch376_byte_write_store:
    sta CH376_LAST_STATUS
    cmp CH376_INT_DISK_WRITE
    beq ch376_byte_write_ok
    jsr ch376_clear_int
ch376_byte_write_ok:
    sec
    rts
ch376_byte_write_fail:
    lda 0x00
    sta CH376_LAST_STATUS
    clc
    rts

; BYTE_WR_GO — continue multi-chunk write.
ch376_cmd_byte_wr_go:
    lda CH376_CMD_BYTE_WR_GO
    jmp ch376_cmd_interrupt

; WR_REQ_DATA after INT_DISK_WRITE.
; CH376_WR_WANT = bytes requested in BYTE_WRITE (caller sets).
; Chip may return a length byte (Ch376msc); some UART modules do not —
; if no length arrives quickly, TX CH376_WR_WANT bytes (Abraxas-style).
; Source via CH376_DST_*; advances pointer. A = bytes sent. C=1 OK.
ch376_wr_req_data:
    jsr ch376_usb_timeout_on
    jsr ch376_uart_sync
    lda CH376_CMD_WR_REQ_DATA
    jsr ch376_uart_cmd
    ; Brief wait for optional length byte (do not use full USB timeout —
    ; if the module expects data immediately, a long wait deadlocks).
    ldx 0x00
    ldy 0x20
ch376_wrd_wait_len:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne ch376_wrd_got_len
    dex
    bne ch376_wrd_wait_len
    dey
    bne ch376_wrd_wait_len
    ; No length — send what BYTE_WRITE asked for
    lda CH376_WR_WANT
    beq ch376_wrd_fail
    jmp ch376_wrd_use_len
ch376_wrd_got_len:
    lda ACIA2_RW_DATA_ADDR
    beq ch376_wrd_fail
    cmp CH376_WR_WANT
    beq ch376_wrd_use_len
    bcc ch376_wrd_use_len
    lda CH376_WR_WANT
ch376_wrd_use_len:
    sta CH376_WIRE_LEN
    sta CH376_SCRATCH
    ldy CH376_DST_PAGE
    ldd CH376_DST_MSB
    lde CH376_DST_LSB
ch376_wrd_tx:
    ldx 0x00
    lda yde,x
    jsr ch376_uart_putc
    ine
    bne ch376_wrd_next
    ind
    bne ch376_wrd_next
    iny
ch376_wrd_next:
    dec CH376_SCRATCH
    bne ch376_wrd_tx
    sty CH376_DST_PAGE
    std CH376_DST_MSB
    ste CH376_DST_LSB
    ; Abraxas sees a trailing byte (often 0xFF) after data — drop it
    ; so it is not mistaken for BYTE_WR_GO status.
    jsr ch376_drain_rx
    jsr ch376_usb_timeout_off
    lda CH376_WIRE_LEN
    sec
    rts
ch376_wrd_fail:
    jsr ch376_drain_rx
    jsr ch376_usb_timeout_off
    lda 0x00
    clc
    rts

; Write from Y:DE; CH376_REMAIN_LO/HI = byte count. File must already be open.
; Updates CH376_LOADED_*; C=1 OK, C=0 fail.
ch376_file_write_from:
    lda 0x00
    sta CH376_LOADED_LO
    sta CH376_LOADED_HI
    sty CH376_DST_PAGE
    std CH376_DST_MSB
    ste CH376_DST_LSB
ch376_fwt_loop:
    lda CH376_REMAIN_LO
    ora CH376_REMAIN_HI
    bne ch376_fwt_req
    sec
    rts
ch376_fwt_req:
    lda CH376_REMAIN_HI
    bne ch376_fwt_chunk_max
    lda CH376_REMAIN_LO
    cmp CH376_WRITE_CHUNK
    bcc ch376_fwt_chunk_use
ch376_fwt_chunk_max:
    lda CH376_WRITE_CHUNK
ch376_fwt_chunk_use:
    sta CH376_WR_WANT
    sta CH376_SCRATCH
    jsr ch376_usb_timeout_on
    lda CH376_SCRATCH
    jsr ch376_cmd_byte_write
    bcc ch376_fwt_fail
    lda CH376_LAST_STATUS
    cmp CH376_INT_SUCCESS
    beq ch376_fwt_done
    cmp CH376_INT_DISK_WRITE
    bne ch376_fwt_fail
ch376_fwt_data:
    jsr ch376_wr_req_data
    bcc ch376_fwt_fail
    lda CH376_WIRE_LEN
    beq ch376_fwt_fail
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
    ; Remaining of this BYTE_WRITE request (for next WR_REQ if 1E again)
    sec
    lda CH376_WR_WANT
    sbc CH376_SCRATCH
    sta CH376_WR_WANT
    jsr ch376_drain_rx
    lda CH376_CMD_BYTE_WR_GO
    jsr ch376_cmd_interrupt
    bcc ch376_fwt_fail
    lda CH376_LAST_STATUS
    cmp CH376_INT_DISK_WRITE
    beq ch376_fwt_data
    cmp CH376_INT_SUCCESS
    beq ch376_fwt_loop
    jmp ch376_fwt_fail
ch376_fwt_done:
    sec
    rts
ch376_fwt_fail:
    clc
    rts

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
    lda CH376_RDB_MODE_BUF
    sta CH376_RDB_MODE
    sec
    rts
ch376_frt_fail:
    lda CH376_RDB_MODE_BUF
    sta CH376_RDB_MODE
    clc
    rts

; Ch376msc rdFatInfo / directory entry: payload into CH376_BUF.
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

ch376_rd_dir_entry:
    jmp ch376_read_usb_payload_rd

ch376_rd_usb_data0:
    jmp ch376_read_usb_payload_rd
