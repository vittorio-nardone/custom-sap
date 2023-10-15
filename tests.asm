#once

tests:
    ldo 0x7E            ; Tests started indicator


; test0:
;      ldo 0x00            ; Test #0
;      lda 0x10   
;      cmp 0x12            ; Clear Carry        
;      adc 0x01            ; 0x10 + 0x01 = 0x11
;      cmp 0x11            ; this set Carry   
;      bne fail
;      adc 0x01            ; 0x11 + 0x01 + Carry = 0x13
;      cmp 0x13
;      bne fail

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
     ldo 0x13            ; Test #13: ADC with/out Carry
     lda 0x10   
     cmp 0x12            ; Clear Carry        
     adc 0x01            ; 0x10 + 0x01 = 0x11
     cmp 0x11            ; this set Carry   
     bne fail
     adc 0x01            ; 0x11 + 0x01 + Carry = 0x13
     cmp 0x13
     bne fail    

testend:
    ldo 0x0E            ; Tests finished, jmp back to main program
    jmp main            

fail:
    hlt