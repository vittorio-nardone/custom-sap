;==========================================================
; Otto assembly code to solve N Queens puzzle
; created 2025 by Vittorio Nardone
;
; https://www.vittorionardone.it
;==========================================================

; C64
; BGCOLOR       = 0xd020
; BORDERCOLOR   = 0xd021
; BASIC         = 0x0801
; SCREENRAM     = 0x0400
; CLEARSCREEN   = 0xe544  
; BSOUT         = 0xffd2                ;kernel character output sub
; BSOUTPTR      = 0xfb                  ;zero page pointer
; BUINTOUT      = 0xbdcd                ;basic print XA as unsigned integer
; CURSORPOS     = 0xe50a                ;current cursor position

;==========================================================
; INCLUDE
;==========================================================

#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

;==========================================================
; Entry point
;==========================================================

#bank ram
jmp entry

;==========================================================
; SETTINGS
;==========================================================

NDIM:
    #d 0x08               ; in 4-12 range
QUEENCHAR:
    #d 0x51
BOARDCHAR:
    #d 0x2E
COLOR:
    #d 0x01


;==========================================================
; CODE
;==========================================================
entry:

                jsr VT100_ERASE_SCREEN  ; clear the screen
;
                ldd .welcome[15:8]      ; print welcome message
                lde .welcome[7:0]
                jsr ACIA_SEND_STRING
;
                ldd .dimension[15:8]    ; print dimension message
                lde .dimension[7:0]
                jsr ACIA_SEND_STRING

                jsr waitkey             ; wait for dimension
                sec
                sbc 0x30
                cmp 0x01                ; is it starting with 1?
                bne .entrycheck         
                jsr waitkey             ; wait for dimension
                sec                     
                sbc 0x26    
                cmp 0x0D                ; is it more then 12?
                bcs entry
                jmp .entrystore                
.entrycheck:
                cmp 0x04                ; is it less than 4?
                bcc entry
                cmp 0x0A                ; is it more then 9?
                bcs entry

               
.entrystore:
                sta NDIM                ; store dimension

                ; lda 0x00                ; print dimension
                ; ldx NDIM
                ; jsr BUINTOUT              
                jsr ACIA_SEND_NEWLINE
;
                ; jsr starttimer	        ; start seconds counter
;
                jsr init                ; init memory
;              
                ldx 0x00                ; start from row 0
                jsr run
;
                ; jsr stoptimer	        ; stop seconds counter
;
                rts                     ; exit the program

.welcome:
    #d 0x0A, 0x0D, "c64 n queens puzzle", 0x0A, 0x0D, 0x00 
.dimension:
    #d "dimension (4-12)? ", 0x00

;==========================================================
; Init
;==========================================================
CHESSBOARD:
    ; reserve 255 bytes
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00     
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
NDIML1:
    #d 0x00    
NDIMP1:
    #d 0x00 

init:
                ldx NDIM                ; calculate NDIM-1
                dex 
                stx NDIML1
                inx                     ; calculate NDIM+1
                inx
                stx NDIMP1
                lda 0xFF
                sta CURSORX
                lda BOARDCHAR
                ldx 0x00
                stx FOUNDCOUNTH
                stx FOUNDCOUNTL
                
;
.initloop:
                sta CHESSBOARD,x        ; fill board 
                inx
                cpx 0xFF
                bne .initloop
                rts

;==========================================================
; Run
; Usage:
;  ldx 0x00         ; (row no, 0..7)
;  jsr run
;==========================================================
RUNX:
    #d 0x00
RUNY:
    #d 0x00 
LASTRUNY:
    #d 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
FOUNDCOUNTL:
    #d 0x00
FOUNDCOUNTH:
    #d 0x00

run:
                stx RUNX             ; store location
                ldy 0x00

.rungo:
                sty RUNY   
                jsr offsetcalc          ; calculate mem offset
                ldy OFFSET              ; get offset from stack
                lda CHESSBOARD,y        ; get chessboard cell
                cmp BOARDCHAR           ; check if empty
                bne .runnext
                ldx RUNX               ; place queen
                lda RUNY
                sta LASTRUNY,x
                tay
                jsr place 
                ldx RUNX               ; move to next row
                inx 
                cpx NDIM                ; last row?
                beq .runfound           
                jmp run                                     

