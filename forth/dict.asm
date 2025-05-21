#once

; **********************************************************
; All user dictionary related stuff
; **********************************************************

; DICT user records
;   - previous LSB
;   - previous MSB
;   - total size LSB
;   - total size MSB
;   - type (0x00 -> cmd, 0x01 -> variable, 0x02 -> constant, 0x03 -> deleted)
;   - label size
;   - label (0x00 terminated)
;   - cmd   (0x00 terminated) / variable & constant 1-byte value

#const F_DICT_USER_DEF_TYPE_COMMAND  = 0x00
#const F_DICT_USER_DEF_TYPE_VARIABLE = 0x01
#const F_DICT_USER_DEF_TYPE_CONSTANT = 0x02
#const F_DICT_USER_DEF_TYPE_DELETED = 0x03

F_TOKEN_IS_USER_DICTIONARY:
    ldy F_DICT_USER_COUNT
    beq .dictionary_end    

    ldd F_DICT_USER_LAST_ADD_MSB
    lde F_DICT_USER_LAST_ADD_LSB
.check_if_match:   
    ; store dict counter
    phy

    ; check if deleted
    ldx 0x04
    lda de, x
    cmp F_DICT_USER_DEF_TYPE_DELETED
    beq .check_next_dictionary_item

    ; check label size
    inx
    lda de, x
    cmp F_TOKEN_COUNT_LSB
    bne .check_next_dictionary_item

    ; start label check
    inx
    jsr F_16_SET_TOKEN_POS_TO_START

.check_char_match:
    lda de,x
    beq .end_of_dictionary_item
    cmp (F_INPUT_BUFFER_PTR_LSB)
    bne .check_next_dictionary_item 
    inx
    jsr F_16_INC_TOKEN_POS
    jmp .check_char_match

.end_of_dictionary_item:
    ply

.match:    
    ste F_DICT_EXEC_USER_LSB
    std F_DICT_EXEC_USER_MSB
    sec
    rts

.check_next_dictionary_item:
    ply
    dey
    beq .dictionary_end

    ldx 0x00
    lda de, x ; LSB
    pha
    inx
    lda de, x ; MSB
    tad
    ple
    jmp .check_if_match    

.dictionary_end:
    clc
    rts

F_EXECUTE_USER_DICTIONARY:
    ldd F_DICT_EXEC_USER_MSB
    lde F_DICT_EXEC_USER_LSB

.skip_label:
    ; calculate offset
    ldx 0x05
    lda de, x
    clc
    adc 0x06
    pha

.check_type:
    ldx 0x04
    lda de, x
    plx ; restore offset
    cmp F_DICT_USER_DEF_TYPE_VARIABLE
    beq .is_a_var
    cmp F_DICT_USER_DEF_TYPE_COMMAND
    beq .is_a_cmd
    ; cmp F_DICT_USER_DEF_TYPE_CONSTANT
    ; beq .is_a_const
    ; jmp .unknown_type
    
.is_a_const:
    ; push value in the stack
    inx
    lda de, x
    sta F_TOKEN_VALUE 
    jsr F_STACK_PUSH
.const_end:
    rts
    
.is_a_var:
    ; calculate and push address in the stack
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

    ; set size of new input buffer
    inx
    phx
    stx F_INPUT_BUFFER_COUNT_LSB
    ldx 0x02
    lda de,x
    clc ; -1
    sbc F_INPUT_BUFFER_COUNT_LSB
    sta F_INPUT_BUFFER_COUNT_LSB
    inx
    lda de,x
    sbc 0x00
    sta F_INPUT_BUFFER_COUNT_MSB

    ; calculate offset and change pointer
    pla ; restore x
    clc
    adc e
    sta F_INPUT_BUFFER_START_LSB
    tda
    adc 0x00
    sta F_INPUT_BUFFER_START_MSB

    ; ; allocate and init a new cache area
    ; jsr F_ADD_USER_TO_DICT_CACHE
    ; jsr F_NEW_DICT_CACHE_AREA
    ; jsr F_INIT_DICT_CACHE

    ; init token vars
    jsr F_16_RESET_TOKEN_ALL
    rts

; F_EXECUTE_CACHED_USER_DICT_CMD:
;     ldd F_DICT_EXEC_USER_MSB
;     lde F_DICT_EXEC_USER_LSB

; .skip_label_type:
;     ; calculate offset
;     ldx 0x04
;     lda de, x
;     clc
;     adc 0x05
;     tax

