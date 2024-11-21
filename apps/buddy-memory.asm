; Buddy System Memory Allocator for Project Otto
; Manages memory blocks of power of 2 sizes

; Probably CHANGE THIS when adding to kernel
#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x9000
    #size 0x1000
    #outp 0
}

#bank ram

; **************************************************************************
TEST:
    jsr BUDDY_INIT

    lda MAX_LEVEL
    jsr BUDDY_ALLOCATE
    bcs .fail

    lda MIN_LEVEL
    jsr BUDDY_ALLOCATE
    bcs .fail

    lda MAX_LEVEL + 1
    jsr BUDDY_ALLOCATE
    bcc .fail

    lda MIN_LEVEL - 1
    jsr BUDDY_ALLOCATE
    bcc .fail

    lda MIN_LEVEL
    jsr BUDDY_ALLOCATE

    tda
    tao
    rts

.fail:
    ldo 0xFA
    rts


; **************************************************************************
; Constants
#const MEMORY_START = 0x8400 ;  App memory area
#const MEMORY_END   = 0x9000 ;

#const BLOCK_FREE = 0x10
#const BLOCK_USED = 0x20
#const BLOCK_BUDDY_LEFT = 0x40
#const BLOCK_BUDDY_RIGHT = 0x80

#const MAX_LEVEL = 0x0A   ;  2^10 = 1K bytes
#const MIN_LEVEL = 0x05   ;  2^5 = 32 bytes

#const MAX_SIZE  = 2^MAX_LEVEL 
#const MIN_SIZE  = 2^MIN_LEVEL

#const MEMORY_BLOCK_HEADER_SIZE = 0x03
; Block structure
; +0  0bFFFFSSSS   F-> Free/Allocated   S-> Size    
; +1  next block pointer LSB
; +2  next block pointer MSB

; Temp variables
#const MEMORY_TMP_PTR_MSB = 0x8100
#const MEMORY_TMP_PTR_LSB = 0x8101

#const MEMORY_BLOCK_SIZE_MSB = 0x8102
#const MEMORY_BLOCK_SIZE_LSB = 0x8103

#const MEMORY_REQ_BLOCK_LEVEL = 0x8104

#const MEMORY_FOUND_BLOCK_MSB = 0x8105
#const MEMORY_FOUND_BLOCK_LSB = 0x8106
#const MEMORY_FOUND_BLOCK_LEVEL = 0x8107

; **************************************************************************
; TODO if available memory is not exactly a multiple of max block size
BUDDY_INIT:
    ldd MEMORY_START[15:8]
    lde MEMORY_START[7:0]

    lda MAX_LEVEL
    jsr BUDDY_CALC_SIZE

.init_block:
    ; Set block status
    ldx 0x00
    lda BLOCK_FREE + MAX_LEVEL
    sta (de),x      

    ; Calculate and set the next block address
    clc    
    lda MEMORY_BLOCK_SIZE_LSB
    adc e
    sta MEMORY_TMP_PTR_LSB
    lda MEMORY_BLOCK_SIZE_MSB
    ; noc
    adc d
    sta MEMORY_TMP_PTR_MSB

    ; Check if we need to set another block
    ldx MEMORY_TMP_PTR_MSB
    cpx MEMORY_END[15:8]
    beq .check_lsb
    bcs .finished
    jmp .another_block
.check_lsb:    
    ldx MEMORY_TMP_PTR_LSB
    cpx MEMORY_END[7:0]
    bcc .another_block

.finished:
    ; Set current block pointer to null (no next block)
    ldx 0x01
    lda 0x00
    sta (de),x 
    inx
    sta (de),x 
    rts

.another_block:
    ; Set current block pointer to the next block address
    ldx 0x01
    lda MEMORY_TMP_PTR_LSB
    sta (de),x 
    inx
    lda MEMORY_TMP_PTR_MSB
    sta (de),x 

    ; init next block
    ldd MEMORY_TMP_PTR_MSB
    lde MEMORY_TMP_PTR_LSB    
    jmp .init_block

; **************************************************************************
; Input: A = exponent (0-15)
; Output: MEMORY_BLOCK_SIZE_LSB / MEMORY_BLOCK_SIZE_MSB
; Modifies A
BUDDY_CALC_SIZE:
    tax
    lda POW2_LSB,x
    sta MEMORY_BLOCK_SIZE_LSB
    lda POW2_MSB,x
    sta MEMORY_BLOCK_SIZE_MSB
    rts 

