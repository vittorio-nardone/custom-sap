#once
#bank kernel

; OTIO v1 — Otto Terminal I/O (SD read-only)

#const OTIO_SYNC       = 0xF0
#const OTIO_ETX        = 0xF1
#const OTIO_MAGIC_O    = 0x4F
#const OTIO_MAGIC_T    = 0x54
#const OTIO_VER        = 0x01

#const OTIO_STAT_OK    = 0x00
#const OTIO_STAT_ERR   = 0x01
#const OTIO_STAT_EOF   = 0x03

#const OTIO_CMD_PING   = 0x01
#const OTIO_CMD_LIST   = 0x10
#const OTIO_CMD_FOPEN  = 0x20
#const OTIO_CMD_FREAD  = 0x21
#const OTIO_CMD_FCLOSE = 0x22

#const OTIO_CAP_SD     = 0x01
#const OTIO_PEER_AUTO  = 0x00
#const OTIO_PEER_OFF   = 0x01
#const OTIO_PEER_ON    = 0x02
#const OTIO_PEER_OTIO  = 0x01

#const OTIO_ENTRY_SIZE = 26
#const OTIO_CHUNK_SIZE = 64
#const OTIO_TIMEOUT    = 0x96
#const OTIO_PATH_MAX   = 47

otio_msg_no_sd:
    #d 0x0A, 0x0D, "INFO: SD not available", 0x0A, 0x0D, 0x00
otio_msg_no_peer:
    #d 0x0A, 0x0D, "INFO: OTIO not available", 0x0A, 0x0D, 0x00
otio_msg_list_fail:
    #d 0x0A, 0x0D, "INFO: SD list failed", 0x0A, 0x0D, 0x00
otio_sd_hdr:
    #d "SD: ", 0x00
otio_load_start_msg:
    #d 0x0A, 0x0D, "INFO: Loading from SD...", 0x0A, 0x0D, 0x00
otio_load_ok_msg:
    #d 0x0A, 0x0D, "INFO: Load successful!", 0x0A, 0x0D, 0x00
otio_load_fail_msg:
    #d 0x0A, 0x0D, "INFO: Load failed!", 0x0A, 0x0D, 0x00

; OTIO_SEND_BYTE — A = byte
OTIO_SEND_BYTE:
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    rts

; OTIO_WAIT_RX — A=byte or 0xFF timeout (16-bit timer compare)
OTIO_WAIT_RX:
    lda INT_TIMER_COUNTER_LSB
    sta MATH16_WORK
    lda INT_TIMER_COUNTER_MSB
    sta MATH16_WORK + 1
    lda OTIO_TIMEOUT
    clc
    adc MATH16_WORK
    sta MATH16_TMP
    lda MATH16_WORK + 1
    adc 0x00
    sta MATH16_SIGN
.otio_wait_loop:
    lda ACIA_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    bne .otio_wait_got
    lda INT_TIMER_COUNTER_LSB
    cmp MATH16_TMP
    lda INT_TIMER_COUNTER_MSB
    sbc MATH16_SIGN
    bcc .otio_wait_loop
    lda 0xFF
    rts
.otio_wait_got:
    lda ACIA_RW_DATA_ADDR
    rts

; OTIO_SEND_FRAME — A=CMD, X=payload len, payload at OTIO_FRAME_BUFFER
OTIO_SEND_FRAME:
    sta MATH16_B
    stx MATH16_A
    lda 0x00
    sta MATH16_A + 1
    lda OTIO_SYNC
    jsr OTIO_SEND_BYTE
    lda OTIO_MAGIC_O
    jsr OTIO_SEND_BYTE
    lda OTIO_MAGIC_T
    jsr OTIO_SEND_BYTE
    lda OTIO_VER
    jsr OTIO_SEND_BYTE
    sta MATH16_SIGN
    lda MATH16_B
    jsr OTIO_SEND_BYTE
    clc
    adc MATH16_SIGN
    sta MATH16_SIGN
    lda MATH16_A
    jsr OTIO_SEND_BYTE
    clc
    adc MATH16_SIGN
    sta MATH16_SIGN
    lda MATH16_A + 1
    jsr OTIO_SEND_BYTE
    clc
    adc MATH16_SIGN
    sta MATH16_SIGN
    ldx 0x00
