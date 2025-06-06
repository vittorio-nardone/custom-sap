#once
#bank kernel
MICROCODE_test:
    ldo 0x7E            ; Tests started indicator

; CLK Speed test
;     sei
; .start:    
;     scs
;     ldx 0x00
;     ldy 0x01
; .loop:
;     inx
;     txa
;     tao
;     cpx 0x10
;     bne .loop
;     dey
;     cpy 0x00
;     bne .start
;     scf
;     ldx 0x00
;     jmp .loop

.test1:
    ldo 0x01            ; Test #1: JMP
    jmp .test2
    hlt

.test2:
    ldo 0x02            ; Test #2: LDA & CMP & BEQ
    lda 0x34            ; Load dummy value
    cmp 0x34
    beq .test3
    hlt

.test3:
    ldo 0x03            ; Test #3: LDA & CMP & BEQ
    lda 0x32            ; Load dummy value
    cmp 0x34
    beq .fail

.test4:
    ldo 0x04            ; Test #4: LDA & STA & BEQ
    lda 0x05
    sta 0x8000          ; First RAM byte
    lda 0x02            ; Reset
    lda 0x8000          ; Load from memory
    cmp 0x05            
    beq .test4sub1
    hlt
.test4sub1:
    lda 0x05
    sta 0x8001
    cmp 0x8001
    beq .test4sub2
    hlt
.test4sub2:        ; Test CMP x,y indexed            
    ldx 0x34
    ldy 0x05
    lda 0x05
    sta 0x8001
    cmp 0x7fcd,x
    bne .fail
    cmp 0x7ffc,y
    bne .fail
    lda 0x20
    cmp 0x7fcd,x
    beq .fail
    cmp 0x7ffc,y
    beq .fail

    lda 0x05
    sta 0x018001
    cmp 0x017fcd,x
    bne .fail
    cmp 0x017ffc,y
    bne .fail
    lda 0x20
    cmp 0x017fcd,x
    beq .fail
    cmp 0x017ffc,y
    beq .fail

.test5:
    ldo 0x05            ; Test #5: BNE
    lda 0x05
    cmp 0x03            
    bne .test5sub1
    hlt    
.test5sub1:
    lda 0x05
    sta 0x8001
    lda 0x04
    cmp 0x8001
    bne .test6
    hlt

.test6:
    ldo 0x06            ; Test #6: BNE
    lda 0x22
    cmp 0x22            
    bne .fail

.test7:                  
    ldo 0x07            ; Test #7: Z Flag on LDA
    lda 0x02
    cmp 0x05            ; Clear flag with CMP 
    lda 0x00            ; Set flag with LDA (from bus)
    bne .fail
        
.test8:                  
    ldo 0x08            ; Test #8: BCS (A > M - jmp)
    lda 0x13
    cmp 0x02                    
    bcs .test9
    hlt

.test9:                  
    ldo 0x09            ; Test #9: BCS (A < M - dont jmp)
    lda 0x23
    cmp 0x55                    
    bcs .fail

.test10:                  
    ldo 0x10            ; Test #10: BCC (A > M - don't jmp)
    lda 0x13
    cmp 0x02                    
    bcc .fail

.test11:                  
    ldo 0x11            ; Test #11: BCC (A < M - jmp)
    lda 0x23
    cmp 0x55                    
    bcc .test12
    hlt

.test12:                  
    ldo 0x12            ; Test #12: BCC (A = M - don't jmp)
    lda 0x73
    cmp 0x73                    
    bcc .fail

