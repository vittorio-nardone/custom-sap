#once
; **********************************************************
; All status related stuff (save/restore status)
; **********************************************************

; STATUS records
; - TOTAL SIZE   
;    - F_INPUT_BUFFER_COUNT 
;    - F_TOKEN_START 
;    - F_TOKEN_COUNT 
;    - F_DICT_CACHE_START_LSB
;    - F_DICT_CACHE_START_MSB
;    - INPUT_BUFFER 

F_PUSH_STATUS:
    ldd F_STATUS_START[15:8]
    lde F_STATUS_START[7:0]
    ldy F_STATUS_COUNT
    beq .push_vars
    ldx 0x00

.go_to_record_loop:
    lda de,x
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    dey
    bne .go_to_record_loop

.push_vars:
    ldx 0x01
    lda F_INPUT_BUFFER_COUNT
    sta de, x
    inx
    lda F_TOKEN_START
    sta de, x
    inx
    lda F_TOKEN_COUNT
    sta de, x
    inx
    lda F_DICT_CACHE_START_LSB
    sta de, x
    inx
    lda F_DICT_CACHE_START_MSB
    sta de, x
    inx
    ldy 0x00
.push_input_loop:
    lda F_INPUT_BUFFER_START, y
    sta de, x
    inx
    iny
    cpy F_INPUT_BUFFER_COUNT
    bne .push_input_loop
    inc F_STATUS_COUNT
    txa
    ldx 0x00
    sta de, x
    rts

F_PULL_STATUS:
    dec F_STATUS_COUNT
    ldd F_STATUS_START[15:8]
    lde F_STATUS_START[7:0]
    ldy F_STATUS_COUNT
    beq .pull_vars
    ldx 0x00
.go_to_record_loop:
    lda de,x
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    dey
    bne .go_to_record_loop
.pull_vars:
    ldx 0x01
    lda de, x
    sta F_INPUT_BUFFER_COUNT
    inx
    lda de, x
    sta F_TOKEN_START
    inx
    lda de, x
    sta F_TOKEN_COUNT
    inx
    lda de, x
    sta F_DICT_CACHE_START_LSB
    inx
    lda de, x
    sta F_DICT_CACHE_START_MSB
    inx
    ldy 0x00
.pull_input_loop:
    lda de, x
    sta F_INPUT_BUFFER_START, y
    inx
    iny
    cpy F_INPUT_BUFFER_COUNT
    bne .pull_input_loop
    rts