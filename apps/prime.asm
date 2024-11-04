#include "../ruledef.asm"
#include "../symbols.asm"

#bankdef ram
{
    #addr 0x9000
    #size 0x1000
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
    TYA
    JSR ACIA_SEND_HEX
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
