#once
#bank kernel

#include "utils.asm"

; **********************************************************
; CONSTANTS
;
; **********************************************************

#const ACIA_CONTROL_STATUS_ADDR = 0x6020
#const ACIA_RW_DATA_ADDR = ACIA_CONTROL_STATUS_ADDR + 1
#const ACIA_INIT_MASTER_RESET = 0x03    ; master reset
#const ACIA_INIT_115200_8N1 = 0x15      ; base init value
#const ACIA_INIT_28800_8N1 = 0x16       ; base init value
#const ACIA_INIT_ENABLE_RX_INT = 0x80   ; add this to enable RX interrupt
#const ACIA_INIT_ENABLE_TX_INT = 0x20   ; add this to enable TX interrupt

#const ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL = 0x01
#const ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY = 0x02
#const ACIA_STATUS_REG_RECEIVER_OVERRUN = 0x20

; RAM variables defined in memmap.asm

; **********************************************************
; SUBROUTINE: ACIA_INIT
;
; DESCRIPTION:
;
; INPUTS:
;
; OUTPUTS:
;
; DESTROY:
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 06/10/2024
; **********************************************************
 
ACIA_INIT:
    pha
    lda ACIA_INIT_MASTER_RESET
    sta ACIA_CONTROL_STATUS_ADDR
    lda 0x00
    sta ACIA_1_RX_BUFFER_PULL_INDEX
    sta ACIA_1_RX_BUFFER_PUSH_INDEX
    lda 0xFF
    sta ACIA_1_RX_BUFFER_AVAILABLE
    pla
    sta ACIA_CONTROL_STATUS_ADDR
    rts

; **********************************************************
; SUBROUTINE: ACIA_SEND_STRING
;
; DESCRIPTION:
;
; INPUTS:
;
; OUTPUTS:
;
; DESTROY:
;   X A
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 06/10/2024
; **********************************************************

ACIA_SEND_STRING:
    ldx 0x00                ; set message offset to 0
.send_char:
    lda de,x              ; load next char
    beq .send_end           ; if char is 0, we've finished
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    inx
    bne .send_char
    ind
    jmp .send_char
.send_end:
    rts

; **********************************************************
; SUBROUTINE: ACIA_SEND_STRING_NO_WAIT
;
; DESCRIPTION:
;
; INPUTS:
;   D E
;   X
;
; OUTPUTS:
;   X
;
; DESTROY:
;   A
;
; FLAGS AFFECTED:
;   C if send finished
;
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 06/10/2024
; **********************************************************

ACIA_SEND_STRING_NO_WAIT:
    lda ACIA_CONTROL_STATUS_ADDR      
    bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
    beq .send_busy
    lda de,x              ; load next char
    beq .send_end           ; if char is 0, we've finished
    sta ACIA_RW_DATA_ADDR
    inx
    jmp ACIA_SEND_STRING_NO_WAIT
.send_busy:
    clc
    rts   
.send_end:
    sec
    rts    

; **********************************************************
; SUBROUTINE: ACIA_WAIT_SEND_CLEAR
;
; DESCRIPTION:
;
; INPUTS:
;
; OUTPUTS:
;
; DESTROY:
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 06/10/2024
; **********************************************************

ACIA_WAIT_SEND_CLEAR:
  pha                   
.send_clr_loop:
  lda ACIA_CONTROL_STATUS_ADDR      
  bit ACIA_STATUS_REG_TRANSMIT_DATA_REGISTER_EMPTY
  beq .send_clr_loop
  pla  
  rts    

; **********************************************************
; SUBROUTINE: ACIA_SEND_CHAR
;
; DESCRIPTION:
;
; INPUTS:
;   A
;
; OUTPUTS:
;
; DESTROY:
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 20/10/2024
; **********************************************************

ACIA_SEND_CHAR:
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    rts

; **********************************************************
; SUBROUTINE: ACIA_SEND_HEX
;
; DESCRIPTION:
;
; INPUTS:
;   A
;
; OUTPUTS:
;
; DESTROY:
;   A X
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 20/10/2024
; **********************************************************

ACIA_SEND_HEX:
    jsr BINHEX
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    txa
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    rts    

; **********************************************************
; SUBROUTINE: ACIA_SEND_DECIMAL
;
; DESCRIPTION:
;
; INPUTS:
;   A
;
; OUTPUTS:
;
; DESTROY:
;   A X Y
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 21/11/2024
; **********************************************************

ACIA_SEND_DECIMAL:
    jsr BINDEC
    jsr ACIA_WAIT_SEND_CLEAR
    stx ACIA_RW_DATA_ADDR
    jsr ACIA_WAIT_SEND_CLEAR
    sty ACIA_RW_DATA_ADDR
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    rts    

; **********************************************************
; SUBROUTINE: ACIA_SEND_NEWLINE
;
; DESCRIPTION:
;
; INPUTS:
;
; OUTPUTS:
;
; DESTROY:
;   A
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 20/10/2024
; **********************************************************

ACIA_SEND_NEWLINE:
    lda 0x0A
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    lda 0x0D
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    rts    

