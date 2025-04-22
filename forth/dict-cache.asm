#once

; **********************************************************
; All dict chache related stuff
; **********************************************************

#const F_DICT_CACHE_TYPE_FREE = 0x00
#const F_DICT_CACHE_TYPE_BUILT_IN = 0x01
#const F_DICT_CACHE_TYPE_USER_DICT_CMD = 0x02

; Cache layout
;
; 64 bytes -> status [0 - free, 1 built-in, 2 user, 3 vars? ...]
; 128 bytes -> 
;       for built-in (2 bytes), LSB/MSB ptr to function
;       for user (4 bytes), LSB/MSB ptr to dict record + LSB/MSB ptr to cache area 
;
; Note:
; For user dict cmd, we store 4 bytes in the cache starting from position X = TOKEN_START * 2 + 64 bytes
; The second pair of bytes overwrites the TOKEN_START + 1 area, but due to the fact it's a command,
; the TOKEN_START + 1 could be the second char of the command or a space. In both cases, this position will be
; never used, so it's safe.


F_INIT_DICT_CACHE:
    ldx 0x00
    lda F_DICT_CACHE_TYPE_FREE
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB
.loop:
    sta de, x
    inx
    cpx F_MAX_INPUT_SIZE ; 64 bytes 
    bne .loop
    rts

F_IS_DICT_CACHED:
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB
    ldx F_TOKEN_START
    lda de, x
    beq .no_cache
    sta F_DICT_CACHE_TYPE
    sec
    rts
.no_cache:
    clc
    rts

F_GET_CACHED_BUILT_IN:
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB

    lda F_TOKEN_START
    asl a                   ; offset is 2x F_TOKEN_START 
    clc
    adc F_MAX_INPUT_SIZE    ; add map offset (first 64 bytes)
    tax
    lda de, x
    sta F_DICT_EXEC_BUILT_IN_PTR_LSB
    inx
    lda de, x
    sta F_DICT_EXEC_BUILT_IN_PTR_MSB
    lda 0x00
    sta F_DICT_EXEC_BUILT_IN_PTR_PAGE
    rts

F_ADD_BUILT_IN_TO_DICT_CACHE:
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB
    ldx F_TOKEN_START
    lda F_DICT_CACHE_TYPE_BUILT_IN
    sta de, x               ; mark in map
    txa
    asl a                   ; offset is 2x F_TOKEN_START 
    clc
    adc F_MAX_INPUT_SIZE    ; add map offset (first 64 bytes)
    tax
    lda F_DICT_EXEC_BUILT_IN_PTR_LSB
    sta de, x
    inx
    lda F_DICT_EXEC_BUILT_IN_PTR_MSB
    sta de, x
    rts

F_GET_CACHED_USER_DICT_CMD:
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB

    lda F_TOKEN_START
    asl a                   ; offset is 2x F_TOKEN_START 
    clc
    adc F_MAX_INPUT_SIZE    ; add map offset (first 64 bytes)
    tax

    lda de, x
    sta F_DICT_EXEC_USER_LSB
    inx
    lda de, x
    sta F_DICT_EXEC_USER_MSB
    inx

    lda de, x
    sta F_DICT_EXEC_USER_CACHE_LSB
    inx
    lda de, x
    sta F_DICT_EXEC_USER_CACHE_MSB
    rts    

F_ADD_USER_TO_DICT_CACHE:
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB
    ldx F_TOKEN_START
    lda F_DICT_CACHE_TYPE_BUILT_IN
    sta de, x               ; mark in map
    txa
    asl a                   ; offset is 2x F_TOKEN_START 
    clc
    adc F_MAX_INPUT_SIZE    ; add map offset (first 64 bytes)
    tax
    lda F_DICT_EXEC_USER_LSB
    sta de, x
    inx
    lda F_DICT_EXEC_USER_MSB
    sta de, x
    rts

F_NEW_DICT_CACHE_AREA:
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB
    ldx F_TOKEN_START
    lda F_DICT_CACHE_TYPE_USER_DICT_CMD
    sta de, x               ; mark in map 

    ; calculate next area address
    lda F_LAST_ALLOC_DICT_CACHE_START_LSB
    clc
    adc F_MAX_INPUT_SIZE * 3
    sta F_LAST_ALLOC_DICT_CACHE_START_LSB
    lda F_LAST_ALLOC_DICT_CACHE_START_MSB
    adc 0x00
    sta F_LAST_ALLOC_DICT_CACHE_START_MSB

    ; store pointer in current map & switch to new cache area
    inx
    txa
    asl a                   ; offset is 2x [F_TOKEN_START +1] Why? Read at top of the file
    clc
    adc F_MAX_INPUT_SIZE    ; add map offset (first 64 bytes)
    tax
    lda F_LAST_ALLOC_DICT_CACHE_START_LSB
    sta de, x
    sta F_DICT_CACHE_START_LSB
    lda F_LAST_ALLOC_DICT_CACHE_START_MSB
    inx
    sta de, x
    sta F_DICT_CACHE_START_MSB
    rts

