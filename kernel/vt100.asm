#once
#bank kernel

#include "serial.asm"

#const VT100_BUFFER   = 0x8120

VT100:

.vt100_send_buffer:
    ldd VT100_BUFFER[15:8]
    lde VT100_BUFFER[7:0]
    jsr ACIA_SEND_STRING
    rts

.vt100_add_dec_to_buffer:
    phx
    jsr BINDEC
    txd
    plx

    cpd 0x00
    beq .skip_100
    std VT100_BUFFER,x
    inx
.skip_100:
    cpy 0x00
    beq .skip_10
    sty VT100_BUFFER,x
    inx 
.skip_10:
    sta VT100_BUFFER,x
    inx 
    rts

VT100_ERASE_SCREEN:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[2J", 0x00

VT100_CURSOR_HOME:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[H", 0x00

VT100_CURSOR_POSITION:
    lda 0x1B
    sta VT100_BUFFER
    lda "["
    sta VT100_BUFFER + 1
    ldx 0x02

    tda
    jsr VT100.vt100_add_dec_to_buffer

    lda ";"
    sta VT100_BUFFER,x
    inx
    
    tea
    jsr VT100.vt100_add_dec_to_buffer    
    
    lda "H"
    sta VT100_BUFFER,x
    inx
    lda 0x00
    sta VT100_BUFFER,x
    jsr VT100.vt100_send_buffer
    rts

; Additional VT100 Escape Code Subroutines

; Cursor Movement Subroutines
VT100_CURSOR_UP:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[A", 0x00

VT100_CURSOR_DOWN:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[B", 0x00

VT100_CURSOR_RIGHT:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[C", 0x00

VT100_CURSOR_LEFT:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[D", 0x00

; Screen Clearing Subroutines
VT100_CLEAR_LINE_END:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[K", 0x00

VT100_CLEAR_LINE_START:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[1K", 0x00

VT100_CLEAR_ENTIRE_LINE:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[2K", 0x00

; Text Attribute Subroutines
VT100_TEXT_RESET:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[0m", 0x00

VT100_TEXT_BOLD:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[1m", 0x00

VT100_TEXT_UNDERLINE:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[4m", 0x00

VT100_TEXT_BLINK:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[5m", 0x00

VT100_TEXT_REVERSE:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[7m", 0x00

; Color Subroutines (Foreground Colors)
VT100_FG_BLACK:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[30m", 0x00

VT100_FG_RED:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[31m", 0x00

VT100_FG_GREEN:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[32m", 0x00

VT100_FG_YELLOW:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[33m", 0x00

VT100_FG_BLUE:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[34m", 0x00

VT100_FG_MAGENTA:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[35m", 0x00

VT100_FG_CYAN:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[36m", 0x00

VT100_FG_WHITE:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[37m", 0x00

; Background Colors (Similar pattern to Foreground Colors)
VT100_BG_BLACK:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[40m", 0x00

VT100_BG_RED:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[41m", 0x00

VT100_BG_GREEN:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[42m", 0x00

VT100_BG_YELLOW:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[43m", 0x00

VT100_BG_BLUE:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[44m", 0x00

VT100_BG_MAGENTA:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[45m", 0x00

VT100_BG_CYAN:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[46m", 0x00

VT100_BG_WHITE:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[47m", 0x00

; VT100 Scrolling Escape Code Subroutines

; Scroll Screen Entire Display
VT100_SCROLL_SCREEN_FULL:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[r", 0x00

; Scroll Screen Specific Region
VT100_SCROLL_SCREEN_REGION:
    lda 0x1B
    sta VT100_BUFFER
    lda "["
    sta VT100_BUFFER + 1

    ldx 0x02
    tda
    jsr VT100.vt100_add_dec_to_buffer

    lda ";"
    sta VT100_BUFFER,x
    inx

    tea
    jsr VT100.vt100_add_dec_to_buffer
  
    lda "r"
    sta VT100_BUFFER,x
    inx
    lda 0x00
    sta VT100_BUFFER,x
    jsr VT100.vt100_send_buffer
    rts

; Scroll Down One Line
VT100_SCROLL_DOWN:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "D", 0x00

; Scroll Up One Line
VT100_SCROLL_UP:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "M", 0x00

; VT100 Wrap and Font Control Subroutines

; Enable Line Wrap
VT100_ENABLE_WRAP:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[7h", 0x00

; Disable Line Wrap
VT100_DISABLE_WRAP:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[7l", 0x00

; Set Default Font (G0)
VT100_FONT_DEFAULT:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "(", 0x00

; Set Alternate Font (G1)
VT100_FONT_ALTERNATE:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, ")", 0x00

; VT100 Device Reset Subroutine

; Reset Device to Default Settings
VT100_DEVICE_RESET:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "c", 0x00
    
; Requests a Report Cursor Position response from the device.
VT100_QUERY_CURSOR_POSITION:
    ldd .data[15:8]
    lde .data[7:0]
    jsr ACIA_SEND_STRING
    rts
.data:
    #d 0x1B, "[6n", 0x00