.test13:
    ldo 0x13            ; Test #13: ADC with/out Carry & CLC/SEC
    lda 0x10
    clc                 ; Clear Carry        
    adc 0x01            ; 0x10 + 0x01 = 0x11
    cmp 0x11            ; this set Carry   
    bne .fail
    adc 0x01            ; 0x11 + 0x01 + Carry = 0x13
    cmp 0x13            ; this set Carry
    bne .fail
    clc                 ; Clear Carry   
    adc 0x01            ; 0x13 + 0x01 = 0x14
    cmp 0x14            ; this set Carry
    bne .fail
    clc                 ; Clear Carry   
    sec                 ; Set Carry
    adc 0x01            ; 0x14 + 0x01 + Carry = 0x16
    cmp 0x16            ; this set Carry
    bne .fail   
    lda 0x55            ; test ADC absolute
    sta 0x8181
    lda 0x88
    clc
    adc 0x8181          ; 0x88 + 0x55 = 0xDD
    cmp 0xDD
    bne .fail 
    lda 0x88
    sec
    adc 0x8181          ; 0x88 + 0x55 + Carry = 0xDE
    cmp 0xDE
    bne .fail    
     
.test14:
    ldo 0x14            ; Test #14: JSR & RTS
    lda 0x00
    jsr .test14sub1
    cmp 0x04
    beq .test15
    hlt
.test14sub1:
    lda 0x01
    jsr .test14sub2
    rts
.test14sub2:
    lda 0x02
    jsr .test14sub3
    rts
.test14sub3:
    lda 0x03
    jsr .test14sub4
    rts
.test14sub4:
    lda 0x04
    rts

.test15:                 ; Test #15: INC
    ldo 0x15
    lda 0xAF
    sta 0x8181
    lda 0x00
    inc 0x8181          ; check inc
    beq .fail            ; zero flag must not be set
    lda 0x8181   
    cmp 0xB0
    bne .fail
    lda 0xFF
    sta 0x8181
    inc 0x8181          ; check if zero flag is set
    bne .fail            ; zero flag must be set

.test16:                 ; Test #16: DEC
    ldo 0x16
    lda 0xB0
    sta 0x8182
    lda 0x00
    dec 0x8182          ; check dec
    beq .fail            ; zero flag must not be set
    lda 0x8182   
    cmp 0xAF
    bne .fail    
    lda 0x01
    sta 0x8182
    dec 0x8182          ; check if zero flag is set
    bne .fail            ; zero flag must be set

.test17:                 ; Test #17: EOR
    ldo 0x17
    lda 0x22
    eor 0x44            ; 0x22 XOR 0x44 = 0x66    
    beq .fail            ; zero flag must not be set
    cmp 0x66
    bne .fail
    eor 0x66            ; 0x66 XOR 0x66 = 0x00
    bne .fail            ; zero flag must be set

.test18:                 ; Test #18: X registers
    ldo 0x18
    ldx 0x66
    txa
    cmp 0x66
    bne .fail
    lda 0x33
    tax
    lda 0x01
    txa
    cmp 0x33
    bne .fail

.test19:                 ; Test #19: X,Y index 
    ldo 0x19
    lda 0x34            ; Test lda with index (no carry)
    sta 0x8182          ; Store a value in 0x8182
    lda 0x00            ; Clean acc
    ldx 0x02            
    lda 0x8180,X        ; Load from 0x8180 + 0x02 (X) = 0x8182
    cmp 0x34            
    bne .fail
    lda 0x36            ; Test lda with index (with carry)
    sta 0x8101          ; Store a value in 0x8101
    lda 0x00            ; Clean acc
    ldx 0x03
    lda 0x80FE,X        ; Load from 0x80FE + 0x03 (X) = 0x8101
    cmp 0x36
    bne .fail
    lda 0x45            ; Test sta with index (with carry)
    ldx 0x03
    sta 0x81FE,X        ; Save to 0x81FE + 0x03 (X) = 0x8201
    lda 0x00            ; Clean acc
    lda 0x8201          ; Load directly
    cmp 0x44            
    beq .fail
    cmp 0x45
    bne .fail
    lda 0x23            ; Test sta with index (no carry)
    ldx 0x04
    sta 0x810E,X        ; Save to 0x810E + 0x04 (X) = 0x8112
    lda 0x00            ; Clean acc
    lda 0x8112          ; Load directly
    cmp 0x44            
    beq .fail
    cmp 0x23
    bne .fail   

    lda 0x32            ; Test ldy with x index
    sta 0x8102          ; Store a value in 0x8102
    ldy 0x00            ; Clean y
    ldx 0x03            
    ldy 0x80FF,X        ; Load from 0x8180 + 0x02 (X) = 0x8182
    cpy 0x32            
    bne .fail
   
    lda 0x33            ; Test ldx with y index
    sta 0x8114          ; Store a value in 0x8102
    ldx 0x00            ; Clean x
    ldy 0x15            
    ldx 0x80FF,y        ; Load from 0x8180 + 0x02 (X) = 0x8182
    cpx 0x33            
    bne .fail

