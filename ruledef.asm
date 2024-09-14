#once
#ruledef
{
	; Add Memory to Accumulator with Carry (absolute) [Z C]
	ADC {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x03 @ value
 	} 
	; Add Register D to Accumulator with Carry [Z C]
	ADC d => { 
		0x6F
 	} 
	; Add Register E to Accumulator with Carry [Z C]
	ADC e => { 
		0x06
 	} 
	; Add Memory to Accumulator with Carry (immediate) [Z C]
	ADC {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0x69 @ value
 	} 
	; Add Memory to Accumulator with Carry (zero page) [Z C]
	ADC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x6D @ value
 	} 
	; Add Memory to Accumulator (absolute - X index) [Z C]
	ADD {value: u24},x  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x05 @ value
 	} 
	; Add Memory to Accumulator (absolute - Y index) [Z C]
	ADD {value: u24},y  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x87 @ value
 	} 
	; Add Memory to Accumulator (zero page - X index) [Z C]
	ADD {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x04 @ value
 	} 
	; Add Memory to Accumulator (zero page - Y index) [Z C]
	ADD {value: u16},y  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x86 @ value
 	} 
	; AND Memory with Accumulator (absolute) [Z]
	AND {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x08 @ value
 	} 
	; AND Register D with Accumulator [Z]
	AND d => { 
		0x09
 	} 
	; AND Register E with Accumulator [Z]
	AND e => { 
		0x0A
 	} 
	; AND Memory with Accumulator (immediate) [Z]
	AND {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0x29 @ value
 	} 
	; AND Memory with Accumulator (zero page) [Z]
	AND {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x07 @ value
 	} 
	; Branch on Carry Clear (absolute) 
	BCC {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x19 @ value
 	} 
	; Branch on Carry Clear (zero page) 
	BCC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x90 @ value
 	} 
	; Branch on Carry Set (absolute) 
	BCS {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x22 @ value
 	} 
	; Branch on Carry Set (zero page) 
	BCS {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xB0 @ value
 	} 
	; Branch on Result Zero (absolute) 
	BEQ {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x23 @ value
 	} 
	; Branch on Result Zero (zero page) 
	BEQ {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xF0 @ value
 	} 
	; Test Accumulator BITs with Memory (absolute) [Z]
	BIT {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x17 @ value
 	} 
	; Test Accumulator BITs with Memory (immediate) [Z]
	BIT {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0x15 @ value
 	} 
	; Test Accumulator BITs with Memory (zero page) [Z]
	BIT {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x16 @ value
 	} 
	; Branch on Result Minus (absolute) 
	BMI {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x24 @ value
 	} 
	; Branch on Result Minus (zero page) 
	BMI {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x30 @ value
 	} 
	; Branch on Result not Zero (absolute) 
	BNE {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x25 @ value
 	} 
	; Branch on Result not Zero (zero page) 
	BNE {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xD0 @ value
 	} 
	; Branch on Result Plus (absolute) 
	BPL {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x27 @ value
 	} 
	; Branch on Result Plus (zero page) 
	BPL {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x10 @ value
 	} 
	; Jump to interrupt handler routine [I]
	BRK => { 
		0x00
 	} 
	; Branch on oVerflow Clear (absolute) 
	BVC {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x65 @ value
 	} 
	; Branch on oVerflow Clear (zero page) 
	BVC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x63 @ value
 	} 
	; Branch on oVerflow Set (absolute) 
	BVS {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x67 @ value
 	} 
	; Branch on oVerflow Set (zero page) 
	BVS {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x64 @ value
 	} 
	; Clear Carry Flag [C]
	CLC => { 
		0x18
 	} 
	; Clear interrupt disable [I]
	CLI => { 
		0x58
 	} 
	; Compare Memory with Accumulator (absolute) [Z C]
	CMP {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x42 @ value
 	} 
	; Compare Memory with Accumulator (immediate) [Z C]
	CMP {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xC9 @ value
 	} 
	; Compare Memory with Accumulator (zero page) [Z C]
	CMP {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x5C @ value
 	} 
	; Compare Memory with Register D (absolute) [Z C]
	CPD {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x44 @ value
 	} 
	; Compare Register E and Register D [Z C]
	CPD e => { 
		0x51
 	} 
	; Compare Memory with Register D (immediate) [Z C]
	CPD {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE5 @ value
 	} 
	; Compare Memory with Register D (zero page) [Z C]
	CPD {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x43 @ value
 	} 
	; Compare Memory with Register E (absolute) [Z C]
	CPE {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x46 @ value
 	} 
	; Compare Memory with Register E (immediate) [Z C]
	CPE {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE4 @ value
 	} 
	; Compare Memory with Register E (zero page) [Z C]
	CPE {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x45 @ value
 	} 
	; Compare Memory with Register X (absolute) [Z C]
	CPX {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x4A @ value
 	} 
	; Compare Register D and Register X [Z C]
	CPX d => { 
		0xEB
 	} 
	; Compare Register E and Register X [Z C]
	CPX e => { 
		0xE2
 	} 
	; Compare Memory and Register X (immediate) [Z C]
	CPX {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE0 @ value
 	} 
	; Compare Memory with Register X (zero page) [Z C]
	CPX {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x47 @ value
 	} 
	; Compare Register Y and Register X [Z C]
	CPX y => { 
		0xE1
 	} 
	; Compare Memory with Register Y (absolute) [Z C]
	CPY {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x4E @ value
 	} 
	; Compare Register D and Register Y [Z C]
	CPY d => { 
		0x4F
 	} 
	; Compare Register E and Register Y [Z C]
	CPY e => { 
		0x50
 	} 
	; Compare Memory and Register Y (immediate) [Z C]
	CPY {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE3 @ value
 	} 
	; Compare Memory with Register Y (zero page) [Z C]
	CPY {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x4B @ value
 	} 
	; Decrement Memory by One (absolute) [Z]
	DEC {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x53 @ value
 	} 
	; Decrement Memory by One (zero page) [Z]
	DEC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xCE @ value
 	} 
	; Decrement Register D by One [Z]
	DED => { 
		0x28
 	} 
	; Decrement Register E by One [Z]
	DEE => { 
		0x2D
 	} 
	; Decrement Register X by One [Z]
	DEX => { 
		0xCA
 	} 
	; Decrement Register Y by One [Z]
	DEY => { 
		0xCB
 	} 
	; Exclusive-OR Memory with Accumulator (absolute) [Z]
	EOR {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x12 @ value
 	} 
	; Exclusive-OR Register D with Accumulator [Z]
	EOR d => { 
		0x13
 	} 
	; Exclusive-OR Register E with Accumulator [Z]
	EOR e => { 
		0x14
 	} 
	; Exclusive-OR Memory with Accumulator (immediate) [Z]
	EOR {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0x49 @ value
 	} 
	; Exclusive-OR Memory with Accumulator (zero page) [Z]
	EOR {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x11 @ value
 	} 
	; Freeze CPU 
	HLT => { 
		0xFF
 	} 
	; Increment Memory by One (absolute) [Z]
	INC {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x52 @ value
 	} 
	; Increment Memory by One (zero page) [Z]
	INC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xEE @ value
 	} 
	; Increment Register D by One [Z]
	IND => { 
		0x2E
 	} 
	; Increment Register E by One [Z]
	INE => { 
		0x2F
 	} 
	; Increment Register X by One [Z]
	INX => { 
		0xE8
 	} 
	; Increment Register Y by One [Z]
	INY => { 
		0xC8
 	} 
	; Jump to New Location (absolute) 
	JMP {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x4D @ value
 	} 
	; Jump to New Location (zero page) 
	JMP {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x4C @ value
 	} 
	; Jump to New Location Saving Return Address (absolute) 
	JSR {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x21 @ value
 	} 
	; Jump to New Location Saving Return Address (zero page) 
	JSR {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x20 @ value @ 0x00
 	} 
	; Load Accumulator with Memory (absolute) [Z]
	LDA {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0xA7 @ value
 	} 
	; Load Accumulator with Memory (absolute - X index) [Z O]
	LDA {value: u24},x  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0xBE @ value
 	} 
	; Load Accumulator with Memory (absolute - Y index) [Z O]
	LDA {value: u24},y  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x32 @ value
 	} 
	; Load Accumulator with Memory (immediate) [Z]
	LDA {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA9 @ value
 	} 
	; Load Accumulator with Memory (zero page) [Z]
	LDA {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xAD @ value
 	} 
	; Load Accumulator with Memory (zero page - X index) [Z O]
	LDA {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xBD @ value
 	} 
	; Load Accumulator with Memory (zero page - Y index) [Z O]
	LDA {value: u16},y  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x31 @ value
 	} 
	; Load Register D with Memory (absolute) [Z]
	LDD {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x34 @ value
 	} 
	; Load Register D with Memory (immediate) [Z]
	LDD {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA5 @ value
 	} 
	; Load Register D with Memory (zero page) [Z]
	LDD {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x33 @ value
 	} 
	; Load Register E with Memory (absolute) [Z]
	LDE {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x36 @ value
 	} 
	; Load Register E with Memory (immediate) [Z]
	LDE {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA6 @ value
 	} 
	; Load Register E with Memory (zero page) [Z]
	LDE {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x35 @ value
 	} 
	; Load Output with Memory (absolute) 
	LDO {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x41 @ value
 	} 
	; Load Output with Memory (immediate) 
	LDO {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xFE @ value
 	} 
	; Load Output with Memory (zero page) 
	LDO {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xFD @ value
 	} 
	; Load Register X with Memory (absolute) [Z]
	LDX {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0xA4 @ value
 	} 
	; Load Register X with Memory (immediate) [Z]
	LDX {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA2 @ value
 	} 
	; Load Register X with Memory (zero page) [Z]
	LDX {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xA3 @ value
 	} 
	; Load Register Y with Memory (absolute) [Z]
	LDY {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x39 @ value
 	} 
	; Load Register Y with Memory (immediate) [Z]
	LDY {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xA0 @ value
 	} 
	; Load Register Y with Memory (zero page) [Z]
	LDY {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x37 @ value
 	} 
	; No Operation 
	NOP => { 
		0xEA
 	} 
	; OR Memory with Accumulator (absolute) [Z]
	ORA {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x0D @ value
 	} 
	; OR Register D with Accumulator [Z]
	ORA d => { 
		0x0E
 	} 
	; OR Register E with Accumulator [Z]
	ORA e => { 
		0x0F
 	} 
	; OR Memory with Accumulator (immediate) [Z]
	ORA {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0x0B @ value
 	} 
	; OR Memory with Accumulator (zero page) [Z]
	ORA {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x0C @ value
 	} 
	; Push Accumulator on Stack 
	PHA => { 
		0x48
 	} 
	; Pull Accumulator from Stack [Z]
	PLA => { 
		0x68
 	} 
	; Rotate One Bit Left (absolute) [Z N C]
	ROL {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x54 @ value
 	} 
	; Rotate One Bit Left (accumulator) [Z N C]
	ROL a => { 
		0x2A
 	} 
	; Rotate Register D One Bit Left [Z N C]
	ROL d => { 
		0x2C
 	} 
	; Rotate Register E One Bit Left [Z N C]
	ROL e => { 
		0x2B
 	} 
	; Rotate One Bit Left (zero page) [Z N C]
	ROL {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x26 @ value
 	} 
	; Rotate One Bit Right (absolute) [Z N C]
	ROR {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x55 @ value
 	} 
	; Rotate One Bit Right (accumulator) [Z N C]
	ROR a => { 
		0x6A
 	} 
	; otate Register D One Bit Right [Z N C]
	ROR d => { 
		0x6C
 	} 
	; Rotate Register E One Bit Right [Z N C]
	ROR e => { 
		0x6B
 	} 
	; Rotate One Bit Right (zero page) [Z N C]
	ROR {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x66 @ value
 	} 
	; Return from Interrupt [I]
	RTI => { 
		0x40
 	} 
	; Return from Subroutine 
	RTS => { 
		0x60
 	} 
	; Subtract Memory from Accumulator with Borrow (absolute) [Z C]
	SBC {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x5B @ value
 	} 
	; Subtract Register D from Accumulator with Borrow [Z C]
	SBC d => { 
		0x5D
 	} 
	; Subtract Register E from Accumulator with Borrow [Z C]
	SBC e => { 
		0x5E
 	} 
	; Subtract Memory from Accumulator with Borrow (immediate) [Z C]
	SBC {value: u8} => { 
		assert(value >= 0)
		assert(value <= 0xff)
		0xE9 @ value
 	} 
	; Subtract Memory from Accumulator with Borrow (zero page) [Z C]
	SBC {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0xED @ value
 	} 
	; Subtract Register E from Register X with Borrow [Z C]
	SBX e => { 
		0xEF
 	} 
	; Set clock speed to Fast 
	SCF => { 
		0x02
 	} 
	; Set clock speed to Slow 
	SCS => { 
		0x01
 	} 
	; Set Carry Flag [C]
	SEC => { 
		0x38
 	} 
	; Set interrupt disable [I]
	SEI => { 
		0x78
 	} 
	; Store Accumulator in Memory (absolute) 
	STA {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x8E @ value
 	} 
	; Store Accumulator in Memory (absolute - X index) [O]
	STA {value: u24},x  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x62 @ value
 	} 
	; Store Accumulator in Memory (absolute - Y index) [O]
	STA {value: u24},y  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x70 @ value
 	} 
	; Store Accumulator in Memory (zero page) 
	STA {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x8D @ value
 	} 
	; Store Accumulator in Memory (zero page - X index) [O]
	STA {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x9D @ value
 	} 
	; Store Accumulator in Memory (zero page - Y index) [O]
	STA {value: u16},y  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x6E @ value
 	} 
	; Store Register D in Memory (absolute) 
	STD {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x7B @ value
 	} 
	; Store Register D in Memory (absolute - X index) [O]
	STD {value: u24},x  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x7D @ value
 	} 
	; Store Register D in Memory (absolute - Y index) [O]
	STD {value: u24},y  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x7F @ value
 	} 
	; Store Register D in Memory (zero page) 
	STD {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x7A @ value
 	} 
	; Store Register D in Memory (zero page - X index) [O]
	STD {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x7C @ value
 	} 
	; Store Register D in Memory (zero page - Y index) [O]
	STD {value: u16},y  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x7E @ value
 	} 
	; Store Register E in Memory (absolute) 
	STE {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x81 @ value
 	} 
	; Store Register E in Memory (absolute - X index) [O]
	STE {value: u24},x  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x83 @ value
 	} 
	; Store Register E in Memory (absolute - Y index) [O]
	STE {value: u24},y  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x85 @ value
 	} 
	; Store Register E in Memory (zero page) 
	STE {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x80 @ value
 	} 
	; Store Register E in Memory (zero page - X index) [O]
	STE {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x82 @ value
 	} 
	; Store Register E in Memory (zero page - Y index) [O]
	STE {value: u16},y  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x84 @ value
 	} 
	; Store Register X in Memory (absolute) 
	STX {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x72 @ value
 	} 
	; Store Register X in Memory (absolute - Y index) [O]
	STX {value: u24},y  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x74 @ value
 	} 
	; Store Register X in Memory (zero page) 
	STX {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x71 @ value
 	} 
	; Store Register X in Memory (zero page - Y index) [O]
	STX {value: u16},y  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x73 @ value
 	} 
	; Store Register Y in Memory (absolute) 
	STY {value: u24} => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x76 @ value
 	} 
	; Store Register Y in Memory (absolute - X index) [O]
	STY {value: u24},x  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x79 @ value
 	} 
	; Store Register Y in Memory (zero page) 
	STY {value: u16} => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x75 @ value
 	} 
	; Store Register Y in Memory (zero page - X index) [O]
	STY {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x77 @ value
 	} 
	; Subtract Memory from Accumulator (absolute - X index) [Z C]
	SUB {value: u24},x  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x61 @ value
 	} 
	; Subtract Memory from Accumulator (absolute - Y index) [Z C]
	SUB {value: u24},y  => { 
		assert(value >= 0x10000)
		assert(value <= 0xffffff)
		0x89 @ value
 	} 
	; Subtract Memory from Accumulator (zero page - X index) [Z C]
	SUB {value: u16},x  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x5F @ value
 	} 
	; Subtract Memory from Accumulator (zero page - Y index) [Z C]
	SUB {value: u16},y  => { 
		assert(value >= 0)
		assert(value <= 0xffff)
		0x88 @ value
 	} 
	; Transfer Accumulator to Register D [Z]
	TAD => { 
		0x56
 	} 
	; Transfer Accumulator to Register E [Z]
	TAE => { 
		0x57
 	} 
	; Transfer Accumulator to Interrupt mask register 
	TAI => { 
		0xAE
 	} 
	; Transfer Accumulator to Output [Z]
	TAO => { 
		0xAB
 	} 
	; Transfer Accumulator to Register X [Z]
	TAX => { 
		0xAA
 	} 
	; Transfer Accumulator to Register Y [Z]
	TAY => { 
		0xBB
 	} 
	; Transfer Register D to Accumulator [Z]
	TDA => { 
		0x59
 	} 
	; Transfer Register D to Register X [Z]
	TDX => { 
		0x9C
 	} 
	; Transfer Register E to Accumulator [Z]
	TEA => { 
		0x5A
 	} 
	; Transfer Register E to Register Y [Z]
	TEY => { 
		0x8C
 	} 
	; Transfer Interrupt register to Accumulator [Z]
	TIA => { 
		0xAC
 	} 
	; Transfer Register X to Accumulator [Z]
	TXA => { 
		0x8A
 	} 
	; Transfer Register X to Register D [Z]
	TXD => { 
		0x9B
 	} 
	; Transfer Register Y to Accumulator [Z]
	TYA => { 
		0xBA
 	} 
	; Transfer Register Y to Register E [Z]
	TYE => { 
		0x8B
 	} 
}
