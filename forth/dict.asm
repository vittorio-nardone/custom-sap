#once

; **********************************************************
; All user dictionary related stuff
; **********************************************************

#const F_DICT_USER_DEF_TYPE_COMMAND  = 0x00
#const F_DICT_USER_DEF_TYPE_VARIABLE = 0x01
#const F_DICT_USER_DEF_TYPE_CONSTANT = 0x02

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
    ldd F_DICT_USER_START_MSB
    lde F_DICT_USER_START_LSB

.go_to_item_loop:
    lda F_DICT_EXEC_USER_ITEM
    beq .skip_label
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

.skip_label:
    ldx 0x01
.skip_label_loop:
    lda de, x
    beq .check_type
    inx
    jmp .skip_label_loop

.check_type:
    inx
    lda de, x
    cmp F_DICT_USER_DEF_TYPE_VARIABLE
    beq .is_a_var
    cmp F_DICT_USER_DEF_TYPE_COMMAND
    beq .is_a_cmd
    ; cmp F_DICT_USER_DEF_TYPE_CONSTANT
    ; beq .is_a_const
    ; jmp .unknown_type
    
.is_a_const:
    inx
    lda de, x
    sta F_TOKEN_VALUE
    jsr F_STACK_PUSH
.const_end:
    rts
    
.is_a_var:
    inx
    txa
    clc
    adc e
    tae
    tda
    adc 0x00
    tad
    std F_TOKEN_VALUE
    jsr F_STACK_PUSH 
    ste F_TOKEN_VALUE   
    jsr F_STACK_PUSH 
.var_end:
    rts

.is_a_cmd:
    phx
    phd
    phe
    jsr F_PUSH_STATUS
    ple
    pld
    plx

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
;   - type (0x00 -> cmd, 0x01 -> variable, 0x02 -> constant)
;   - cmd   (0x00 terminated) / variable & constant 1-byte value
F_DICTIONARY_USER_CMD_ADD:
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
    lda F_DICT_USER_DEF_TYPE_COMMAND ; set CMD flag
    sta de, x
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

F_DICTIONARY_USER_VAR_ADD:
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
    beq .set_var
    inx
    iny
    jmp .add_loop
.set_var:
    inx
    lda F_DICT_ADD_USER_DEF_TYPE ; set flag (var/const)
    sta de, x
    inx
    lda F_DICT_ADD_USER_DEF_VALUE ; set default value
    sta de, x
    inx    
    txa
    ldx 0x00
    sta de, x    
    ; inc # of user functions
    inc F_DICT_USER_COUNT 
    rts

F_BI_NEW_DEF_LABEL:
    #d ":", 0x00 
F_BI_NEW_DEF:
    lda F_TOKEN_COUNT
    sec
    adc F_TOKEN_START
    tax
    ldy 0x00
.label_loop:
    lda F_INPUT_BUFFER_START,x
    inx
    cmp 0x20
    beq .label_end
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
.skip:    
    sta F_DICT_ADD_BUFFER_START, y
    iny
    cpx F_INPUT_BUFFER_COUNT
    bcc .label_loop
    jmp .error

.label_end:
    lda 0x00
    sta F_DICT_ADD_BUFFER_START, y

.find_cmd_loop:
    lda F_INPUT_BUFFER_START,x
    stx F_DICT_ADD_USER_START
    inx
    cmp 0x20 
    bne .cmd_read  
    cpx F_INPUT_BUFFER_COUNT
    bcc .find_cmd_loop
    jmp .error
.cmd_read:
    lda 0x00
    sta F_DICT_ADD_USER_COUNT
.cmd_loop:
    lda F_INPUT_BUFFER_START,x
    inc F_DICT_ADD_USER_COUNT
    inx
    cmp ";" 
    beq .add  
    cpx F_INPUT_BUFFER_COUNT
    bne .cmd_loop
    jmp .error

.add:
    stx F_TOKEN_COUNT
    jsr F_DICTIONARY_USER_CMD_ADD
    rts

.error:
    lda .error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    rts

.error_msg:
    #d "ERROR IN DEFINITION"
    #d 0x00

F_BI_VARIABLE_LABEL:
    #d "VARIABLE", 0x00 