.test20:
    ldo 0x20            ; Test #20: SBC with/out Carry (Borrow)
    lda 0x25   
    sec                 ; Set Carry        
    sbc 0x12            ; 0x25 - 0x12 - notC (0) = 0x13
    cmp 0x13 
    bne .fail 
    lda 0x25   
    clc                 ; Clear Carry        
    sbc 0x21            ; 0x25 - 0x21 - notC (1) = 0x03
    cmp 0x03
    bne .fail 
    lda 0x55            ; test SBC absolute
    sta 0x8181    
    lda 0x59
    sec
    sbc 0x8181          ; 0x59 - 0x55 - notC (0) = 0x04
    cmp 0x04
    bne .fail
    lda 0x59
    clc
    sbc 0x8181          ; 0x59 - 0x55 - notC (1) = 0x03
    cmp 0x03
    bne .fail
    lda 0x37            ; test if Z flag is set
    sec
    sbc 0x37
    bne .fail

.test21:                 ; Test #21: AND (immediate)
    ldo 0x21
    lda 0x22
    and 0x02            ; 0x22 AND 0x02 = 0x02    
    beq .fail            ; zero flag must not be set
    cmp 0x02
    bne .fail
    and 0x01            ; 0x02 AND 0x01 = 0x00
    bne .fail            ; zero flag must be set

.test22:                 ; Test #22: ROR/ROL
    ldo 0x22
    lda 0x44
    clc 
    rol a               ; 0x44 << 1 bit = 0x88    
    beq .fail            ; zero flag must not be set
    cmp 0x88
    bne .fail
    sec
    rol a               ; 0x88 << 1 bit + carry = 0x111 
    cmp 0x11
    bne .fail  
    lda 0x23
    clc
    ror A               ; 0x23 >> 1 bit = 0x11
    cmp 0x11
    bne .fail
    sec
    ror a               ; 0x11 >> 1 bit + carry = 0x88
    cmp 0x88
    bne .fail
    clc
    lda 0x02            ; 0x02 >> 0x01 >> 0x00 (set zero flag)
    ror A
    ror A
    bne .fail
    sec
    rol A               ; 0x00 << 1 bit + carry = 0x01 (clear zero flag)
    beq .fail  
    lda 0x80
    clc
    rol a               ; 0x80 << 1 bit = 0x00 (set zero flag)
    bne .fail        
    sec
    lda 0x20            ; page memory
    sta 0x8111
    lda 0x00
    ror 0x8111          ; 0x20 >> 1 bit + carry = 0x90 
    lda 0x8111
    cmp 0x90
    bne .fail
    clc
    lda 0x20            ; page memory
    sta 0x8111
    lda 0x00
    rol 0x8111          ; 0x20 << 1 bit = 0x40 
    lda 0x8111
    cmp 0x40
    bne .fail
    clc                 ; test input/output Carry (acc/zero page/absolute - ROL/ROC)
    lda 0xF8
    rol A
    bcc .fail
    cmp 0xF0
    bne .fail
    sec
    lda 0xF8
    rol A
    bcc .fail
    cmp 0xF1
    bne .fail
    sec
    lda 0x05
    rol A
    bcs .fail
    cmp 0x0B
    bne .fail    
    clc
    lda 0x05
    rol A
    bcs .fail
    cmp 0x0A
    bne .fail    

    clc                 
    lda 0xF8
    sta 0x8111
    rol 0x8111
    bcc .fail
    lda 0x8111
    cmp 0xF0
    bne .fail

    sec
    lda 0x05
    sta 0x8111
    rol 0x8111
    bcs .fail
    lda 0x8111
    cmp 0x0B
    bne .fail

    clc                
    lda 0x78
    sta 0x8111
    ror 0x8111
    bcs .fail
    lda 0x8111
    cmp 0x3C
    bne .fail

    sec
    lda 0x05
    sta 0x8111
    ror 0x8111
    bcc .fail
    lda 0x8111
    cmp 0x82
    bne .fail    

    sec
    lda 0x05
    sta 0x008111
    rol 0x008111
    bcs .fail
    lda 0x008111
    cmp 0x0B
    bne .fail

    clc                
    lda 0x78
    sta 0x008111
    ror 0x008111
    bcs .fail
    lda 0x008111
    cmp 0x3C
    bne .fail