.runnext:
                ldx RUNX               ; try next cell in row
                ldy RUNY
.runmoveright:
                iny
                cpy NDIM                ; end of row?
                bne .rungo 
                
.runprevrow:
                dex                     ; try previous row
                cpx 0xFF                ; already first row?
                beq .runend             

                stx RUNX
                jsr undoqueen           ; remove queen from row

.runnexty:
                ldx RUNX               ; try next cell in row
                pha
                lda LASTRUNY,x
                tay
                pla
                jmp .runmoveright

.runfound:
                inc FOUNDCOUNTL        ; result found, inc
                bne .runfoundprint
                inc FOUNDCOUNTH

.runfoundprint:
                jsr printboard          ; print founded result
                ldx RUNX
                jsr undoqueen           ; remove last queen
                jmp .runnexty           ; try next cell in row

.runend:         
                ldd .found[15:8]        ; print results message
                lde .found[7:0]
                jsr ACIA_SEND_STRING

                lda FOUNDCOUNTH
                sta BINDEC32_VALUE+1
                lda FOUNDCOUNTL
                sta BINDEC32_VALUE
                lda 0x00
                sta BINDEC32_VALUE+2
                sta BINDEC32_VALUE+3
                jsr ACIA_SEND_DECIMAL32

                ; ldx #<.timeelapsed       ; print results message
                ; ldy #>.timeelapsed 
                ; jsr sprint
                ; jsr printtimer
     
                jsr ACIA_SEND_NEWLINE

                rts                     ; end of the run

.found:
    #d 0x0A, 0x0D, "solutions found: ", 0x00 
.timeelapsed:
    #d 0x0A, 0x0D, "duration in seconds: ", 0x00

;==========================================================
; Wait for a key pressed (result in A)
; Usage:
;   jsr waitkey  
;==========================================================
waitkey:
                lda ACIA_CONTROL_STATUS_ADDR                    ; read serial 1 status
                bit ACIA_STATUS_REG_RECEIVE_DATA_REGISTER_FULL  ; check if Receive Data Register is full
                beq waitkey
                lda ACIA_RW_DATA_ADDR                           ; read serial 1 data
                jsr ACIA_SEND_CHAR
                rts                                             ; return            

;==========================================================
; Remove a queen from a specific row and empty all 
; cells blocked by the removed queen
; Usage:
;  ldx 0x01 (queen row no, 0..7)
;  jsr undoqueen
;==========================================================

CLEANVALUE:
    #d 0x00
CLEANX:
    #d 0x00
CLEANCOUNTER:
    #d 0x00

undoqueen:        
                stx CLEANX             ; search for queen
                ldy 0x00
                jsr offsetcalc          ; calculate mem offset
                ldy OFFSET              
                ldx 0x00
                lda QUEENCHAR 
.undoqueenl1:
                tad
                pha
                lda CHESSBOARD,y        ; get chessboard cell
                tae
                pla
                cpd e                   ; queen found?
                ;cmp CHESSBOARD,y        ; queen found?
                beq .undoqueenstart
                iny
                inx                     ; increase counter
                cpx NDIM                ; end of row?
                bne .undoqueenl1  
                
.undoqueenstart:
                lda BOARDCHAR           ; remove queen
                sta CHESSBOARD,y 
                ldy 0x00                ; start cleaning
                ldx 0x00
                sty CLEANCOUNTER
                lda CLEANX             ; calculate value to search for
                clc         
                adc 0x30
                sta CLEANVALUE         
                
.undoqueenl2:
                ldd CLEANVALUE 
                pha
                lda CHESSBOARD,y        ; get chessboard cell
                tae
                pla
                cpd e                   ; queen found?      
                ; cmp CHESSBOARD,y        ; correct value?
                bne .undoqueennext
                lda BOARDCHAR
                sta CHESSBOARD,y        ; replace with empty char

.undoqueennext:
                iny                     ; increase counters
                inx
                cpx NDIM                ; end of the row?
                bne .undoqueenl2
                ldx 0x00
                inc CLEANCOUNTER
                lda CLEANCOUNTER   
                cmp NDIM                ; last row?
                bne .undoqueenl2
;
                rts                     ; return

;==========================================================
; Place a queen and block cells
; Usage:
;  ldx 0x01         ; (row no, 0..7)
;  ldy 0x01         ; (column no, 0..7)
;  jsr place        
;==========================================================