F_BI_VARIABLE:
    lda F_TOKEN_COUNT
    sec
    adc F_TOKEN_START
    tax
    ldy 0x00
.label_loop:
    cpx F_INPUT_BUFFER_COUNT
    beq .label_end
    bcs .error
    
    lda F_INPUT_BUFFER_START,x
    inx
    inc F_TOKEN_COUNT
    cmp 0x20
    beq .label_end
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
.skip:    
    sta F_DICT_ADD_BUFFER_START, y
    iny
    jmp .label_loop

.label_end:
    lda 0x00
    sta F_DICT_ADD_BUFFER_START, y

    lda F_DICT_USER_DEF_TYPE_VARIABLE
    sta F_DICT_ADD_USER_DEF_TYPE

    inc F_TOKEN_COUNT
    jsr F_DICTIONARY_USER_VAR_ADD
    rts

.error:
    lda .error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    rts

.error_msg:
    #d "ERROR IN DEFINITION"
    #d 0x00


F_BI_EMARK_LABEL:
    #d "!", 0x00 
F_BI_EMARK:
    jsr F_STACK_PULL
    bcc .end 
    lde F_TOKEN_VALUE    
    
    jsr F_STACK_PULL
    bcc .end 
    ldd F_TOKEN_VALUE    

    jsr F_STACK_PULL
    bcc .end 
    lda F_TOKEN_VALUE

    ldx 0x00
    sta de,x
.end:
    rts 

F_BI_AT_LABEL:
    #d "@", 0x00 
F_BI_AT:
    jsr F_STACK_PULL
    bcc .end 
    lde F_TOKEN_VALUE    
    
    jsr F_STACK_PULL
    bcc .end 
    ldd F_TOKEN_VALUE    

    ldx 0x00
    lda de,x

    sta F_TOKEN_VALUE
    JSR F_STACK_PUSH

.end:
    rts 

F_BI_QMARK_LABEL:
    #d "?", 0x00 
F_BI_QMARK:
    jsr F_STACK_PULL
    bcc .end 
    lde F_TOKEN_VALUE    
    
    jsr F_STACK_PULL
    bcc .end 
    ldd F_TOKEN_VALUE    

    ldx 0x00
    lda de,x

    jsr ACIA_SEND_DECIMAL
    lda 0x20
    jsr ACIA_SEND_CHAR
.end:
    rts 

F_BI_PLUS_EMARK_LABEL:
    #d "+!", 0x00 
F_BI_PLUS_EMARK:
    jsr F_STACK_PULL
    bcc .end 
    lde F_TOKEN_VALUE    
    
    jsr F_STACK_PULL
    bcc .end 
    ldd F_TOKEN_VALUE    

    jsr F_STACK_PULL
    bcc .end 
 
    ldx 0x00
    lda de,x
    clc
    adc F_TOKEN_VALUE
    sta de,x
.end:
    rts 

F_BI_CONSTANT_LABEL:
    #d "CONSTANT", 0x00 
F_BI_CONSTANT:
    lda F_TOKEN_COUNT
    sec
    adc F_TOKEN_START
    tax
    ldy 0x00
.label_loop:
    cpx F_INPUT_BUFFER_COUNT
    beq .label_end
    bcs .error
    
    lda F_INPUT_BUFFER_START,x
    inx
    inc F_TOKEN_COUNT
    cmp 0x20
    beq .label_end
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
.skip:    
    sta F_DICT_ADD_BUFFER_START, y
    iny
    jmp .label_loop

.label_end:
    inc F_TOKEN_COUNT

    lda 0x00
    sta F_DICT_ADD_BUFFER_START, y

    lda F_DICT_USER_DEF_TYPE_CONSTANT
    sta F_DICT_ADD_USER_DEF_TYPE

    jsr F_STACK_PULL
    bcc .end

    lda F_TOKEN_VALUE
    sta F_DICT_ADD_USER_DEF_VALUE

    jsr F_DICTIONARY_USER_VAR_ADD

.end:
    rts

.error:
    lda .error_msg[15:8]
    sta F_ERROR_MSG_MSB
    lda .error_msg[7:0]
    sta F_ERROR_MSG_LSB
    lda #1
    sta F_EXECUTION_ERROR_FLAG
    rts

.error_msg:
    #d "ERROR IN DEFINITION"
    #d 0x00