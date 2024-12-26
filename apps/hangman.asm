; =====================================================
; Otto Hangman Game
; =====================================================
; Description:
;   A word-guessing game implemented in assembly for the Otto system
;   Players have limited attempts to guess a mystery word
;
; Game Mechanics:
;   - Randomly selects a word from a predefined word list
;   - Supports revealing individual letters
;   - Allows full word guessing
;   - Tracks and limits number of tries
;
; Scoring System:
;   - Initial score = word length * 10 (score_penalty)
;   - Each letter reveal reduces score by 10 points
;   - Winning preserves the remaining score
;   - Losing results in zero score
;
; Key System Requirements:
;   - The Otto Project (assembly is 6502-like)
;   - Serial communication (ACIA) for I/O
;   - Timer interrupt for random seed generation
;
; Implementation Details:
;   - Maximum word length: 10 characters
;   - Maximum attempts: 4 tries
;   - Uses timer counter for pseudo-random word selection
;
; Memory Usage:
;   - RAM bank at 0x9000
;   - Dedicated memory areas for game state tracking
;
; Created: 21/11/2024
; Author: Vittorio Nardone
; =====================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

; Memory bank definition for RAM
#bankdef ram
{
    #addr 0x9000   ; Starting address of RAM
    #size 0x1000   ; Size of RAM bank (4096 bytes)
    #outp 0        ; Output configuration
}

#bank ram

; Game constants
#const max_word_length = 10 ; Maximum length of the word to guess
#const score_penalty = 10   ; Used to calculate the final score (initial score = wordlength * penalty, any reveal -> score = score-penalty)

begin:
    ; Configure and enable timer interrupt
    lda INT_TIMER  ; Load interrupt timer mask
    tai  ; Initialize interrupt
    cli  ; Clear interrupt flag, allowing interrupts

.new_game:
    ; Display welcome message and wait for key press
    ldd welcome_message[15:8]  ; Load high byte of message address
    lde welcome_message[7:0]   ; Load low byte of message address
    jsr ACIA_SEND_STRING   ; Send welcome message to serial output
    jsr ACIA_READ_CHAR     ; Wait for user to press a key
 
    ; Select random word using timer counter as seed
    lda INT_TIMER_COUNTER_LSB  ; Get least significant byte of timer
    sta word_index  ; Use this as an index to select a word
    
    ; Initialize game state variables
    lda 0x01
    sta tries_count  ; Set initial number of tries
    
    ; Clear tries_chars memory area
    ldx 0x00
    lda 0x00
    sta tries_chars_index
.init_tries_chars_area_loop:
    sta tries_chars,x  ; Zero out each byte
    inx
    cpx max_word_length
    bne .init_tries_chars_area_loop

    ; Initialize word guess area with zeros
    ldx 0x00
    lda 0x00
.init_word_guess_area_loop:
    sta guess_word,x  ; Zero out each byte of guess area
    inx
    cpx max_word_length
    bne .init_word_guess_area_loop

    ; Find the selected word in word list
    ldd word_list[15:8]
    lde word_list[7:0]
    ldx 0x00
    ldy 0x00

    ldo word_index

.find_word_loop:
    cpy word_index  ; Compare current word index with desired index
    beq .find_word_founded
    
    lda (de),x  ; Load current character 
    bne .find_word_inc_ptr
    iny  ; Increment word count when null terminator found
.find_word_inc_ptr:
    ine  ; Increment pointer
    bne .find_word_loop
    ind  ; Handle pointer rollover
    jmp .find_word_loop

.find_word_founded:
    std word_ptr    ; Store word pointer's high byte
    ste word_ptr+1  ; Store word pointer's low byte
    
    ldx 0x00
.find_word_length_loop:  
    ; Find the length of the random word
    lda (de),x
    beq .calculate_max_tries
    inx
    jmp .find_word_length_loop

.calculate_max_tries:
    inx
    stx max_tries
    dex

    ; Calculate max score (word length * penalty)
    lda 0x00
