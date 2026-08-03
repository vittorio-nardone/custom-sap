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
;   A X D E   (DE advanced to the terminating NUL)
;
; FLAGS AFFECTED:
;
; USAGE:
;
; EXAMPLE:
;
; AUTHOR: VN
; LAST UPDATE: 03/08/2026
; **********************************************************

; Walk DE with INE/IND and always read at offset X=0. Do not scan with a
; growing X index: LDA DE,X / LDA YDE,X do not support page-cross when E+X
; overflows (see microcode "Cross page not supported"). Long mid-page
; strings (common for apps in expansion RAM) would otherwise read the wrong
; page, hit a spurious NUL, and truncate early.

ACIA_SEND_STRING:
    sei                     ; keep Y/D/E stable across timer/serial IRQs
    ldx 0x00
.send_char:
    lda de,x
    beq .send_end
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    ine
    bne .send_char
    ind
    jmp .send_char
.send_end:
    cli
    rts

; **********************************************************
; SUBROUTINE: ACIA_SEND_STRING24
;
; DESCRIPTION: Null-terminated string via serial; 24-bit pointer (Y=page, D:E=low 16).
;   Use for apps linked above 0xFFFF (e.g. expansion RAM). ACIA_SEND_STRING is DE-only.
;
; INPUTS:
;   Y D E  pointer to string
;
; OUTPUTS:
;
; DESTROY:
;   A X D E   (DE advanced to the terminating NUL; Y preserved)
;
; **********************************************************

ACIA_SEND_STRING24:
    sei
    ldx 0x00
.send_char24:
    lda yde,x
    beq .send_end24
    jsr ACIA_WAIT_SEND_CLEAR
    sta ACIA_RW_DATA_ADDR
    ine
    bne .send_char24
    ind
    jmp .send_char24
.send_end24:
    cli
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
; SUBROUTINE: ACIA_FLUSH_RX
;
; Discard all pending UART RX bytes (hardware + irq buffer).
; **********************************************************

ACIA_FLUSH_RX:
    lda 0xFD
    sta 0x6012
    lda 0x00
    sta ACIA_1_RX_BUFFER_PULL_INDEX
    sta ACIA_1_RX_BUFFER_PUSH_INDEX
    lda 0xFF
    sta ACIA_1_RX_BUFFER_AVAILABLE
.acia_flush_hw:
    lda ACIA_CONTROL_STATUS_ADDR
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL
    beq .acia_flush_done
    lda ACIA_RW_DATA_ADDR
    jmp .acia_flush_hw
.acia_flush_done:
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
    ; BINDEC: X/Y are hundreds/tens ASCII only when used; otherwise 0.
    ; Always send A (ones). Do not emit NUL for skipped places.
    jsr BINDEC
    cpx 0x00
    beq .asd_no_hundreds
    jsr ACIA_WAIT_SEND_CLEAR
    stx ACIA_RW_DATA_ADDR
.asd_no_hundreds:
    cpy 0x00
    beq .asd_no_tens
    jsr ACIA_WAIT_SEND_CLEAR
    sty ACIA_RW_DATA_ADDR
.asd_no_tens:
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
; SUBROUTINE: ACIA_READ_ESCAPE_KEY
;
; DESCRIPTION:
;   Parse an ANSI/VT escape sequence already started with ESC (0x1B).
;   Consumes all sequence bytes without echo.
;
; INPUTS:
;   (ESC byte already read by caller)
;
; OUTPUTS:
;   A = final key byte (e.g. 'C' right, 'D' left) or 0 if not recognized
;
; DESTROY:
;   A
;
; FLAGS AFFECTED:
;
; USAGE:
;   Kernel menu uses arrow keys; other sequences are discarded.
;
; AUTHOR: VN
; LAST UPDATE: 04/08/2026
; **********************************************************

ACIA_READ_ESCAPE_KEY:
    jsr ACIA_READ_CHAR
    cmp "["
    beq .csi
    cmp "O"
    beq .ss3
    lda 0x00
    rts

.ss3:
    jsr ACIA_READ_CHAR
    rts

.csi:
    jsr ACIA_READ_CHAR
.csi_loop:
    cmp 0x40
    bcc .csi_more
    cmp 0x7F
    bcs .csi_more
    rts

.csi_more:
    jsr ACIA_READ_CHAR
    jmp .csi_loop

; Alias: discard escape sequence without using the key
ACIA_CONSUME_ESCAPE:
    jsr ACIA_READ_ESCAPE_KEY
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

; **********************************************************
; SUBROUTINE: ACIA_READ_DECIMAL16S
;
; DESCRIPTION:
;   Read a signed 16-bit decimal integer from serial.
;   Characters are echoed back. Input terminates on CR (0x0D).
;   Leading whitespace is ignored. Optional leading '-'.
;
; INPUTS:
;   (none — reads from serial)
;
; OUTPUTS:
;   MATH16_A : 16-bit signed result (little-endian)
;
; DESTROY:
;   A D E X Y
;
; AUTHOR: VN
; LAST UPDATE: 03/24/2026
; **********************************************************

ACIA_READ_DECIMAL16S:
        lda 0x00
        sta MATH16_A
        sta MATH16_A+1
        sta ACIA_RDEC_SIGN
        sta ACIA_RDEC_COUNT

.rdec_loop:
        jsr ACIA_READ_CHAR
        cmp 0x0D
        beq .rdec_done
        cmp 0x0A
        beq .rdec_done
        cmp 0x7F
        beq .rdec_bs
        cmp 0x08
        beq .rdec_bs

        jsr ACIA_SEND_CHAR

        cmp 0x2D
        bne .rdec_not_minus
        lda 0x01
        sta ACIA_RDEC_SIGN
        jmp .rdec_loop
.rdec_not_minus:
        cmp 0x30
        bcc .rdec_loop
        cmp 0x3A
        bcs .rdec_loop

        sec
        sbc 0x30
        pha

        lda 0x0A
        sta MATH16_B
        lda 0x00
        sta MATH16_B+1
        jsr MUL16S

        pla
        clc
        adc MATH16_A
        sta MATH16_A
        lda 0x00
        adc MATH16_A+1
        sta MATH16_A+1

        inc ACIA_RDEC_COUNT
        jmp .rdec_loop

.rdec_bs:
        lda ACIA_RDEC_COUNT
        bne .rdec_bs_digit
        lda ACIA_RDEC_SIGN
        beq .rdec_loop
        lda 0x00
        sta ACIA_RDEC_SIGN
        jsr VT100_CURSOR_LEFT
        jsr VT100_CLEAR_LINE_END
        jmp .rdec_loop
.rdec_bs_digit:
        lda 0x0A
        sta MATH16_B
        lda 0x00
        sta MATH16_B+1
        jsr DIV16S
        dec ACIA_RDEC_COUNT
        jsr VT100_CURSOR_LEFT
        jsr VT100_CLEAR_LINE_END
        jmp .rdec_loop

.rdec_done:
        lda ACIA_RDEC_SIGN
        beq .rdec_positive
        jsr MATH16_NEGATE_A
.rdec_positive:
        rts