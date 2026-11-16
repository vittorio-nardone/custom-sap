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

#const KERNEL_VERSION = "v1.4.55"
#const KERNEL_BUILDDATE = "11/16/2026"

#include "../assembly/ruledef.asm"
#include "banks.asm"
#include "build_config.asm"
#include "memmap.asm"
#include "tests.asm"
#include "math.asm"
#include "float.asm"
#include "utils.asm"
#include "serial.asm"
#include "interrupt.asm"
#include "random.asm"
#include "xmodem.asm"
#include "storage/const.asm"
#include "storage/io.asm"
#include "storage/burst.asm"
#include "storage/proto.asm"
#include "storage/range.asm"
#include "storage/ot.asm"
#include "storage/api.asm"
#include "storage/menu.asm"
#include "shell.asm"
#include "vt100.asm"
#include "../pascal/pmachine.asm"

#bank low_kernel
#addr 0x0000
boot:
    sei             ; disable interrupts
    scf
    ldo 0x00
#if BUILD_DEBUG != 0 {
    jsr MICROCODE_test
    jsr MATH_test
    jsr FLOAT_test
}
    jmp main



; RAM variables are defined in memmap.asm

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

    ; Seed random number generator
    jsr RANDOM_SEED

.init:
    lda 0x00
    sta CH376_STATUS
    sta MAIN_MENU_STATUS
    sta MAIN_MENU_ADDR_PAGE
    lda 0x84
    sta MAIN_MENU_ADDR_MSB
    lda 0x00
    sta MAIN_MENU_ADDR_LSB
    jsr SHELL_INIT

menu_ready:
    lda 0x00
    sta MAIN_MENU_INPUT_BUFFER_COUNT
    sta MAIN_MENU_INPUT_CURSOR
    sta SHELL_HIST_PAINTED            ; nothing echoed after fresh prompt
    lda 0xFF
    sta SHELL_HIST_POS            ; live edit (not browsing history)
    jsr SHELL_PROMPT

.loop:
    lda ACIA_CONTROL_STATUS_ADDR  ; read serial 1 status
    bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL ; check if Receive Data Register is full
    beq .loop
    lda ACIA_RW_DATA_ADDR  ; read serial 1 data
    tao
    cmp 0x0D
    beq .cmd_entered
    cmp 0x7F
    beq .backspace
    cmp 0x08
    beq .backspace
    cmp 0x1B
    beq .escape
    cmp 0x09
    beq .tab
    ; Editing breaks history browse (line becomes live draft)
    pha
    lda 0xFF
    sta SHELL_HIST_POS
    pla
    jsr ACIA_SEND_CHAR
    ldx MAIN_MENU_INPUT_CURSOR
    sta MAIN_MENU_INPUT_BUFFER,x
    inx
    stx MAIN_MENU_INPUT_CURSOR
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcc .insert_skip_count
    stx MAIN_MENU_INPUT_BUFFER_COUNT
.insert_skip_count:
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    sta SHELL_HIST_PAINTED
    cpx SHELL_INPUT_MAX
    bcs .menu_show_error
    jmp .loop

.tab:
    lda 0xFF
    sta SHELL_HIST_POS
    jsr SHELL_TAB_COMPLETE
    jmp .loop

.escape:
    jsr ACIA_READ_ESCAPE_KEY
    cmp "A"
    beq .hist_up
    cmp "B"
    beq .hist_down
    cmp "D"
    beq .cursor_left
    cmp "C"
    beq .cursor_right
    jmp .loop

.hist_up:
    jsr SHELL_HIST_UP
    jmp .loop

.hist_down:
    jsr SHELL_HIST_DOWN
    jmp .loop

.cursor_left:
    lda MAIN_MENU_INPUT_CURSOR
    beq .loop
    dec MAIN_MENU_INPUT_CURSOR
    jsr VT100_CURSOR_LEFT
    jmp .loop

.cursor_right:
    lda MAIN_MENU_INPUT_CURSOR
    cmp MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .loop
    inc MAIN_MENU_INPUT_CURSOR
    jsr VT100_CURSOR_RIGHT
    jmp .loop

.backspace:
    lda MAIN_MENU_INPUT_CURSOR
    beq .loop
    lda 0xFF
    sta SHELL_HIST_POS
    dec MAIN_MENU_INPUT_CURSOR
    ldx MAIN_MENU_INPUT_CURSOR
.backspace_shift:
    inx
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .backspace_shift_done
    lda MAIN_MENU_INPUT_BUFFER,x
    dex
    sta MAIN_MENU_INPUT_BUFFER,x
    inx
    jmp .backspace_shift
