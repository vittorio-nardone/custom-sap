#once
#ruledef
{
	HLT => 0xff  ; Freeze CPU 
	LDA {value: u8} => 0xa9 @ value 	; Load Accumulator with Memory (immediate) [Z]
	LDA {value: u16} => 0xad @ value 	; Load Accumulator with Memory (absolute) [Z]
	LDA {value: u16},x  => 0xbd @ value 	; Load Accumulator with Memory (absolute,X) [Z O]
	LDX {value: u8} => 0xa2 @ value 	; Load Index X with Memory (immediate) [Z]
	STA {value: u16} => 0x8d @ value 	; Store Accumulator in Memory (absolute) 
	STA {value: u16},x  => 0x9d @ value 	; Store Accumulator in Memory (absolute,X) [O]
	TAO => 0xab  ; Transfer Accumulator to Output 
	TXA => 0x8a  ; Transfer Index X to Accumulator 
	TAX => 0xaa  ; Transfer Accumulator to Index X 
	ADC {value: u8} => 0x69 @ value 	; Add Memory to Accumulator with Carry (immediate) 
	ADC {value: u16} => 0x6d @ value 	; Add Memory to Accumulator with Carry (absolute) 
	INC {value: u16} => 0xee @ value 	; Increment Memory by One (absolute) [Z]
	DEC {value: u16} => 0xce @ value 	; Decrement Memory by One (absolute) [Z]
	EOR {value: u8} => 0x49 @ value 	; Exclusive-OR Memory with Accumulator (immediate) [Z]
	CMP {value: u8} => 0xc9 @ value 	; Compare Memory with Accumulator (immediate) [Z C]
	JMP {value: u16} => 0x4c @ value 	; Jump to New Location (absolute) 
	JSR {value: u16} => 0x20 @ value 	; Jump to New Location Saving Return Address (absolute) 
	RTS => 0x60  ; Return from Subroutine 
	PHA => 0x48  ; Push Accumulator on Stack 
	PLA => 0x68  ; Pull Accumulator from Stack [Z]
	BEQ {value: u16} => 0xf0 @ value 	; Branch on Result Zero (absolute) 
	BNE {value: u16} => 0xd0 @ value 	; Branch on Result not Zero (absolute) 
	BCS {value: u16} => 0xb0 @ value 	; Branch on Carry Set (absolute) 
	BCC {value: u16} => 0x90 @ value 	; Branch on Carry Clear (absolute) 
	LDO {value: u8} => 0xfe @ value 	; Load Output with Memory (immediate) 
	LDO {value: u16} => 0xfd @ value 	; Load Output with Memory (absolute) 
	CLC => 0x18  ; Clear Carry Flag [C]
	SEC => 0x38  ; Set Carry Flag [C]
	NOP => 0xea  ; No Operation 
	BRK => 0x0  ; Jump to interrupt handler routine [I]
	RTI => 0x40  ; Return from Interrupt [I]
	SEI => 0x78  ; Set interrupt disable [I]
	CLI => 0x58  ; Clear interrupt disable [I]
}