.otio_sf_payload:
    cpx MATH16_A
    bcs .otio_sf_chk
    lda 0x837d,x
    jsr OTIO_SEND_BYTE
    clc
    adc MATH16_SIGN
    sta MATH16_SIGN
    inx
    jmp .otio_sf_payload
.otio_sf_chk:
    lda MATH16_SIGN
    jsr OTIO_SEND_BYTE
    lda OTIO_ETX
    jmp OTIO_SEND_BYTE

; OTIO_RECV_FRAME — A=STAT or 0xFF fail; payload at OTIO_FRAME_BUFFER+8, len in MATH16_A
OTIO_RECV_FRAME:
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rf_fail
    cmp OTIO_SYNC
    bne .otio_rf_fail
    ldx 0x01
.otio_rf_read:
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rf_fail
    sta 0x837d,x
    inx
    cpx 0x08
    bcc .otio_rf_read
    lda OTIO_FRAME_BUFFER + 5
    sta MATH16_A
    lda OTIO_FRAME_BUFFER + 6
    sta MATH16_A + 1
    lda MATH16_A
    clc
    adc 0x09
    sta MATH16_B
    lda MATH16_A + 1
    adc 0x00
    sta MATH16_B + 1
.otio_rf_more:
    cpx MATH16_B
    bcs .otio_rf_done
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rf_fail
    sta 0x837d,x
    inx
    jmp .otio_rf_more
.otio_rf_done:
    lda OTIO_FRAME_BUFFER + 4
    rts
.otio_rf_fail:
    jsr ACIA_FLUSH_RX
    lda 0xFF
    rts

; OTIO_RECV_FREAD — after FREAD cmd; A=bytes read, 0=EOF, 0xFF=fail
OTIO_RECV_FREAD:
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_fr_fail
    cmp OTIO_SYNC
    bne .otio_fr_fail
    jsr OTIO_WAIT_RX
    cmp OTIO_MAGIC_O
    bne .otio_fr_fail
    jsr OTIO_WAIT_RX
    cmp 0x44
    beq .otio_fr_data
    cmp 0x54
    bne .otio_fr_fail
    lda OTIO_SYNC
    sta OTIO_FRAME_BUFFER
    lda OTIO_MAGIC_O
    sta OTIO_FRAME_BUFFER + 1
    lda 0x54
    sta OTIO_FRAME_BUFFER + 2
    ldx 0x03
.otio_fr_tail:
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_fr_fail
    sta 0x837d,x
    inx
    cpx 0x08
    bcc .otio_fr_tail
    lda OTIO_FRAME_BUFFER + 5
    sta MATH16_A
    lda OTIO_FRAME_BUFFER + 6
    sta MATH16_A + 1
    lda MATH16_A
    clc
    adc 0x09
    sta MATH16_B
    lda MATH16_A + 1
    adc 0x00
    sta MATH16_B + 1
.otio_fr_more:
    cpx MATH16_B
    bcs .otio_fr_stat
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_fr_fail
    sta 0x837d,x
    inx
    jmp .otio_fr_more
.otio_fr_stat:
    lda OTIO_FRAME_BUFFER + 4
    cmp OTIO_STAT_EOF
    beq .otio_fr_eof
    jmp .otio_fr_fail
.otio_fr_eof:
    lda 0x00
    rts
.otio_fr_data:
    jsr OTIO_RECV_DATA
    rts
.otio_fr_fail:
    lda 0xFF
    rts
