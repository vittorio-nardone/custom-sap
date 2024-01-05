#once
#ruledef
{
	HLT => 0xFF  ; Freeze CPU 
	LDA {value: u8} => 0xA9 @ value 	; Load Accumulator with Memory (immediate) [Z]
	LDA {value: u16} => 0xAD @ value 	; Load Accumulator with Memory (absolute) [Z]
	LDA {value: u16},x  => 0xBD @ value 	; Load Accumulator with Memory (absolute,X) [Z O]
	LDX {value: u8} => 0xA2 @ value 	; Load Index X with Memory (immediate) [Z]
	STA {value: u16} => 0x8D @ value 	; Store Accumulator in Memory (absolute) 
	STA {value: u16},x  => 0x9D @ value 	; Store Accumulator in Memory (absolute,X) [O]
	TAO => 0xAB  ; Transfer Accumulator to Output 
	TIA => 0xAC  ; Transfer Interrupt register to Accumulator 
	TXA => 0x8A  ; Transfer Index X to Accumulator 
	TAX => 0xAA  ; Transfer Accumulator to Index X 
	ADC {value: u8} => 0x69 @ value 	; Add Memory to Accumulator with Carry (immediate) [Z C]
	ADC {value: u16} => 0x6D @ value 	; Add Memory to Accumulator with Carry (absolute) [Z C]
	SBC {value: u8} => 0xE9 @ value 	; Subtract Memory from Accumulator with Borrow (immediate) [Z C]
	SBC {value: u16} => 0xED @ value 	; Subtract Memory from Accumulator with Borrow (absolute) [Z C]
	INC {value: u16} => 0xEE @ value 	; Increment Memory by One (absolute) [Z]
	DEC {value: u16} => 0xCE @ value 	; Decrement Memory by One (absolute) [Z]
	EOR {value: u8} => 0x49 @ value 	; Exclusive-OR Memory with Accumulator (immediate) [Z]
	ASL a => 0x0A  ; Shift Left One Bit (accumulator) [Z C]
	CMP {value: u8} => 0xC9 @ value 	; Compare Memory with Accumulator (immediate) [Z C]
	JMP {value: u16} => 0x4C @ value 	; Jump to New Location (absolute) 
	JSR {value: u16} => 0x20 @ value 	; Jump to New Location Saving Return Address (absolute) 
	RTS => 0x60  ; Return from Subroutine 
	PHA => 0x48  ; Push Accumulator on Stack 
	PLA => 0x68  ; Pull Accumulator from Stack [Z]
	BEQ {value: u16} => 0xF0 @ value 	; Branch on Result Zero (absolute) 
	BNE {value: u16} => 0xD0 @ value 	; Branch on Result not Zero (absolute) 
	BCS {value: u16} => 0xB0 @ value 	; Branch on Carry Set (absolute) 
	BCC {value: u16} => 0x90 @ value 	; Branch on Carry Clear (absolute) 
	LDO {value: u8} => 0xFE @ value 	; Load Output with Memory (immediate) 
	LDO {value: u16} => 0xFD @ value 	; Load Output with Memory (absolute) 
	CLC => 0x18  ; Clear Carry Flag [C]
	SEC => 0x38  ; Set Carry Flag [C]
	NOP => 0xEA  ; No Operation 
	BRK => 0x00  ; Jump to interrupt handler routine [I]
	RTI => 0x40  ; Return from Interrupt [I]
	SEI => 0x78  ; Set interrupt disable [I]
	CLI => 0x58  ; Clear interrupt disable [I]
}