; .is_a_cmd:
;     phx
;     phd
;     phe
;     jsr F_PUSH_STATUS
;     ple
;     pld
;     plx

;     ; set size of new input buffer
;     inx
;     phx
;     stx F_INPUT_BUFFER_COUNT
;     ldx 0x02
;     lda de,x
;     clc ; -1
;     sbc F_INPUT_BUFFER_COUNT
;     sta F_INPUT_BUFFER_COUNT

;     ; calculate offset and change pointer
;     pla ; restore x
;     clc
;     adc e
;     sta F_INPUT_BUFFER_START_LSB
;     tda
;     adc 0x00
;     sta F_INPUT_BUFFER_START_MSB

;     ; restore cache area
;     lda F_DICT_EXEC_USER_CACHE_LSB
;     sta F_DICT_CACHE_START_LSB
;     lda F_DICT_EXEC_USER_CACHE_MSB
;     sta F_DICT_CACHE_START_MSB    

;     ; init token vars
;     lda 0x00
;     sta F_TOKEN_START
;     sta F_TOKEN_COUNT
;     rts

F_DICTIONARY_USER_CMD_ADD:
    ldy F_DICT_USER_COUNT
    beq .first

    ; calculate new record ptr
    ldd F_DICT_USER_LAST_ADD_MSB
    lde F_DICT_USER_LAST_ADD_LSB
    ldx 0x02
    lda de,x
    clc
    adc e
    tae
    inx
    lda de,x
    adc d
    tad

    ; se pointer to previous record
    ldx 0x00
    lda F_DICT_USER_LAST_ADD_LSB
    sta de, x  
    inx
    lda F_DICT_USER_LAST_ADD_MSB
    sta de, x  
    jmp .add

.first:
    ldd F_DICT_USER_START[15:8]
    lde F_DICT_USER_START[7:0]
    ldx 0x00
    lda 0x00
    sta de, x
    inx 
    sta de, x

.add:
    std F_DICT_USER_LAST_ADD_MSB
    ste F_DICT_USER_LAST_ADD_LSB
    ; calculate total size 
    ldx 0x02
    ldy 0x00
    clc         
    lda 0x08    ; fixed fields + null termination of label/cmd
    adc F_DICT_ADD_USER_LABEL_COUNT
    bcc .skip_size_msb_inc
    iny
.skip_size_msb_inc:
    adc F_DICT_ADD_USER_COUNT_LSB
    sta de, x
    tya
    inx
    adc F_DICT_ADD_USER_COUNT_MSB
    sta de, x

    inx
    lda F_DICT_USER_DEF_TYPE_COMMAND ; set CMD flag
    sta de, x
    inx
    lda F_DICT_ADD_USER_LABEL_COUNT ; set label size
    sta de, x
    inx 
    lda F_DICT_ADD_USER_LABEL_START_LSB
    sta F_TOKEN_POS_LSB
    lda F_DICT_ADD_USER_LABEL_START_MSB
    sta F_TOKEN_POS_MSB
    jsr F_16_SET_BUFFER_PTR_TO_TOKEN_POS
.add_loop:
    jsr F_16_GET_INPUT_BYTE
    sta de, x
    dec F_DICT_ADD_USER_LABEL_COUNT
    beq .copy_cmd
    jsr .incx
    jsr F_16_INC_TOKEN_POS
    jmp .add_loop
.copy_cmd:
    ; null terminate label
    lda 0x00 
    jsr .incx
    sta de, x
    lda F_DICT_ADD_USER_START_LSB
    sta F_TOKEN_POS_LSB
    lda F_DICT_ADD_USER_START_MSB
    sta F_TOKEN_POS_MSB
    jsr F_16_SET_BUFFER_PTR_TO_TOKEN_POS
    jsr .incx
.copy_cmd_loop:
    jsr F_16_GET_INPUT_BYTE
    sta de, x
    jsr F_16_INC_TOKEN_POS
    jsr .incx    
    dec F_DICT_ADD_USER_COUNT_LSB
    bne .copy_cmd_loop   
    lda F_DICT_ADD_USER_COUNT_MSB
    bne .dec_count_msb
    lda 0x00    ; terminate string
    sta de, x  
    ; inc # of user functions
    inc F_DICT_USER_COUNT 
    rts
.dec_count_msb:
    dec F_DICT_ADD_USER_COUNT_MSB
    jmp .copy_cmd_loop
.incx:
    inx
    bne .skip_inc
    ind
.skip_inc:
    rts

