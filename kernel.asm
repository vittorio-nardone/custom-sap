;
; Memory map ( TODO use #bankdef )
;
; 0x0000-0x1FFF (8k) - ROM #1
;       0x00FF-(?)  - reserved for interrupt routine
; 0x2000-0x3FFF (8k) - ROM #2
; 0x4000-0x5FFF (8k) - ROM #3
; 0x6000-0x67FF (2K) - device I/O
;       0x600? - keyboard (8 locations, lda) 
;       0x601? - xorshift random generator (lda)
;           0x6010 - low random byte
;           0x6011 - high random byte
;           0x6012 - random init (call N times for seeding)
;       0x602? - serial #1
;           0x6020 - Control/Status Registers
;           0x6021 - Transmit/Receive Data Registers

; 0x6800-0x7FFF (6K) - 6k for video 
; 0x8000-0xFFFF (32k) - RAM
;       0x8000-0x83FF (1k) - reserved for kernel operations
;           0x8200-0x82FF  - XMODEM buffer
;           0x8338-0x833F  - XMODEM variables
;
;           0x83F1         - ACIA 1 rx buffer size
;           0x83F2-0x83F3  - ACIA 1 rx buffer push/pull indexes
;           0x83F4-0x83F5  - pointer to ACIA 1 rx buffer 
;
;           0x83F6-0x83F7  - 16 bit Time counter (MSB, LSB)
;
;           0x83F8-0x83F9  - pointer to INT1 interrupt handler 
;           0x83FA-0x83FB  - pointer to INT2 interrupt handler (serial)
;           0x83FC-0x83FD  - pointer to TIMER interrupt handler
;           0x83FE-0x83FF  - pointer to KEYB interrupt handler
;       0xF000-0xFFFF (4k) - reserved for stack
;
;
; Memory expansion board (64k) - RAM
; 0x010000 - 0x01FFFF
; 
;  Interrupt register / mask register bits
;  (1) (1) (1) (1) key timer ext2 ext1
;
;  Flag register
;  N x x x Z C x x


; TODO
; - XMODEM durante ricezione dati fare check timeout (qualcosa di molto veloce, altrimenti perdiamo byte)
; - XMODEM rendere tutte le label locali + pulizia/refactoring


#include "ruledef.asm"
#include "banks.asm"
#include "tests.asm"
#include "math.asm"
#include "utils.asm"
#include "serial.asm"
#include "interrupt.asm"
#include "xmodem.asm"

#bank low_kernel
#addr 0x0000
boot:
    sei             ; disable int
    scf
    ldo 0x00
    jsr MICROCODE_test
    jsr MATH_test
    jmp main


#const MAIN_MENU_STATUS = 0x8000
#const MAIN_MENU_INPUT_BUFFER_COUNT = 0x8001
#const MAIN_MENU_RUN_MSB = 0x8002
#const MAIN_MENU_RUN_LSB = 0x8003
#const MAIN_MENU_INPUT_BUFFER = 0x8004  ; - 0x8013 (max 16 chars)

#bank kernel
main:
    scf

    ; Enable serial
    lda ACIA_INIT_115200_8N1
    jsr ACIA_INIT

    ; Configure & Enable interrupt
    lda INT_TIMER  ; set int mask
    JSR INTERRUPT_INIT
    cli

.init:
    lda 0x00
    sta MAIN_MENU_STATUS

.ready:
    jsr ACIA_SEND_NEWLINE
    lda 0x00
    sta MAIN_MENU_INPUT_BUFFER_COUNT
    lda 0x3E
    jsr ACIA_SEND_CHAR

.loop:
    ;ldo timerInterruptCounter
    ;jsr MATH_test

    lda ACIA_CONTROL_STATUS_ADDR  ; read serial 1 status
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; check if Receive Data Register is full
    beq .loop
    lda ACIA_RW_DATA_ADDR  ; read serial 1 data
    jsr ACIA_SEND_CHAR
    tao
    cmp 0x0D
    beq .cmd_entered
    ldx MAIN_MENU_INPUT_BUFFER_COUNT
    sta MAIN_MENU_INPUT_BUFFER,x
    inc MAIN_MENU_INPUT_BUFFER_COUNT
    cpx 0x0F
    beq .menu_show_error
    jmp .loop

.cmd_entered:
    ldx MAIN_MENU_INPUT_BUFFER_COUNT 
    cpx 0x00
    beq .menu_show_help
    lda MAIN_MENU_INPUT_BUFFER
    cmp "d"
    beq .menu_dump_command
    cmp "u"
    beq .menu_upload_command
    cmp "r"
    beq .menu_run_command
    cmp "h"
    beq .menu_halt_command
.menu_show_error:
    ldd .menu_error_msg[15:8]
    lde .menu_error_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .ready    

.menu_show_help:
    ldd .menu_help_msg[15:8]
    lde .menu_help_msg[7:0]
    jsr ACIA_SEND_STRING

    ldy MAIN_MENU_STATUS    
    cpy 0x01 
    beq .menu_upload_command_error
    cpy 0x02
    beq .menu_upload_command_ok
    jmp .ready    

.menu_dump_command:
    ldd 0x90
    lde 0x00

    lda MAIN_MENU_INPUT_BUFFER_COUNT
    cmp 0x01
    beq .menu_dump_command_start
    cmp 0x05
    bne .menu_show_error

    lda MAIN_MENU_INPUT_BUFFER + 1
    ldx MAIN_MENU_INPUT_BUFFER + 2
    jsr HEXBIN
    tad

    lda MAIN_MENU_INPUT_BUFFER + 3
    ldx MAIN_MENU_INPUT_BUFFER + 4
    jsr HEXBIN
    tae
 
.menu_dump_command_start:
    ldy 0x00

.menu_dump_command_dump_16byte:   
    jsr ACIA_SEND_NEWLINE

    tda
    jsr ACIA_SEND_HEX

    tea
    jsr ACIA_SEND_HEX

    lda 0x3a
    jsr ACIA_SEND_CHAR

    lda 0x20
    jsr ACIA_SEND_CHAR

    ldx 0x00

.menu_dump_command_dump_byte:    
    lda (de),x
    phx
    jsr ACIA_SEND_HEX
    plx
    lda 0x20
    jsr ACIA_SEND_CHAR  

    inx
    cpx 0x04
    beq .menu_dump_command_dump_byte_space
    cpx 0x08
    beq .menu_dump_command_dump_byte_space
    cpx 0x0C
    beq .menu_dump_command_dump_byte_space
    cpx 0x10
    beq .menu_dump_command_dump_byte_space
    jmp .menu_dump_command_dump_byte_eor_check
    
.menu_dump_command_dump_byte_space:        
    lda 0x20
    jsr ACIA_SEND_CHAR    
    
.menu_dump_command_dump_byte_eor_check:        
    cpx 0x10
    bne .menu_dump_command_dump_byte
    
    ldx 0x00

.menu_dump_command_dump_char: 

    lda (de),x
    cmp 0x1F
    bcc .menu_dump_command_dump_char_dot
    cmp 0x7E
    bcs .menu_dump_command_dump_char_dot
    jmp .menu_dump_command_dump_char_send

.menu_dump_command_dump_char_dot:
    lda 0x2E

.menu_dump_command_dump_char_send:
    jsr ACIA_SEND_CHAR 
    inx

    cpx 0x08
    bne .menu_dump_command_dump_char_eor_check

    lda 0x20
    jsr ACIA_SEND_CHAR    
    
.menu_dump_command_dump_char_eor_check:    
    cpx 0x10
    bne .menu_dump_command_dump_char

    iny
    cpy 0x10
    beq .ready
    
    tea
    clc
    adc 0x10
    tae
    bcs .menu_dump_command_dump_16byte

    ind
    jmp .menu_dump_command_dump_16byte

.menu_upload_command:
    ldd 0x90
    lde 0x00

    lda MAIN_MENU_INPUT_BUFFER_COUNT
    cmp 0x01
    beq .menu_upload_command_start
    cmp 0x05
    bne .menu_show_error

    lda MAIN_MENU_INPUT_BUFFER + 1
    ldx MAIN_MENU_INPUT_BUFFER + 2
    jsr HEXBIN
    tad

    lda MAIN_MENU_INPUT_BUFFER + 3
    ldx MAIN_MENU_INPUT_BUFFER + 4
    jsr HEXBIN
    tae

.menu_upload_command_start:
    phd
    phe
    ldd .menu_upload_command_start_msg[15:8]
    lde .menu_upload_command_start_msg[7:0]
    jsr ACIA_SEND_STRING
    ple
    pld
    sei
    jsr XMODEM
    cli
    sta MAIN_MENU_STATUS    
    jmp .ready


.menu_upload_command_error:
    ldd .menu_upload_command_error_msg[15:8]
    lde .menu_upload_command_error_msg[7:0]
    jsr ACIA_SEND_STRING
    ldy 0x00
    sty MAIN_MENU_STATUS
    jmp .ready

.menu_upload_command_ok:
    ldd .menu_upload_command_ok_msg[15:8]
    lde .menu_upload_command_ok_msg[7:0]
    jsr ACIA_SEND_STRING
    ldy 0x00
    sty MAIN_MENU_STATUS
    jmp .ready

.menu_run_command:
    ldd 0x90
    lde 0x00

    lda MAIN_MENU_INPUT_BUFFER_COUNT
    cmp 0x01
    beq .menu_run_command_start
    cmp 0x05
    bne .menu_show_error

    lda MAIN_MENU_INPUT_BUFFER + 1
    ldx MAIN_MENU_INPUT_BUFFER + 2
    jsr HEXBIN
    tad

    lda MAIN_MENU_INPUT_BUFFER + 3
    ldx MAIN_MENU_INPUT_BUFFER + 4
    jsr HEXBIN
    tae

.menu_run_command_start:
    std MAIN_MENU_RUN_MSB
    ste MAIN_MENU_RUN_LSB
    jsr (MAIN_MENU_RUN_MSB)

    ldd .menu_run_command_end_msg[15:8]
    lde .menu_run_command_end_msg[7:0]
    jsr ACIA_SEND_STRING

    jmp .ready

.menu_halt_command:
    hlt

.menu_help_msg:
    #d 0x0A, 0x0D, 0x0A, 0x0D
    #d "Project OTTO - Kernel v1.0", 0x0A, 0x0D, 0x0A, 0x0D
    #d "Valid commands (default address 0x9000):", 0x0A, 0x0D
    #d "   dxxxx  - dump memory ", 0x0A, 0x0D
    #d "   uxxxx  - upload application", 0x0A, 0x0D
    #d "   rxxxx  - run application", 0x0A, 0x0D
    #d "   h      - halt system", 0x0A, 0x0D
    #d 0x00

.menu_error_msg:
    #d 0x0A, 0x0D
    #d "?syntax error", 0x0A, 0x0D 
    #d 0x00

.menu_run_command_end_msg:
    #d 0x0A, 0x0D
    #d "INFO: Execution ended.", 0x0A, 0x0D 
    #d 0x00

.menu_upload_command_error_msg:
    #d 0x0A, 0x0D
    #d "INFO: Upload Failed!", 0x0A, 0x0D 
    #d 0x00

.menu_upload_command_ok_msg:
    #d 0x0A, 0x0D
    #d "INFO: Upload Successful!", 0x0A, 0x0D 
    #d 0x00

.menu_upload_command_start_msg:
    #d 0x0A, 0x0D
    #d "INFO: Begin XMODEM/CRC transfer.  Press <Esc> to abort..."
    #d 0x0A, 0x0D
    #d 0x00