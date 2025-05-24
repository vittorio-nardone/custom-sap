#once

; **********************************************************
; All dict chache related stuff
; **********************************************************

; Cache record layout
; - record number LSB
; - record number MSB
; - next record LSB
; - next record MSB
; - record type
; - record data (3 bytes)
;       for built-in (2 bytes), LSB/MSB ptr to function
;       for user (3 bytes), LSB/MSB ptr to dict record + cache area number (1 byte) 

#const F_MAX_DICT_CACHE_AREAS = 8
#const F_DICT_CACHE_RECORD_TYPE_EOF = 0x00
#const F_DICT_CACHE_RECORD_TYPE_BUILT_IN = 0x01
#const F_DICT_CACHE_RECORD_TYPE_USER_DICT_CMD = 0x02
#const F_DICT_CACHE_RECORD_SIZE = 0x08

F_INIT_DICT_CACHE:
;     ; Clean entry points list - not required, easier debug
;     ldd F_DICT_CACHE_START[15:8]
;     lde F_DICT_CACHE_START[7:0]
;     ldx 0x00
;     lda 0x00
; .clean_loop:
;     sta de, x
;     inx
;     sta de, x
;     inx
;     cpx 2*F_MAX_DICT_CACHE_AREAS
;     bne .clean_loop

    ; set the entry point to the to the first element of the cache
    ; the first 2*F_MAX_DICT_CACHE_AREAS bytes are reserved for storing the entry point of each cache area
    ;  - first byte is LSB, second is MSB
    lda (F_DICT_CACHE_START + (2*F_MAX_DICT_CACHE_AREAS))[7:0]
    sta F_DICT_CACHE_START_LSB
    sta F_DICT_CACHE_START
    lda (F_DICT_CACHE_START + (2*F_MAX_DICT_CACHE_AREAS))[15:8]
    sta F_DICT_CACHE_START_MSB
    sta F_DICT_CACHE_START + 1

    ; create eof record 
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB
    lda F_DICT_CACHE_RECORD_TYPE_EOF
    ldx 0x04    ; set type EOF
    sta de, x
    ldx 0x00    ; set record number to MAX
    lda 0xFF
    sta de, x
    inx
    sta de, x
    std F_DICT_CACHE_LAST_ADDED_MSB
    std F_DICT_CACHE_EOF_MSB
    ste F_DICT_CACHE_LAST_ADDED_LSB
    ste F_DICT_CACHE_EOF_LSB

    ; set selected area to the first one
    lda 0x00
    sta F_DICT_CACHE_SELECTED_AREA
    sta F_DICT_CACHE_LAST_ADDED_AREA
    rts

F_SELECT_DICT_CACHE_AREA:
    ldy F_DICT_CACHE_SELECTED_AREA
    ldd F_DICT_CACHE_START[15:8]
    lde F_DICT_CACHE_START[7:0]
    ldx 0x00
.loop:
    cpy 0x00
    beq .switch
    inx
    inx
    dey
    jmp .loop
.switch:
    lda de, x
    sta F_DICT_CACHE_START_LSB
    inx
    lda de, x
    sta F_DICT_CACHE_START_MSB    
    rts

F_NEW_DICT_CACHE_AREA:
    inc F_DICT_CACHE_LAST_ADDED_AREA
    lda F_DICT_CACHE_LAST_ADDED_AREA
    cmp F_MAX_DICT_CACHE_AREAS
    beq .full
    tay
    ldd F_DICT_CACHE_START[15:8]
    lde F_DICT_CACHE_START[7:0]
    ldx 0x00
.loop:
    cpy 0x00
    beq .fill
    inx
    inx
    dey
    jmp .loop
.fill:
    ; set entry point
    lda F_DICT_CACHE_EOF_LSB
    sta de, x
    inx 
    lda F_DICT_CACHE_EOF_MSB
    sta de, x    
    sec
    rts

.full:
    clc
    rts


F_ADD_BUILT_IN_TO_DICT_CACHE:
    lda F_DICT_CACHE_RECORD_TYPE_BUILT_IN
    sta F_DICT_CACHE_ADD_TYPE
    lda F_DICT_EXEC_BUILT_IN_PTR_LSB
    sta F_DICT_CACHE_ADD_PTR_LSB
    lda F_DICT_EXEC_BUILT_IN_PTR_MSB
    sta F_DICT_CACHE_ADD_PTR_MSB  
    lda 0x00
    sta F_DICT_CACHE_ADD_CACHE_NUMBER  
    jsr F_ADD_ITEM_TO_DICT_CACHE
    rts

F_ADD_USER_TO_DICT_CACHE:
    lda F_DICT_CACHE_RECORD_TYPE_USER_DICT_CMD
    sta F_DICT_CACHE_ADD_TYPE
    lda F_DICT_EXEC_USER_LSB
    sta F_DICT_CACHE_ADD_PTR_LSB
    lda F_DICT_EXEC_USER_MSB
    sta F_DICT_CACHE_ADD_PTR_MSB  
    lda F_DICT_CACHE_LAST_ADDED_AREA
    sta F_DICT_CACHE_ADD_CACHE_NUMBER  
    jsr F_ADD_ITEM_TO_DICT_CACHE
    rts

