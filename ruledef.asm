#once
#ruledef
{
	; Freeze CPU 
	HLT => { 
		0xFF
 	} 
	; Set CPU speed to SLOW 
	SCS => { 
		0x01
 	} 
	; Set CPU speed to FAST 
	SCF => { 
		0x02
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
	; Load Accumulator with Memory (absolute,X) [Z O]
	LDA {value: u24},x  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0xBE @ value
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
	; Load Index Y with Memory (immediate) [Z]
	LDY {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA0 @ value
 	} 
	; Load Index D with Memory (immediate) [Z]
	LDD {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA5 @ value
 	} 
	; Load Index E with Memory (immediate) [Z]
	LDE {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA6 @ value
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
	; Transfer Index Y to Accumulator 
	TYA => { 
		0xBA
 	} 
	; Transfer Accumulator to Index Y 
	TAY => { 
		0xBB
 	} 
	; Transfer Index Y to Index E 
	TYE => { 
		0x8B
 	} 
	; Transfer Index E to Index Y 
	TEY => { 
		0x8C
 	} 
	; Transfer Index X to Index D 
	TXD => { 
		0x9B
 	} 
	; Transfer Index D to Index X 
	TDX => { 
		0x9C
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
	; Add Index D to Accumulator with Carry (Index D) [Z C]
	ADC d => { 
		0x6F
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
	; Subtract Index E from Index X with Borrow (Index X) [Z C]
	SBX e => { 
		0xEF
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
	; Increment Index Y by One [Z]
	INY => { 
		0xC8
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
	; Decrement Index Y by One [Z]
	DEY => { 
		0xCB
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
	; Rotate One Bit Left (accumulator) [Z N]
	ROL a => { 
		0x2A
 	} 
	; Rotate One Bit Left (Index E) [Z N]
	ROL e => { 
		0x2B
 	} 
	; Rotate One Bit Left (Index D) [Z N]
	ROL d => { 
		0x2C
 	} 
	; Rotate One Bit Left (page) [Z N]
	ROL {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x26 @ value
 	} 
	; Rotate One Bit Right (accumulator) [Z N]
	ROR a => { 
		0x6A
 	} 
	; Rotate One Bit Right (Index E) [Z N]
	ROR e => { 
		0x6B
 	} 
	; Rotate One Bit Right (Index D) [Z N]
	ROR d => { 
		0x6C
 	} 
	; Rotate One Bit Right (page) [Z N]
	ROR {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x66 @ value
 	} 
	; Compare Memory with Accumulator (immediate) [Z C]
	CMP {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xC9 @ value
 	} 
	; Compare Memory with Accumulator (page) [Z C]
	CMP {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x5C @ value
 	} 
	; Compare Memory and Index X (immediate) [Z C]
	CPX {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE0 @ value
 	} 
	; Compare Index Y and Index X (Index Y) [Z C]
	CPX y => { 
		0xE1
 	} 
	; Compare Index E and Index X (Index E) [Z C]
	CPX e => { 
		0xE2
 	} 
	; Compare Index E and Index X (Index D) [Z C]
	CPX d => { 
		0xEB
 	} 
	; Compare Memory and Index Y (immediate) [Z C]
	CPY {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE3 @ value
 	} 
	; Compare Memory with Index E (immediate) [Z C]
	CPE {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE4 @ value
 	} 
	; Compare Memory with Index D (immediate) [Z C]
	CPD {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE5 @ value
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
	; Branch on Result Minus (page) 
	BMI {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x30 @ value
 	} 
	; Branch on Result Plus (page) 
	BPL {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x10 @ value
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