PLACEX:
    #d 0x00
PLACEY:
    #d 0x00
PLACEXLOOP:
    #d 0x00
PLACEYLOOP:
    #d 0x00
PLACEXCHAR:
    #d 0x00

place:
                stx PLACEX             ; store location
                sty PLACEY
                txa
                clc
                adc 0x30
                sta PLACEXCHAR
;
.placerow:                              ; fill the row
                ldy 0x00
                jsr offsetcalc          ; calculate mem offset
                ldy OFFSET              ; get offset from stack                
                ldx 0x00                ; first column               
;
.placerowloop:   
                lda CHESSBOARD,y        ; get chessboard cell
                cmp BOARDCHAR           ; check if empty
                bne .placerownext
                lda PLACEXCHAR         ; load filling char 
                sta CHESSBOARD,y        ; set chessboard cell
.placerownext:
                iny                     ; increase counters
                inx
                cpx NDIM                ; end of row?
                bne .placerowloop                
;
.placecol:                               ; fill the column
                ldy PLACEY
                ldx 0x00
                jsr offsetcalc          ; calculate mem offset
                ldy OFFSET              ; get offset from stack                
                ldx 0x00                ; first row
;
.placecolloop:   
                lda CHESSBOARD,y        ; get chessboard cell
                cmp BOARDCHAR           ; check if empty
                bne .placecolnext
                lda PLACEXCHAR         ; load filling char
                sta CHESSBOARD,y       ; set chessboard cell
.placecolnext:
                lda OFFSET              ; decrease offset by 8
                clc
                adc NDIM
                sta OFFSET              ; store new offset
                tay
                inx                     ; increase counter
                cpx NDIM                ; end of row?
                bne .placecolloop     
;
.placediag:                             ; fill diag (->)
                ldy PLACEY
                ldx PLACEX
                stx PLACEXLOOP         ; store indexes
                sty PLACEYLOOP
                jsr offsetcalc          ; calculate mem offset
;
.placediagloop:
                ldx PLACEXLOOP         ; move indexes ->
                ldy PLACEYLOOP
                inx
                iny
                cpx NDIM                ; end of row?
                beq .placeback     
                cpy NDIM                ; end of column?
                beq .placeback  
                stx PLACEXLOOP         ; store indexes
                sty PLACEYLOOP    
                lda OFFSET              ; increase offset
                clc
                adc NDIMP1
                sta OFFSET       
                tay 
                lda CHESSBOARD,y        ; get chessboard cell
                cmp BOARDCHAR           ; check if empty
                bne .placediagloop                 
                lda PLACEXCHAR         ; load filling char
                sta CHESSBOARD,y       ; set chessboard cell
                jmp .placediagloop         
.placeback:                              ; fill diag (<-)
;
                ldy PLACEY             
                ldx PLACEX
                stx PLACEXLOOP         ; restore indexes
                sty PLACEYLOOP
                jsr offsetcalc          ; calculate mem offset
;
.placebackloop:
                ldx PLACEXLOOP         ; move indexes <-
                ldy PLACEYLOOP
                dex
                dey
                cpx 0xFF                ; end of row?
                beq .placediag2     
                cpy 0xFF                ; end of column?
                beq .placediag2  
                stx PLACEXLOOP         ; store indexes
                sty PLACEYLOOP    
                lda OFFSET              ; decrease offset
                sec
                sbc NDIMP1
                sta OFFSET
                tay
                lda CHESSBOARD,y        ; get chessboard cell
                cmp BOARDCHAR           ; check if empty
                bne .placebackloop   
                lda PLACEXCHAR         ; load filling char 
                sta CHESSBOARD,y       ; set chessboard cell   
                jmp .placebackloop
;
.placediag2:                             ; fill diag (->)
                ldy PLACEY
                ldx PLACEX
                stx PLACEXLOOP         ; store indexes
                sty PLACEYLOOP
                jsr offsetcalc          ; calculate mem offset
