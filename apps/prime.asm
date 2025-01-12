#include "../assembly/ruledef.asm"
#include "../kernel/symbols.asm"

#bankdef ram
{
    #addr 0x8400
    #size 0x6C00
    #outp 0
}

#bank ram

    LDD PrintMessage[15:8]
    LDE PrintMessage[7:0]
    jsr ACIA_SEND_STRING


    LDX 0x00                ; Initialize X to 0
    LDY 0x00                ; Initialize Y to 0

    ; Initialize the list of numbers:
    ; 1 represents that the number is prime, 0 that it is not.
    LDA 0x01              ; Set "prime" value (1)
InitializeList:
    STA PrimeMap,x          ; Store it at $9200+X
    INX
    CPX 0xFF              ; Compare X with 255
    BNE InitializeList    ; Continue until X < 256

    ; Set 0 and 1 as non-prime
    LDA 0x00
    STA PrimeMap             ; Set 0 as non-prime
    STA PrimeMap+1             ; Set 1 as non-prime

    ; Start the Sieve of Eratosthenes
SieveLoop:
    LDX 0x02              ; Start from number 2
NextPrime:
    LDA PrimeMap,x        ; Check if X is prime
    BEQ Skip              ; Skip if it’s not prime
    STX CurrentPrime      ; Store X as the current prime

    ; Mark multiples of X as non-prime
MultiplyLoop:
    TXA                   ; Load the current prime number
    CLC
    ADC CurrentPrime      ; Calculate the next multiple
    ; NOC                   
    BCS DoneMarking       ; Exit if Y > 255
    STA CurrentPrime
    TAY                   ; Save Y as the index

    LDA 0x00              ; Set as non-prime
    STA PrimeMap,y        ; Mark the multiple as non-prime
    JMP MultiplyLoop      ; Continue to the next multiple

DoneMarking:
    INX                   ; Move to the next number
    CPX 0xFF              ; Check if we’ve exceeded 255
    BCC NextPrime         ; Continue if X < 255
    JMP Print

Skip:
    INX                   ; Move to the next number if not prime
    CPX 0xFF              ; Check if we’ve exceeded 255
    BNE NextPrime         ; Continue if X < 255

Print:
    LDY 0x00              ; Initialize X to 0
    LDE 0x00
PrintLoop:
    LDA PrimeMap,y
    BEQ NotPrime

    PHX
    PHY
    TYA
    JSR byte_to_ascii 

    PHA
    TXA      
    JSR ACIA_SEND_CHAR
    TYA
    JSR ACIA_SEND_CHAR
    PLA
    JSR ACIA_SEND_CHAR

    PLY
    PLX
    LDA 0x20
    JSR ACIA_SEND_CHAR
    INE
    CPE 0x0A
    BNE NotPrime
    JSR ACIA_SEND_NEWLINE
    LDE 0x00
NotPrime:
    INY                   ; Move to the next number
    CPY 0xFF              ; Check if we’ve exceeded 255
    BCC PrintLoop         ; Continue if X < 255  

    JSR ACIA_SEND_NEWLINE

    RTS                   ; End of the program

; Variables
CurrentPrime:
    #d 0x00      ; Holds the current prime number

PrintMessage:
    #d 0x0A, 0x0D, "Finding prime numbers <256:", 0x0A, 0x0D, 0x00    

PrimeMap:
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    #d 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00



; Convert byte in A to ASCII decimal string
; Input: A register (0-255)
; Output: X,Y,A  

byte_to_ascii:
   
    pha               ; Store original number
    
    ; Handle hundreds digit
    ldx 0x00
    cmp 100
    bcc tens          ; If < 100, skip hundreds
    
    ; Divide by 100
    pla             
    sec
    ldy 0x00
hundreds_loop:
    cmp 100
    bcc hundreds_end
    sbc 100
    iny
    bcs hundreds_loop
    
hundreds_end:  
    ; Store remainder and convert hundreds to ASCII
    pha
    tya
    ora 0x30        ; Convert to ASCII
    tax             ; Store hundreds digit
    
tens:
    ; Handle tens digit
    ldy 0x00
    pla
    pha
    cmp 10
    bcc ones        ; If < 10, skip tens
    
    ; Divide by 10
    pla
    sec
    ldy 0x00
tens_loop:
    cmp 10
    bcc tens_end
    sbc 10
    iny
    bcs tens_loop

tens_end:    
    ; Store remainder and convert tens to ASCII
    pha
    tya
    ora 0x30        ; Convert to ASCII
    tay             ; Store tens digit
    
ones:
    ; Handle ones digit
    pla
    ora 0x30        ; Convert to ASCII
    rts