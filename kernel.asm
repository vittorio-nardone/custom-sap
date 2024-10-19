;
; Memory map ( TODO use #bankdef )
;
; 0x0000-0x5FFF (24k) - ROM
;       0x00FF-(?)  - reserved for interrupt routine
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
;           0x83F1         - ACIA 1 rx buffer size
;           0x83F2-0x83F3  - ACIA 1 rx buffer push/pull indexes
;           0x83F4-0x83F5  - pointer to ACIA 1 rx buffer 
;           0x83F6-0x83F7  - 16 bit Time counter (MSB, LSB)
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

#include "ruledef.asm"
#include "banks.asm"
#include "tests.asm"
#include "math.asm"
#include "serial.asm"
#include "interrupt.asm"

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
#const MAIN_MENU_INPUT_BUFFER = 0x8001
 
#bank kernel
main:
    scs

    ; Enable serial
    lda ACIA_INIT_115200_8N1
    jsr SERIAL_INIT

    ; Configure & Enable interrupt
    lda INT_TIMER  ; set int mask
    JSR INTERRUPT_INIT
    cli

.init:
    lda 0x00
    sta MAIN_MENU_STATUS
    ldd MAIN_MENU_INPUT_BUFFER[15:8]
    lde MAIN_MENU_INPUT_BUFFER[7:0]
    ldx 0x00

.ready:
    lda 0x3E
    sta ACIA_RW_DATA_ADDR  ; write prompt TODO check status before

.loop:
    ;ldo timerInterruptCounter
    ;jsr MATH_test

    lda ACIA_CONTROL_STATUS_ADDR  ; read serial 1 status
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; check if Receive Data Register is full
    beq .loop
    lda ACIA_RW_DATA_ADDR  ; read serial 1 data
    sta ACIA_RW_DATA_ADDR  ; write back serial 1 data TODO check status before
    tao
    cmp 0x0D
    beq .cmd_entered
    sta (de),x
    inx
    jmp .loop

.cmd_entered:
    cpx 0x00
    beq .menu_show_help

    txa
    tay
    ldx 0x00
    lda (de),x
    cmp "d"
    beq .menu_dump_command
    cmp "l"
    beq .menu_load_command
    cmp "r"
    beq .menu_run_command
    cmp "h"
    beq .menu_halt_command
.menu_show_error:
    phd
    phe
    ldd .menu_error_msg[15:8]
    lde .menu_error_msg[7:0]
    jsr ACIA_SEND_STRING
    ple
    pld
    ldx 0x00
    jmp .ready    

.menu_show_help:
    phd
    phe
    ldd .menu_help_msg[15:8]
    lde .menu_help_msg[7:0]
    jsr ACIA_SEND_STRING
    ple
    pld
    ldx 0x00
    jmp .ready    

.menu_dump_command:
    ; todo
    jmp .ready

.menu_load_command:
    ; todo
    jmp .ready

.menu_run_command:
    ; todo
    jmp .ready

.menu_halt_command:
    hlt

.menu_help_msg:
  ; #d 0x0A, 0x0D, "Greetings Professor Falken, shall we play a game?", 0x0A, 0x0D, 0x00
  #d 0x0A, 0x0D
  #d "Project OTTO - Kernel v1.0", 0x0A, 0x0D
  #d "Available commands:", 0x0A, 0x0D
  #d "   d - dump memory", 0x0A, 0x0D
  #d "   l - load application", 0x0A, 0x0D
  #d "   r - run application", 0x0A, 0x0D
  #d "   h - halt system", 0x0A, 0x0D
  #d 0x00

.menu_error_msg:
  #d 0x0A, 0x0D
  #d "?syntax error", 0x0A, 0x0D 
  #d 0x00
