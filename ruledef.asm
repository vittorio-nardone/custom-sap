#once
#ruledef
{
	; Freeze CPU 
	HLT => { 
		0xFF
 	} 
	; Load Accumulator with Memory (immediate) [Z]
	LDA {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA9 @ value
 	} 
	; Load Accumulator with Memory (page) [Z]
	LDA {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xAD @ value
 	} 
	; Load Accumulator with Memory (absolute) [Z]
	LDA {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0xA7 @ value
 	} 
	; Load Accumulator with Memory (page,X) [Z O]
	LDA {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xBD @ value
 	} 
	; Load Index X with Memory (immediate) [Z]
	LDX {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA2 @ value
 	} 
	; Load Index X with Memory (page) [Z]
	LDX {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xA3 @ value
 	} 
	; Load Index X with Memory (absolute) [Z]
	LDX {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0xA4 @ value
 	} 
	; Store Accumulator in Memory (page) 
	STA {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x8D @ value
 	} 
	; Store Accumulator in Memory (absolute) 
	STA {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x8E @ value
 	} 
	; Store Accumulator in Memory (page,X) [O]
	STA {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x9D @ value
 	} 
	; Transfer Accumulator to Output 
	TAO => { 
		0xAB
 	} 
	; Transfer Interrupt register to Accumulator 
	TIA => { 
		0xAC
 	} 
	; Transfer Accumulator to Interrupt mask register 
	TAI => { 
		0xAE
 	} 
	; Transfer Index X to Accumulator 
	TXA => { 
		0x8A
 	} 
	; Transfer Accumulator to Index X 
	TAX => { 
		0xAA
 	} 
	; Add Memory to Accumulator with Carry (immediate) [Z C]
	ADC {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0x69 @ value
 	} 
	; Add Memory to Accumulator with Carry (page) [Z C]
	ADC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x6D @ value
 	} 
	; Subtract Memory from Accumulator with Borrow (immediate) [Z C]
	SBC {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE9 @ value
 	} 
	; Subtract Memory from Accumulator with Borrow (page) [Z C]
	SBC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xED @ value
 	} 
	; Increment Memory by One (page) [Z]
	INC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xEE @ value
 	} 
	; Increment Index X by One [Z]
	INX => { 
		0xE8
 	} 
	; Decrement Memory by One (page) [Z]
	DEC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xCE @ value
 	} 
	; Decrement Index X by One [Z]
	DEX => { 
		0xCA
 	} 
	; Exclusive-OR Memory with Accumulator (immediate) [Z]
	EOR {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0x49 @ value
 	} 
	; AND Memory with Accumulator (immediate) [Z]
	AND {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0x29 @ value
 	} 
	; Shift Left One Bit (accumulator) [Z C]
	ASL a => { 
		0x0A
 	} 
	; Compare Memory with Accumulator (immediate) [Z C]
	CMP {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xC9 @ value
 	} 
	; Compare Memory and Index X (immediate) [Z C]
	CPX {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE0 @ value
 	} 
	; Jump to New Location (page) 
	JMP {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x4C @ value
 	} 
	; Jump to New Location (absolute) 
	JMP {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x4D @ value
 	} 
	; Jump to New Location Saving Return Address (page) 
	JSR {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x20 @ value @ 0x00
 	} 
	; Jump to New Location Saving Return Address (absolute) 
	JSR {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x21 @ value
 	} 
	; Return from Subroutine 
	RTS => { 
		0x60
 	} 
	; Push Accumulator on Stack 
	PHA => { 
		0x48
 	} 
	; Pull Accumulator from Stack [Z]
	PLA => { 
		0x68
 	} 
	; Branch on Result Zero (page) 
	BEQ {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xF0 @ value
 	} 
	; Branch on Result not Zero (page) 
	BNE {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xD0 @ value
 	} 
	; Branch on Carry Set (page) 
	BCS {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xB0 @ value
 	} 
	; Branch on Carry Clear (page) 
	BCC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x90 @ value
 	} 
	; Load Output with Memory (immediate) 
	LDO {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xFE @ value
 	} 
	; Load Output with Memory (page) 
	LDO {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xFD @ value
 	} 
	; Clear Carry Flag [C]
	CLC => { 
		0x18
 	} 
	; Set Carry Flag [C]
	SEC => { 
		0x38
 	} 
	; No Operation 
	NOP => { 
		0xEA
 	} 
	; Jump to interrupt handler routine [I]
	BRK => { 
		0x00
 	} 
	; Return from Interrupt [I]
	RTI => { 
		0x40
 	} 
	; Set interrupt disable [I]
	SEI => { 
		0x78
 	} 
	; Clear interrupt disable [I]
	CLI => { 
		0x58
 	} 
}