.test23:
    ldo 0x23            ; Test #23: INX / DEX / CPX
    ldx 0x23
    inx
    inx
    cpx 0x25
    bne .fail
    dex
    cpx 0x24
    bne .fail

.test24:
    ldo 0x24            ; Test #24: Check LZ
    lda 0x00            ; Z flag must be clear/set on LDA
    bne .fail
    cmp 0x01            ; Z flag must be clear/set on CMP
    beq .fail

.test25:
    ldo 0x25            ; Test #25: Ram expansion & Absolute addr.
    lda 0x23
    sta 0x01FFFF
    lda 0x22
    sta 0x010000
    lda 0x00
    ldx 0x35
    ldx 0x01FFFF
    cpx 0x23
    bne .fail
    lda 0x010000
    cmp 0x22
    bne .fail
    lda 0x45
    sta 0x010022
    ldx 0x21
    inx
    lda 0x00
    lda 0x010000,x
    cmp 0x45
    bne .fail
    ; write code in ram and JSR to ram (to test 24bit PC)
    lda 0xfe            ; write in memory: LDO 0xFF 
    sta 0x010101
    lda 0xff
    sta 0x010102        ; write in memory: RTS
    lda 0x60
    sta 0x010103
    jsr 0x010101        ; JSR to code written in memory
    ldo 0x25            ; it should return here

.test26:                 ; Test #26: PHA / PLA
    ldo 0x26            
    lda 0x80
    ldx 0x00
.test26inc:   
    clc 
    adc 0x01
    pha
    cmp 0x92
    bne .test26inc
.test26dec:
    pla 
    inx
    cmp 0x81
    bne .test26dec
    cpx 0x12
    bne .fail

.test27:                 ; Test #27 BMI/BPL
    ldo 0x27
    lda 0x12
    bmi .fail
    lda 0xff
    bpl .fail
    ldx 0x02
    dex
    dex
    dex
    bmi .test27_1_ok
    jmp .fail
.test27_1_ok:
    lda 0xff
    clc
    adc 0x02
    bpl .test27_2_ok
    jmp .fail
.test27_2_ok:
    nop

.test28:                 ; Test #28: Y register
    ldo 0x28
    ldy 0x23
    iny
    iny
    cpy 0x25
    bne .fail
    dey
    cpy 0x24
    bne .fail
    ldy 0x66
    tya
    cmp 0x66
    bne .fail
    lda 0x33
    tay
    cpy 0x33
    bne .fail
    lda 0x01
    tya
    cmp 0x33
    bne .fail
    ldx 0x32
    inx
    cpx Y
    bne .fail