; **************************************************************************
; Input:
;   A -> requested level (block size) 
;        MIN_LEVEL <= A <= MAX_LEVEL
;        Block size = 2^A - 3 bytes
;
;        Example: 
;           A=8 -> 256 - 3 = 253 bytes
; Output:
;   DE -> pointer to memory 
;   C set if no memory available

BUDDY_ALLOCATE:
; Validate A
    cmp MIN_LEVEL
    bcc .block_not_found
    cmp MAX_LEVEL + 1
    bcs .block_not_found

    sta MEMORY_REQ_BLOCK_LEVEL

    ldd MEMORY_START[15:8]
    lde MEMORY_START[7:0]

; Init search
.init_search:
    lda 0x00
    sta MEMORY_FOUND_BLOCK_MSB
    sta MEMORY_FOUND_BLOCK_LSB
    lda 0xFF
    sta MEMORY_FOUND_BLOCK_LEVEL

; Search for block
.check_if_block_is_free:
    ldx 0x00
    lda (de),x
    bit BLOCK_FREE 
    beq .jump_to_next_block
    and 0x0F
    cmp MEMORY_REQ_BLOCK_LEVEL
    beq .block_found            ; same size, perfect
    bcc .jump_to_next_block     ; free block is too small

    cmp MEMORY_FOUND_BLOCK_LEVEL
    bcs .jump_to_next_block     ; already found a better fit (same or smaller size)
    
    std MEMORY_FOUND_BLOCK_MSB  ; save candidate
    ste MEMORY_FOUND_BLOCK_LSB
    sta MEMORY_FOUND_BLOCK_LEVEL

.jump_to_next_block:
    ldx 0x02
    lda (de),x 
    beq .end_of_block_list
    pha
    dex
    lda (de),x 
    tae
    pla
    tad
    jmp .check_if_block_is_free


.block_found:
    ; Set block as used
    ldx 0x00
    lda (de),x
    and BLOCK_BUDDY_LEFT + BLOCK_BUDDY_RIGHT + 0x0F
    ora BLOCK_USED
    sta (de),x

    ; Inc DE pointer to skip header 
    clc
    lda 0x03
    adc e
    tae
    lda 0x00
    ; noc
    adc d
    tad

    ; Clear Carry (block found!)
    clc
    rts


.end_of_block_list:
    ; Check if block found, split it
    lda MEMORY_FOUND_BLOCK_LEVEL
    cmp 0xFF
    beq .block_not_found

    ; Start split process
    ldd MEMORY_FOUND_BLOCK_MSB
    lde MEMORY_FOUND_BLOCK_LSB

    ; Store pointer to the next block in the stack
    ldx 0x01
    lda (de),x
    pha
    inx
    lda (de),x
    pha

    ; Calculate new size
    ldx MEMORY_FOUND_BLOCK_LEVEL
    dex
    stx MEMORY_FOUND_BLOCK_LEVEL
    txa
    jsr BUDDY_CALC_SIZE

    ; Set block status
    ldx 0x00
    lda MEMORY_FOUND_BLOCK_LEVEL
    ora BLOCK_FREE + BLOCK_BUDDY_LEFT
    sta (de),x      

    ; Calculate and set the next block address
    clc    
    lda MEMORY_BLOCK_SIZE_LSB
    adc e
    ldx 0x01
    sta (de),x
    sta MEMORY_TMP_PTR_LSB
    lda MEMORY_BLOCK_SIZE_MSB
    ; noc
    adc d
    ldx 0x02
    sta (de),x
    sta MEMORY_TMP_PTR_MSB

    ; Point to buddy block
    ldd MEMORY_TMP_PTR_MSB
    lde MEMORY_TMP_PTR_LSB

    ; Set block status
    ldx 0x00
    lda MEMORY_FOUND_BLOCK_LEVEL
    ora BLOCK_FREE + BLOCK_BUDDY_RIGHT
    sta (de),x      

    ; Restore pointer to next block
    ldx 0x02
    pla
    sta (de),x
    pla
    dex
    sta (de),x

    ; Restart search
    ldd MEMORY_FOUND_BLOCK_MSB
    lde MEMORY_FOUND_BLOCK_LSB
    jmp .init_search

.block_not_found:
    lde 0x00
    ldd 0x00
    ; Set Carry (sorry, block NOT found!)
    sec
    rts



BUDDY_RELEASE:
    ; TODO
    rts