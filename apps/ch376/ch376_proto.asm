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
    ; USB_INT_DISK_READ/WRITE: data still in chip — do NOT GET_STATUS yet
    ; (Ch376msc UART goes straight to RD_USB_DATA0).
    cmp CH376_INT_DISK_READ
    beq ch376_interrupt_ok
    cmp 0x1E
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

; DISK_QUERY / FAT payload: ultra-tight RX under SEI (ACIA2 is 1-byte FIFO).
; No JSR / stack traffic in the byte loop — 115200 needs a read every ~87us.
ch376_rd_disk_query:
    phx
    phy
    jsr ch376_usb_timeout_on
    lda 0x00
    sta CH376_PULL_MODE
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
    lda 0x20
    sta CH376_CAP
    jsr ch376_rd_usb_burst
    ply
    plx
    rts

; Send RD_USB_DATA0 and read len+payload. CH376_CAP = max bytes to store.
; Success: A=stored, WIRE_LEN=len, RD_LEN=len, C=1.
; Fail: A=0, C=0; CH376_OVERRUN = last ACIA2 status.
ch376_rd_usb_burst:
    lda 0x00
    sta CH376_OVERRUN
    sta CH376_WIRE_LEN
    sta CH376_RD_LEN
    sei
    ; 57 AB 27 — inline TX so we enter RX wait ASAP.
ch376_rdb_tx1:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq ch376_rdb_tx1
    lda CH376_SYNC1
    sta ACIA2_RW_DATA_ADDR
ch376_rdb_tx2:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq ch376_rdb_tx2
    lda CH376_SYNC2
    sta ACIA2_RW_DATA_ADDR
ch376_rdb_tx3:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq ch376_rdb_tx3
    lda CH376_CMD_RD_USB_DATA0
    sta ACIA2_RW_DATA_ADDR
    ; Length byte.
    ldx 0x00
    ldy 0xFF
ch376_rdb_wlen:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne ch376_rdb_glen
    dex
    bne ch376_rdb_wlen
    dey
    bne ch376_rdb_wlen
    jmp ch376_rdb_fail
ch376_rdb_glen:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVER_OVERRUN
    beq ch376_rdb_glen_rd
    sta CH376_OVERRUN
ch376_rdb_glen_rd:
    lda ACIA2_RW_DATA_ADDR
    sta CH376_WIRE_LEN
    sta CH376_RD_LEN
    beq ch376_rdb_fail
    tax
    ldy 0x00
    ; Body: X=remaining, Y=store index, D:E=per-byte timeout.
ch376_rdb_body:
    ldd 0x00
    lde 0xC0
ch376_rdb_wbyte:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne ch376_rdb_gbyte
    dee
    bne ch376_rdb_wbyte
    ded
    bne ch376_rdb_wbyte
    jmp ch376_rdb_fail
ch376_rdb_gbyte:
    bit ACIA_STATUS_REG_RECEIVER_OVERRUN
    beq ch376_rdb_gbyte_rd
    sta CH376_OVERRUN
ch376_rdb_gbyte_rd:
    lda ACIA2_RW_DATA_ADDR
    cpy CH376_CAP
    bcs ch376_rdb_skip
    sta CH376_BUF,y
    iny
ch376_rdb_skip:
    dex
    bne ch376_rdb_body
    lda 0x52
    sta CH376_PULL_MODE
    cli
    jsr ch376_clear_int
    jsr ch376_usb_timeout_off
    tya
    sec
    rts
ch376_rdb_fail:
    lda ACIA2_CONTROL_STATUS_ADDR
    sta CH376_OVERRUN
    lda 0x52
    sta CH376_PULL_MODE
    cli
    jsr ch376_usb_timeout_off
    lda 0x00
    clc
    rts

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
