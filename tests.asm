#once
#addr 0x0200
tests:
    ldo 0x7E            ; Tests started indicator

test1:
    ldo 0x01            ; Test #1: JMP
    jmp test2
    hlt

test2:
    ldo 0x02            ; Test #2: LDA & CMP & BEQ
    lda 0x34            ; Load dummy value
    cmp 0x34
    beq test3
    hlt

test3:
    ldo 0x03            ; Test #3: LDA & CMP & BEQ
    lda 0x32            ; Load dummy value
    cmp 0x34
    beq fail

test4:
    ldo 0x04            ; Test #4: LDA & STA & BEQ
    lda 0x05
    sta 0x8000          ; First RAM byte
    lda 0x02            ; Reset
    lda 0x8000          ; Load from memory
    cmp 0x05            
    beq test5
    hlt

test5:
    ldo 0x05            ; Test #5: BNE
    lda 0x05
    cmp 0x03            
    bne test6
    hlt    

test6:
    ldo 0x06            ; Test #6: BNE
    lda 0x22
    cmp 0x22            
    bne fail

test7:                  
    ldo 0x07            ; Test #7: Z Flag on LDA
    lda 0x02
    cmp 0x05            ; Clear flag with CMP 
    lda 0x00            ; Set flag with LDA (from bus)
    bne fail
        
test8:                  
    ldo 0x08            ; Test #8: BCS (A > M - jmp)
    lda 0x13
    cmp 0x02                    
    bcs test9
    hlt

test9:                  
    ldo 0x09            ; Test #9: BCS (A < M - dont jmp)
    lda 0x23
    cmp 0x55                    
    bcs fail

test10:                  
    ldo 0x10            ; Test #10: BCC (A > M - don't jmp)
    lda 0x13
    cmp 0x02                    
    bcc fail

test11:                  
    ldo 0x11            ; Test #11: BCC (A < M - jmp)
    lda 0x23
    cmp 0x55                    
    bcc test12
    hlt

test12:                  
    ldo 0x12            ; Test #12: BCC (A = M - don't jmp)
    lda 0x73
    cmp 0x73                    
    bcc fail

test13:
    ldo 0x13            ; Test #13: ADC with/out Carry & CLC/SEC
    lda 0x10
    clc                 ; Clear Carry        
    adc 0x01            ; 0x10 + 0x01 = 0x11
    cmp 0x11            ; this set Carry   
    bne fail
    adc 0x01            ; 0x11 + 0x01 + Carry = 0x13
    cmp 0x13            ; this set Carry
    bne fail
    clc                 ; Clear Carry   
    adc 0x01            ; 0x13 + 0x01 = 0x14
    cmp 0x14            ; this set Carry
    bne fail
    clc                 ; Clear Carry   
    sec                 ; Set Carry
    adc 0x01            ; 0x14 + 0x01 + Carry = 0x16
    cmp 0x16            ; this set Carry
    bne fail   
    lda 0x55            ; test ADC absolute
    sta 0x8181
    lda 0x88
    clc
    adc 0x8181          ; 0x88 + 0x55 = 0xDD
    cmp 0xDD
    bne fail 
    lda 0x88
    sec
    adc 0x8181          ; 0x88 + 0x55 + Carry = 0xDE
    cmp 0xDE
    bne fail    
     
test14:
    ldo 0x14            ; Test #14: JSR & RTS
    lda 0x00
    jsr test14sub1
    cmp 0x04
    beq test15
    hlt
test14sub1:
    lda 0x01
    jsr test14sub2
    rts
test14sub2:
    lda 0x02
    jsr test14sub3
    rts
test14sub3:
    lda 0x03
    jsr test14sub4
    rts
test14sub4:
    lda 0x04
    rts

