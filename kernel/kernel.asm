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

;           0x8100-0x810F  - MEMORY management variables  
;           0x8120-0x812F  - VT100 variables          

;           0x8200-0x82FF  - XMODEM buffer
;           0x8337-0x833F  - XMODEM variables
;
;           0x8340-0x834D  - UTILS variables
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
;       0x8400-0xEFFF (27k) - ram for apps (108 pages of 256 bytes) 
;       0xF000-0xFFFF (4k) - reserved for stack
;
; Memory expansion board (64k) - RAM
; 0x010000 - 0x01FFFF
; 
;  Interrupt register / mask register bits
;  (1) (1) (1) (1) key timer ext2 ext1
;
;  Flag register
;  N x x x Z C x x
;
;  Overflow flag != 6502 implementation. It's used internally for indexing and value is equal to carry
;
;

#include "../assembly/ruledef.asm"
#include "banks.asm"
#include "tests.asm"
#include "math.asm"
; #include "float.asm" - Work in progress
#include "memory.asm"
#include "utils.asm"
#include "serial.asm"
#include "interrupt.asm"
#include "xmodem.asm"
#include "vt100.asm"
#include "istructions.asm"

#bank low_kernel
#addr 0x0000
boot:
    sei             ; disable interrupts
    scf
    ldo 0x00
    jsr MICROCODE_test
    jsr MATH_test
    jmp main


#const MAIN_MENU_STATUS = 0x8000
#const MAIN_MENU_INPUT_BUFFER_COUNT = 0x8001
#const MAIN_MENU_ADDR_PAGE = 0x8002
#const MAIN_MENU_ADDR_MSB = 0x8003
#const MAIN_MENU_ADDR_LSB = 0x8004
#const MAIN_MENU_DUMP_COUNT = 0x8005
#const MAIN_MENU_OPCODE_MSB = 0x8006
#const MAIN_MENU_OPCODE_LSB = 0x8007
#const MAIN_MENU_OPCODE_LENGTH = 0x8008
#const MAIN_MENU_OPCODE_LENGTH_2 = 0x8009
#const MAIN_MENU_OPCODE_PTR = 0x800A
#const MAIN_MENU_INPUT_BUFFER = 0x800B  ; - 0x801A (max 16 chars)

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
    beq .menu_help_command
    cmp "a"
    beq .menu_disassembler_command
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

.menu_help_command:
    ldd .menu_help_msg[15:8]
    lde .menu_help_msg[7:0]
    jsr ACIA_SEND_STRING
    ldd .menu_adv_help_msg[15:8]
    lde .menu_adv_help_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp .ready

; --------------------------------------

.menu_read_address:
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    cmp 0x01
    beq .menu_read_address_default
    cmp 0x05
    beq .menu_read_address_len5
    cmp 0x07
    beq .menu_read_address_len7
    sec
    rts

.menu_read_address_len7:
    lda MAIN_MENU_INPUT_BUFFER + 1
    ldx MAIN_MENU_INPUT_BUFFER + 2
    jsr HEXBIN
    tay

    lda MAIN_MENU_INPUT_BUFFER + 3
    ldx MAIN_MENU_INPUT_BUFFER + 4
    jsr HEXBIN
    tad

    lda MAIN_MENU_INPUT_BUFFER + 5
    ldx MAIN_MENU_INPUT_BUFFER + 6
    jsr HEXBIN
    tae
    clc
    rts

.menu_read_address_len5:
    ldy 0x00
    
    lda MAIN_MENU_INPUT_BUFFER + 1
    ldx MAIN_MENU_INPUT_BUFFER + 2
    jsr HEXBIN
    tad

    lda MAIN_MENU_INPUT_BUFFER + 3
    ldx MAIN_MENU_INPUT_BUFFER + 4
    jsr HEXBIN
    tae
    clc
    rts

.menu_read_address_default:  
    ldy 0x00
    ldd 0x84
    lde 0x00
    clc
    rts

.menu_store_address:
    sty MAIN_MENU_ADDR_PAGE
    std MAIN_MENU_ADDR_MSB
    ste MAIN_MENU_ADDR_LSB
    rts

.menu_load_address:
    ldy MAIN_MENU_ADDR_PAGE
    ldd MAIN_MENU_ADDR_MSB
    lde MAIN_MENU_ADDR_LSB
    rts

