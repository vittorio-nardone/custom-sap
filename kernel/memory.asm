#once
#bank kernel

; **********************************************************
; VERY SIMPLE MEMORY MANAGEMENT ROUTINES
;
; call MEMORY_INIT_DEFAULT to set up memory map with 16k of managed memory:
;  - 0xAF00-0xAFFF (256 bytes) - memory map
;  - 0xB000-0xEFFF (16k) - managed memory
;
;
; ; ------ Example usage -----
; ; Initialize memory management
; jsr MEMORY_INIT_DEFAULT

; ; Allocate 4 blocks
; lda 0x04
; jsr MEMORY_ALLOCATE ; returns pointer in DE

; ; ...
; ; Do something with the memory
; ; ...

; ; Deallocate the memory 
; lda #0x02
; jsr MEMORY_DEALLOCATE ; provide pointer in DE
; rts
; ; ------ End of example usage ------


#const MEMORY_START_PTR     = 0x8100      ; PTR to the starting address of managed memory (Little-endian - 2 bytes)
#const MEMORY_MAP_START_PTR = 0x8102      ; PTR to the starting address of memory map (Little-endian - 2 bytes)
#const MEMORY_TMP_PTR       = 0x8104      ; PTR to the temporary address (Little-endian - 2 bytes)

; Constants for memory management
#const MEMORY_SIZE = 0x4000      ; Total size of managed memory (16KB)
#const MEMORY_BLOCK_SIZE = 0x40         ; Block size (64 bytes)
#const MEMORY_MAX_BLOCKS = MEMORY_SIZE / MEMORY_BLOCK_SIZE

; Memory map structure
; Byte 0: Block status (0 = free, 1 = allocated)


MEMORY_INIT_DEFAULT:

;       0xAF00-0xAFFF (256 bytes) - memory map
;       0xB000-0xEFFF (16k) - managed memory
;
; Initialize pointers to the memory map (0xAF00) and the memory (0xB000)
    pha
    lda #0x00
    sta MEMORY_MAP_START_PTR
    lda #0xAF
    sta MEMORY_MAP_START_PTR+1

    lda #0x00
    sta MEMORY_START_PTR
    lda #0xB0
    sta MEMORY_START_PTR+1
    jsr MEMORY_INIT
    pla
    rts

; Memory management initialization
MEMORY_INIT:
    pha
    phx
    phd
    phe
    ldd MEMORY_MAP_START_PTR+1
    lde MEMORY_MAP_START_PTR
    ldx #0
    lda #0
.init_loop:
    sta de,x      ; Mark all blocks as free
    inx
    cpx #MEMORY_MAX_BLOCKS
    bne .init_loop
    ple
    pld
    plx
    pla
    rts

; Memory allocation
; Input:  A = number of blocks to allocate
; Output: 
;       DE = address of the first allocated block
;       C = 0 if allocation successful, 1 if failed
MEMORY_ALLOCATE:
    pha
    phy
    tay                     ; Save requested size in Y    
    
    ldx #0                 ; Index to scan the map
    lda MEMORY_START_PTR
    sta MEMORY_TMP_PTR 
    lda MEMORY_START_PTR+1
    sta MEMORY_TMP_PTR+1

    ldd MEMORY_MAP_START_PTR+1
    lde MEMORY_MAP_START_PTR

.find_free:
    lda de,x       ; Check if block is free
    bne .next_block        ; If not free, move to next
    
    cpy #0x01
    beq .blocks_found

    ; Check if there are enough consecutive free blocks
    phx                     ; Save current index
    phy                     ; Save requested size
    
.check_consecutive:
    inx
    lda de,x
    bne .check_consecutive_failed
    dey
    bne .check_consecutive
    
    ; Blocks found, mark as allocated
    ply                     ; Restore initial index
    plx                     ; Restore requested size
    
.blocks_found:
    ; Mark blocks as allocated
    lda #1
.mark_blocks:
    sta de,x
    inx
    dey
    bne .mark_blocks
    clc
    jmp .alloc_done
    
 .check_consecutive_failed:
    ply
    plx

.next_block:
    lda MEMORY_BLOCK_SIZE
    clc
    adc MEMORY_TMP_PTR
    sta MEMORY_TMP_PTR
    lda 0x00
    adc MEMORY_TMP_PTR+1
    sta MEMORY_TMP_PTR+1
    inx
    cpx #MEMORY_MAX_BLOCKS
    bne .find_free
    
.not_found:
    sec
    
.alloc_done:
    ply
    pla
    ldd MEMORY_TMP_PTR+1
    lde MEMORY_TMP_PTR
    rts

; Memory deallocation
; Input: DE = address of the first allocated block
;        A = number of blocks to deallocate
; Output: 
;       C = 0 if deallocation successful, 1 if failed
MEMORY_DEALLOCATE:
    pha
    phx
    phy
    tay

    sec
    tea 
    sbc MEMORY_START_PTR
    tae
    tda  
    sbc MEMORY_START_PTR+1
    tad

    ldx #0
.loop:
    cpd 0x00
    bne .increase_index
    cpe 0x00
    bne .increase_index
    jmp .deallocate

.increase_index:
    inx
    cpx #MEMORY_MAX_BLOCKS
    beq .deallocation_failed
    sec
    tea 
    sbc #MEMORY_BLOCK_SIZE
    tae
    tda
    sbc #0x00
    tad
    jmp .loop

.deallocate:
    lda #0
    ldd MEMORY_MAP_START_PTR+1
    lde MEMORY_MAP_START_PTR

.deallocate_loop:
    sta de,x
    inx
    dey
    bne .deallocate_loop
    clc
    ply
    plx
    pla
    rts 

.deallocation_failed:
    sec
    pla
    plx
    ply
    rts