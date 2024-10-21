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
;   ————————————————————————————————————
;
HEXBIN:                    ; assumes text is in BYTE_CONV_H and BYTE_CONV_L
    jsr .asc_hex_to_bin    ; convert to number - result is in A
    clc
    rol a
    clc
    rol a
    clc
    rol a
    clc
    rol a
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
    cmp 0x10                ; is value more than 10?
    bcc .asc_hex_to_bin_end ; if not, we're okay
    sbc 0x07                ; otherwise subtract another $07 for A-F
.asc_hex_to_bin_end:
    rts                     ; value is returned in A