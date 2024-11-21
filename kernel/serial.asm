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

#const ACIA_1_RX_BUFFER_AVAILABLE   = 0x83F1
#const ACIA_1_RX_BUFFER_PULL_INDEX  = 0x83F2 
#const ACIA_1_RX_BUFFER_PUSH_INDEX  = 0x83F3 
#const ACIA_1_RX_BUFFER_POINTER  = 0x83F4 ; -0x83F5  - pointer to ACIA 1 RX buffer base address

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
    lda (de),x              ; load next char
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
    lda (de),x              ; load next char
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
    sta (de),x                                     ; store data
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
    lda (de),x                                     ; load data
    sec
    rts
.acia_read_to_buffer_nochar:
    clc
    rts    