; OTIO_RECV_DATA — SYNC/O/D already consumed; A=byte count or 0xFF fail
OTIO_RECV_DATA:
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rd_fail
    sta OTIO_FILE_HANDLE
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rd_fail
    sta OTIO_CHUNK_SEQ
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rd_fail
    sta MATH16_A
    lda 0x00
    sta MATH16_SIGN
    lda OTIO_FILE_HANDLE
    clc
    adc MATH16_SIGN
    sta MATH16_SIGN
    lda OTIO_CHUNK_SEQ
    clc
    adc MATH16_SIGN
    sta MATH16_SIGN
    lda MATH16_A
    clc
    adc MATH16_SIGN
    sta MATH16_SIGN
    ldx 0x00
.otio_rd_data:
    cpx MATH16_A
    bcs .otio_rd_chk
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rd_fail
    sta OTIO_CHUNK_BUFFER,x
    clc
    adc MATH16_SIGN
    sta MATH16_SIGN
    inx
    jmp .otio_rd_data
.otio_rd_chk:
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rd_fail
    cmp MATH16_SIGN
    bne .otio_rd_fail
    jsr OTIO_WAIT_RX
    cmp 0xFF
    beq .otio_rd_fail
    cmp OTIO_ETX
    bne .otio_rd_fail
    lda MATH16_A
    rts
.otio_rd_fail:
    lda 0xFF
    rts

; OTIO_PING
OTIO_PING:
    lda OTIO_CMD_PING
    ldx 0x00
    jsr OTIO_SEND_FRAME
    jsr OTIO_RECV_FRAME
    cmp 0xFF
    beq .otio_ping_fail
    cmp OTIO_STAT_OK
    bne .otio_ping_fail
    lda OTIO_FRAME_BUFFER + 10
    sta OTIO_CAPS
    lda 0x01
    rts
.otio_ping_fail:
    jsr ACIA_FLUSH_RX
    lda 0x00
    rts

OTIO_INIT_PEER:
    lda 0x00
    sta OTIO_CWD
    lda OTIO_PEER_CFG
    cmp OTIO_PEER_OFF
    beq .otio_init_none
    jsr OTIO_PING
    cmp 0x01
    bne .otio_init_none
    lda OTIO_PEER_OTIO
    sta OTIO_PEER_STATUS
    rts
.otio_init_none:
    lda 0x00
    sta OTIO_PEER_STATUS
    rts

OTIO_CHECK_PEER:
    lda OTIO_PEER_STATUS
    bne .otio_peer_ok
    lda OTIO_PEER_CFG
    cmp OTIO_PEER_OFF
    beq .otio_peer_missing
    jsr OTIO_PING
    cmp 0x01
    bne .otio_peer_missing
    lda OTIO_PEER_OTIO
    sta OTIO_PEER_STATUS
    clc
    rts
.otio_peer_missing:
    ldd otio_msg_no_peer[15:8]
    lde otio_msg_no_peer[7:0]
    jsr ACIA_SEND_STRING
    sec
    rts
.otio_peer_ok:
    clc
    rts

OTIO_CHECK_SD:
    jmp OTIO_CHECK_PEER

; OTIO_READ_LINE — read into OTIO_PATH_INPUT until CR; null-terminate
OTIO_READ_LINE:
    ldx 0x00
.otio_rl_clear:
    lda 0x00
    sta OTIO_PATH_INPUT,x
    inx
    cpx OTIO_PATH_MAX
    bcc .otio_rl_clear
    ldx 0x00
.otio_rl_loop:
    jsr ACIA_READ_CHAR
    cmp 0x0D
    beq .otio_rl_done
    cmp 0x7F
    beq .otio_rl_bs
    cmp 0x08
    beq .otio_rl_bs
    cpx OTIO_PATH_MAX
    bcs .otio_rl_loop
    sta OTIO_PATH_INPUT,x
    jsr ACIA_SEND_CHAR
    inx
    jmp .otio_rl_loop