.menu_inc_address:
    inc MAIN_MENU_ADDR_LSB
    bne .menu_inc_address_end
    inc MAIN_MENU_ADDR_MSB
    bne .menu_inc_address_end
    inc MAIN_MENU_ADDR_PAGE
.menu_inc_address_end:
    rts

; --------------------------------------

.menu_dump_command:
    jsr .menu_read_address
    bcs .menu_show_error

.menu_dump_command_start:
    lda 0x00
    sta MAIN_MENU_DUMP_COUNT

.menu_dump_command_dump_16byte:   
    jsr ACIA_SEND_NEWLINE

    tya
    jsr ACIA_SEND_HEX

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
    lda yde,x
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

    lda yde,x
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

    inc MAIN_MENU_DUMP_COUNT
    lda MAIN_MENU_DUMP_COUNT
    cmp 0x10
    beq .ready
    
    tea
    clc
    adc 0x10
    tae
    bcc .menu_dump_command_dump_16byte

    ind
    bne .menu_dump_command_dump_16byte

    iny
    jmp .menu_dump_command_dump_16byte

.menu_upload_command:
    jsr .menu_read_address
    bcs .menu_show_error

.menu_upload_command_start:
    phd
    phe
    ldd .menu_upload_command_start_msg[15:8]
    lde .menu_upload_command_start_msg[7:0]
    jsr ACIA_SEND_STRING
    ple
    pld
    sei
    jsr XMODEM_RCV
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
    jsr .menu_read_address
    bcs .menu_show_error
    jsr .menu_store_address

.menu_run_command_start:    
    ;jsr (MAIN_MENU_ADDR_PAGE)
    #d 0x93, 0x00, MAIN_MENU_ADDR_PAGE[15:8],  MAIN_MENU_ADDR_PAGE[7:0]

    ldd .menu_run_command_end_msg[15:8]
    lde .menu_run_command_end_msg[7:0]
    jsr ACIA_SEND_STRING

    jmp .ready

.menu_disassembler_command:
    jsr .menu_read_address
    bcs .menu_show_error
    jsr .menu_store_address
    lda 0x00
    sta MAIN_MENU_DUMP_COUNT

; print address
.menu_disassembler_command_dump_address:   
    jsr .menu_load_address
    jsr ACIA_SEND_NEWLINE

    tya
    jsr ACIA_SEND_HEX

    tda
    jsr ACIA_SEND_HEX

    tea
    jsr ACIA_SEND_HEX

    lda 0x3a
    jsr ACIA_SEND_CHAR

    lda 0x20
    jsr ACIA_SEND_CHAR

.menu_disassembler_command_get_opcode:  
    ldx 0x00
    lda yde,x         ; get code
    pha
    
    jsr ACIA_SEND_HEX   ; print it
    lda 0x20
    jsr ACIA_SEND_CHAR

    jsr .menu_inc_address

    ; get pointer to opcode description
    plx
    lda ISTRUCTIONS.OPCODE_MSB, x
    tad
    lda ISTRUCTIONS.OPCODE_LSB, x
    tae

    std MAIN_MENU_OPCODE_MSB
    ste MAIN_MENU_OPCODE_LSB

    ; get value length
    ldx 0x00
    lda de,x 
    sta MAIN_MENU_OPCODE_LENGTH
    inx
    lda de,x 
    sta MAIN_MENU_OPCODE_LENGTH_2

    ; Restore pointer
    jsr .menu_load_address
    ldx 0x00
 
 .menu_disassembler_command_dump_value:
    cpx MAIN_MENU_OPCODE_LENGTH
    beq .menu_disassembler_command_dump_value_end

    lda yde,x         ; get code
    phx
    jsr ACIA_SEND_HEX   ; print it
    lda 0x20
    jsr ACIA_SEND_CHAR
    plx
    inx
    jmp .menu_disassembler_command_dump_value

.menu_disassembler_command_dump_value_end:
    ldx 0x03
.menu_disassembler_command_dump_value_end_loop:
    cpx MAIN_MENU_OPCODE_LENGTH
    beq .menu_disassembler_command_print_prefix
    lda 0x20
    jsr ACIA_SEND_CHAR
    jsr ACIA_SEND_CHAR
    jsr ACIA_SEND_CHAR
    dex
    jmp .menu_disassembler_command_dump_value_end_loop    