.calculate_max_score_loop:
    clc
    adc score_penalty
    dex
    bne .calculate_max_score_loop
    sta score
    
.print_placeholder:
    ; Print current try number
    ldd tentative_message[15:8]  
    lde tentative_message[7:0]   
    jsr ACIA_SEND_STRING   

    lda "#"
    jsr ACIA_SEND_CHAR
    lda tries_count
    jsr ACIA_SEND_DECIMAL
    lda " "
    jsr ACIA_SEND_CHAR

    ; Initialize character index for word display
    lda 0x00
    sta current_char_index

.print_placeholder_loop:
    ; Load current character of the word
    ldd word_ptr
    lde word_ptr+1
    ldx current_char_index
    lda (de),x
    beq .ask_user  ; End of word reached
    sta current_char

    ; Check if character has been revealed
    ldd tries_chars[15:8]
    lde tries_chars[7:0]
    ldx 0x00
.print_placeholder_char_search:
    lda (de),x
    cmp current_char
    beq .print_placeholder_print_char
    inx
    cpx max_word_length
    beq .print_placeholder_char_not_found
    jmp .print_placeholder_char_search

.print_placeholder_char_not_found:
    lda "_"  ; Display underscore for unrevealed characters
    sta current_char
.print_placeholder_print_char:
    lda current_char
    jsr ACIA_SEND_CHAR
    lda " "
    jsr ACIA_SEND_CHAR

    inc current_char_index
    jmp .print_placeholder_loop

.ask_user:
    jsr ACIA_SEND_NEWLINE
    
    ; Check if no tries left
    lda tries_count
    cmp max_tries
    beq .no_more_tentative

    ; Prompt user to reveal a letter or guess the word
    ldd ask_user_message[15:8]
    lde ask_user_message[7:0]
    jsr ACIA_SEND_STRING
.ask_user_loop:    
    jsr ACIA_READ_CHAR
    cmp "r"  ; Reveal letter option
    beq .reveal_char
    cmp "g"  ; Guess whole word option
    beq .user_guess_word
    jmp .ask_user_loop

.reveal_char:
    ; Update the score
    lda score
    sec
    sbc score_penalty
    sta score
    ; Process letter reveal
    ldd ask_user_reveal_letter[15:8]
    lde ask_user_reveal_letter[7:0]
    jsr ACIA_SEND_STRING   
    jsr ACIA_READ_CHAR
    jsr ACIA_SEND_CHAR
    ldd tries_chars[15:8]
    lde tries_chars[7:0]
    ldx tries_chars_index
    sta (de),x  ; Store revealed character
    inc tries_chars_index
    inc tries_count
    jmp .print_placeholder

.game_end_lose:
    ; Display loss message and reveal word
    ldd game_lose_message[15:8]
    lde game_lose_message[7:0]
    jsr ACIA_SEND_STRING   

    ldd word_ptr
    lde word_ptr+1
    jsr ACIA_SEND_STRING  

    jsr ACIA_SEND_NEWLINE

    rts  ; Return from subroutine

.no_more_tentative:
    ; Process full word guess
    ldd no_more_tentative_message[15:8]
    lde no_more_tentative_message[7:0]
    jsr ACIA_SEND_STRING   

.user_guess_word:
    ; Process full word guess
    ldd word_prompt_message[15:8]
    lde word_prompt_message[7:0]
    jsr ACIA_SEND_STRING   
    ldx 0x00
.user_guess_word_loop:
    jsr ACIA_READ_CHAR
    jsr ACIA_SEND_CHAR
    cmp 0x0D  ; Check for enter key
    beq .compare_word
    sta guess_word,x  ; Store guessed character
    inx
    cpx max_word_length
    beq .compare_word
    jmp .user_guess_word_loop

.compare_word:
    ; Compare guessed word with actual word
    ldd word_ptr
    lde word_ptr+1
    ldx 0x00
