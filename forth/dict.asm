#once

; **********************************************************
; All user dictionary related stuff
; **********************************************************

F_TOKEN_IS_DICTIONARY:
    ldd F_DICT_USER_START_MSB
    lde F_DICT_USER_START_LSB
    lda 0x00
    sta F_DICT_EXEC_USER_ITEM
    ldy F_DICT_USER_COUNT
    beq .dictionary_end    

.check_if_match:   
    ldx 0x01
    phy
    ldy F_TOKEN_START

.check_char_match:
    lda de,x
    beq .end_of_dictionary_item
    cmp F_INPUT_BUFFER_START,y
    bne .check_next_dictionary_item 
    inx
    iny
    jmp .check_char_match

.end_of_dictionary_item:
    dex
    cpx F_TOKEN_COUNT
    bne .check_next_dictionary_item
    ply

.match:    
    sec
    rts

.check_next_dictionary_item:
    ply
    dey
    beq .dictionary_end

    ldx 0x00
    lda de, x
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    inc F_DICT_EXEC_USER_ITEM
    jmp .check_if_match    

.dictionary_end:
    clc
    rts

F_EXECUTE_DICTIONARY:
    jsr F_PUSH_STATUS

    ldd F_DICT_USER_START_MSB
    lde F_DICT_USER_START_LSB

.go_to_item_loop:
    lda F_DICT_EXEC_USER_ITEM
    beq .find_cmd
    dec F_DICT_EXEC_USER_ITEM

    ldx 0x00
    lda de, x
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    jmp .go_to_item_loop

.find_cmd:
    ldx 0x01
.find_cmd_loop:
    lda de, x
    beq .copy_cmd
    inx
    jmp .find_cmd_loop

.copy_cmd:
    inx
    ldy 0x00
    sty F_INPUT_BUFFER_COUNT
.copy_cmd_loop:   
    lda de,x
    beq .copy_cmd_end
    sta F_INPUT_BUFFER_START, y
    inx
    iny
    inc F_INPUT_BUFFER_COUNT
    jmp .copy_cmd_loop
.copy_cmd_end:
    lda 0x00
    sta F_TOKEN_START
    sta F_TOKEN_COUNT
    rts

; DICT user records
; - TOTAL SIZE
;   - label (0x00 terminated)
;   - cmd   (0x00 terminated)
F_DICTIONARY_USER_ADD:
    ldd F_DICT_USER_START_MSB
    lde F_DICT_USER_START_LSB
    ldy F_DICT_USER_COUNT
    beq .add
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
.add:
    ldx 0x01
    ldy 0x00
.add_loop:
    lda F_DICT_ADD_BUFFER_START, y
    sta de, x
    beq .copy_cmd
    inx
    iny
    jmp .add_loop
.copy_cmd:
    ldy F_DICT_ADD_USER_START
    inx
.copy_cmd_loop:
    lda F_INPUT_BUFFER_START, y
    sta de, x
    iny
    inx
    dec F_DICT_ADD_USER_COUNT
    bne .copy_cmd_loop
    lda 0x00
    sta de, x 
    ; set record size
    inx
    txa
    ldx 0x00
    sta de, x    
    ; inc # of user functions
    inc F_DICT_USER_COUNT 
    rts