.menu_disassembler_command_print_prefix:
    ldd MAIN_MENU_OPCODE_MSB
    lde MAIN_MENU_OPCODE_LSB  
    ldx 0x02

.menu_disassembler_command_print_prefix_get_char:
    lda de,x          ; get char
    beq .menu_disassembler_command_print_prefix_end
    jsr ACIA_SEND_CHAR
    inx
    jmp .menu_disassembler_command_print_prefix_get_char

.menu_disassembler_command_print_prefix_end:
    inx
    stx MAIN_MENU_OPCODE_PTR

.menu_disassembler_command_print_value: 
    lda MAIN_MENU_OPCODE_LENGTH_2
    beq .menu_disassembler_command_print_suffix
    
    ; Restore pointer
    jsr .menu_load_address
    ldx 0x00
    
    lda 0x20
    jsr ACIA_SEND_CHAR
    lda "0"
    jsr ACIA_SEND_CHAR
    lda "x"
    jsr ACIA_SEND_CHAR

 .menu_disassembler_command_print_value_loop:
    cpx MAIN_MENU_OPCODE_LENGTH_2
    beq .menu_disassembler_command_print_value_end

    lda yde,x         ; get code
    phx
    jsr ACIA_SEND_HEX   ; print it
    plx
    inx
    jmp .menu_disassembler_command_print_value_loop   

.menu_disassembler_command_print_value_end:
    lda 0x20
    jsr ACIA_SEND_CHAR 

.menu_disassembler_command_print_suffix:
    ldd MAIN_MENU_OPCODE_MSB
    lde MAIN_MENU_OPCODE_LSB  
    ldx MAIN_MENU_OPCODE_PTR

.menu_disassembler_command_print_suffix_get_char:
    lda de,x          ; get char
    beq .menu_disassembler_command_print_suffix_end
    jsr ACIA_SEND_CHAR
    inx
    jmp .menu_disassembler_command_print_suffix_get_char    

.menu_disassembler_command_print_suffix_end:
    lda MAIN_MENU_OPCODE_LENGTH
    beq .menu_disassembler_command_next
    jsr .menu_inc_address
    dec MAIN_MENU_OPCODE_LENGTH
    jmp .menu_disassembler_command_print_suffix_end

.menu_disassembler_command_next:
    inc MAIN_MENU_DUMP_COUNT
    lda MAIN_MENU_DUMP_COUNT
    cmp 0x0a
    beq .ready
    jmp .menu_disassembler_command_dump_address

.menu_help_msg:
    #d 0x0A, 0x0D, 0x0A, 0x0D
    #d "Project OTTO - Kernel v1.2.5", 0x0A, 0x0D, 0x0A, 0x0D
    #d "Valid commands (default address 0x8400):", 0x0A, 0x0D
    #d "   ayyxxxx  - disAssemble memory ", 0x0A, 0x0D
    #d "   dyyxxxx  - Dump memory ", 0x0A, 0x0D
    #d "   uyyxxxx  - Upload application", 0x0A, 0x0D
    #d "   ryyxxxx  - Run application", 0x0A, 0x0D
    #d "   h        - Show help", 0x0A, 0x0D
    #d 0x00

.menu_adv_help_msg:    
    #d 0x0A, 0x0D
    #d "Examples:", 0x0A, 0x0D
    #d "   d        - dump the contents of memory at the default address", 0x0A, 0x0D
    #d "   d8000    - dump the contents of memory starting from location 0x8000", 0x0A, 0x0D
    #d "   u010000  - upload an application and store it at location 0x010000", 0x0A, 0x0D
    #d "   r010000  - run the application at location 0x020000", 0x0A, 0x0D
    #d 0x0A, 0x0D  
    #d "Memory map:", 0x0A, 0x0D     
    #d "   0x0000-0x5FFF      - ROM", 0x0A, 0x0D
    #d "   0x6000-0x83FF      - reserved", 0x0A, 0x0D
    #d "   0x8400-0xEFFF      - free RAM (27KB)", 0x0A, 0x0D
    #d "   0xF000-0xFFFF      - reserved", 0x0A, 0x0D
    #d "   0x010000-0x01FFFF  - free RAM (64KB) - expansion #1", 0x0A, 0x0D
    #d "   0x020000-0x02FFFF  - free RAM (64KB) - expansion #2", 0x0A, 0x0D
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