.backspace_shift_done:
    dec MAIN_MENU_INPUT_BUFFER_COUNT
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    sta SHELL_HIST_PAINTED
    jsr VT100_CURSOR_LEFT
    jsr VT100_CLEAR_LINE_END
    ldx MAIN_MENU_INPUT_CURSOR
.backspace_echo:
    cpx MAIN_MENU_INPUT_BUFFER_COUNT
    bcs .backspace_repos
    lda MAIN_MENU_INPUT_BUFFER,x
    jsr ACIA_SEND_CHAR
    inx
    jmp .backspace_echo
.backspace_repos:
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    sec
    sbc MAIN_MENU_INPUT_CURSOR
    beq .loop
    tay
.backspace_cursor_left:
    jsr VT100_CURSOR_LEFT
    dey
    bne .backspace_cursor_left
    jmp .loop

.cmd_entered:
    jsr SHELL_HIST_PUSH
    jsr SHELL_DISPATCH
    jmp menu_ready

.menu_show_error:
    ldd menu_error_msg[15:8]
    lde menu_error_msg[7:0]
    jsr ACIA_SEND_STRING
    jmp menu_ready

; --------------------------------------

MENU_HELP:
    ldd menu_help_msg[15:8]
    lde menu_help_msg[7:0]
    jsr ACIA_SEND_STRING
    ldd menu_adv_help_msg[15:8]
    lde menu_adv_help_msg[7:0]
    jsr ACIA_SEND_STRING
    ldd menu_default_addr_msg[15:8]
    lde menu_default_addr_msg[7:0]
    jsr ACIA_SEND_STRING
    lda MAIN_MENU_ADDR_PAGE
    jsr ACIA_SEND_HEX
    lda MAIN_MENU_ADDR_MSB
    jsr ACIA_SEND_HEX
    lda MAIN_MENU_ADDR_LSB
    jsr ACIA_SEND_HEX
    lda ")"
    jsr ACIA_SEND_CHAR
    jsr ACIA_SEND_NEWLINE
    rts

; --------------------------------------

MENU_READ_ADDRESS:
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
    ldy MAIN_MENU_ADDR_PAGE
    ldd MAIN_MENU_ADDR_MSB
    lde MAIN_MENU_ADDR_LSB
    clc
    rts

MENU_STORE_ADDRESS:
    sty MAIN_MENU_ADDR_PAGE
    std MAIN_MENU_ADDR_MSB
    ste MAIN_MENU_ADDR_LSB
    rts

; --------------------------------------

MENU_SHOW_ERROR_RTS:
    ldd menu_error_msg[15:8]
    lde menu_error_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

MENU_DUMP:
    jsr MENU_READ_ADDRESS
    bcs MENU_SHOW_ERROR_RTS

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
    beq .dump_done
    
    tea
    clc
    adc 0x10
    tae
    bcc .menu_dump_command_dump_16byte

    ind
    bne .menu_dump_command_dump_16byte

    iny
    jmp .menu_dump_command_dump_16byte

.dump_done:
    jmp ACIA_SEND_NEWLINE

MENU_UPLOAD:
    jsr MENU_READ_ADDRESS
    bcs MENU_SHOW_ERROR_RTS
    ; Set auto-detect flag based on whether address was explicit
    lda MAIN_MENU_INPUT_BUFFER_COUNT
    cmp 0x01
    bne .menu_upload_explicit
    lda 0x01
    sta XMODEM_AUTO_ADDR
    jmp .menu_upload_command_start
.menu_upload_explicit:
    lda 0x00
    sta XMODEM_AUTO_ADDR

.menu_upload_command_start:
    phd
    phe
    ldd menu_upload_command_start_msg[15:8]
    lde menu_upload_command_start_msg[7:0]
    jsr ACIA_SEND_STRING
    ple
    pld
    sei
    jsr XMODEM_RCV
    cli
    cmp 0x02
    bne .menu_upload_failed
    ; Upload successful — show immediate feedback
    ldd menu_upload_command_ok_msg[15:8]
    lde menu_upload_command_ok_msg[7:0]
    jsr ACIA_SEND_STRING
    ; Check if OT header was detected (XMODEM_AUTO_ADDR == 2)
    lda XMODEM_AUTO_ADDR
    cmp 0x02
    bne .menu_upload_done
    ; Header found — update default address
    lda XMODEM_LOAD_PTRP
    sta MAIN_MENU_ADDR_PAGE
    lda XMODEM_LOAD_PTRH
    sta MAIN_MENU_ADDR_MSB
    lda XMODEM_LOAD_PTR
    sta MAIN_MENU_ADDR_LSB
    ; Print new default address
    ldd menu_upload_addr_msg[15:8]
    lde menu_upload_addr_msg[7:0]
    jsr ACIA_SEND_STRING
    lda MAIN_MENU_ADDR_PAGE
    jsr ACIA_SEND_HEX
    lda MAIN_MENU_ADDR_MSB
    jsr ACIA_SEND_HEX
    lda MAIN_MENU_ADDR_LSB
    jsr ACIA_SEND_HEX
    jsr ACIA_SEND_NEWLINE
    jmp .menu_upload_done