.compare_word_loop:
    lda (de),x
    beq .compare_word_length  ; End of word reached
    sta current_char
    lda guess_word,x
    cmp current_char
    bne .game_end_lose  ; Incorrect guess
    inx
    jmp .compare_word_loop
.compare_word_length:
    lda guess_word,x
    beq .game_end_win   ; 100% match
    jmp .game_end_lose  ; user word is longer


.game_end_win:
    ; Display win message and reveal word
    ldd game_win_message[15:8]
    lde game_win_message[7:0]
    jsr ACIA_SEND_STRING   

    ldd word_ptr
    lde word_ptr+1
    jsr ACIA_SEND_STRING  

    ldd game_win_score_message[15:8]
    lde game_win_score_message[7:0]
    jsr ACIA_SEND_STRING   

    lda score
    jsr ACIA_SEND_DECIMAL

    rts  ; Return from subroutine

; Memory variables
word_index:
    #d 0x00  ; Index of selected word
tries_count:
    #d 0x00  ; Remaining tries
tries_chars:
    #d 0x00`(8*max_word_length)  ; Array of revealed characters
tries_chars_index:
    #d 0x00  ; Index for tracking revealed characters
word_ptr:
    #d 0x00, 0x00  ; Pointer to current word
current_char:
    #d 0x00  ; Current character being processed
current_char_index:
    #d 0x00  ; Index of current character
guess_word:
    #d 0x00`(8*max_word_length)  ; User's guessed word
score:
    #d 0x00  ; Score of the game
max_tries:
    #d 0x00

; Game messages
welcome_message:
    #d 0x0A, 0x0D, 
    #d "Welcome to Otto Hangman Game", 0x0A, 0x0D,
    #d "Press any key to start the game.", 0x00   

ask_user_message:
    #d 0x0A, 0x0D, 
    #d "Would you like to (r)eveal a letter or (g)uess the word? ", 0x00

ask_user_reveal_letter:
    #d 0x0A, 0x0D,
    #d "What letter would you like to reveal? ", 0x00

game_lose_message:
    #d 0x0A, 0x0D, 
    #d 0x0A, 0x0D, 
    #d "You lose! The mystery word is ", 0x00

game_win_message:
    #d 0x0A, 0x0D, 
    #d "Congratulation! You win! The mystery word is ", 0x00

game_win_score_message:
    #d 0x0A, 0x0D, 
    #d "Your score for this game is ", 0x00

no_more_tentative_message:
    #d 0x0A, 0x0D, 
    #d "No more reveal, sorry.", 0x00     

tentative_message:
    #d 0x0A, 0x0D, 
    #d 0x0A, 0x0D, 
    #d "Tentative ", 0x00     

word_prompt_message:
    #d 0x0A, 0x0D, 
    #d "Type the word and press enter: ", 0x00      