F_DICTIONARY_USER_VAR_ADD:
    ldy F_DICT_USER_COUNT
    beq .first

    ; calculate new record ptr
    ldd F_DICT_USER_LAST_ADD_MSB
    lde F_DICT_USER_LAST_ADD_LSB
    ldx 0x02
    lda de,x
    clc
    adc e
    tae
    inx
    lda de,x
    adc d
    tad

    ; se pointer to previous record
    ldx 0x00
    lda F_DICT_USER_LAST_ADD_LSB
    sta de, x  
    inx
    lda F_DICT_USER_LAST_ADD_MSB
    sta de, x  
    jmp .add

.first:
    ldd F_DICT_USER_START[15:8]
    lde F_DICT_USER_START[7:0]
    ldx 0x00
    lda 0x00
    sta de, x
    inx 
    sta de, x

.add:
    ; calculate total size 
    ldx 0x02
    ldy 0x00
    clc         
    lda 0x08    ; fixed fields + null termination of label/cmd
    adc F_DICT_ADD_USER_LABEL_COUNT
    bcc .skip_size_msb_inc
    iny
.skip_size_msb_inc:
    sta de, x
    tya
    inx
    sta de, x

    ; set flag (var/const)
    inx
    lda F_DICT_ADD_USER_DEF_TYPE 
    sta de, x
    inx
    lda F_DICT_ADD_USER_LABEL_COUNT ; set label size
    sta de, x
    inx
    lda F_DICT_ADD_USER_LABEL_START_LSB
    sta F_TOKEN_POS_LSB
    lda F_DICT_ADD_USER_LABEL_START_MSB
    sta F_TOKEN_POS_MSB
    jsr F_16_SET_BUFFER_PTR_TO_TOKEN_POS
.add_loop:
    jsr F_16_GET_INPUT_BYTE
    sta de, x
    dec F_DICT_ADD_USER_LABEL_COUNT
    beq .set_var
    inx
    jsr F_16_INC_TOKEN_POS
    jmp .add_loop
.set_var:
    ; null terminate label
    lda 0x00 
    inx
    sta de, x
    ; set default value
    inx
    lda F_DICT_ADD_USER_DEF_VALUE
    sta de, x
    ; inc # of user functions
    inc F_DICT_USER_COUNT 
    std F_DICT_USER_LAST_ADD_MSB
    ste F_DICT_USER_LAST_ADD_LSB 
    rts

F_FORGET_TOKEN_IN_USER_DICTIONARY:
    ldy F_DICT_USER_COUNT
    beq .dictionary_end    

    ldd F_DICT_USER_LAST_ADD_MSB
    lde F_DICT_USER_LAST_ADD_LSB
.check_if_match:   
    ; store dict counter
    phy

    ; check if deleted
    ldx 0x04
    lda de, x
    cmp F_DICT_USER_DEF_TYPE_DELETED
    beq .check_next_dictionary_item

    ; check label size
    inx
    lda de, x
    cmp F_TOKEN_COUNT_LSB
    bne .check_next_dictionary_item

    ; start label check
    inx
    jsr F_16_SET_TOKEN_POS_TO_START

.check_char_match:
    lda de,x
    beq .end_of_dictionary_item
    cmp (F_INPUT_BUFFER_PTR_LSB)
    bne .check_next_dictionary_item 
    inx
    jsr F_16_INC_TOKEN_POS
    jmp .check_char_match

.end_of_dictionary_item:
    ply

.match:
    ; set as deleted    
    ldx 0x04
    lda F_DICT_USER_DEF_TYPE_DELETED
    sta de, x
    sec
    rts

.check_next_dictionary_item:
    ply
    dey
    beq .dictionary_end

    ldx 0x00
    lda de, x ; LSB
    pha
    inx
    lda de, x ; MSB
    tad
    ple
    jmp .check_if_match    

.dictionary_end:
    clc
    rts

F_BI_NEW_DEF_LABEL:
    #d ":", 0x00 
F_BI_NEW_DEF:
    jsr F_16_SET_TOKEN_POS_TO_START_PLUS_COUNT
.find_label_loop:
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_GET_INPUT_BYTE
    cmp 0x20 
    beq .next_char
    cmp 0x0D
    beq .next_char
    jmp .label_found  
.next_char:
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .find_label_loop
    jmp .error
.label_found:
    lda F_TOKEN_POS_LSB
    sta F_DICT_ADD_USER_LABEL_START_LSB
    lda F_TOKEN_POS_MSB
    sta F_DICT_ADD_USER_LABEL_START_MSB
    ldy 0x00