.menu_upload_failed:
    ldd menu_upload_command_error_msg[15:8]
    lde menu_upload_command_error_msg[7:0]
    jsr ACIA_SEND_STRING
.menu_upload_done:
    lda 0x00
    sta MAIN_MENU_STATUS
    rts

MENU_RUN:
    jsr MENU_READ_ADDRESS
    bcs MENU_SHOW_ERROR_RTS
    jsr MENU_STORE_ADDRESS

MENU_RUN_START:
    ; JSR indirect: pointer to 24-bit target at MAIN_MENU_ADDR_PAGE..+2 (big-endian page,hi,lo)
    #d 0x93, 0x00, MAIN_MENU_ADDR_PAGE[15:8], MAIN_MENU_ADDR_PAGE[7:0]

    ldd menu_run_command_end_msg[15:8]
    lde menu_run_command_end_msg[7:0]
    jsr ACIA_SEND_STRING
    rts

; --------------------------------------

menu_help_msg:
    #d 0x0A, 0x0D
    #d "Otto Kernel ", KERNEL_VERSION, " (", KERNEL_BUILDDATE, ")", 0x0A, 0x0D
    #d "Native commands:", 0x0A, 0x0D
    #d "  help,?              show this help", 0x0A, 0x0D
    #d "  ver                 kernel version", 0x0A, 0x0D
    #d "  cls                 clear screen", 0x0A, 0x0D
    #d "  addr [hex]          show/set working address", 0x0A, 0x0D
    #d "  dump [addr]         hex+ASCII memory dump", 0x0A, 0x0D
    #d "  call [addr]         JSR to address", 0x0A, 0x0D
    #d "  upload [addr]       XMODEM receive to memory", 0x0A, 0x0D
    #d "  peek addr           read one byte", 0x0A, 0x0D
    #d "  poke addr val       write one byte", 0x0A, 0x0D
    #d "  fill addr len val   fill memory range", 0x0A, 0x0D
    #d "  copy src dst len    copy memory range", 0x0A, 0x0D
    #d 0x00

menu_adv_help_msg:
    #d "  mount / umount      USB storage", 0x0A, 0x0D
    #d "  dir / cd [path]     list / change directory", 0x0A, 0x0D
    #d "  mkdir / rmdir name  create / remove directory", 0x0A, 0x0D
    #d "  del name            delete file", 0x0A, 0x0D
    #d "  type file           print text file", 0x0A, 0x0D
    #d "  load file [addr]    load from USB", 0x0A, 0x0D
    #d "  save file len [addr]  save memory to USB (+OT)", 0x0A, 0x0D
    #d "  exec file / <name>  load+run (NAME.BIN)", 0x0A, 0x0D
    #d 0x0A, 0x0D
    #d "Legacy: d/u/r/h[+hex]  (e.g. d8400, r)", 0x0A, 0x0D
    #d "Addr hex: 8400 or 020000. Default addr below.", 0x0A, 0x0D
    #d 0x00

menu_error_msg:
    #d 0x0A, 0x0D
    #d "?syntax error", 0x0A, 0x0D 
    #d 0x00

menu_run_command_end_msg:
    #d 0x0A, 0x0D
    #d "INFO: Execution ended.", 0x0A, 0x0D 
    #d 0x00

menu_upload_command_error_msg:
    #d 0x0A, 0x0D
    #d "INFO: Upload Failed!", 0x0A, 0x0D 
    #d 0x00

menu_upload_command_ok_msg:
    #d 0x0A, 0x0D
    #d "INFO: Upload Successful!", 0x0A, 0x0D 
    #d 0x00

menu_upload_addr_msg:
    #d "INFO: Default address set to 0x"
    #d 0x00

menu_default_addr_msg:
    #d "  (addr 0x"
    #d 0x00

menu_upload_command_start_msg:
    #d 0x0A, 0x0D
    #d "INFO: Begin XMODEM/CRC transfer.  Press <Esc> to abort..."
    #d 0x0A, 0x0D
    #d 0x00
