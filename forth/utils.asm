#once 

; **********************************************************
; All utils for tokens, etc..
; **********************************************************

F_TOKENIZE:
    lda 0x00
    sta F_TOKEN_COUNT
    ldx F_TOKEN_START
.skip_spaces:
    lda (F_INPUT_BUFFER_START_LSB),x
    cmp 0x20
    bne .loop
    inx
    inc F_TOKEN_START
    cpx F_INPUT_BUFFER_COUNT
    bne .skip_spaces
    jmp .end
.loop:
    lda (F_INPUT_BUFFER_START_LSB),x
    cmp 0x20
    beq .end
    inc F_TOKEN_COUNT
    inx
    cpx F_INPUT_BUFFER_COUNT
    bne .loop
.end:
    rts

F_FIND_TOKEN:
    lda F_FIND_TOKEN_MSB
    sta F_CMP_TOKEN_MSB
    lda F_FIND_TOKEN_LSB
    sta F_CMP_TOKEN_MSB

    ; save in stack 
    lda F_TOKEN_START
    pha
    lda F_TOKEN_COUNT
    pha

.next_token:
    ; set new start
    clc
    lda F_TOKEN_COUNT
    adc F_TOKEN_START
    sta F_TOKEN_START
    cmp F_INPUT_BUFFER_COUNT
    beq .not_found

    jsr F_TOKENIZE

    ;compare
    jsr F_COMPARE_TOKEN
    bcc .next_token

.found:
    lda F_TOKEN_START
    sta F_FIND_TOKEN_START
    lda F_TOKEN_COUNT
    sta F_FIND_TOKEN_COUNT    
    jmp .done

.not_found:
    lda 0x00
    sta F_FIND_TOKEN_START
    sta F_FIND_TOKEN_COUNT ; not found
    
.done:
    pla 
    sta F_TOKEN_COUNT
    pla 
    sta F_TOKEN_START
    rts

F_PRINT_TOKEN:
    ldy F_TOKEN_COUNT
    ldx F_TOKEN_START
.loop:
    lda (F_INPUT_BUFFER_START_LSB),x
    jsr ACIA_SEND_CHAR
    inx
    dey
    bne .loop
    rts

F_TOKEN_IS_NUMBER:
    ldy F_TOKEN_COUNT
    ldx F_TOKEN_START
.loop:
    lda (F_INPUT_BUFFER_START_LSB),x
    cmp 0x30
    bcc .end
    cmp 0x3A
    bcs .end
    inx
    dey
    bne .loop
    sec
    rts
.end:
    clc
    rts

F_TOKEN_TO_NUMBER:
    ldy F_TOKEN_COUNT
    ldx F_TOKEN_START
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
    lda (F_INPUT_BUFFER_START_LSB),x
    sec 
    sbc #0x30   
    clc
    adc F_TOKEN_VALUE
    sta F_TOKEN_VALUE
    inx
    dey
    bne .loop
    rts

F_TOKEN_TO_UPPERCASE:
    ldy F_TOKEN_COUNT
    ldx F_TOKEN_START
.loop:
    lda (F_INPUT_BUFFER_START_LSB),x
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
    sta (F_INPUT_BUFFER_START_LSB),x
.skip:
    inx
    dey
    bne .loop
    rts

; compare, case insensitive
F_COMPARE_TOKEN:
    ldd F_CMP_TOKEN_MSB
    lde F_CMP_TOKEN_LSB    

    ldy F_TOKEN_START
    ldx 0x00

.cmp_loop:
    lda (F_INPUT_BUFFER_START_LSB),y
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
    iny
    jmp .cmp_loop

.check_token_length:
    cpx F_TOKEN_COUNT
    bne .not_equal
    sec
    rts

.not_equal:
    clc
    rts