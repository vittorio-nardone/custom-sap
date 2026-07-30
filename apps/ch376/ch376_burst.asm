; CH376 RD_USB_DATA0 SEI burst — must run from 16-bit address space.
; Assembled at CH376_BURST_ENTRY (0x82B0). Apps above 64 KB copy this
; image there at startup (absolute branches encode 16-bit = fast enough).

ch376_burst_start:
ch376_rd_usb_burst:
    lda 0x00
    sta CH376_OVERRUN
    sta CH376_WIRE_LEN
    sta CH376_RD_LEN
    sei
.ch376_rdb_tx1:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .ch376_rdb_tx1
    lda CH376_SYNC1
    sta ACIA2_RW_DATA_ADDR
.ch376_rdb_tx2:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .ch376_rdb_tx2
    lda CH376_SYNC2
    sta ACIA2_RW_DATA_ADDR
.ch376_rdb_tx3:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .ch376_rdb_tx3
    lda CH376_CMD_RD_USB_DATA0
    sta ACIA2_RW_DATA_ADDR
    ldx 0x00
    ldy 0xFF
.ch376_rdb_wlen:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne .ch376_rdb_glen
    dex
    bne .ch376_rdb_wlen
    dey
    bne .ch376_rdb_wlen
    jmp .ch376_rdb_fail
.ch376_rdb_glen:
    lda ACIA2_RW_DATA_ADDR
    sta CH376_WIRE_LEN
    sta CH376_RD_LEN
    beq .ch376_rdb_fail
    sta CH376_RD_LEFT
    lda CH376_RDB_MODE
    bne .ch376_rdb_dst
    ldy 0x00
    jmp .ch376_rdb_buf_body

; ---- BUF mode: Y = index into CH376_BUF ----
.ch376_rdb_buf_body:
    ldx 0x00
    lda 0xC0
    sta CH376_TMO_BYTE
.ch376_rdb_buf_w:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne .ch376_rdb_buf_g
    dex
    bne .ch376_rdb_buf_w
    dec CH376_TMO_BYTE
    bne .ch376_rdb_buf_w
    jmp .ch376_rdb_fail
.ch376_rdb_buf_g:
    lda ACIA2_RW_DATA_ADDR
    cpy CH376_CAP
    bcs .ch376_rdb_buf_skip
    sta CH376_BUF,y
    iny
.ch376_rdb_buf_skip:
    dec CH376_RD_LEFT
    bne .ch376_rdb_buf_body
    jmp .ch376_rdb_ok_buf

; ---- DST mode: Y:DE destination ----
.ch376_rdb_dst:
    ldy CH376_DST_PAGE
    ldd CH376_DST_MSB
    lde CH376_DST_LSB
.ch376_rdb_dst_body:
    ldx 0x00
    lda 0xC0
    sta CH376_TMO_BYTE
.ch376_rdb_dst_w:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne .ch376_rdb_dst_g
    dex
    bne .ch376_rdb_dst_w
    dec CH376_TMO_BYTE
    bne .ch376_rdb_dst_w
    jmp .ch376_rdb_fail
.ch376_rdb_dst_g:
    lda ACIA2_RW_DATA_ADDR
    ldx 0x00
    sta yde,x
    ine
    bne .ch376_rdb_dst_skip
    ind
.ch376_rdb_dst_skip:
    dec CH376_RD_LEFT
    bne .ch376_rdb_dst_body
    sty CH376_DST_PAGE
    std CH376_DST_MSB
    ste CH376_DST_LSB
    lda 0x52
    sta CH376_PULL_MODE
    cli
    jsr ch376_clear_int
    jsr ch376_usb_timeout_off
    lda CH376_WIRE_LEN
    sec
    rts

.ch376_rdb_ok_buf:
    lda 0x52
    sta CH376_PULL_MODE
    cli
    jsr ch376_clear_int
    jsr ch376_usb_timeout_off
    tya
    sec
    rts

.ch376_rdb_fail:
    lda ACIA2_CONTROL_STATUS_ADDR
    sta CH376_OVERRUN
    lda 0x52
    sta CH376_PULL_MODE
    cli
    jsr ch376_usb_timeout_off
    lda 0x00
    clc
    rts

ch376_burst_end:

#const CH376_BURST_SIZE = ch376_burst_end - ch376_burst_start
#const CH376_BURST_TAIL = CH376_BURST_SIZE - 0x100
#assert CH376_BURST_SIZE <= CH376_BURST_MAX
#assert CH376_BURST_SIZE > 0x100