; 
.placediag2loop:
                ldx PLACEXLOOP         ; move indexes ->
                ldy PLACEYLOOP
                dex
                iny
                cpx 0xFF                ; end of row?
                beq .placeback2     
                cpy NDIM                ; end of column?
                beq .placeback2  
                stx PLACEXLOOP         ; store indexes
                sty PLACEYLOOP    
                lda OFFSET              ; increase offset by 9
                sec
                sbc NDIML1
                sta OFFSET       
                tay 
                lda CHESSBOARD,y        ; get chessboard cell
                cmp BOARDCHAR           ; check if empty
                bne .placediag2loop                 
                lda PLACEXCHAR         ; load filling char
                sta CHESSBOARD,y       ; set chessboard cell
                jmp .placediag2loop  
.placeback2:                             ; fill diag (->)
                ldy PLACEY
                ldx PLACEX
                stx PLACEXLOOP         ; store indexes
                sty PLACEYLOOP
                jsr offsetcalc          ; calculate mem offset
;
.placeback2loop:
                ldx PLACEXLOOP         ; move indexes ->
                ldy PLACEYLOOP
                inx
                dey
                cpx NDIM                ; end of row?
                beq .placequeen     
                cpy 0xFF                ; end of column?
                beq .placequeen  
                stx PLACEXLOOP         ; store indexes
                sty PLACEYLOOP    
                lda OFFSET              ; increase offset by 9
                clc
                adc NDIML1
                sta OFFSET       
                tay 
                lda CHESSBOARD,y        ; get chessboard cell
                cmp BOARDCHAR           ; check if empty
                bne .placeback2loop                 
                lda PLACEXCHAR         ; load filling char
                sta CHESSBOARD,y       ; set chessboard cell
                jmp .placeback2loop                  
.placequeen:                   
;
                ldx PLACEX
                ldy PLACEY
                jsr offsetcalc          ; calculate mem offset
                ldy OFFSET              ; get offset from stack
                lda QUEENCHAR           ; load filling char
                sta CHESSBOARD,y        ; set chessboard cell

                rts



;==========================================================
; Calculate memory offset
; Usage:
;  ldx 0x01         ; (row no, 0..7)
;  ldy 0x01         ; (column no, 0..7)
;  jsr offsetcalc   ; result in OFFSET 
;  lda OFFSET 
;==========================================================
OFFSET:
    #d 0x00

offsetcalc:      
                lda 0x00                ; reset offset
.offsetrow:
                cpx 0x00                ; last row?
                beq .offsetcolumn       ; offset calculated, jmp
                dex                     ; decrease row no
                clc                     ; clear carry (for adc)
                adc NDIM                ; add one row offset
                jmp .offsetrow          ; loop
.offsetcolumn:
                sta OFFSET              ; store row offset in menory
                tya                     ; move column no (y) to a
                clc                     ; clear carry (for adc)
                adc OFFSET              ; add column offset
                sta OFFSET              ; store again in memory
                rts

;==========================================================
; Print board contents
; Usage:
;  jsr printboard
;==========================================================
CURSORX:
    #d 0xFF
CURSORY:
    #d 0x00
ROWCOUNT:
    #d 0x00

printboard:
;                 lda CURSORX            ; first time call? 
;                 cmp 0xFF
;                 bne .printsetcursor
;                 sec
;                 jsr CURSORPOS           ; get & store cursor position 
;                 stx CURSORX            
;                 sty CURSORY
;                 jmp .printboardinit
; ;
; .printsetcursor:
;                 ldx CURSORX            ; restore cursor position
;                 ldy CURSORY
;                 clc
;                 jsr CURSORPOS 
;                            
.printboardinit:
                jsr VT100_ERASE_SCREEN  

                ldx 0x00                ; reset chars counter
                stx ROWCOUNT       
; 
.printrow:
                ldy 0x00                ; reset row counter
.printrowloop:
                lda CHESSBOARD,x        ; get chessboard content
                cmp QUEENCHAR           ; is it a queen?
                beq .printrowchar
                lda BOARDCHAR           ; load board fill char
.printrowchar:
                jsr ACIA_SEND_CHAR      ; print it
                lda " "                 ; print space
                jsr ACIA_SEND_CHAR      ; print it
                inx                     ; increase counters                
                iny                     
                cpy NDIM                ; end of row?
                bne .printrowloop
;               
                jsr ACIA_SEND_NEWLINE   ; go to next line
;
                inc ROWCOUNT           ; increase row counter
                lda ROWCOUNT
                cmp NDIM                ; end of board?
                bne .printrow
;
                rts                     ; return
                