test15:                 ; Test #15: INC
    ldo 0x15
    lda 0xAF
    sta 0x8181
    lda 0x00
    inc 0x8181          ; check inc
    beq fail            ; zero flag must not be set
    lda 0x8181   
    cmp 0xB0
    bne fail
    lda 0xFF            
    sta 0x8181
    inc 0x8181          ; check if zero flag is set
    bne fail            ; zero flag must be set

test16:                 ; Test #16: DEC
    ldo 0x16
    lda 0xB0
    sta 0x8182
    lda 0x00
    dec 0x8182          ; check dec
    beq fail            ; zero flag must not be set
    lda 0x8182   
    cmp 0xAF
    bne fail    
    lda 0x01
    sta 0x8182
    dec 0x8182          ; check if zero flag is set
    bne fail            ; zero flag must be set

test17:                 ; Test #17: EOR
    ldo 0x17
    lda 0x22
    eor 0x44            ; 0x22 XOR 0x44 = 0x66    
    beq fail            ; zero flag must not be set
    cmp 0x66
    bne fail
    eor 0x66            ; 0x66 XOR 0x66 = 0x00
    bne fail            ; zero flag must be set

test18:                 ; Test #18: X registers
    ldo 0x18
    ldx 0x66
    txa
    cmp 0x66
    bne fail
    lda 0x33
    tax
    lda 0x01
    txa
    cmp 0x33
    bne fail

test19:                 ; Test #19: X index 
    ldo 0x19
    lda 0x34            ; Test lda with index (no carry)
    sta 0x8182          ; Store a value in 0x8182
    lda 0x00            ; Clean acc
    ldx 0x02            
    lda 0x8180,X        ; Load from 0x8180 + 0x02 (X) = 0x8182
    cmp 0x34            
    bne fail
    lda 0x36            ; Test lda with index (with carry)
    sta 0x8101          ; Store a value in 0x8101
    lda 0x00            ; Clean acc
    ldx 0x03
    lda 0x80FE,X        ; Load from 0x80FE + 0x03 (X) = 0x8101
    cmp 0x36
    bne fail
    lda 0x45            ; Test sta with index (with carry)
    ldx 0x03
    sta 0x81FE,X        ; Save to 0x81FE + 0x03 (X) = 0x8201
    lda 0x00            ; Clean acc
    lda 0x8201          ; Load directly
    cmp 0x44            
    beq fail
    cmp 0x45
    bne fail
    lda 0x23            ; Test sta with index (no carry)
    ldx 0x04
    sta 0x810E,X        ; Save to 0x810E + 0x04 (X) = 0x8112
    lda 0x00            ; Clean acc
    lda 0x8112          ; Load directly
    cmp 0x44            
    beq fail
    cmp 0x23
    bne fail   

test20:
    ldo 0x20            ; Test #20: SBC with/out Carry (Borrow)
    lda 0x25   
    sec                 ; Set Carry        
    sbc 0x12            ; 0x25 - 0x12 - notC (0) = 0x13
    cmp 0x13 
    bne fail 
    lda 0x25   
    clc                 ; Clear Carry        
    sbc 0x21            ; 0x25 - 0x21 - notC (1) = 0x03
    cmp 0x03
    bne fail 
    lda 0x55            ; test SBC absolute
    sta 0x8181    
    lda 0x59
    sec
    sbc 0x8181          ; 0x59 - 0x55 - notC (0) = 0x04
    cmp 0x04
    bne fail
    lda 0x59
    clc
    sbc 0x8181          ; 0x59 - 0x55 - notC (1) = 0x03
    cmp 0x03
    bne fail
    lda 0x37            ; test if Z flag is set
    sec
    sbc 0x37
    bne fail

test80:
    ldo 0x80            ; Test #80 (long): PHA / PLA
    lda 0x80
test80inc:   
    clc 
    adc 0x01
    tao
    pha
    cmp 0x92
    bne test80inc
test80dec:
    pla 
    tao
    cmp 0x81
    bne test80dec

testend:
    sei
    ldo 0x0E            ; Tests finished, jmp back to main program
    rts           

fail:
    hlt