.otio_rl_bs:
    dex
    bmi .otio_rl_loop
    lda 0x08
    jsr ACIA_SEND_CHAR
    jmp .otio_rl_loop
.otio_rl_done:
    lda 0x00
    sta OTIO_PATH_INPUT,x
    jsr ACIA_SEND_NEWLINE
    rts

; OTIO_SET_CWD — path at OTIO_PATH_INPUT
OTIO_SET_CWD:
    ldx 0x00
.otio_cwd_copy:
    lda OTIO_PATH_INPUT,x
    sta OTIO_CWD,x
    beq .otio_cwd_done
    inx
    cpx OTIO_PATH_MAX
    bcc .otio_cwd_copy
.otio_cwd_done:
    rts

; OTIO_PRINT_LIST_HDR — path at OTIO_PATH_INPUT (or CWD if empty)
OTIO_PRINT_LIST_HDR:
    jsr ACIA_SEND_NEWLINE
    ldd otio_sd_hdr[15:8]
    lde otio_sd_hdr[7:0]
    jsr ACIA_SEND_STRING
    lda OTIO_PATH_INPUT
    bne .otio_pl_path
    ldd OTIO_CWD[15:8]
    lde OTIO_CWD[7:0]
    jmp .otio_pl_echo
.otio_pl_path:
    ldd OTIO_PATH_INPUT[15:8]
    lde OTIO_PATH_INPUT[7:0]
.otio_pl_echo:
    jsr ACIA_SEND_STRING
    lda OTIO_PATH_INPUT
    bne .otio_pl_done
    lda OTIO_CWD
    bne .otio_pl_done
    lda 0x2F
    jsr ACIA_SEND_CHAR
.otio_pl_done:
    jsr ACIA_SEND_NEWLINE
    rts

; OTIO_FRAME_PATH_FROM_MENU — copy menu arg (index 1..) into OTIO_FRAME_BUFFER
OTIO_FRAME_PATH_FROM_MENU:
    lda 0x00
    sta OTIO_FRAME_PATH_LEN
    lda 0x01
    sta MATH16_WORK + 1
    lda 0x00
    sta MATH16_WORK
.otio_fp_copy:
    ldx MATH16_WORK + 1
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .otio_fp_done
    lda MAIN_MENU_INPUT_BUFFER,x
    pha
    ldx MATH16_WORK
    sta 0x837d,x
    inc OTIO_FRAME_PATH_LEN
    inc MATH16_WORK
    inc MATH16_WORK + 1
    pla
    jmp .otio_fp_copy
.otio_fp_done:
    ldx MATH16_WORK
    lda 0x00
    sta 0x837d,x
    rts

; OTIO_LIST_PRINT — path prefix already in OTIO_FRAME_BUFFER
OTIO_LIST_PRINT:
    lda 0x00
    sta MATH16_WORK
    sta MATH16_WORK + 1
.otio_list_loop:
    jsr OTIO_LIST_PAGE
    lda MATH16_TMP
    cmp 0x02
    beq .otio_list_done
    cmp 0x01
    beq .otio_list_done
    inc MATH16_WORK
    bne .otio_list_loop
    inc MATH16_WORK + 1
    jmp .otio_list_loop
.otio_list_done:
    rts

; OTIO_LIST_PAGE — offset in MATH16_WORK; path prefix in OTIO_FRAME_BUFFER
OTIO_LIST_PAGE:
    ldx OTIO_FRAME_PATH_LEN
    inx
    lda MATH16_WORK
    sta 0x837d,x
    inx
    lda MATH16_WORK + 1
    sta 0x837d,x
    txa
    tax
    lda OTIO_CMD_LIST
    jsr OTIO_SEND_FRAME
    jsr OTIO_RECV_FRAME
    cmp 0xFF
    beq .otio_lp_err
    cmp OTIO_STAT_ERR
    beq .otio_lp_err
    cmp OTIO_STAT_EOF
    beq .otio_lp_eof
    jmp .otio_lp_more