.test29:                 ; Test #29: E register
    ldo 0x29
    lde 0x66
    tey
    cpy 0x66
    bne .fail
    ldy 0x33
    tye
    cpe 0x33
    bne .fail
    ldy 0x01
    tey
    cpy 0x33
    bne .fail
    lde 0x12
    ldx 0x25   
    sec                 ; Set Carry        
    sbx E               ; 0x25 - 0x12 - notC (0) = 0x13
    cpx 0x13 
    bne .fail
    lde 0x21 
    ldx 0x25   
    clc                 ; Clear Carry        
    sbx E               ; 0x25 - 0x21 - notC (1) = 0x03
    cpx 0x03
    bne .fail 
    sec
    lde 0x20
    ror E               ; 0x20 >> 1 bit + carry = 0x90 
    cpe 0x90
    bne .fail
    clc
    lde 0x20  
    rol E               ; 0x20 << 1 bit = 0x40 
    cpe 0x40
    bne .fail
    ldx 0x3f
    inx
    cpx E
    bne .fail

.test30:                 ; Test #30: D register
    ldo 0x30
    ldd 0x66
    tdx
    cpx 0x66
    bne .fail
    ldx 0x33
    txd
    cpd 0x33
    bne .fail
    ldx 0x01
    tdx
    cpx 0x33
    bne .fail
    lda 0x10
    ldd 0x01
    clc                 ; Clear Carry        
    adc D               ; 0x10 + 0x01 = 0x11
    cmp 0x11            ; this set Carry   
    bne .fail
    adc D               ; 0x11 + 0x01 + Carry = 0x13
    cmp 0x13            ; this set Carry
    bne .fail
    clc                 ; Clear Carry   
    adc D               ; 0x13 + 0x01 = 0x14
    cmp 0x14            ; this set Carry
    bne .fail
    clc                 ; Clear Carry   
    sec                 ; Set Carry
    adc D               ; 0x14 + 0x01 + Carry = 0x16
    cmp 0x16            ; this set Carry
    bne .fail   
    sec
    ldd 0x20
    ror D               ; 0x20 >> 1 bit + carry = 0x90 
    cpd 0x90
    bne .fail
    clc
    ldd 0x20  
    rol D               ; 0x20 << 1 bit = 0x40 
    cpd 0x40
    bne .fail
    ldx 0x3f
    inx
    cpx D
    bne .fail

; .test31:                 ; Test #31: RND generator
;     ldo 0x31
;     lda 0x6012           ; Seed
;     lda 0x6012
; .test31_loop:
;     lda 0x6010
;     cmp 0x2a             ; try until test value is generated
;     bne .test31_loop

.test32:                ; Test #32: BIT
    ldo 0x32
    lda 0x23
    sta 0x8111
    lda 0x11
    bit 0x008111        ; Absolute - 0x23 and 0x11 != 0 
    beq .fail    
    bit 0x8111          ; Zero page - 0x23 and 0x11 != 0
    beq .fail           
    cmp 0x11            ; Acc is not changed
    bne .fail
    lda 0x04
    bit 0x8111          ; Zero page - 0x23 and 0x04 = 0
    bne .fail
    cmp 0x04            ; Acc is not changed
    bne .fail           
    bit 0x04            ; Immediate - 0x04 and 0x04 != 0
    beq .fail

.test33:                ; Test #33: ADD
    ldo 0x33
    lda 0x20
    sta 0x8130          ; 0x20 -> 0x8130 
    lda 0x04            ; 0x04 -> acc
    ldx 0x30            ; 0x30 -> x
    clc
    adc 0x8100,x        ; 0x04 (acc) + [0x8100 + 0x30 (x)] = 0x04 + [0x8130] = 0x04 + 0x20 = 0x24
    cmp 0x24
    bne .fail
    lda 0x02            ; 0x02 -> acc
    ldx 0x55            ; 0x55 -> x
    clc
    adc 0x80DB,x        ; 0x02 (acc) + [0x80DB + 0x55 (x)] = 0x02 + [0x8130] = 0x02 + 0x20 = 0x22
    cmp 0x22
    bne .fail 
    clc
    adc 0x0080DB,x      ; 0x22 (acc) + [0x80DB + 0x55 (x)] = 0x22 + [0x8130] = 0x22 + 0x20 = 0x42  (absolute)
    cmp 0x42
    bne .fail

