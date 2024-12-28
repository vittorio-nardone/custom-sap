#once
#bank kernel

;================================================================================
;
;BINHEX: CONVERT BINARY BYTE TO HEX ASCII CHARS
;
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte to convert
;
;   Returned Values: .A: MSN ASCII char
;                    .X: LSN ASCII char
;   ————————————————————————————————————
;
BINHEX:
        pha                   ;save byte
        and 0x0F              ;extract LSN
        tax                   ;save it
        pla                   ;recover byte
        lsr a                 ;extract...
        lsr a                 ;MSN
        lsr a
        lsr a
        pha                   ;save MSN
        txa                   ;LSN
        jsr .ascii_lsn        ;generate ASCII LSN
        tax                   ;save
        pla                   ;get MSN & fall thru
;
;
;   convert nybble to hex ASCII equivalent...
;
.ascii_lsn:
        cmp 0x0A
        bcc .finalize         ;in decimal range
;
        adc 0x66              ;hex compensate
;         
.finalize:
        eor 0x30              ;finalize nybble
        rts                   ;done
;



;================================================================================
;
;HEXBIN: CONVERT HEX ASCII CHARS TO BINARY BYTE
;
;   ————————————————————————————————————
;   Preparatory Ops: 
;                     A: MSN ASCII char
;                     X: LSN
; 
;
;   Returned Values:  A
;
;   Warning: don't check if chars are valid (0-F)
;   ————————————————————————————————————
;
HEXBIN:                    ; assumes text is in A and X
    jsr .asc_hex_to_bin    ; convert to number - result is in A
    asl a
    asl a
    asl a
    asl a
    phd
    tad                    ; and store
    txa
    jsr .asc_hex_to_bin    ; convert to number - result is in A
    ora d                  ; OR with previous result
    pld
    rts
 
.asc_hex_to_bin:            ; assumes ASCII char val is in A
    sec
    sbc 0x30                ; subtract $30 - this is good for 0-9
    cmp 0x0A                ; is value >= 10?
    bcc .asc_hex_to_bin_end ; if not, we're okay
    sbc 0x07                ; otherwise subtract another $07 for A-F
    cmp 0x10                ; is value >= 16?
    bcc .asc_hex_to_bin_end ; if not, we're okay
    sbc 0x20                ; otherwise subtract another $20 for a-f
.asc_hex_to_bin_end:
    rts                     ; value is returned in A


;================================================================================
;
;BINDEC: CONVERT BINARY BYTE TO DECIMAL ASCII CHARS
;
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte to convert
;
;   Returned Values: .X: MSN ASCII char
;                    .Y: 
;                    .A: LSN ASCII char
;   ————————————————————————————————————
;
BINDEC:
    pha                 ; Store original number
                        ; Handle hundreds digit
    ldx 0x00
    cmp 100
    bcc .tens           ; If < 100, skip hundreds
                        ; Divide by 100
    pla             
    sec
    ldy 0x00
.hundreds_loop:
    cmp 100
    bcc .hundreds_end
    sbc 100
    iny
    bcs .hundreds_loop
.hundreds_end:  
                        ; Store remainder and convert hundreds to ASCII
    pha
    tya
    ora 0x30            ; Convert to ASCII
    tax                 ; Store hundreds digit 
.tens:
                        ; Handle tens digit
    ldy 0x00
    pla
    pha
    cmp 10
    bcc .ones           ; If < 10, skip tens  
                        ; Divide by 10
    pla
    sec
    ldy 0x00
.tens_loop:
    cmp 10
    bcc .tens_end
    sbc 10
    iny
    bcs .tens_loop
.tens_end:    
                        ; Store remainder and convert tens to ASCII
    pha
    tya
    ora 0x30            ; Convert to ASCII
    tay                 ; Store tens digit
.ones:
                        ; Handle ones digit
    pla
    ora 0x30            ; Convert to ASCII
    rts