.otio_lp_eof:
    lda 0x01
    sta MATH16_TMP
    jmp .otio_lp_print
.otio_lp_more:
    lda 0x00
    sta MATH16_TMP
    jmp .otio_lp_print
.otio_lp_err:
    lda 0x02
    sta MATH16_TMP
    ldd otio_msg_list_fail[15:8]
    lde otio_msg_list_fail[7:0]
    jsr ACIA_SEND_STRING
    jsr ACIA_FLUSH_RX
    rts
.otio_lp_print:
    lda 0x07
    sta MATH16_B
    lda 0x00
    sta MATH16_B + 1
.otio_lp_entry:
    lda MATH16_A
    ora MATH16_A + 1
    beq .otio_lp_done
    lda MATH16_A
    cmp OTIO_ENTRY_SIZE
    bcc .otio_lp_done
    jsr OTIO_PRINT_ENTRY
    lda MATH16_A
    sec
    sbc OTIO_ENTRY_SIZE
    sta MATH16_A
    lda MATH16_A + 1
    sbc 0x00
    sta MATH16_A + 1
    lda MATH16_B
    clc
    adc OTIO_ENTRY_SIZE
    sta MATH16_B
    bcc .otio_lp_entry
    inc MATH16_B + 1
    jmp .otio_lp_entry
.otio_lp_done:
    rts

; OTIO_PRINT_ENTRY — entry at OTIO_FRAME_BUFFER + MATH16_B
OTIO_PRINT_ENTRY:
    jsr ACIA_SEND_NEWLINE
    lda 0x20
    jsr ACIA_SEND_CHAR
    jsr ACIA_SEND_CHAR
    ldx MATH16_B
    lda 0x837d,x
    cmp 0x02
    beq .otio_pe_dir
    ldd otio_tag_file[15:8]
    lde otio_tag_file[7:0]
    jmp .otio_pe_tag
.otio_pe_dir:
    ldd otio_tag_dir[15:8]
    lde otio_tag_dir[7:0]
.otio_pe_tag:
    jsr ACIA_SEND_STRING
    ldx MATH16_B
    inx
    lda 0x837d,x
    sta MATH16_SIGN
    inx
.otio_pe_name:
    lda MATH16_SIGN
    beq .otio_pe_done
    dec MATH16_SIGN
    lda 0x837d,x
    jsr ACIA_SEND_CHAR
    inx
    jmp .otio_pe_name
.otio_pe_done:
    rts

otio_tag_dir:
    #d "<DIR>  ", 0x00
otio_tag_file:
    #d "<FILE> ", 0x00

; OTIO_LOAD_FILE — path OTIO_PATH_INPUT, dest Y + MAIN_MENU_ADDR_MSB/LSB
OTIO_LOAD_FILE:
    ldd otio_load_start_msg[15:8]
    lde otio_load_start_msg[7:0]
    jsr ACIA_SEND_STRING
    ldx 0x00
    ldd OTIO_PATH_INPUT[15:8]
    lde OTIO_PATH_INPUT[7:0]
.otio_ld_path:
    lda de,x
    sta 0x837d,x
    beq .otio_ld_open
    inx
    cpx OTIO_PATH_MAX
    bcc .otio_ld_path
    lda 0x00
    sta 0x837d,x