; **********************************************************
; SUBROUTINE: ACIA_READ_CHAR
;
; DESCRIPTION:
;
; INPUTS:
;
; OUTPUTS:
;
; DESTROY:
;   
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 21/11/2024
; **********************************************************

ACIA_READ_CHAR:
    lda ACIA_CONTROL_STATUS_ADDR  ; read serial 1 status
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; check if Receive Data Register is full
    beq ACIA_READ_CHAR
    lda ACIA_RW_DATA_ADDR  ; read serial 1 data
    rts

; **********************************************************
; SUBROUTINE: ACIA_READ_TO_BUFFER
;
; DESCRIPTION:
;
; INPUTS:
;
; OUTPUTS:
;
; DESTROY:
;   A D E X
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 06/10/2024
; **********************************************************

ACIA_READ_TO_BUFFER:
    ldd ACIA_1_RX_BUFFER_POINTER
    lde ACIA_1_RX_BUFFER_POINTER + 1
.acia_read_to_buffer_check_status:
    lda ACIA_1_RX_BUFFER_AVAILABLE                 ; check if buffer is full
    beq .acia_read_to_buffer_end

    lda ACIA_CONTROL_STATUS_ADDR                   ; read serial 1 status
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; check if Receive Data Register is full
    beq .acia_read_to_buffer_end
    
    lda ACIA_RW_DATA_ADDR                          ; read serial 1 data
    ; sta ACIA_RW_DATA_ADDR                        ; write back serial 1 data
    
    ldx ACIA_1_RX_BUFFER_PUSH_INDEX                ; load index for storing data
    inc ACIA_1_RX_BUFFER_PUSH_INDEX                ; inc index
    dec ACIA_1_RX_BUFFER_AVAILABLE                 ; dec buffer availability
    sta de,x                                     ; store data
    jmp .acia_read_to_buffer_check_status
.acia_read_to_buffer_end:
    rts

; **********************************************************
; SUBROUTINE: ACIA_PULL_FROM_BUFFER
;
; DESCRIPTION:
;
; INPUTS:
;
; OUTPUTS:
;   A
;
; DESTROY:
;   A D E X
;
; FLAGS AFFECTED:
;   C if char is readed
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 06/10/2024
; **********************************************************

ACIA_PULL_FROM_BUFFER:
    ldd ACIA_1_RX_BUFFER_POINTER
    lde ACIA_1_RX_BUFFER_POINTER + 1
.acia_pull_from_buffer_check_status:
    lda ACIA_1_RX_BUFFER_AVAILABLE                 ; check if buffer is empty
    cmp 0xFF
    beq .acia_read_to_buffer_nochar
   
    ldx ACIA_1_RX_BUFFER_PULL_INDEX                ; load index for storing data
    inc ACIA_1_RX_BUFFER_PULL_INDEX                ; inc index
    inc ACIA_1_RX_BUFFER_AVAILABLE                 ; inc buffer availability
    lda de,x                                     ; load data
    sec
    rts
.acia_read_to_buffer_nochar:
    clc
    rts    


; **********************************************************
; SUBROUTINE: ACIA_SEND_DECIMAL32
;
; DESCRIPTION:
;
; INPUTS:
;   BINDEC32_VALUE: 32 bit value to convert LSB -> MSB
;
; OUTPUTS:
;
; DESTROY:
;   A X Y
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 29/01/2025
; **********************************************************
ACIA_SEND_DECIMAL32:
        jsr BINDEC32
        ldx 0x09
.l1:
        lda BINDEC32_RESULT,x
        bne .l2
        dex             ; skip leading zeros
        bne .l1

.l2:
        lda BINDEC32_RESULT,x
        ora 0x30
        tao
        jsr ACIA_SEND_CHAR
        dex
        bpl .l2
        rts

; **********************************************************
; SUBROUTINE: ACIA_SEND_DECIMAL16S
;
; DESCRIPTION:
;   Print a signed 16-bit integer as a decimal string.
;   Negative values are printed with a leading '-'.
;   Uses BINDEC32 / ACIA_SEND_DECIMAL32 internally.
;
; INPUTS:
;   MATH16_A : 16-bit signed value (little-endian)
;
; OUTPUTS:
;   (none — output sent to ACIA)
;
; DESTROY:
;   A X Y
;
; AUTHOR: VN
; LAST UPDATE: 03/24/2026
; **********************************************************

ACIA_SEND_DECIMAL16S:
        lda MATH16_A+1
        bpl .positive

        ; Print '-' sign
        lda 0x2D
        jsr ACIA_SEND_CHAR

        ; Negate to get absolute value
        jsr MATH16_NEGATE_A

.positive:
        ; Zero-extend 16-bit to 32-bit into BINDEC32_VALUE
        lda MATH16_A
        sta BINDEC32_VALUE
        lda MATH16_A+1
        sta BINDEC32_VALUE+1
        lda 0x00
        sta BINDEC32_VALUE+2
        sta BINDEC32_VALUE+3

        jsr ACIA_SEND_DECIMAL32
        rts