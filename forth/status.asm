#once
; **********************************************************
; All status related stuff (save/restore status)
; **********************************************************

; STATUS records (9 bytes)
;    - F_INPUT_BUFFER_COUNT_LSB
;    - F_INPUT_BUFFER_COUNT_MSB
;    - F_TOKEN_START_LSB
;    - F_TOKEN_START_MSB
;    - F_TOKEN_COUNT_LSB
;    - F_TOKEN_COUNT_MSB
;    - F_DICT_CACHE_SELECTED_AREA
;    - F_INPUT_BUFFER_START_LSB
;    - F_INPUT_BUFFER_START_MSB

#const F_STATUS_RECORD_SIZE = 0x09

F_PUSH_STATUS:
    ldd F_STATUS_START[15:8]
    lde F_STATUS_START[7:0]
    ldy F_STATUS_COUNT
    beq .push_vars
    ldx 0x00

.go_to_record_loop:
    lda F_STATUS_RECORD_SIZE ; record size
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    dey
    bne .go_to_record_loop

.push_vars:
    ldx 0x00
    lda F_INPUT_BUFFER_COUNT_LSB
    sta de, x
    inx
    lda F_INPUT_BUFFER_COUNT_MSB
    sta de, x
    inx
    lda F_TOKEN_START_LSB
    sta de, x
    inx
    lda F_TOKEN_START_MSB
    sta de, x
    inx
    lda F_TOKEN_COUNT_LSB
    sta de, x
    inx
    lda F_TOKEN_COUNT_MSB
    sta de, x
    inx
    lda F_DICT_CACHE_SELECTED_AREA
    sta de, x
    inx
    lda F_INPUT_BUFFER_START_LSB
    sta de, x
    inx
    lda F_INPUT_BUFFER_START_MSB
    sta de, x
    inc F_STATUS_COUNT
    rts

F_PULL_STATUS:
    dec F_STATUS_COUNT
    ldd F_STATUS_START[15:8]
    lde F_STATUS_START[7:0]
    ldy F_STATUS_COUNT
    beq .pull_vars
    ldx 0x00
.go_to_record_loop:
    lda F_STATUS_RECORD_SIZE ; record size
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    dey
    bne .go_to_record_loop
.pull_vars:
    ldx 0x00
    lda de, x
    sta F_INPUT_BUFFER_COUNT_LSB
    inx
    lda de, x
    sta F_INPUT_BUFFER_COUNT_MSB
    inx
    lda de, x
    sta F_TOKEN_START_LSB
    inx
    lda de, x
    sta F_TOKEN_START_MSB
    inx
    lda de, x
    sta F_TOKEN_COUNT_LSB
    inx
    lda de, x
    sta F_TOKEN_COUNT_MSB
    inx
    lda de, x
    sta F_DICT_CACHE_SELECTED_AREA
    inx
    lda de, x
    sta F_INPUT_BUFFER_START_LSB
    inx
    lda de, x
    sta F_INPUT_BUFFER_START_MSB
    jsr F_SELECT_DICT_CACHE_AREA
    rts