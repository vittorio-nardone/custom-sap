; CH376 RD_USB_DATA0 receive burst.
;
; ACIA #2 has a single byte RX FIFO, so at 115200 baud a byte must be picked
; up roughly every 87us. The loop therefore runs under SEI with no JSR and no
; 24-bit operands: every variable it touches lives below 0x10000 (memmap.asm)
; and the kernel itself is linked in the 16-bit ROM space, so all branches
; assemble to the short form.
;
; Inputs:
;   CH376_RDB_MODE  0 = store into CH376_BUF (capped by CH376_CAP)
;                   1 = store to Y:D:E taken from CH376_DST_PAGE/MSB/LSB
; Outputs:
;   C=1 and A = bytes received (BUF mode returns the stored count),
;   CH376_WIRE_LEN = length announced by the chip; C=0 on timeout.

#once
#bank kernel

ch376_rd_usb_burst:
    lda 0x00
    sta CH376_OVERRUN
    sta CH376_WIRE_LEN
    sta CH376_RD_LEN
    sei
.tx1:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .tx1
    lda CH376_SYNC1
    sta ACIA2_RW_DATA_ADDR
.tx2:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .tx2
    lda CH376_SYNC2
    sta ACIA2_RW_DATA_ADDR
.tx3:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .tx3
    lda CH376_CMD_RD_USB_DATA0
    sta ACIA2_RW_DATA_ADDR
    ldx 0x00
    ldy 0xFF
.wlen:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne .glen
    dex
    bne .wlen
    dey
    bne .wlen
    jmp .fail
.glen:
    lda ACIA2_RW_DATA_ADDR
    sta CH376_WIRE_LEN
    sta CH376_RD_LEN
    beq .fail
    sta CH376_RD_LEFT
    lda CH376_RDB_MODE
    bne .dst
    ldy 0x00
    jmp .buf_body

; ---- BUF mode: Y = index into CH376_BUF ----
.buf_body:
    ldx 0x00
    lda 0xC0
    sta CH376_TMO_BYTE
.buf_w:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne .buf_g
    dex
    bne .buf_w
    dec CH376_TMO_BYTE
    bne .buf_w
    jmp .fail
.buf_g:
    lda ACIA2_RW_DATA_ADDR
    cpy CH376_CAP
    bcs .buf_skip
    sta CH376_BUF,y
    iny
.buf_skip:
    dec CH376_RD_LEFT
    bne .buf_body
    jmp .ok_buf

; ---- DST mode: Y:DE destination ----
.dst:
    ldy CH376_DST_PAGE
    ldd CH376_DST_MSB
    lde CH376_DST_LSB
.dst_body:
    ldx 0x00
    lda 0xC0
    sta CH376_TMO_BYTE
.dst_w:
    lda ACIA2_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne .dst_g
    dex
    bne .dst_w
    dec CH376_TMO_BYTE
    bne .dst_w
    jmp .fail
.dst_g:
    lda ACIA2_RW_DATA_ADDR
    ldx 0x00
    sta yde,x
    ine
    bne .dst_skip
    ind
.dst_skip:
    dec CH376_RD_LEFT
    bne .dst_body
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

.ok_buf:
    lda 0x52
    sta CH376_PULL_MODE
    cli
    jsr ch376_clear_int
    jsr ch376_usb_timeout_off
    tya
    sec
    rts

.fail:
    lda ACIA2_CONTROL_STATUS_ADDR
    sta CH376_OVERRUN
    lda 0x52
    sta CH376_PULL_MODE
    cli
    ; Mid-burst timeout leaves bytes in the 1-byte RX FIFO / INT# asserted —
    ; drain and GET_STATUS so the next command is not desynced.
    jsr ch376_drain_rx
    jsr ch376_clear_int
    jsr ch376_usb_timeout_off
    lda 0x00
    clc
    rts
