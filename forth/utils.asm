#once 

; **********************************************************
; All utils for tokens, etc..
; **********************************************************

F_TOKENIZE:
    jsr F_16_RESET_TOKEN_COUNT
    jsr F_16_SET_TOKEN_POS_TO_START
.skip_spaces:
    F_MACRO_16_GET_INPUT_BYTE
    cmp 0x20
    beq .next_char
    cmp 0x0D
    beq .next_char
    jmp .loop
.next_char:
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_START
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .skip_spaces
    jmp .end
.loop:
    F_MACRO_16_GET_INPUT_BYTE
    cmp 0x20
    beq .end
    cmp 0x0D
    beq .end
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .loop
.end:
    rts

F_FIND_TOKEN:
    lda F_FIND_TOKEN_MSB
    sta F_CMP_TOKEN_MSB
    lda F_FIND_TOKEN_LSB
    sta F_CMP_TOKEN_LSB

    ; save in stack 
    lda F_TOKEN_START_LSB
    pha
    lda F_TOKEN_START_MSB
    pha
    lda F_TOKEN_COUNT_LSB
    pha
    lda F_TOKEN_COUNT_MSB
    pha

.next_token:
    jsr F_16_ADD_COUNT_TO_TOKEN_START
    jsr F_16_CHECK_START_END_OF_FILE
    bcs .not_found

    lda F_FIND_TOKEN_START_LIMIT_LSB
    ora F_FIND_TOKEN_START_LIMIT_MSB
    beq .tokenize

    lda F_TOKEN_START_MSB
    cmp F_FIND_TOKEN_START_LIMIT_MSB
    beq .check_lsb_limit
    bcs .not_found
    jmp .tokenize

.check_lsb_limit:
    lda F_TOKEN_START_LSB
    cmp F_FIND_TOKEN_START_LIMIT_LSB
    bcs .not_found    
  
.tokenize:
    jsr F_TOKENIZE
    jsr F_16_CHECK_START_END_OF_FILE
    bcs .not_found

    ;compare
    jsr F_COMPARE_TOKEN
    bcc .next_token

.found:
    lda F_TOKEN_START_LSB
    sta F_FIND_TOKEN_START_LSB
    lda F_TOKEN_START_MSB
    sta F_FIND_TOKEN_START_MSB
    lda F_TOKEN_COUNT_LSB
    sta F_FIND_TOKEN_COUNT_LSB  
    lda F_TOKEN_COUNT_MSB
    sta F_FIND_TOKEN_COUNT_MSB  
    sec
    jmp .done

.not_found:
    lda 0x00
    sta F_FIND_TOKEN_START_LSB
    sta F_FIND_TOKEN_START_MSB
    sta F_FIND_TOKEN_COUNT_LSB ; not found
    sta F_FIND_TOKEN_COUNT_MSB ; not found
    clc
    
.done:
    pla 
    sta F_TOKEN_COUNT_MSB
    pla 
    sta F_TOKEN_COUNT_LSB
    pla 
    sta F_TOKEN_START_MSB
    pla
    sta F_TOKEN_START_LSB
    rts

F_PRINT_TOKEN:
    jsr F_16_SET_TOKEN_POS_TO_START
.loop:
    F_MACRO_16_GET_INPUT_BYTE
    jsr ACIA_SEND_CHAR
    jsr F_16_INC_TOKEN_POS
    jsr F_16_CHECK_END_OF_TOKEN
    bcc .loop
    rts

F_TOKEN_IS_NUMBER:
    jsr F_16_SET_TOKEN_POS_TO_START
.loop:
    F_MACRO_16_GET_INPUT_BYTE
    cmp 0x30
    bcc .end
    cmp 0x3A
    bcs .end
    jsr F_16_INC_TOKEN_POS
    jsr F_16_CHECK_END_OF_TOKEN
    bcc .loop
    sec
    rts
.end:
    clc
    rts

F_TOKEN_TO_NUMBER:
    jsr F_16_SET_TOKEN_POS_TO_START
    lda #0x00
    sta F_TOKEN_VALUE
.loop:
    lda F_TOKEN_VALUE
    beq .add
    asl a
    tad
    asl a
    asl a
    clc
    adc D
    sta F_TOKEN_VALUE
.add:
    F_MACRO_16_GET_INPUT_BYTE
    sec 
    sbc #0x30   
    clc
    adc F_TOKEN_VALUE
    sta F_TOKEN_VALUE
    jsr F_16_INC_TOKEN_POS
    jsr F_16_CHECK_END_OF_TOKEN
    bcc .loop
    rts

F_TOKEN_TO_UPPERCASE:
    jsr F_16_SET_TOKEN_POS_TO_START
.loop:
    F_MACRO_16_GET_INPUT_BYTE
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
    jsr F_16_SET_INPUT_BYTE
.skip:
    jsr F_16_INC_TOKEN_POS
    jsr F_16_CHECK_END_OF_TOKEN
    bcc .loop
    rts

; compare, case insensitive
F_COMPARE_TOKEN:
    ldd F_CMP_TOKEN_MSB
    lde F_CMP_TOKEN_LSB    

    jsr F_16_SET_TOKEN_POS_TO_START
    ldx 0x00

.cmp_loop:
    F_MACRO_16_GET_INPUT_BYTE
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
.skip:
    sta F_CMP_CURRENT_CHAR
    lda de,x
    beq .check_token_length 
    cmp F_CMP_CURRENT_CHAR
    bne .not_equal
    inx
    jsr F_16_INC_TOKEN_POS
    jmp .cmp_loop
.check_token_length:
    cpx F_TOKEN_COUNT_LSB
    bne .not_equal
    sec
    rts

.not_equal:
    clc
    rts