.label_loop:
    jsr F_16_GET_INPUT_BYTE
    cmp 0x20
    beq .label_end
    cmp 0x0D
    beq .label_end
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
    jsr F_16_SET_INPUT_BYTE
.skip:    
    iny
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .label_loop
    jmp .error

.label_end:
    sty F_DICT_ADD_USER_LABEL_COUNT
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT

.find_cmd_loop:
    jsr F_16_GET_INPUT_BYTE
    cmp 0x20 
    beq .next_char2
    cmp 0x0D
    beq .next_char2
    jmp .cmd_read  
.next_char2:
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .find_cmd_loop
    jmp .error
.cmd_read:
    lda F_TOKEN_POS_LSB
    sta F_DICT_ADD_USER_START_LSB
    lda F_TOKEN_POS_MSB
    sta F_DICT_ADD_USER_START_MSB
    lda 0x00
    sta F_DICT_ADD_USER_COUNT_LSB
    sta F_DICT_ADD_USER_COUNT_MSB
.cmd_loop:
    jsr F_16_GET_INPUT_BYTE
    cmp ";" 
    beq .add  
    inc F_DICT_ADD_USER_COUNT_LSB
    bne .skip_count_msb_inc
    inc F_DICT_ADD_USER_COUNT_MSB
.skip_count_msb_inc:
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .cmd_loop
    jmp .error

.add:
    jsr F_16_INC_TOKEN_COUNT
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

F_BI_FORGET_LABEL:
    #d "FORGET", 0x00 
F_BI_FORGET:
    ; move to the end of the current token
    jsr F_16_ADD_COUNT_TO_TOKEN_START
    jsr F_16_CHECK_START_END_OF_FILE
    bcs .error

    ; find next token 
    jsr F_TOKENIZE
    jsr F_16_CHECK_START_END_OF_FILE
    bcs .error

    jsr F_TOKEN_TO_UPPERCASE
    jsr F_FORGET_TOKEN_IN_USER_DICTIONARY
    bcc .error
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
    #d "NOT FOUND"
    #d 0x00

F_BI_VARIABLE_LABEL:
    #d "VARIABLE", 0x00 
F_BI_VARIABLE:
    jsr F_16_SET_TOKEN_POS_TO_START_PLUS_COUNT
.find_label_loop:
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_GET_INPUT_BYTE
    cmp 0x20 
    beq .next_char
    cmp 0x0D
    beq .next_char
    jmp .label_found  
.next_char:
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .find_label_loop
    jmp .error
.label_found:
    lda F_TOKEN_POS_LSB
    sta F_DICT_ADD_USER_LABEL_START_LSB
    lda F_TOKEN_POS_MSB
    sta F_DICT_ADD_USER_LABEL_START_MSB
    ldy 0x00
.label_loop:
    jsr F_16_GET_INPUT_BYTE
    cmp 0x20
    beq .label_end
    cmp 0x0D
    beq .label_end
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
    jsr F_16_SET_INPUT_BYTE
.skip:    
    iny
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .label_loop
    jmp .error

.label_end:
    sty F_DICT_ADD_USER_LABEL_COUNT
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT

    lda F_DICT_USER_DEF_TYPE_VARIABLE
    sta F_DICT_ADD_USER_DEF_TYPE

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
    jsr F_16_SET_TOKEN_POS_TO_START_PLUS_COUNT
.find_label_loop:
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_GET_INPUT_BYTE
    cmp 0x20 
    beq .next_char
    cmp 0x0D
    beq .next_char
    jmp .label_found  
.next_char:
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .find_label_loop
    jmp .error
.label_found:
    lda F_TOKEN_POS_LSB
    sta F_DICT_ADD_USER_LABEL_START_LSB
    lda F_TOKEN_POS_MSB
    sta F_DICT_ADD_USER_LABEL_START_MSB
    ldy 0x00
.label_loop:
    jsr F_16_GET_INPUT_BYTE
    cmp 0x20
    beq .label_end
    cmp 0x0D
    beq .label_end
    cmp "a" 
    bcc .skip
    cmp "z"+1      
    bcs .skip
    sec
    sbc 0x20
    jsr F_16_SET_INPUT_BYTE
.skip:    
    iny
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT
    jsr F_16_CHECK_POS_END_OF_FILE
    bcc .label_loop
    jmp .error

.label_end:
    sty F_DICT_ADD_USER_LABEL_COUNT
    jsr F_16_INC_TOKEN_POS
    jsr F_16_INC_TOKEN_COUNT

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


