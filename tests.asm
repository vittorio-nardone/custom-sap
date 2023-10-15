#once

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
        
testend:
    ldo 0x0E            ; Tests finished, jmp back to main program
    jmp main            

fail:
    hlt