F_ADD_ITEM_TO_DICT_CACHE:
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB

    lda 0x00
    sta F_DICT_CACHE_TMP_LSB
    sta F_DICT_CACHE_TMP_MSB

.check:
    ldx 0x04
    lda de, x
    cmp F_DICT_CACHE_RECORD_TYPE_EOF
    beq .add_here
    ldx 0x01
    lda de, x
    cmp F_TOKEN_START_MSB
    beq .check_lsb
    bcs .go_next
.add_here:
    ; set ptr to last added to a new memory block
    lda F_DICT_CACHE_LAST_ADDED_LSB
    clc
    adc F_DICT_CACHE_RECORD_SIZE
    sta F_DICT_CACHE_LAST_ADDED_LSB
    lda F_DICT_CACHE_LAST_ADDED_MSB
    adc 0x00
    sta F_DICT_CACHE_LAST_ADDED_MSB

    phd ; save current record ptr
    phe
    ldd F_DICT_CACHE_LAST_ADDED_MSB
    lde F_DICT_CACHE_LAST_ADDED_LSB
    ldx 0x00
    lda F_TOKEN_START_LSB
    sta de, x
    inx
    lda F_TOKEN_START_MSB
    sta de, x  
    inx
    pla ; restore and save LSB
    sta de, x
    inx
    pla ; restore and save MSB
    sta de, x

    lda F_DICT_CACHE_TMP_LSB
    ora F_DICT_CACHE_TMP_MSB
    beq .update_entry_point

    ; update prev record to point to this
    phd ; save current recort ptr
    phe
    ldd F_DICT_CACHE_TMP_MSB
    lde F_DICT_CACHE_TMP_LSB
    ldx 0x02
    lda F_DICT_CACHE_LAST_ADDED_LSB
    sta de, x
    inx
    lda F_DICT_CACHE_LAST_ADDED_MSB
    sta de, x    
    ple
    pld

.replace_here:
    ldx 0x04
    lda F_DICT_CACHE_ADD_TYPE
    sta de, x
    inx
    lda F_DICT_CACHE_ADD_PTR_LSB
    sta de, x
    inx
    lda F_DICT_CACHE_ADD_PTR_MSB
    sta de, x
    inx
    lda F_DICT_CACHE_ADD_CACHE_NUMBER
    sta de, x
    rts    

.update_entry_point:
    phd
    phe
    ldd F_DICT_CACHE_START[15:8]
    lde F_DICT_CACHE_START[7:0]
    ldx 0x00
    ldy F_DICT_CACHE_SELECTED_AREA
.update_entry_point_loop:
    beq .update_entry_point_store
    inx
    inx
    dey
    jmp .update_entry_point_loop
.update_entry_point_store:
    lda F_DICT_CACHE_LAST_ADDED_LSB
    sta de, x
    sta F_DICT_CACHE_START_LSB
    inx
    lda F_DICT_CACHE_LAST_ADDED_MSB
    sta de, x    
    sta F_DICT_CACHE_START_MSB
    ple
    pld
    jmp .replace_here

.check_lsb:
    dex
    lda de, x
    cmp F_TOKEN_START_LSB
    beq .replace_here
    bcs .add_here
.go_next:
    ; save this ptr
    ste F_DICT_CACHE_TMP_LSB
    std F_DICT_CACHE_TMP_MSB
    ; get next
    ldx 0x02
    lda de,x
    pha
    inx
    lda de,x
    tad
    pla
    tae
    jmp .check

F_IS_DICT_CACHED:
    ldd F_DICT_CACHE_START_MSB
    lde F_DICT_CACHE_START_LSB

.check:
    ldx 0x04
    lda de, x
    cmp F_DICT_CACHE_RECORD_TYPE_EOF
    beq .no_cache
    ldx 0x01
    lda de, x
    cmp F_TOKEN_START_MSB
    beq .check_lsb
    bcc .go_next
    jmp .no_cache

.check_lsb:
    dex
    lda de, x
    cmp F_TOKEN_START_LSB
    beq .found
    bcc .go_next
    jmp .no_cache

.go_next:
    ; get next
    ldx 0x02
    lda de,x
    pha
    inx
    lda de,x
    tad
    pla
    tae
    jmp .check

.found:
    ldx 0x04
    lda de, x
    sta F_DICT_CACHE_TYPE
    cmp F_DICT_CACHE_RECORD_TYPE_BUILT_IN
    beq .builtin
    cmp F_DICT_CACHE_RECORD_TYPE_USER_DICT_CMD
    beq .user
    jmp .end
.user:
    inx
    lda de, x
    sta F_DICT_EXEC_USER_LSB
    inx
    lda de, x
    sta F_DICT_EXEC_USER_MSB
    inx
    lda de, x
    sta F_DICT_EXEC_USER_CACHE_NUMBER
    jmp .end
.builtin:
    inx
    lda de, x
    sta F_DICT_EXEC_BUILT_IN_PTR_LSB
    inx
    lda de, X
    sta F_DICT_EXEC_BUILT_IN_PTR_MSB
    lda 0x00
    sta F_DICT_EXEC_BUILT_IN_PTR_PAGE
.end:
    sec
    rts

.no_cache:
    clc
    rts