.test34:                ; Test #34: Indirect
    ldo 0x34
    lda 0x25
    sta (.test34ptr1)
    lda 0x10
    lda (.test34ptr1)
    cmp 0x25
    bne .fail

    lda 0x2A
    sta (.test34ptr2)
    lda 0x10
    lda (.test34ptr2)
    cmp 0x2A
    bne .fail

    lda (.test34ptr1)
    cmp (.test34ptr2)
    beq .fail
    sta (.test34ptr2)
    cmp (.test34ptr2)
    bne .fail

    lda 0x50
    ldx 0x02
    sta (.test34ptr1),x
    lda 0x12
    ldy 0x02
    lda (.test34ptr1),y
    cmp 0x50
    bne .fail

    lda 0x34
    ldx 0x05
    ldy 0x05
    sta (.test34ptr1),y
    lda 0x12
    lda (.test34ptr1),x
    cmp 0x34
    bne .fail

    lda 0x35
    ldy 0x02
    ldx 0x07
    sta (.test34ptr2),x
    lda 0x20
    ldy 0x07
    cmp (.test34ptr2),y
    beq .fail
 
    lda 0x35
    cmp (.test34ptr2),x
    bne .fail

    jmp .test35

.test34ptr1:
    #d 0xFF, 0x80       ; PTR to 0x80FF (to test carry case)

.test34ptr2:
    #d 0x15, 0x80       ; PTR to 0x8015(to test non-carry case)



.test35:                ; Test #35: INW
    ldo 0x35
    lda 0x10            ; simple increment
    sta 0x8080
    lda 0x00
    sta 0x8081
    inw 0x8080
    bcs .fail

    lda 0x8080
    cmp 0x11
    bne .fail
    lda 0x8081
    cmp 0x00
    bne .fail
    
    lda 0xFF            ; inc MSB case
    sta 0x8080
    lda 0x04
    sta 0x8081
    inw 0x8080
    bcs .fail

    lda 0x8080
    cmp 0x00
    bne .fail
    lda 0x8081
    cmp 0x05
    bne .fail

    lda 0xFF            ; carry case
    sta 0x8080
    lda 0xFF
    sta 0x8081
    inw 0x8080
    bcc .fail

.test36:                ; Test #36: DEW
    ldo 0x36
    lda 0x10            ; simple decrement
    sta 0x8080
    lda 0x00
    sta 0x8081
    dew 0x8080
    bcc .fail
    lda 0x8080
    cmp 0x0F
    bne .fail
    lda 0x8081
    cmp 0x00
    bne .fail
    lda 0x00            ; dec MSB case
    sta 0x8080
    lda 0x04
    sta 0x8081
    dew 0x8080
    bcc .fail
    lda 0x8080
    cmp 0xFF
    bne .fail
    lda 0x8081
    cmp 0x03
    bne .fail
    lda 0x00            ; carry case
    sta 0x8080
    lda 0x00
    sta 0x8081
    dew 0x8080
    bcs .fail
    lda 0x8080
    cmp 0xFF
    bne .fail
    lda 0x8081
    cmp 0xFF
    bne .fail

.test99:                 ; Test #99: Test Stack (> 256 values)
    ldo 0x99
    lda 0x07
    ldx 0xFF
    pha
    lda 0x08
.test99push:    
    pha
    txa
    tao
    dex
    bne .test99push
    lda 0x09
    pha
    lda 0x00
    pla
    cmp 0x09
    bne .fail
    ldx 0xFF
.test99pull:    
    pla
    txa
    tao    
    dex
    bne .test99pull    
    pla
    cmp 0x07
    bne .fail

.testend:
    ldo 0x0E            ; Tests finished, jmp back to main program
    rts          

.fail:
    hlt