.otio_ld_open:
    txa
    tax
    lda OTIO_CMD_FOPEN
    jsr OTIO_SEND_FRAME
    jsr OTIO_RECV_FRAME
    cmp 0xFF
    beq .otio_ld_fail
    cmp OTIO_STAT_OK
    bne .otio_ld_fail
    lda OTIO_FRAME_BUFFER + 7
    sta OTIO_FILE_HANDLE
    lda OTIO_FRAME_BUFFER + 8
    sta OTIO_FILE_SIZE
    lda OTIO_FRAME_BUFFER + 9
    sta OTIO_FILE_SIZE + 1
    lda OTIO_FRAME_BUFFER + 10
    sta OTIO_FILE_SIZE + 2
    lda OTIO_FRAME_BUFFER + 11
    sta OTIO_FILE_SIZE + 3
    lda 0x00
    sta OTIO_FILE_OFFSET
    sta OTIO_FILE_OFFSET + 1
    sta OTIO_FILE_OFFSET + 2
    sta OTIO_FILE_OFFSET + 3
.otio_ld_read:
    lda OTIO_FILE_HANDLE
    sta OTIO_FRAME_BUFFER
    lda OTIO_FILE_OFFSET
    sta OTIO_FRAME_BUFFER + 1
    lda OTIO_FILE_OFFSET + 1
    sta OTIO_FRAME_BUFFER + 2
    lda OTIO_FILE_OFFSET + 2
    sta OTIO_FRAME_BUFFER + 3
    lda OTIO_FILE_OFFSET + 3
    sta OTIO_FRAME_BUFFER + 4
    lda OTIO_CMD_FREAD
    ldx 0x05
    jsr OTIO_SEND_FRAME
    jsr OTIO_RECV_FREAD
    cmp 0xFF
    beq .otio_ld_fail
    beq .otio_ld_close
    jsr OTIO_STORE_CHUNK
    bcs .otio_ld_fail
    lda OTIO_FILE_OFFSET
    clc
    adc MATH16_A
    sta OTIO_FILE_OFFSET
    lda OTIO_FILE_OFFSET + 1
    adc 0x00
    sta OTIO_FILE_OFFSET + 1
    lda OTIO_FILE_OFFSET + 2
    adc 0x00
    sta OTIO_FILE_OFFSET + 2
    lda OTIO_FILE_OFFSET + 3
    adc 0x00
    sta OTIO_FILE_OFFSET + 3
    jmp .otio_ld_read
.otio_ld_close:
    lda OTIO_FILE_HANDLE
    sta OTIO_FRAME_BUFFER
    lda OTIO_CMD_FCLOSE
    ldx 0x01
    jsr OTIO_SEND_FRAME
    jsr OTIO_RECV_FRAME
.otio_ld_done:
    ldd otio_load_ok_msg[15:8]
    lde otio_load_ok_msg[7:0]
    jsr ACIA_SEND_STRING
    lda 0x00
    rts
.otio_ld_fail:
    lda OTIO_FILE_HANDLE
    sta OTIO_FRAME_BUFFER
    lda OTIO_CMD_FCLOSE
    ldx 0x01
    jsr OTIO_SEND_FRAME
    ldd otio_load_fail_msg[15:8]
    lde otio_load_fail_msg[7:0]
    jsr ACIA_SEND_STRING
    lda 0x01
    rts

; OTIO_STORE_CHUNK — len in MATH16_A
OTIO_STORE_CHUNK:
    ldy MAIN_MENU_ADDR_PAGE
    ldd MAIN_MENU_ADDR_MSB
    lde MAIN_MENU_ADDR_LSB
    tea
    clc
    adc OTIO_FILE_OFFSET
    tae
    tda
    clc
    adc OTIO_FILE_OFFSET + 1
    tad
    tya
    clc
    adc OTIO_FILE_OFFSET + 2
    tay
    ldx 0x00
.otio_sc_loop:
    cpx MATH16_A
    bcs .otio_sc_ok
    lda OTIO_CHUNK_BUFFER,x
    pha
    ldx 0x00
    sta yde,x
    pla
    tax
    ine
    bne .otio_sc_next
    ind
    bne .otio_sc_next
    iny
.otio_sc_next:
    inx
    jmp .otio_sc_loop
.otio_sc_ok:
    clc
    rts