word_list:
    #d "altair", 0x00  
    #d "apple", 0x00  
    #d "commodore", 0x00  
    #d "vic20", 0x00  
    #d "c64", 0x00  
    #d "zx81", 0x00  
    #d "spectrum", 0x00  
    #d "trs80", 0x00  
    #d "osborne", 0x00  
    #d "kaypro", 0x00  
    #d "ibmpc", 0x00  
    #d "macintosh", 0x00  
    #d "lisaii", 0x00  
    #d "amiga", 0x00  
    #d "atari", 0x00  
    #d "520st", 0x00  
    #d "1040st", 0x00  
    #d "gameboy", 0x00  
    #d "nintendo", 0x00  
    #d "pong", 0x00  
    #d "pacman", 0x00  
    #d "spacewar", 0x00  
    #d "adventure", 0x00  
    #d "zork", 0x00  
    #d "wolfenstein", 0x00  
    #d "doom", 0x00  
    #d "basic", 0x00  
    #d "cobol", 0x00  
    #d "fortran", 0x00  
    #d "pascal", 0x00  
    #d "assembler", 0x00  
    #d "byte", 0x00  
    #d "bit", 0x00  
    #d "kilobyte", 0x00  
    #d "megabyte", 0x00  
    #d "floppy", 0x00  
    #d "diskette", 0x00  
    #d "cdrom", 0x00  
    #d "eprom", 0x00  
    #d "ram", 0x00  
    #d "rom", 0x00  
    #d "cpu", 0x00  
    #d "alu", 0x00  
    #d "vlsi", 0x00  
    #d "eprom", 0x00  
    #d "zilog", 0x00  
    #d "8080", 0x00  
    #d "6502", 0x00  
    #d "z80", 0x00  
    #d "motorola", 0x00  
    #d "68000", 0x00  
    #d "tape", 0x00  
    #d "cassette", 0x00  
    #d "cartridge", 0x00  
    #d "joystick", 0x00  
    #d "crt", 0x00  
    #d "monitor", 0x00  
    #d "plasma", 0x00  
    #d "printer", 0x00  
    #d "dotmatrix", 0x00  
    #d "laserprinter", 0x00  
    #d "modem", 0x00  
    #d "baud", 0x00  
    #d "ethernet", 0x00  
    #d "ascii", 0x00  
    #d "ansi", 0x00  
    #d "iso", 0x00  
    #d "dos", 0x00  
    #d "msdos", 0x00  
    #d "cp-m", 0x00  
    #d "unix", 0x00  
    #d "xenix", 0x00  
    #d "atari2600", 0x00  
    #d "gamegear", 0x00  
    #d "intellivision", 0x00  
    #d "colecovision", 0x00  
    #d "pongconsole", 0x00  
    #d "gamewatch", 0x00  
    #d "pongarcade", 0x00  
    #d "arcade", 0x00  
    #d "joystick", 0x00  
    #d "trackball", 0x00  
    #d "keyboard", 0x00  
    #d "mouse", 0x00  
    #d "microdrive", 0x00  
    #d "qwerty", 0x00  
    #d "dvorak", 0x00  
    #d "powerpc", 0x00  
    #d "risc", 0x00  
    #d "cisc", 0x00  
    #d "analog", 0x00  
    #d "digital", 0x00  
    #d "datasette", 0x00  
    #d "soundblaster", 0x00  
    #d "soundchip", 0x00  
    #d "sidchip", 0x00  
    #d "plip", 0x00  
    #d "rj45", 0x00  
    #d "serial", 0x00  
    #d "parallel", 0x00  
    #d "usb", 0x00  
    #d "firewire", 0x00  
    #d "pci", 0x00  
    #d "isa", 0x00  
    #d "vga", 0x00  
    #d "cga", 0x00  
    #d "ega", 0x00  
    #d "mda", 0x00  
    #d "hercules", 0x00  
    #d "sprite", 0x00  
    #d "tilemap", 0x00  
    #d "bitplane", 0x00  
    #d "dma", 0x00  
    #d "scsi", 0x00  
    #d "ide", 0x00  
    #d "mfm", 0x00  
    #d "rll", 0x00  
    #d "platter", 0x00  
    #d "head", 0x00  
    #d "sector", 0x00  
    #d "cluster", 0x00  
    #d "cylinder", 0x00  
    #d "track", 0x00  
    #d "bootloader", 0x00  
    #d "bios", 0x00  
    #d "firmware", 0x00  
    #d "eprom", 0x00  
    #d "prom", 0x00  
    #d "eeprom", 0x00  
    #d "battery", 0x00  
    #d "keyboardcontroller", 0x00  
    #d "rtc", 0x00  
    #d "memmap", 0x00  
    #d "bcd", 0x00  
    #d "binary", 0x00  
    #d "hexadecimal", 0x00  
    #d "octal", 0x00  
    #d "asciiart", 0x00  
    #d "spriteeditor", 0x00  
    #d "debugger", 0x00  
    #d "emulator", 0x00  
    #d "vm", 0x00  
    #d "interp", 0x00  
    #d "opcode", 0x00  
    #d "register", 0x00  
    #d "stack", 0x00  
    #d "heap", 0x00  
    #d "page", 0x00  
    #d "segment", 0x00  
    #d "offset", 0x00  
    #d "pointer", 0x00  
    #d "interrupt", 0x00  
    #d "irq", 0x00  
    #d "halt", 0x00  
    #d "nmi", 0x00  
    #d "timer", 0x00  
    #d "watchdog", 0x00  
    #d "crtcontroller", 0x00  
    #d "framebuffer", 0x00  
    #d "raster", 0x00  
    #d "vsync", 0x00  
    #d "hsync", 0x00  
    #d "composite", 0x00  
    #d "rgb", 0x00  
    #d "monochrome", 0x00  
    #d "palette", 0x00  
    #d "lut", 0x00  
    #d "scanline", 0x00  
    #d "blitter", 0x00  
    #d "tileset", 0x00  
    #d "spritesheet", 0x00  
    #d "tileengine", 0x00  
    #d "scrolling", 0x00  
    #d "parallax", 0x00  
    #d "hud", 0x00  
    #d "joystickport", 0x00  
    #d "dmaengine", 0x00  
    #d "zxspectrum", 0x00  
    #d "trsdos", 0x00  
    #d "deskmate", 0x00  
    #d "protext", 0x00  
    #d "wordstar", 0x00  
    #d "dbase", 0x00  
    #d "lotus123", 0x00  
    #d "visicalc", 0x00  
    #d "draw", 0x00  
    #d "paint", 0x00  
    #d "deluxepaint", 0x00  
    #d "dpaint", 0x00  
    #d "bitmap", 0x00  
    #d "pixel", 0x00  
    #d "dithering", 0x00  
    #d "palette", 0x00  
    #d "tapeinterface", 0x00  
    #d "spooler", 0x00  
    #d "driver", 0x00  
    #d "firmware", 0x00  
    #d "memorybank", 0x00  
    #d "bankedmemory", 0x00  
    #d "bankselect", 0x00  
    #d "vgabios", 0x00  
    #d "bootsector", 0x00  
    #d "bootdisk", 0x00  
    #d "autoexec", 0x00  
    #d "configsys", 0x00  
    #d "sysinit", 0x00  
    #d "peek", 0x00  
    #d "poke", 0x00  
    #d "spritecollision", 0x00  
    #d "colorburst", 0x00  
    #d "vblank", 0x00  
    #d "sideborder", 0x00  
    #d "overscan", 0x00  
    #d "charset", 0x00  
    #d "screenmemory", 0x00  
    #d "vector", 0x00  
    #d "bitmapmode", 0x00  
    #d "textmode", 0x00  
    #d "ctrl", 0x00  
    #d "reset", 0x00  
    #d "powerled", 0x00  
    #d "diskcontroller", 0x00  
    #d "turboload", 0x00  
    #d "dosbox", 0x00  
    #d "kickstart", 0x00  
    #d "workbench", 0x00  
    #d "filemanager", 0x00  
    #d "commandline", 0x00  
    #d "shell", 0x00  
    #d "terminal", 0x00  
    #d "ansiart", 0x00  
    #d "crtc", 0x00  
    #d "scrolllock", 0x00  
    #d "numlock", 0x00  
    #d "printscreen", 0x00  
    #d "functionkey", 0x00  
    #d "sysreq", 0x00  
    #d "lightpen", 0x00  
    #d "paddle", 0x00  
    #d "dial", 0x00  
    #d "pseudocolor", 0x00  
    #d "blit", 0x00  
    #d "shifter", 0x00  
    #d "bankswitching", 0x00  
    #d "vram", 0x00  
    #d "linearframebuffer", 0x00  
    #d "texel", 0x00  
    #d "texmapping", 0x00  
    #d "wireframe", 0x00  
    #d "rasterizer", 0x00  
    #d "polygon", 0x00  
    #d "scanconvert", 0x00  
    #d "subpixel", 0x00  
    #d "antialiasing", 0x00  
    #d "alpha", 0x00  
    #d "otto", 0x00
  
