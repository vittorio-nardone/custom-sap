from intelhex import IntelHex

##################################################################
## Configuration
##
##
CONTROL_ROMS_COUNT = 6

##################################################################
## Control bits
##
##
CONTROL_BITS = {
    ## EEPROM #1 - Memory board
    "LMARL":        { "eeprom": 0, "bit": 0, "lowActive": False },
    "LMARH":        { "eeprom": 0, "bit": 1, "lowActive": False },
    "LMARPAGE":     { "eeprom": 0, "bit": 2, "lowActive": False },
    "MEMADDRVALID": { "eeprom": 0, "bit": 3, "lowActive": False },
    "LMARPAGEZERO": { "eeprom": 0, "bit": 4, "lowActive": False },
    "EMAR":         { "eeprom": 0, "bit": 5, "lowActive": False },
    "WRAM":         { "eeprom": 0, "bit": 6, "lowActive": False },
    "ERAM":         { "eeprom": 0, "bit": 7, "lowActive": False },
    ## EEPROM #2 - Alu board
    "LRALU-IN":     { "eeprom": 1, "bit": 0, "lowActive": False },
    "LRALU-OUT":    { "eeprom": 1, "bit": 1, "lowActive": False },
    "ALUS0":        { "eeprom": 1, "bit": 2, "lowActive": False },
    "ALUS1":        { "eeprom": 1, "bit": 3, "lowActive": False },
    "ALUS2":        { "eeprom": 1, "bit": 4, "lowActive": False },
    "ALUS3":        { "eeprom": 1, "bit": 5, "lowActive": False },
    "aluE0":        { "eeprom": 1, "bit": 6, "lowActive": False },
    "aluE1":        { "eeprom": 1, "bit": 7, "lowActive": False }, 
    ## EEPROM #3 - Alu/Flags board
    "notCLC":       { "eeprom": 2, "bit": 0, "lowActive": True },   
    "LO":           { "eeprom": 2, "bit": 1, "lowActive": False },   
    "LZN":          { "eeprom": 2, "bit": 2, "lowActive": False },   
    "LC":           { "eeprom": 2, "bit": 3, "lowActive": False },   
    "ERALU-OUT":    { "eeprom": 2, "bit": 4, "lowActive": False },   
    "alufE0":       { "eeprom": 2, "bit": 5, "lowActive": False },
    "alufE1":       { "eeprom": 2, "bit": 6, "lowActive": False },
    "alufE2":       { "eeprom": 2, "bit": 7, "lowActive": False },
    ## EEPROM #4 - Registers board
    "rL0":          { "eeprom": 3, "bit": 0, "lowActive": False },
    "rL1":          { "eeprom": 3, "bit": 1, "lowActive": False },
    "rL2":          { "eeprom": 3, "bit": 2, "lowActive": False },
    "rE0":          { "eeprom": 3, "bit": 3, "lowActive": False },
    "rE1":          { "eeprom": 3, "bit": 4, "lowActive": False },
    "rE2":          { "eeprom": 3, "bit": 5, "lowActive": False },
    "tmpS1":        { "eeprom": 3, "bit": 6, "lowActive": False },
    "tmpS0":        { "eeprom": 3, "bit": 7, "lowActive": False },
    ## EEPROM #5 - Instructions board
    "LIR":          { "eeprom": 4, "bit": 0, "lowActive": False },
    "CHKI":         { "eeprom": 4, "bit": 1, "lowActive": False },
    "notHLT":       { "eeprom": 4, "bit": 2, "lowActive": True },
    "notENAI":      { "eeprom": 4, "bit": 3, "lowActive": True },
    "LINT-MASK":    { "eeprom": 4, "bit": 4, "lowActive": False },
    "EINT-OUT":     { "eeprom": 4, "bit": 5, "lowActive": False }, 
    "notDISI":      { "eeprom": 4, "bit": 6, "lowActive": True },
    "notNOP":       { "eeprom": 4, "bit": 7, "lowActive": True },
    ## EEPROM #6 - PC/SP board
    "ESP":          { "eeprom": 5, "bit": 0, "lowActive": False },
    "EPCADDR":      { "eeprom": 5, "bit": 1, "lowActive": False },
    "CPC":          { "eeprom": 5, "bit": 2, "lowActive": False },
    "notCSP":       { "eeprom": 5, "bit": 3, "lowActive": True },
    "SPD":          { "eeprom": 5, "bit": 4, "lowActive": False },
    "pcE2":         { "eeprom": 5, "bit": 5, "lowActive": False }, 
    "pcE1":         { "eeprom": 5, "bit": 6, "lowActive": False },
    "pcE0":         { "eeprom": 5, "bit": 7, "lowActive": False },
}

##################################################################
## Common Control Words
##

######## In registries board
# Enable (OE) MUX
CC_notEACC = ['rE0']
CC_notEX   = ['rE1']
CC_notEY   = ['rE1', 'rE0']
CC_notETMP = ['rE2']
CC_notED   = ['rE2', 'rE0']
CC_notEE   = ['rE2', 'rE1']
CC_notLOWSPEED = ['rE2', 'rE1', 'rE0']

# Load (C) MUX
CC_LACC    = ['rL0']
CC_LX      = ['rL1']
CC_LY      = ['rL1', 'rL0']
CC_HIGHSPEED  = ['rL2']
CC_LD      = ['rL2', 'rL0']
CC_LE      = ['rL2', 'rL1']
CC_LOUT    = ['rL2', 'rL1', 'rL0']

CC_LTMP    = ['tmpS0', 'tmpS1']

######## In PC/SP board
# PC MUX
CC_notEPCL      = ['pcE0']
CC_notEPCH      = ['pcE1']
CC_notEPCPAGE   = ['pcE1', 'pcE0']
CC_notLPCL      = ['pcE2']
CC_notLPCH      = ['pcE2', 'pcE0']
CC_notLPCPAGE   = ['pcE2', 'pcE1']
CC_notLPCHP0    = ['pcE2', 'pcE1', 'pcE0'] # this load PC H and reset PC PAGE to zero

######## In ALU/Flags board
CC_CHKC     = ['alufE0']
CC_CHKZ     = ['alufE1']
CC_CHKN     = ['alufE1', 'alufE0']
CC_CHKO     = ['alufE2']
CC_EFRIN    = ['alufE2', 'alufE0']
CC_EFROUT   = ['alufE2', 'alufE1']
CC_SEC      = ['alufE2', 'alufE1', 'alufE0'] 

CC_ALUCN    = ['aluE0']  # set to 1 the CN input of the lower ALU
CC_ALUCARRY = ['aluE1']  # connect notCARRY to the CN input of the lower ALU
CC_ALUM     = ['aluE1', 'aluE0'] # set to 1 the M input of the both ALUs

######## 
CC_LOAD_PC_POINTED_RAM_INTO_IR      = ['LIR', 'ERAM', 'EPCADDR', 'MEMADDRVALID']
CC_PC_INCREMENT                     = ['CPC']
CC_LAST_T                           = ['notNOP']

CC_INC_STACK_POINTER           = ['SPD', 'notCSP']
CC_DEC_STACK_POINTER           = ['notCSP']

CC_ALU_DETECT_ZERO             = ['LRALU-IN', 'aluE1', 'aluE0']

DEFAULT_T0 = [ CC_LOAD_PC_POINTED_RAM_INTO_IR + ['CHKI'], CC_PC_INCREMENT ]

##################################################################
## Instructions
##
##
    # "NAM":                                                    <- the name (truncated to 3 chars) [required]
    #       {     "c": 0x00,                                    <- the op code of the instruction [required]
    #             "d": "Jump to interrupt handler routine",     <- instruction description [required]      
    #             "b": [0x12, 0x34],                            <- add bytes after op code
    #             "f": ['Z'],                                   <- flags affected
    #             "v": "u8",                                    <- operand value definition (u8/u16)
    #             "w": True,                                    <- boolean, True if operator is a 16bit Word (ptr to LSB provided, ptr to MSB calculated by assembler)
    #             "op": "a",                                    <- operand label (no real value) 
    #             "i": "x",                                     <- index registry (only when v defined)  
    #             "t0": [                                       <- fetch cycles (if not defined, the default one is used)
    #                     CC_LOAD_PC_POINTED_RAM_INTO_IR,
    #                 ],
    #             "m": [                                        <- control words (NOP is automatically added to the last one) [required]
    #                     ['ESP', 'CHKZ'],
    #                     CC_INC_STACK_POINTER + ['LX'],
    #                 ] },    
    #             "true": [                                     <- if checked condition is verified (i.e. CHKZ), these control words are executed
    #                   ['CPC'], 
    #                   ['CPC'], 
    #                ] },  

INSTRUCTIONS_SET = dict(sorted({
    "HLT": {    "c": 0xFF,  
                "d": "Freeze CPU",  
                "sim": "self.HLT = True", 
                "m": [ ['notHLT'] ] },

    "SCS": {    "c": 0x01,  
                "d": "Set clock speed to Slow", 
                "sim": "self.PC += 1",   
                "m": [ CC_notLOWSPEED ] },

    "SCF": {    "c": 0x02,  
                "d": "Set clock speed to Fast",  
                "sim": "self.PC += 1",
                "m": [ CC_HIGHSPEED ] },

    "LDAi": {   "c": 0xA9,  
                "d": "Load Accumulator with Memory (immediate)", 
                "f": ['Z','N'],
                "v": "u8",
                "sim": "self.A = self.load_from_memory(immediate=True)",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },

    "LDAp": {   "c": 0xAD,  
                "d": "Load Accumulator with Memory (zero page)", 
                "f": ['Z','N'],
                "v": "u16",
                "sim": "self.A = self.load_from_memory(mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },

    "LDAa": {   "c": 0xA7,  
                "d": "Load Accumulator with Memory (absolute)", 
                "f": ['Z','N'],
                "v": "u24",
                "sim": "self.A = self.load_from_memory(mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },

    "LDAindp": {   "c": 0xB1,  
                "d": "Load Accumulator with Memory (indirect - zero page)", 
                "f": ['Z','N'],
                "v": "u16",
                "sim": "self.A = self.load_from_memory(mem_operands_size=2, indirect=True)",
                "m": [  
                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LACC,    

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP,     

                        # set address and load value in ACC
                        ['LMARL'] + CC_notEACC,
                        ['LMARH'] + CC_notETMP,
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP,  

                        # set address and load value in ACC
                        ['LMARL'] + CC_notEACC,
                        ['LMARH'] + CC_notETMP,
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },

    "LDApx": {  "c": 0xBD,  # Cross page not supported
                "d": "Load Accumulator with Memory (zero page - X index)", 
                "f": ['Z','O','N'],
                "v": "u16",
                "i": "x",
                "sim": "self.A = self.load_from_memory(mem_operands_size=2, index=self.X)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LACC,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEACC,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] }, 

    "LDAindpx": {   "c": 0xBC,  
                "d": "Load Accumulator with Memory (indirect - zero page - X index)", 
                "f": ['Z','N','C'], # the Carry is set according to LSB + X > 0xFF
                "v": "u16",
                "i": "x",
                "sim": "self.A = self.load_from_memory(mem_operands_size=2, indirect=True, index=self.X)",
                "m": [  
                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB + X
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN'],
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEX + CC_ALUCN,   
                        ['ERALU-OUT'] + CC_LACC,

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,     

                        # set address and load value in ACC
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,  

                        # set address and load value in ACC
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     

    "LDAdepx": {  "c": 0x94,  # Cross page not supported
                "d": "Load Accumulator with Memory (DE pointer - zero page - X index)", 
                "f": ['Z','O','N'],
                "op": "de",
                "i": "x",
                "sim": "self.A = self.load_from_memory(registry_operands='de', index=self.X)",
                "m": [  
                        ['LMARPAGEZERO', 'LRALU-IN'] + CC_notEE, 
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notED,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notED,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },   
          
    "LDAydeax": {  "c": 0xB2,  # Cross page not supported
                "d": "Load Accumulator with Memory (YDE pointer - absolute - X index)", 
                "f": ['Z','O','N'],
                "op": "yde",
                "i": "x",
                "sim": "self.A = self.load_from_memory(registry_operands='yde', index=self.X)",
                "m": [  
                        ['LMARPAGE'] + CC_notEY,
                        ['LRALU-IN'] + CC_notEE, 
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notED,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notED,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },                      

    "LDAax": {  "c": 0xBE,  # Cross page not supported
                "d": "Load Accumulator with Memory (absolute - X index)", 
                "f": ['Z','O','N'],
                "v": "u24",
                "i": "x",
                "sim": "self.A = self.load_from_memory(mem_operands_size=3, index=self.X)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LACC,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEACC,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },               

    "LDApy": {  "c": 0x31,  # Cross page not supported
                "d": "Load Accumulator with Memory (zero page - Y index)", 
                "f": ['Z','O','N'],
                "v": "u16",
                "i": "y",
                "sim": "self.A = self.load_from_memory(mem_operands_size=2, index=self.Y)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LACC,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEACC,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     

    "LDAindpy": {   "c": 0xC1,  
                "d": "Load Accumulator with Memory (indirect - zero page - Y index)", 
                "f": ['Z','N','C'], # the Carry is set according to LSB + Y > 0xFF
                "v": "u16",
                "i": "y",
                "sim": "self.A = self.load_from_memory(mem_operands_size=2, indirect=True, index=self.Y)",
                "m": [  
                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB + Y
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN'],
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEY + CC_ALUCN,   
                        ['ERALU-OUT'] + CC_LACC,

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,     

                        # set address and load value in ACC
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,  

                        # set address and load value in ACC
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },      

    "LDAay": {  "c": 0x32,  # Cross page not supported
                "d": "Load Accumulator with Memory (absolute - Y index)", 
                "f": ['Z','O','N'],
                "v": "u24",
                "i": "y",
                "sim": "self.A = self.load_from_memory(mem_operands_size=3, index=self.Y)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LACC,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEACC,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },               


    "LDXi": {   "c": 0xA2,  
                "d": "Load Register X with Memory (immediate)", 
                "f": ['Z','N'],
                "v": "u8",
                "sim": "self.X = self.load_from_memory(immediate=True)",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR', 'MEMADDRVALID'] + CC_LX + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },               

    "LDXp": {   "c": 0xA3,  
                "d": "Load Register X with Memory (zero page)", 
                "f": ['Z','N'],
                "v": "u16",
                "sim": "self.X = self.load_from_memory(mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },

    "LDXa": {   "c": 0xA4,  
                "d": "Load Register X with Memory (absolute)", 
                "f": ['Z','N'],
                "v": "u24",
                "sim": "self.X = self.load_from_memory(mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },

    "LDXpy": {  "c": 0x1C,  # Cross page not supported
                "d": "Load Register X with Memory (zero page - Y index)", 
                "f": ['Z','O','N'],
                "v": "u16",
                "i": "y",
                "sim": "self.X = self.load_from_memory(mem_operands_size=2, index=self.Y)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LX,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notEX,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEX,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },     

    "LDYi": {   "c": 0xA0,  
                "d": "Load Register Y with Memory (immediate)", 
                "f": ['Z','N'],
                "v": "u8",
                "sim": "self.Y = self.load_from_memory(immediate=True)",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR', 'MEMADDRVALID'] + CC_LY + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },   

    "LDYp": {   "c": 0x37,  
                "d": "Load Register Y with Memory (zero page)", 
                "f": ['Z','N'],
                "v": "u16",
                "sim": "self.Y = self.load_from_memory(mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LY + CC_ALU_DETECT_ZERO 
                    ] },

    "LDYa": {   "c": 0x39,  
                "d": "Load Register Y with Memory (absolute)", 
                "f": ['Z','N'],
                "v": "u24",
                "sim": "self.Y = self.load_from_memory(mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LY + CC_ALU_DETECT_ZERO 
                    ] },                        

    "LDYpx": {  "c": 0x1D,  # Cross page not supported
                "d": "Load Register Y with Memory (zero page - X index)", 
                "f": ['Z','O','N'],
                "v": "u16",
                "i": "x",
                "sim": "self.Y = self.load_from_memory(mem_operands_size=2, index=self.X)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LY,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notEY,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LY + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEY,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LY + CC_ALU_DETECT_ZERO 
                    ] },    

    "LDDi": {   "c": 0xA5,  
                "d": "Load Register D with Memory (immediate)", 
                "f": ['Z','N'],
                "v": "u8",
                "sim": "self.D = self.load_from_memory(immediate=True)",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR', 'MEMADDRVALID'] + CC_LD + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },   

    "LDDp": {   "c": 0x33,  
                "d": "Load Register D with Memory (zero page)", 
                "f": ['Z','N'],
                "v": "u16",
                "sim": "self.D = self.load_from_memory(mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LD + CC_ALU_DETECT_ZERO 
                    ] },

    "LDDa": {   "c": 0x34,  
                "d": "Load Register D with Memory (absolute)", 
                "f": ['Z','N'],
                "v": "u24",
                "sim": "self.D = self.load_from_memory(mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LD + CC_ALU_DETECT_ZERO 
                    ] },   

    "LDDpx": {  "c": 0x1E,  # Cross page not supported
                "d": "Load Register D with Memory (zero page - X index)", 
                "f": ['Z','O','N'],
                "v": "u16",
                "i": "x",
                "sim": "self.D = self.load_from_memory(mem_operands_size=2, index=self.X)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LD,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notED,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LD + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notED,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LD + CC_ALU_DETECT_ZERO 
                    ] },                     

    "LDEi": {   "c": 0xA6,  
                "d": "Load Register E with Memory (immediate)", 
                "f": ['Z','N'],
                "v": "u8",
                "sim": "self.E = self.load_from_memory(immediate=True)",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR', 'MEMADDRVALID'] + CC_LE + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },   

    "LDEp": {   "c": 0x35,  
                "d": "Load Register E with Memory (zero page)", 
                "f": ['Z','N'],
                "v": "u16",
                "sim": "self.E = self.load_from_memory(mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LE + CC_ALU_DETECT_ZERO 
                    ] },

    "LDEa": {   "c": 0x36,  
                "d": "Load Register E with Memory (absolute)", 
                "f": ['Z','N'],
                "v": "u24",
                "sim": "self.E = self.load_from_memory(mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LE + CC_ALU_DETECT_ZERO 
                    ] },      

    "LDEpx": {  "c": 0x1F,  # Cross page not supported
                "d": "Load Register E with Memory (zero page - X index)", 
                "f": ['Z','O','N'],
                "v": "u16",
                "i": "x",
                "sim": "self.E = self.load_from_memory(mem_operands_size=2, index=self.X)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LE,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notEE,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LE + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notED,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LE + CC_ALU_DETECT_ZERO 
                    ] },                 

    "STAp": {   "c": 0x8D,  
                "d": "Store Accumulator in Memory (zero page)", 
                "v": "u16",
                "sim":  "self.store_in_memory(self.A, mem_operands_size=2)", 
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ] },      

    "STAa": {   "c": 0x8E,  
                "d": "Store Accumulator in Memory (absolute)", 
                "v": "u24",
                "sim":  "self.store_in_memory(self.A, mem_operands_size=3)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ] },  

    "STAindp": {   "c": 0xB8,  
                "d": "Store Accumulator in Memory (indirect - zero page)", 
                "v": "u16",
                "sim":  "self.store_in_memory(self.A, mem_operands_size=2, indirect=True)", 
                "t0": [ 
                        CC_LOAD_PC_POINTED_RAM_INTO_IR + ['CHKI'] 
                      ],                 
                 "m": [  
                        # store acc value in stack
                        ['CPC', 'ESP', 'WRAM'] + CC_notEACC,

                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LACC,    

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP,     

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH'] + CC_notETMP,

                        # restore ACC value and save it
                        ['ESP', 'ERAM'] + CC_LACC,
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP,  

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH'] + CC_notETMP,

                        # restore ACC value and save it
                        ['ESP', 'ERAM'] + CC_LACC,
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC
                    ] },  

    "STApx": {  "c": 0x9D,  # Cross page not supported
                "d": "Store Accumulator in Memory (zero page - X index)", 
                "v": "u16",
                "i": "x",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.A, mem_operands_size=2, index=self.X)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC,
                    ] },   

    "STAindpx": {   "c": 0xBF,  
                "d": "Store Accumulator in Memory (indirect - zero page - X index)", 
                "f": ['C'], # the Carry is set according to LSB + X > 0xFF
                "v": "u16",
                "i": "x",
                "sim":  "self.store_in_memory(self.A, mem_operands_size=2, indirect=True, index=self.X)", 
                "t0": [ 
                        CC_LOAD_PC_POINTED_RAM_INTO_IR + ['CHKI'] 
                      ],                 
                "m": [  
                        # store acc value in stack
                        ['CPC', 'ESP', 'WRAM'] + CC_notEACC,

                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB + X
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN'],
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEX + CC_ALUCN,   
                        ['ERALU-OUT'] + CC_LACC,

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,   

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],

                        # restore ACC value and save it
                        ['ESP', 'ERAM'] + CC_LACC,
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,  

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],

                        # restore ACC value and save it
                        ['ESP', 'ERAM'] + CC_LACC,
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC
                    ] },  

    "STAdepx": {  "c": 0xA1,  # Cross page not supported
                "d": "Store Accumulator in Memory (DE pointer - zero page - X index)", 
                "i": "x",
                "op": "de",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.A, registry_operands='de', index=self.X)",
                "m": [  
                        ['LMARPAGEZERO', 'LRALU-IN'] + CC_notEE, 
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notED,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notED,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC,
                    ] },         

    "STAydeax": {  "c": 0xB3,  # Cross page not supported
                "d": "Store Accumulator in Memory (YDE pointer - absolute - X index)", 
                "i": "x",
                "op": "yde",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.A, registry_operands='yde', index=self.X)",
                "m": [  
                        ['LMARPAGE'] + CC_notEY,
                        ['LRALU-IN'] + CC_notEE, 
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notED,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notED,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC,
                    ] },                   

    "STAax": {  "c": 0x62,  # Cross page not supported
                "d": "Store Accumulator in Memory (absolute - X index)", 
                "v": "u24",
                "i": "x",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.A, mem_operands_size=3, index=self.X)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],            
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC,
                    ] },                       

    "STApy": {  "c": 0x6E,  # Cross page not supported
                "d": "Store Accumulator in Memory (zero page - Y index)", 
                "v": "u16",
                "i": "y",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.A, mem_operands_size=2, index=self.Y)", 
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC,
                    ] },   

    "STAindpy": {   "c": 0xC2,  
                "d": "Store Accumulator in Memory (indirect - zero page - Y index)", 
                "f": ['C'], # the Carry is set according to LSB + Y > 0xFF
                "v": "u16",
                "i": "y",
                "sim":  "self.store_in_memory(self.A, mem_operands_size=2, indirect=True, index=self.Y)", 
                "t0": [ 
                        CC_LOAD_PC_POINTED_RAM_INTO_IR + ['CHKI'] 
                      ],                 
                "m": [  
                        # store acc value in stack
                        ['CPC', 'ESP', 'WRAM'] + CC_notEACC,

                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB + X
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN'],
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEY + CC_ALUCN,   
                        ['ERALU-OUT'] + CC_LACC,

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,   

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],

                        # restore ACC value and save it
                        ['ESP', 'ERAM'] + CC_LACC,
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,  

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],

                        # restore ACC value and save it
                        ['ESP', 'ERAM'] + CC_LACC,
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC
                    ] }, 

    "STAay": {  "c": 0x70,  # Cross page not supported
                "d": "Store Accumulator in Memory (absolute - Y index)", 
                "v": "u24",
                "i": "y",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.A, mem_operands_size=3, index=self.Y)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],            
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC,
                    ] },    

    "STXp": {   "c": 0x71,  
                "d": "Store Register X in Memory (zero page)", 
                "v": "u16",
                "sim":  "self.store_in_memory(self.X, mem_operands_size=2)", 
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEX  
                    ] },      

    "STXa": {   "c": 0x72,  
                "d": "Store Register X in Memory (absolute)", 
                "v": "u24",
                "sim":  "self.store_in_memory(self.X, mem_operands_size=3)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEX  
                    ] },  

    "STXpy": {  "c": 0x73,  # Cross page not supported
                "d": "Store Register X in Memory (zero page - Y index)", 
                "v": "u16",
                "i": "y",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.X, mem_operands_size=2, index=self.Y)", 
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEX  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEX,
                    ] },   

    "STXay": {  "c": 0x74,  # Cross page not supported
                "d": "Store Register X in Memory (absolute - Y index)", 
                "v": "u24",
                "i": "y",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.X, mem_operands_size=3, index=self.Y)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],            
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEX  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEX,
                    ] },                        

    "STYp": {   "c": 0x75,  
                "d": "Store Register Y in Memory (zero page)", 
                "v": "u16",
                "sim":  "self.store_in_memory(self.Y, mem_operands_size=2)", 
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEY  
                    ] },      

    "STYa": {   "c": 0x76,  
                "d": "Store Register Y in Memory (absolute)", 
                "v": "u24",
                "sim":  "self.store_in_memory(self.Y, mem_operands_size=3)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEY  
                    ] },  

    "STYpx": {  "c": 0x77,  # Cross page not supported
                "d": "Store Register Y in Memory (zero page - X index)", 
                "v": "u16",
                "i": "x",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.Y, mem_operands_size=2, index=self.X)", 
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEY  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEY,
                    ] },   

    "STYax": {  "c": 0x79,  # Cross page not supported
                "d": "Store Register Y in Memory (absolute - X index)", 
                "v": "u24",
                "i": "x",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.Y, mem_operands_size=3, index=self.X)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],            
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEY  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEY,
                    ] },   

   "STDp": {   "c": 0x7A,  
                "d": "Store Register D in Memory (zero page)", 
                "v": "u16",
                "sim":  "self.store_in_memory(self.D, mem_operands_size=2)", 
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED  
                    ] },      

    "STDa": {   "c": 0x7B,  
                "d": "Store Register D in Memory (absolute)", 
                "v": "u24",
                "sim":  "self.store_in_memory(self.D, mem_operands_size=3)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED  
                    ] },  

    "STDpx": {  "c": 0x7C,  # Cross page not supported
                "d": "Store Register D in Memory (zero page - X index)", 
                "v": "u16",
                "i": "x",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.D, mem_operands_size=2, index=self.X)", 
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED,
                    ] },   

    "STDax": {  "c": 0x7D,  # Cross page not supported
                "d": "Store Register D in Memory (absolute - X index)", 
                "v": "u24",
                "i": "x",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.D, mem_operands_size=3, index=self.X)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],            
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED,
                    ] },                       

    "STDpy": {  "c": 0x7E,  # Cross page not supported
                "d": "Store Register D in Memory (zero page - Y index)", 
                "v": "u16",
                "i": "y",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.D, mem_operands_size=2, index=self.Y)", 
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED,
                    ] },   

    "STDay": {  "c": 0x7F,  # Cross page not supported
                "d": "Store Register D in Memory (absolute - Y index)", 
                "v": "u24",
                "i": "y",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.D, mem_operands_size=3, index=self.Y)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],            
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notED,
                    ] },                       

   "STEp": {   "c": 0x80,  
                "d": "Store Register E in Memory (zero page)", 
                "v": "u16",
                "sim":  "self.store_in_memory(self.E, mem_operands_size=2)", 
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE  
                    ] },      

    "STEa": {   "c": 0x81,  
                "d": "Store Register E in Memory (absolute)", 
                "v": "u24",
                "sim":  "self.store_in_memory(self.E, mem_operands_size=3)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE  
                    ] },  

    "STEpx": {  "c": 0x82,  # Cross page not supported
                "d": "Store Register E in Memory (zero page - X index)", 
                "v": "u16",
                "i": "x",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.E, mem_operands_size=2, index=self.X)", 
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE,
                    ] },   

    "STEax": {  "c": 0x83,  # Cross page not supported
                "d": "Store Register E in Memory (absolute - X index)", 
                "v": "u24",
                "i": "x",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.E, mem_operands_size=3, index=self.X)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],            
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE,
                    ] },                       

    "STEpy": {  "c": 0x84,  # Cross page not supported
                "d": "Store Register E in Memory (zero page - Y index)", 
                "v": "u16",
                "i": "y",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.E, mem_operands_size=2, index=self.Y)", 
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE,
                    ] },   

    "STEay": {  "c": 0x85,  # Cross page not supported
                "d": "Store Register E in Memory (absolute - Y index)", 
                "v": "u24",
                "i": "y",
                "f": ['O'],
                "sim":  "self.store_in_memory(self.E, mem_operands_size=3, index=self.Y)", 
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],            
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP, 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEE,
                    ] },      

    "TAO":  {   "c": 0xAB,  
                "d": "Transfer Accumulator to Output", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('A', 'OUT')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LOUT + CC_notEACC  
                    ] },     

    "TIA":  {   "c": 0xAC,  
                "d": "Transfer Interrupt register to Accumulator", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('INT', 'A')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + ['EINT-OUT'] + CC_LACC 
                    ] }, 

    "TAI":  {   "c": 0xAE,  
                "d": "Transfer Accumulator to Interrupt mask register", 
                "sim": "self.transfer('A', 'INT')",
                "m": [  
                        ['LINT-MASK'] + CC_notEACC, 
                    ] }, 

    "TXA":  {   "c": 0x8A,  
                "d": "Transfer Register X to Accumulator", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('X', 'A')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LACC + CC_notEX 
                    ] },     

    "TAX":  {   "c": 0xAA,  
                "d": "Transfer Accumulator to Register X", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('A', 'X')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LX + CC_notEACC 
                    ] },   


    "TYA":  {   "c": 0xBA,  
                "d": "Transfer Register Y to Accumulator", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('Y', 'A')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LACC + CC_notEY  
                    ] },  

    "TAY":  {   "c": 0xBB,  
                "d": "Transfer Accumulator to Register Y", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('A', 'Y')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LY + CC_notEACC  
                    ] },  

    "TYE":  {   "c": 0x8B,  
                "d": "Transfer Register Y to Register E", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('Y', 'E')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LE + CC_notEY 
                    ] },                                     

    "TEY":  {   "c": 0x8C,  
                "d": "Transfer Register E to Register Y", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('E', 'Y')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LY + CC_notEE 
                    ] },   

    "TXD":  {   "c": 0x9B,  
                "d": "Transfer Register X to Register D", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('X', 'D')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LD + CC_notEX 
                    ] },                                     

    "TDX":  {   "c": 0x9C,  
                "d": "Transfer Register D to Register X", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('D', 'X')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LX + CC_notED 
                    ] },   

    "TAD":  {   "c": 0x56,  
                "d": "Transfer Accumulator to Register D", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('A', 'D')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LD + CC_notEACC  
                    ] },     

    "TAE":  {   "c": 0x57,  
                "d": "Transfer Accumulator to Register E", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('A', 'E')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LE + CC_notEACC  
                    ] },     

    "TDA":  {   "c": 0x59,  
                "d": "Transfer Register D to Accumulator", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('D', 'A')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LACC + CC_notED  
                    ] },     

    "TEA":  {   "c": 0x5A,  
                "d": "Transfer Register E to Accumulator", 
                "f": ['Z', 'N'],
                "sim": "self.transfer('E', 'A')",
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LACC + CC_notEE
                    ] },                                                                                  

    "ADCi": {   "c": 0x69,  
                "d": "Add Memory to Accumulator with Carry (immediate)",   
                "f": ['Z', 'N', 'C'],
                "v": "u8",
                "sim": "self.A = self.math_operation('adc', self.A, operator_immediate=True)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     

    "ADCp": {   "c": 0x6D,  
                "d": "Add Memory to Accumulator with Carry (zero page)",   
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "sim": "self.A = self.math_operation('adc', self.A, operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     
                                             
    "ADCa": {   "c": 0x03,  
                "d": "Add Memory to Accumulator with Carry (absolute)",   
                "f": ['Z', 'N', 'C'],
                "v": "u24",
                "sim": "self.A = self.math_operation('adc', self.A, operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },                         

    "ADCpx": {  "c": 0x04,  # Cross page not supported
                "d": "Add Memory to Accumulator with Carry (zero page - X index)",   
                "f": ['Z', 'N', 'C', 'O'],
                "v": "u16",
                "i": "x",
                "sim": "self.A = self.math_operation('adc', self.A, operator_mem_operands_size=2, operator_index=self.X)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,

                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  

    "ADCax": {  "c": 0x05,  # Cross page not supported
                "d": "Add Memory to Accumulator with Carry (absolute - X index)",   
                "f": ['Z', 'N', 'C', 'O'],
                "v": "u24",
                "i": "x",
                "sim": "self.A = self.math_operation('adc', self.A, operator_mem_operands_size=3, operator_index=self.X)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],                    
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,

                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },            

    "ADCpy": {  "c": 0x86,  # Cross page not supported
                "d": "Add Memory to Accumulator with Carry (zero page - Y index)",   
                "f": ['Z', 'N', 'C', 'O'],
                "v": "u16",
                "i": "y",
                "sim": "self.A = self.math_operation('adc', self.A, operator_mem_operands_size=2, operator_index=self.Y)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,

                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  

    "ADCay": {  "c": 0x87,  # Cross page not supported
                "d": "Add Memory to Accumulator with Carry (absolute - Y index)",   
                "f": ['Z', 'N', 'C', 'O'],
                "v": "u24",
                "i": "y",
                "sim": "self.A = self.math_operation('adc', self.A, operator_mem_operands_size=3, operator_index=self.Y)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],                    
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,

                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],                                           
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },                                     

    "ADCdr": {  "c": 0x6F,  
                "d": "Add Register D to Accumulator with Carry",   
                "f": ['Z', 'N', 'C'],
                "op": "d",
                "sim": "self.A = self.math_operation('adc', self.A, operator_registry='D')",
                "m": [  
                        ['LRALU-IN'] + CC_notED,
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  

    "ADCer": {  "c": 0x06,  
                "d": "Add Register E to Accumulator with Carry",   
                "f": ['Z', 'N', 'C'],
                "op": "e",
                "sim": "self.A = self.math_operation('adc', self.A, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notEE,
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  

    "SBCi": {   "c": 0xE9,  
                "d": "Subtract Memory from Accumulator with Borrow (immediate)",   
                "f": ['Z', 'N', 'C'],
                "v": "u8",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_immediate=True)",
                "m": [  
                        ['LRALU-IN'] + CC_notEACC, 
                        ['ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'EPCADDR', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['CPC', 'ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },     

    "SBCp": {   "c": 0xED,  
                "d": "Subtract Memory from Accumulator with Borrow (zero page)",  
                "f": ['Z', 'N', 'C'], 
                "v": "u16",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                     
                        ['CPC', 'LRALU-IN'] + CC_notEACC, 
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  

    "SBCa": {   "c": 0x5B,  
                "d": "Subtract Memory from Accumulator with Borrow (absolute)",  
                "f": ['Z', 'N', 'C'], 
                "v": "u24",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                    
                        ['CPC', 'LRALU-IN'] + CC_notEACC, 
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },       

    "SBCdr": {  "c": 0x5D,  
                "d": "Subtract Register D from Accumulator with Borrow",   
                "f": ['Z', 'N', 'C'],
                "op": "d",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_registry='D')",
                "m": [  
                        ['LRALU-IN'] + CC_notEACC, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notED + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },           

    "SBCer": {  "c": 0x5E,  
                "d": "Subtract Register E from Accumulator with Borrow",   
                "f": ['Z', 'N', 'C'],
                "op": "e",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notEACC, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEE + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },                                                        

    "SBCpx": {  "c": 0x5F,  # Cross page not supported
                "d": "Subtract Memory from Accumulator with Borrow (zero page - X index)",   
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "i": "x",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_mem_operands_size=2, operator_index=self.X)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  

    "SBCax": {  "c": 0x61,  # Cross page not supported
                "d": "Subtract Memory from Accumulator with Borrow (absolute - X index)",   
                "f": ['Z', 'N', 'C'],
                "v": "u24",
                "i": "x",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_mem_operands_size=3, operator_index=self.X)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],                    
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },      

    "SBCpy": {  "c": 0x88,  # Cross page not supported
                "d": "Subtract Memory from Accumulator with Borrow (zero page - Y index)",   
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "i": "y",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_mem_operands_size=2, operator_index=self.Y)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  

    "SBCay": {  "c": 0x89,  # Cross page not supported
                "d": "Subtract Memory from Accumulator with Borrow (absolute - Y index)",   
                "f": ['Z', 'N', 'C'],
                "v": "u24",
                "i": "y",
                "sim": "self.A = self.math_operation('sbc', self.A, operator_mem_operands_size=3, operator_index=self.Y)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],                    
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     

    "SBXer": {  "c": 0xEF,  
                "d": "Subtract Register E from Register X with Borrow",   
                "f": ['Z', 'N', 'C'],
                "op": "e",
                "sim": "self.X = self.math_operation('sbc', self.X, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notEX, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEE + CC_ALUCARRY,
                        ['ERALU-OUT', 'LZN'] + CC_LX + CC_ALU_DETECT_ZERO  
                    ] },    

    "INCp": {   "c": 0xEE,  
                "d": "Increment Memory by One (zero page)",  
                "f": ['Z', 'N'],  
                "v": "u16",
                "sim": "self.math_operation('inc', operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'MEMADDRVALID'], 
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_ALU_DETECT_ZERO  
                    ] },  

    "INWp": {   "c": 0xF1,  
                "d": "Increment Memory Word by One (zero page)",  
                "f": ['C'],  
                "v": "u16",
                "w": True,
                "sim": "self.math_operation('inc', operator_mem_operands_size=4, flags=['C'])",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'MEMADDRVALID', 'LC'], 
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_CHKC, #check carry, if not set save 3 clocks
                        ['CPC'],
                        ['CPC']
                    ],
                "true": [
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'MEMADDRVALID', 'LC'] + CC_ALUCARRY,
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'MEMADDRVALID'] 
                    ] },  

    "INCa": {   "c": 0x52,  
                "d": "Increment Memory by One (absolute)",  
                "f": ['Z', 'N'],  
                "v": "u24",
                "sim": "self.math_operation('inc', operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'MEMADDRVALID'], 
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_ALU_DETECT_ZERO  
                    ] },             
                
    "INX": {   "c": 0xE8,  
                "d": "Increment Register X by One",  
                "f": ['Z', 'N'], 
                "sim": "self.math_operation('inc', operator_registry='X')", 
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEX, 
                        ['ERALU-OUT', 'LZN'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },     

    "INY": {   "c": 0xC8,  
                "d": "Increment Register Y by One",  
                "f": ['Z', 'N'],  
                "sim": "self.math_operation('inc', operator_registry='Y')", 
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEY, 
                        ['ERALU-OUT', 'LZN'] + CC_LY + CC_ALU_DETECT_ZERO 
                    ] },            

    "IND": {   "c": 0x2E,  
                "d": "Increment Register D by One",  
                "f": ['Z', 'N'],  
                "sim": "self.math_operation('inc', operator_registry='D')", 
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notED, 
                        ['ERALU-OUT', 'LZN'] + CC_LD + CC_ALU_DETECT_ZERO 
                    ] },     

    "INE": {   "c": 0x2F,  
                "d": "Increment Register E by One",  
                "f": ['Z', 'N'],  
                "sim": "self.math_operation('inc', operator_registry='E')", 
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEE, 
                        ['ERALU-OUT', 'LZN'] + CC_LE + CC_ALU_DETECT_ZERO 
                    ] },                                     

    "DECp": {   "c": 0xCE,  
                "d": "Decrement Memory by One (zero page)",  
                "f": ['Z', 'N'],  
                "v": "u16",
                "sim": "self.math_operation('dec', operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3', 'MEMADDRVALID'] + CC_ALUCN, 
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_ALU_DETECT_ZERO
                    ] },   

    "DEWp": {   "c": 0xF2,  
                "d": "Decrement Memory Word by One (zero page)",  
                "f": ['C'],  
                "v": "u16",
                "w": True,
                "sim": "self.math_operation('dec', operator_mem_operands_size=4, flags=['C'])",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3', 'LC', 'MEMADDRVALID'] + CC_ALUCN,
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_CHKC, #check carry, if set save 3 clocks

                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3', 'LC', 'MEMADDRVALID'] + CC_ALUCN,
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'MEMADDRVALID'] 
                    ],
                "true": [
                        ['CPC'],
                        ['CPC']
                    ] }, 

    "DECa": {   "c": 0x53,  
                "d": "Decrement Memory by One (absolute)",  
                "f": ['Z', 'N'],  
                "v": "u24",
                "sim": "self.math_operation('dec', operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3', 'MEMADDRVALID'] + CC_ALUCN, 
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_ALU_DETECT_ZERO
                    ] },                       

    "DEX": {   "c": 0xCA,  
                "d": "Decrement Register X by One",  
                "f": ['Z','N'], 
                "sim": "self.math_operation('dec', operator_registry='X')", 
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LZN'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },   

    "DEY": {   "c": 0xCB,  
                "d": "Decrement Register Y by One",  
                "f": ['Z', 'N'], 
                "sim": "self.math_operation('dec', operator_registry='Y')",  
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LZN'] + CC_LY + CC_ALU_DETECT_ZERO 
                    ] },   

    "DED": {   "c": 0x28,  
                "d": "Decrement Register D by One",  
                "f": ['Z', 'N'],  
                "sim": "self.math_operation('dec', operator_registry='D')", 
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3'] + CC_notED + CC_ALUCN, 
                        ['ERALU-OUT', 'LZN'] + CC_LD + CC_ALU_DETECT_ZERO 
                    ] },   

    "DEE": {   "c": 0x2D,  
                "d": "Decrement Register E by One",  
                "f": ['Z', 'N'],  
                "sim": "self.math_operation('dec', operator_registry='E')", 
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3'] + CC_notEE + CC_ALUCN, 
                        ['ERALU-OUT', 'LZN'] + CC_LE + CC_ALU_DETECT_ZERO 
                    ] },   

    "EORi": {   "c": 0x49,  
                "d": "Exclusive-OR Memory with Accumulator (immediate)",  
                "f": ['Z', 'N'],  
                "v": "u8",
                "sim": "self.A = self.math_operation('eor', self.A, operator_immediate=True)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },   

   "EORp": {   "c": 0x11,  
                "d": "Exclusive-OR Memory with Accumulator (zero page)",  
                "f": ['Z', 'N'],  
                "v": "u16",
                "sim": "self.A = self.math_operation('eor', self.A, operator_mem_operands_size=2)",
                "m": [                        
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],   
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },       

    "EORa": {   "c": 0x12,  
                "d": "Exclusive-OR Memory with Accumulator (absolute)",  
                "f": ['Z', 'N'],  
                "v": "u24",
                "sim": "self.A = self.math_operation('eor', self.A, operator_mem_operands_size=4)",
                "m": [                        
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],   
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },      

    "EORdr": {  "c": 0x13,  
                "d": "Exclusive-OR Register D with Accumulator",  
                "f": ['Z', 'N'],  
                "op": "d",
                "sim": "self.A = self.math_operation('eor', self.A, operator_registry='D')",
                "m": [  
                        ['LRALU-IN'] + CC_notED, 
                        ['LRALU-OUT', 'ALUS1', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] }, 

    "EORer": {  "c": 0x14,  
                "d": "Exclusive-OR Register E with Accumulator",  
                "f": ['Z', 'N'],  
                "op": "e",
                "sim": "self.A = self.math_operation('eor', self.A, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notEE, 
                        ['LRALU-OUT', 'ALUS1', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] }, 


    "ANDi": {   "c": 0x29,  
                "d": "AND Memory with Accumulator (immediate)",  
                "f": ['Z', 'N'],  
                "v": "u8",
                "sim": "self.A = self.math_operation('and', self.A, operator_immediate=True)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },  

    "ANDp": {   "c": 0x07,  
                "d": "AND Memory with Accumulator (zero page)",  
                "f": ['Z', 'N'],  
                "v": "u16",
                "sim": "self.A = self.math_operation('and', self.A, operator_mem_operands_size=2)",
                "m": [                        
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],   
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },       

    "ANDa": {   "c": 0x08,  
                "d": "AND Memory with Accumulator (absolute)",  
                "f": ['Z', 'N'],  
                "v": "u24",
                "sim": "self.A = self.math_operation('and', self.A, operator_mem_operands_size=4)",
                "m": [                        
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],   
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },      

    "ANDdr": {  "c": 0x09,  
                "d": "AND Register D with Accumulator",  
                "f": ['Z', 'N'],  
                "op": "d",
                "sim": "self.A = self.math_operation('and', self.A, operator_registry='D')",
                "m": [  
                        ['LRALU-IN'] + CC_notED, 
                        ['LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] }, 

    "ANDer": {  "c": 0x0A,  
                "d": "AND Register E with Accumulator",  
                "f": ['Z', 'N'],  
                "op": "e",
                "sim": "self.A = self.math_operation('and', self.A, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notEE, 
                        ['LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] }, 

    "ASLacc": { "c": 0xAF, 
                "d": "Shift Left One Bit (accumulator)",
                "op": "a",  
                "f": ['Z', 'N', 'C'], 
                "sim": "self.A = self.math_operation('asl', self.A)",
                "m": [  
                        ['LZN', 'notCLC'] + CC_LTMP + CC_notEACC, 
                        CC_CHKN,
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ],
                "true": 
                    [  
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ] },        

    "ASLp": { "c": 0x1A, 
                "d": "Shift Left One Bit (zero page)",
                "v": "u16",
                "f": ['Z', 'N', 'C'], 
                "sim": "self.math_operation('asl', operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'notCLC', 'MEMADDRVALID'] + CC_LTMP, 
                        CC_CHKN,
                        ['tmpS1', 'LZN', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ],
                "true": 
                    [  
                        ['tmpS1', 'LZN', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ] },                       

    "ROLacc": { "c": 0x2A, 
                "d": "Rotate One Bit Left (accumulator)",
                "op": "a",  
                "f": ['Z', 'N', 'C'], 
                "sim": "self.A = self.math_operation('rol', self.A)",
                "m": [  
                        ['LZN'] + CC_LTMP + CC_notEACC, 
                        CC_CHKN,
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ],
                "true": 
                    [  
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ]                    },  

    "ROLer": { "c": 0x2B, 
                "d": "Rotate Register E One Bit Left",
                "op": "e",  
                "f": ['Z', 'N', 'C'], 
                "sim": "self.E = self.math_operation('rol', self.E)",
                "m": [  
                        ['LZN'] + CC_LTMP + CC_notEE, 
                        CC_CHKN,
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LE + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ],
                "true": 
                    [
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LE + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ] }, 

    "ROLdr": { "c": 0x2C,  
                "d": "Rotate Register D One Bit Left",
                "op": "d",  
                "f": ['Z', 'N', 'C'], 
                "sim": "self.D = self.math_operation('rol', self.D)",
                "m": [  
                        ['LZN'] + CC_LTMP + CC_notED, 
                        CC_CHKN,
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LD + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ], 
                "true":
                    [
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LD + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ]    
                    }, 

    "ROLp": {   "c": 0x26,  
                "d": "Rotate One Bit Left (zero page)", 
                "f": ['Z', 'N', 'C'], 
                "v": "u16",
                "sim": "self.math_operation('rol', operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'MEMADDRVALID', 'LZN'] + CC_LTMP,
                        CC_CHKN,
                        ['tmpS1', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ],
                "true": 
                    [
                        ['tmpS1', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        CC_SEC      
                    ] },

    "ROLa": {   "c": 0x54,  
                "d": "Rotate One Bit Left (absolute)", 
                "f": ['Z', 'N', 'C'], 
                "v": "u24",
                "sim": "self.math_operation('rol', operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'MEMADDRVALID', 'LZN'] + CC_LTMP,
                        CC_CHKN,
                        ['tmpS1', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ],
                "true": 
                    [
                        ['tmpS1', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ] },                    

    "RORacc": { "c": 0x6A, 
                "d": "Rotate One Bit Right (accumulator)",
                "op": "a",  
                "f": ['Z', 'N', 'C'], 
                "b": [0x01],
                "sim": "self.A = self.math_operation('ror', self.A, extra_bytes=1)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], #Load 0x01
                        ['CPC','LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO, 
                        CC_CHKZ + CC_LTMP + CC_notEACC,                         
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ],
                "true":
                    [
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ] },  
     
    "RORer": {  "c": 0x6B, 
                "d": "Rotate Register E One Bit Right",
                "op": "e",  
                "f": ['Z', 'N', 'C'], 
                "b": [0x01],
                "sim": "self.E = self.math_operation('ror', self.E, extra_bytes=1)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], #Load 0x01
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEE + CC_ALUM,  # AND
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO,                    
                        CC_CHKZ + CC_LTMP + CC_notEE, 
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LE + CC_ALU_DETECT_ZERO,
                        CC_SEC 
                    ],
                "true":
                    [
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LE + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ] },  

    "RORdr": {  "c": 0x6C,  
                "d": "otate Register D One Bit Right",
                "op": "d",  
                "f": ['Z', 'N', 'C'], 
                "b": [0x01],
                "sim": "self.D = self.math_operation('ror', self.D, extra_bytes=1)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], #Load 0x01
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notED + CC_ALUM,  # AND
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO,                                        
                        CC_CHKZ + CC_LTMP + CC_notED, 
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LD + CC_ALU_DETECT_ZERO,
                        CC_SEC 
                    ],
                "true":
                    [
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LD + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ] }, 

    "RORp": {   "c": 0x66, 
                "d": "Rotate One Bit Right (zero page)", 
                "f": ['Z', 'N', 'C'], 
                "b": [0x01],
                "v": "u16",
                "sim": "self.math_operation('ror', operator_mem_operands_size=2, extra_bytes=1)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], #Load 0x01
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_ALUM,  # AND
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO,    
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP + CC_CHKZ,
                        ['tmpS0', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ],
                "true": [
                        ['tmpS0', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ] },

    "RORa": {   "c": 0x55, 
                "d": "Rotate One Bit Right (absolute)", 
                "f": ['Z', 'N', 'C'], 
                "b": [0x01],
                "v": "u24",
                "sim": "self.math_operation('ror', operator_mem_operands_size=3, extra_bytes=1)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], #Load 0x01
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_ALUM,  # AND
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO,                         
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP + CC_CHKZ,
                        ['tmpS0', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ],
                "true": [
                        ['tmpS0', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                ] },                

    "LSRacc": { "c": 0xA8, 
                "d": "Shift One Bit Right (accumulator)",
                "op": "a",  
                "f": ['Z', 'N', 'C'], 
                "b": [0x01],
                "sim": "self.A = self.math_operation('lsr', self.A, extra_bytes=1)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], #Load 0x01
                        ['CPC','LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO, 
                        ['notCLC'] + CC_CHKZ + CC_LTMP + CC_notEACC,                         
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ],
                "true":
                    [
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ] },            

    "LSRp": { "c": 0x1B, 
                "d": "Shift One Bit Right (zero page)",
                "v": "u16",
                "f": ['Z', 'N', 'C'], 
                "b": [0x01],
                "sim": "self.math_operation('lsr', operator_mem_operands_size=2, extra_bytes=1)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], #Load 0x01
                        ['CPC','LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO, 
                        ['notCLC', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_CHKZ + CC_LTMP,                         
                        ['tmpS0', 'LZN', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        CC_SEC
                    ],
                "true":
                    [
                        ['tmpS0', 'LZN', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO,
                        ['notCLC']
                    ] },           

    "ORAi": {   "c": 0x0B,  
                "d": "OR Memory with Accumulator (immediate)",  
                "f": ['Z', 'N'],  
                "v": "u8",
                "sim": "self.A = self.math_operation('or', self.A, operator_immediate=True)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },  

    "ORAp": {   "c": 0x0C,  
                "d": "OR Memory with Accumulator (zero page)",  
                "f": ['Z', 'N'],  
                "v": "u16",
                "sim": "self.A = self.math_operation('or', self.A, operator_mem_operands_size=2)",
                "m": [                        
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],   
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS2'] + CC_notEACC + CC_ALUM,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },       

    "ORAa": {   "c": 0x0D,  
                "d": "OR Memory with Accumulator (absolute)",  
                "f": ['Z', 'N'],  
                "v": "u24",
                "sim": "self.A = self.math_operation('or', self.A, operator_mem_operands_size=3)",
                "m": [                        
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],   
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },      

    "ORAdr": {  "c": 0x0E,  
                "d": "OR Register D with Accumulator",  
                "f": ['Z', 'N'],  
                "op": "d",
                "sim": "self.A = self.math_operation('or', self.A, operator_registry='D')",
                "m": [  
                        ['LRALU-IN'] + CC_notED, 
                        ['LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] }, 

    "ORAer": {  "c": 0x0F,  
                "d": "OR Register E with Accumulator",  
                "f": ['Z', 'N'],  
                "op": "e",
                "sim": "self.A = self.math_operation('or', self.A, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notEE, 
                        ['LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS2'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] }, 

    "CMPi": {   "c": 0xC9,  
                "d": "Compare Memory with Accumulator (immediate)", 
                "f": ['Z', 'N', 'C'],
                "v": "u8",
                "sim": "self.math_operation('cmp', self.A, operator_immediate=True)",
                "m": [  
                        ['LRALU-IN'] + CC_notEACC,
                        ['ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO 
                    ] },      

    "CMPp": {   "c": 0x5C,  
                "d": "Compare Memory with Accumulator (zero page)", 
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                     
                        ['CPC', 'LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ] },   

    "CMPindp": {"c": 0xB9,  
                "d": "Compare Memory with Accumulator (indirect - zero page)", 
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=2, indirect=True)",
                "m": [  
                        # store value in stack
                        ['ESP', 'WRAM'] + CC_notEACC,

                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LACC,    

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP,     

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH'] + CC_notETMP,

                        # restore ACC value and compare 
                        ['CPC', 'LRALU-IN', 'ESP', 'ERAM'] + CC_LACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB
                        ['EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP,  

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH'] + CC_notETMP,

                        # restore ACC value and compare 
                        ['CPC', 'LRALU-IN', 'ESP', 'ERAM'] + CC_LACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO  
                    ]  },   

    "CMPpx": {  "c": 0xB4,  
                "d": "Compare Memory with Accumulator (zero page - X index)", 
                "f": ['Z', 'N', 'C', 'O'],
                "v": "u16",
                "i": "x",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=2, operator_index=self.X)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,                  
                        
                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ] },  

    "CMPindpx": {"c": 0xC0,  
                "d": "Compare Memory with Accumulator (indirect - zero page - X index)", 
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "i": "x",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=2, indirect=True, operator_index=self.X)",
                "t0": [ 
                        CC_LOAD_PC_POINTED_RAM_INTO_IR + ['CHKI'] 
                      ],                 
                "m": [  
                        # store value in stack
                        ['CPC', 'ESP', 'WRAM'] + CC_notEACC,

                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB + X
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN'],
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEX + CC_ALUCN,   
                        ['ERALU-OUT'] + CC_LACC,    

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,       

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],

                        # restore ACC value and compare 
                        ['CPC', 'LRALU-IN', 'ESP', 'ERAM'] + CC_LACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,  

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],

                        # restore ACC value and compare 
                        ['CPC', 'LRALU-IN', 'ESP', 'ERAM'] + CC_LACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO  
                    ]  },   

   "CMPpy": {  "c": 0xB5,  
                "d": "Compare Memory with Accumulator (zero page - Y index)", 
                "f": ['Z', 'N', 'C', 'O'],
                "v": "u16",
                "i": "y",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=2, operator_index=self.Y)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,                  
                        
                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ] }, 

    "CMPindpy": {"c": 0xC3,  
                "d": "Compare Memory with Accumulator (indirect - zero page - Y index)", 
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "i": "y",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=2, indirect=True, operator_index=self.Y)",
                "t0": [ 
                        CC_LOAD_PC_POINTED_RAM_INTO_IR + ['CHKI'] 
                      ],                 
                "m": [  
                        # store value in stack
                        ['CPC', 'ESP', 'WRAM'] + CC_notEACC,

                        # load address in the MAR
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,   
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        
                        # load LSB + X
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN'],
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEY + CC_ALUCN,   
                        ['ERALU-OUT'] + CC_LACC,    

                        # inc MAR-L
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT', 'LO'], 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO, # carry?

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,       

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],

                        # restore ACC value and compare 
                        ['CPC', 'LRALU-IN', 'ESP', 'ERAM'] + CC_LACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ],
                "true": [
                        # carry, inc MAR-H 
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP, 
                        ['ERALU-OUT', 'LMARH'],

                        # load MSB (+ carry)
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN', 'LRALU-OUT'] + CC_ALUCARRY,  

                        # set address
                        ['LMARL'] + CC_notEACC,
                        ['LMARH', 'ERALU-OUT'],

                        # restore ACC value and compare 
                        ['CPC', 'LRALU-IN', 'ESP', 'ERAM'] + CC_LACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO  
                    ]  },   

    "CMPax": {  "c": 0xB6,  
                "d": "Compare Memory with Accumulator (absolute - X index)", 
                "f": ['Z', 'N', 'C', 'O'],
                "v": "u24",
                "i": "x",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=3, operator_index=self.X)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],                    
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,           
                        
                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ] },  

   "CMPay": {  "c": 0xB7,  
                "d": "Compare Memory with Accumulator (absolute - Y index)", 
                "f": ['Z', 'N', 'C', 'O'],
                "v": "u24",
                "i": "y",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=3, operator_index=self.Y)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],                    
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEY + CC_ALUCN, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notETMP,                  
                        
                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ], 
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],

                        ['LRALU-IN'] + CC_notEACC,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ] }, 

    "CMPa": {   "c": 0x42,  
                "d": "Compare Memory with Accumulator (absolute)", 
                "f": ['Z', 'N', 'C'],
                "v": "u24",
                "sim": "self.math_operation('cmp', self.A, operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                    
                        ['CPC', 'LRALU-IN'] + CC_notEACC, 
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                          
                    ] },                       

    "CPXi": {   "c": 0xE0,  
                "d": "Compare Memory and Register X (immediate)", 
                "f": ['Z', 'N', 'C'],
                "v": "u8",
                "sim": "self.math_operation('cmp', self.X, operator_immediate=True)",
                "m": [  
                        ['LRALU-IN'] + CC_notEX,
                        ['ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO 
                    ] },    

    "CPXp": {   "c": 0x47,  
                "d": "Compare Memory with Register X (zero page)", 
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "sim": "self.math_operation('cmp', self.X, operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                     
                        ['CPC', 'LRALU-IN'] + CC_notEX,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO             
                    ] },   

    "CPXa": {   "c": 0x4A,  
                "d": "Compare Memory with Register X (absolute)", 
                "f": ['Z', 'N', 'C'],
                "v": "u24",
                "sim": "self.math_operation('cmp', self.X, operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                    
                        ['CPC', 'LRALU-IN'] + CC_notEX, 
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO    
                    ] },                            

    "CPXyr": {  "c": 0xE1,  
                "d": "Compare Register Y and Register X", 
                "f": ['Z', 'N', 'C'],
                "op": "y",
                "sim": "self.math_operation('cmp', self.X, operator_registry='Y')",
                "m": [  
                        ['LRALU-IN'] + CC_notEX, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEY,
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO                            
                    ] },   

    "CPXer": {  "c": 0xE2,  
                "d": "Compare Register E and Register X", 
                "f": ['Z', 'N', 'C'],
                "op": "e",
                "sim": "self.math_operation('cmp', self.X, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notEX, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEE,
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO   
                    ] },   

    "CPXdr": {  "c": 0xEB,  
                "d": "Compare Register D and Register X", 
                "f": ['Z', 'N', 'C'],
                "op": "d",
                "sim": "self.math_operation('cmp', self.X, operator_registry='D')",
                "m": [  
                        ['LRALU-IN'] + CC_notEX, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notED,
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO   
                    ] },   

    "CPYdr": {  "c": 0x4F,  
                "d": "Compare Register D and Register Y", 
                "f": ['Z', 'N', 'C'],
                "op": "d",
                "sim": "self.math_operation('cmp', self.Y, operator_registry='D')",
                "m": [  
                        ['LRALU-IN'] + CC_notEY, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notED,
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO   
                    ] },      

    "CPYer": {  "c": 0x50,  
                "d": "Compare Register E and Register Y", 
                "f": ['Z', 'N', 'C'],
                "op": "e",
                "sim": "self.math_operation('cmp', self.Y, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notEY, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEE,
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO   
                    ] },          

    "CPDer": {  "c": 0x51,  
                "d": "Compare Register E and Register D", 
                "f": ['Z', 'N', 'C'],
                "op": "e",
                "sim": "self.math_operation('cmp', self.D, operator_registry='E')",
                "m": [  
                        ['LRALU-IN'] + CC_notED, 
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEE,
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO   
                    ] },                                                         

    "CPYi": {   "c": 0xE3,  
                "d": "Compare Memory and Register Y (immediate)", 
                "f": ['Z', 'N', 'C'],
                "v": "u8",
                "sim": "self.math_operation('cmp', self.Y, operator_immediate=True)",
                "m": [  
                        ['LRALU-IN'] + CC_notEY,
                        ['ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO 
                    ] },      

    "CPYp": {   "c": 0x4B,  
                "d": "Compare Memory with Register Y (zero page)", 
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "sim": "self.math_operation('cmp', self.Y, operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                     
                        ['CPC', 'LRALU-IN'] + CC_notEY,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO         
                    ] },   

    "CPYa": {   "c": 0x4E,  
                "d": "Compare Memory with Register Y (absolute)", 
                "f": ['Z', 'N', 'C'],
                "v": "u24",
                "sim": "self.math_operation('cmp', self.Y, operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                    
                        ['CPC', 'LRALU-IN'] + CC_notEY, 
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO    
                    ] },                            

    "CPEi": {   "c": 0xE4,  
                "d": "Compare Memory with Register E (immediate)", 
                "f": ['Z', 'N', 'C'],
                "v": "u8",
                "sim": "self.math_operation('cmp', self.E, operator_immediate=True)",
                "m": [  
                        ['LRALU-IN'] + CC_notEE,
                        ['ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO 
                    ] },   

    "CPEp": {   "c": 0x45,  
                "d": "Compare Memory with Register E (zero page)", 
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "sim": "self.math_operation('cmp', self.E, operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                     
                        ['CPC', 'LRALU-IN'] + CC_notEE,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO    
                    ] },   

    "CPEa": {   "c": 0x46,  
                "d": "Compare Memory with Register E (absolute)", 
                "f": ['Z', 'N', 'C'],
                "v": "u24",
                "sim": "self.math_operation('cmp', self.E, operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                    
                        ['CPC', 'LRALU-IN'] + CC_notEE, 
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO    
                    ] },                                                

    "CPDi": {   "c": 0xE5,  
                "d": "Compare Memory with Register D (immediate)", 
                "f": ['Z', 'N', 'C'],
                "v": "u8",
                "sim": "self.math_operation('cmp', self.D, operator_immediate=True)",
                "m": [  
                        ['LRALU-IN'] + CC_notED,
                        ['ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC', 'ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO 
                    ] },   

    "CPDp": {   "c": 0x43,  
                "d": "Compare Memory with Register D (zero page)", 
                "f": ['Z', 'N', 'C'],
                "v": "u16",
                "sim": "self.math_operation('cmp', self.D, operator_mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                     
                        ['CPC', 'LRALU-IN'] + CC_notED,
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO    
                    ] },   

    "CPDa": {   "c": 0x44,  
                "d": "Compare Memory with Register D (absolute)", 
                "f": ['Z', 'N', 'C'],
                "v": "u24",
                "sim": "self.math_operation('cmp', self.D, operator_mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'],                    
                        ['CPC', 'LRALU-IN'] + CC_notED, 
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO   
                    ] },      

    "BITi": {   "c": 0x15,  
                "d": "Test Accumulator BITs with Memory (immediate)",  
                "f": ['Z', 'N'],  
                "v": "u8",
                "sim": "self.math_operation('and', self.A, operator_immediate=True)",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO  
                    ] },  

    "BITp": {   "c": 0x16,  
                "d": "Test Accumulator BITs with Memory (zero page)",  
                "f": ['Z', 'N'],  
                "v": "u16",
                "sim": "self.math_operation('and', self.A, operator_mem_operands_size=2)",
                "m": [                        
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],   
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO  
                    ] },       

    "BITa": {   "c": 0x17,  
                "d": "Test Accumulator BITs with Memory (absolute)",  
                "f": ['Z', 'N'],  
                "v": "u24",
                "sim": "self.math_operation('and', self.A, operator_mem_operands_size=3)",
                "m": [                        
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'],   
                        ['CPC', 'LRALU-OUT', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC + CC_ALUM, 
                        ['ERALU-OUT', 'LZN'] + CC_ALU_DETECT_ZERO  
                    ] },      

    "JMPp": {   "c": 0x4C,  
                "d": "Jump to New Location (zero page)", 
                "v": "u16",
                "sim": "self.jump(mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCHP0
                    ] },                  

    "JMPa": {   "c": 0x4D,  
                "d": "Jump to New Location (absolute)", 
                "v": "u24",
                "sim": "self.jump(mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE 
                    ] },       

    "JMPindp": {   "c": 0x8F,  
                "d": "Jump to New Location (indirect - zero page)", 
                "v": "u16",
                "sim": "self.jump(mem_operands_size=2, indirect=True)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCHP0,

                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'],
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL,
                        CC_notETMP + CC_notLPCHP0 
                    ] },    

    "JMPinda": {   "c": 0x91,  
                "d": "Jump to New Location (indirect - absolute)", 
                "v": "u24",
                "sim": "self.jump(mem_operands_size=3, indirect=True)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE,

                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE                         
                    ] },                                       

    "JSRp": {   "c": 0x20,  
                "d": "Jump to New Location Saving Return Address (zero page)", 
                "v": "u16",
                "b": [0x00],
                "sim": "self.jump(mem_operands_size=2, jsr=True)",
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCPAGE,
                        CC_INC_STACK_POINTER,
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0  
                    ] },      

    "JSRa": {   "c": 0x21,  
                "d": "Jump to New Location Saving Return Address (absolute)", 
                "v": "u24",
                "sim": "self.jump(mem_operands_size=3, jsr=True)",
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCPAGE,
                        CC_INC_STACK_POINTER,
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE  
                    ] },    

    "JSRindp": { "c": 0x92,  
                "d": "Jump to New Location Saving Return Address (indirect - zero page)", 
                "v": "u16",
                "b": [0x00],       
                "sim": "self.jump(mem_operands_size=2, indirect=True, jsr=True)",         
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCPAGE,
                        CC_INC_STACK_POINTER,

                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0,  

                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0                          
                    ] },      

    "JSRinda": {
                "c": 0x93,  
                "d": "Jump to New Location Saving Return Address (indirect - absolute)", 
                "v": "u24",
                "sim": "self.jump(mem_operands_size=3, indirect=True, jsr=True)", 
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCPAGE,
                        CC_INC_STACK_POINTER,

                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE,

                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE                          
                    ] },                        

    "RTS":  {   "c": 0x60,  
                "d": "Return from Subroutine", 
                "sim": "self.rts()",
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE,
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCH,
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCL,     
                        ['CPC'], 
                        ['CPC'],   
                        ['CPC']                
                    ] },      

    "PHA":  {   "c": 0x48,  
                "d": "Push Accumulator on Stack", 
                "sim": "self.push(self.A)\nself.PC += 1",
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEACC,
                        CC_INC_STACK_POINTER,
                    ] },      

    "PHD":  {   "c": 0x95,  
                "d": "Push Register D on Stack", 
                "sim": "self.push(self.D)\nself.PC += 1",
                "m": [  
                        ['ESP', 'WRAM'] + CC_notED,
                        CC_INC_STACK_POINTER,
                    ] },      

    "PHE":  {   "c": 0x96,  
                "d": "Push Register E on Stack", 
                "sim": "self.push(self.E)\nself.PC += 1",
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEE,
                        CC_INC_STACK_POINTER,
                    ] },      

    "PHX":  {   "c": 0x97,  
                "d": "Push Register X on Stack", 
                "sim": "self.push(self.X)\nself.PC += 1",
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEX,
                        CC_INC_STACK_POINTER,
                    ] },      

    "PHY":  {   "c": 0x98,  
                "d": "Push Register Y on Stack", 
                "sim": "self.push(self.Y)\nself.PC += 1",
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEY,
                        CC_INC_STACK_POINTER,
                    ] },                                                                                      

    "PLA":  {   "c": 0x68,  
                "d": "Pull Accumulator from Stack", 
                "f": ['Z', 'N'],
                "sim": "self.A = self.pop()\nself.PC += 1",
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO
                    ] },      

    "PLD":  {   "c": 0x99,  
                "d": "Pull Register D from Stack", 
                "f": ['Z', 'N'],
                "sim": "self.D = self.pop()\nself.PC += 1",
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM', 'LZN'] + CC_LD + CC_ALU_DETECT_ZERO
                    ] },     

    "PLE":  {   "c": 0x9A,  
                "d": "Pull Register E from Stack", 
                "f": ['Z', 'N'],
                "sim": "self.E = self.pop()\nself.PC += 1",
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM', 'LZN'] + CC_LE + CC_ALU_DETECT_ZERO
                    ] },     

    "PLX":  {   "c": 0x9E,  
                "d": "Pull Register X from Stack", 
                "f": ['Z', 'N'],
                "sim": "self.X = self.pop()\nself.PC += 1",
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM', 'LZN'] + CC_LX + CC_ALU_DETECT_ZERO
                    ] },     

    "PLY":  {   "c": 0x9F,  
                "d": "Pull Register Y from Stack", 
                "f": ['Z', 'N'],
                "sim": "self.Y = self.pop()\nself.PC += 1",
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM', 'LZN'] + CC_LY + CC_ALU_DETECT_ZERO
                    ] },                                                                                     

    "BEQp": {   "c": 0xF0,  
                "d": "Branch on Result Zero (zero page)", 
                "v": "u16",
                "sim": "self.branch('beq', mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKZ,
                        ['CPC'], 
                        ['CPC']
                    ],
                "true": [
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0 
                    ] },   

    "BNEp": {   "c": 0xD0,  
                "d": "Branch on Result not Zero (zero page)", 
                "v": "u16",
                "sim": "self.branch('bne', mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKZ,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCHP0 
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                    ] },   

    "BCSp": {   "c": 0xB0,  
                "d": "Branch on Carry Set (zero page)", 
                "v": "u16",
                "sim": "self.branch('bcs', mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKC,
                        ['CPC'], 
                        ['CPC']
                    ],
                "true": [
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0 
                    ] },    

    "BCCp": {   "c": 0x90,  
                "d": "Branch on Carry Clear (zero page)", 
                "v": "u16",
                "sim": "self.branch('bcc', mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKC,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                    ] },                                          

    "BMIp": {   "c": 0x30,  
                "d": "Branch on Result Minus (zero page)", 
                "v": "u16",
                "sim": "self.branch('bmi', mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKN,
                        ['CPC'], 
                        ['CPC']
                    ],
                "true": [
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0 
                    ] }, 

    "BPLp": {   "c": 0x10,  
                "d": "Branch on Result Plus (zero page)", 
                "v": "u16",
                "sim": "self.branch('bpl', mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKN,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                    ] },                                          
   
    "BEQa": {   "c": 0x23,  
                "d": "Branch on Result Zero (absolute)", 
                "v": "u24",
                "sim": "self.branch('beq', mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKZ,
                        ['CPC'], 
                        ['CPC'],
                        ['CPC']
                    ],
                "true": [
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE                         
                    ] },   

    "BNEa": {   "c": 0x25,  
                "d": "Branch on Result not Zero (absolute)", 
                "v": "u24",
                "sim": "self.branch('bne', mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKZ,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE     
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                        ['CPC']
                    ] },   

    "BCSa": {   "c": 0x22,  
                "d": "Branch on Carry Set (absolute)", 
                "v": "u24",
                "sim": "self.branch('bcs', mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKC,
                        ['CPC'], 
                        ['CPC'],
                        ['CPC']
                    ],
                "true": [
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE     
                    ] },    

    "BCCa": {   "c": 0x19,  
                "d": "Branch on Carry Clear (absolute)", 
                "v": "u24",
                "sim": "self.branch('bcc', mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKC,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE     
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                        ['CPC']
                    ] },                                          

    "BMIa": {   "c": 0x24,  
                "d": "Branch on Result Minus (absolute)", 
                "v": "u24",
                "sim": "self.branch('bmi', mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKN,
                        ['CPC'], 
                        ['CPC'],
                        ['CPC']
                    ],
                "true": [
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE     
                    ] }, 

    "BPLa": {   "c": 0x27,  
                "d": "Branch on Result Plus (absolute)", 
                "v": "u24",
                "sim": "self.branch('bpl', mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKN,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE     
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                        ['CPC']
                    ] },            


    # "BVCp": {   "c": 0x63,  
    #             "d": "Branch on oVerflow Clear (zero page)", 
    #             "v": "u16",
    #             "m": [  
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKO,
    #                     ['CPC'], 
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
    #                     CC_notETMP  + CC_notLPCHP0
    #                 ],
    #             "true": [
    #                     ['CPC'], 
    #                     ['CPC'], 
    #                 ] },         

    # "BVSp": {   "c": 0x64,  
    #             "d": "Branch on oVerflow Set (zero page)", 
    #             "v": "u16",
    #             "m": [  
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKO,
    #                     ['CPC'], 
    #                     ['CPC']
    #                 ],
    #             "true": [
    #                     ['CPC'], 
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
    #                     CC_notETMP  + CC_notLPCHP0 
    #                 ] },    

    # "BVCa": {   "c": 0x65,  
    #             "d": "Branch on oVerflow Clear (absolute)", 
    #             "v": "u24",
    #             "m": [  
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKO,
    #                     ['ESP', 'WRAM'] + CC_notETMP,
    #                     ['CPC'], 
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
    #                     ['CPC'], 
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
    #                     CC_notETMP + CC_notLPCH,
    #                     ['ESP', 'ERAM'] + CC_notLPCPAGE     
    #                 ],
    #             "true": [
    #                     ['CPC'], 
    #                     ['CPC'], 
    #                     ['CPC']
    #                 ] },    

    # "BVSa": {   "c": 0x67,  
    #             "d": "Branch on oVerflow Set (absolute)", 
    #             "v": "u24",
    #             "m": [  
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP + CC_CHKO,
    #                     ['CPC'], 
    #                     ['CPC'],
    #                     ['CPC']
    #                 ],
    #             "true": [
    #                     ['ESP', 'WRAM'] + CC_notETMP,
    #                     ['CPC'], 
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LTMP,
    #                     ['CPC'], 
    #                     ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_notLPCL, 
    #                     CC_notETMP + CC_notLPCH,
    #                     ['ESP', 'ERAM'] + CC_notLPCPAGE     
    #                 ] },    

    "LDOi": {   "c": 0xFE,  
                "d": "Load Output with Memory (immediate)", 
                "v": "u8",
                "sim": "self.OUT = self.load_from_memory(immediate=True)",
                "m": [  
                        ['ERAM', 'EPCADDR', 'MEMADDRVALID'] + CC_LOUT, 
                        ['CPC']  
                    ] },

    "LDOp": {   "c": 0xFD,  
                "d": "Load Output with Memory (zero page)", 
                "v": "u16",
                "sim": "self.OUT = self.load_from_memory(mem_operands_size=2)",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LOUT  
                    ] },

    "LDOa": {   "c": 0x41,  
                "d": "Load Output with Memory (absolute)", 
                "v": "u24",
                "sim": "self.OUT = self.load_from_memory(mem_operands_size=3)",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR', 'MEMADDRVALID'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR', 'MEMADDRVALID'], 
                        ['CPC', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LOUT  
                    ] },                        

    "CLC": {    "c": 0x18,  
                "d": "Clear Carry Flag", 
                "f": ['C'],
                "sim": "self.C = False\nself.PC += 1",
                "m": [  
                        ['notCLC'], 
                    ] },                    

    "SEC": {    "c": 0x38,  
                "d": "Set Carry Flag", 
                "f": ['C'],
                "sim": "self.C = True\nself.PC += 1",
                "m": [  
                        CC_SEC, 
                     ] },                                         

    "NOP": {    "c": 0xEA,  
                "d": "No Operation",    
                "sim": "self.PC += 1",
                "m": [ ] },     

    "DMP": {    "c": 0xF7,  
                "d": "Dump registers in the simulator logs", 
                "sim": '\n'.join((
                    'self.PC += 1',
                    'print(f"-> PC:{cpu.PC:06X} MAR:{cpu.MAR:06X} IR:{cpu.IR:02X} A:{cpu.A:02X} X:{cpu.X:02X} Y:{cpu.Y:02X} D:{cpu.D:02X} E:{cpu.E:02X} OUT:{cpu.OUT:02X} SP:{cpu.SP:04X} C:{cpu.C} Z:{cpu.Z} N:{cpu.N} O:{cpu.O}")',
                )),   
                "m": [ ] },

    "BRK": {    "c": 0x00,  
                "d": "Jump to interrupt handler routine", 
                "f": ['I'],
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR ], # don't check I to resume next op
                "m": [
                        ['ESP', 'WRAM'] + CC_EFROUT,
                        CC_INC_STACK_POINTER, 
                        ['ESP', 'WRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER, 
                        ['ESP', 'WRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER, 
                        ['ESP', 'WRAM'] + CC_notEPCPAGE,
                        CC_INC_STACK_POINTER, 
                        ['ALUS0', 'ALUS1', 'LRALU-OUT'] + CC_notEACC + CC_ALUM,   # 0x0000
                        ['ERALU-OUT'] + CC_notLPCHP0,
                        ['ALUS2', 'ALUS3', 'LRALU-OUT']  + CC_notEACC + CC_ALUM,   # 0xFF
                        ['ERALU-OUT', 'notDISI'] + CC_notLPCL
                     ] },    

    "RTI":  {   "c": 0x40,  
                "d": "Return from Interrupt", 
                "f": ['I'],
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR + ['notENAI'] ], # don't check I to resume next op but enable int
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE,
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCH,
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCL,
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM', 'LC', 'LZN'] + CC_EFRIN  
                    ] },           

    "SEI":  {   "c": 0x78,  
                "d": "Set interrupt disable", 
                "f": ['I'],
                "sim": 'self.I = True\nself.PC += 1',
                "m": [  
                        ['notDISI']     
                    ] },         

    "CLI":  {   "c": 0x58,  
                "d": "Clear interrupt disable", 
                "f": ['I'],
                "sim": 'self.I = False\nself.PC += 1',
                "m": [  
                        ['notENAI']     
                    ] },                                                                      
                                
}.items()))

##################################################################
## Calculate Control Word
##
##
def getControlWord(pins):
    controlWords = [0] * CONTROL_ROMS_COUNT
    for key in CONTROL_BITS:
        if key in pins:
            if CONTROL_BITS[key]['lowActive'] == False:
                controlWords[CONTROL_BITS[key]['eeprom']] += 2**CONTROL_BITS[key]['bit']
        else:
            if CONTROL_BITS[key]['lowActive'] == True:
                controlWords[CONTROL_BITS[key]['eeprom']] += 2**CONTROL_BITS[key]['bit']
    return controlWords

##################################################################
## Verify INSTRUCTIONS_SET
##
def verifyInstructionSet():
    rev_dict = {}
    for key, value in INSTRUCTIONS_SET.items():
        rev_dict.setdefault(value['c'], set()).add(key)
    result = [hex(key) for key, values in rev_dict.items() if len(values) > 1]
    if len(result) > 0:
        raise Exception("Duplicated op code in INSTRUCTIONS_SET: " + str(result))

    for inst in INSTRUCTIONS_SET.keys():
        for wset in ['m','true','t0']:
            if wset in INSTRUCTIONS_SET[inst]:
                for w in INSTRUCTIONS_SET[inst][wset]:
                    for b in w:
                        if not b in CONTROL_BITS.keys():
                            raise Exception("Unknown control bit '" + b + "' in instruction '" + inst + "'")
                        
    for inst in INSTRUCTIONS_SET.keys():
        steps = len(INSTRUCTIONS_SET[inst].get('m',[]))
        if 't0' in INSTRUCTIONS_SET[inst]:
            steps += len(INSTRUCTIONS_SET[inst]['t0'])
        else:
            steps += len(DEFAULT_T0)    
        if steps > 32:
            raise Exception("Total steps greater than 32 in instruction '" + inst + "'")
        
        if 'true' in INSTRUCTIONS_SET[inst]:
            if steps > 16:
                raise Exception("Total steps greater than 16 in instruction '" + inst + "' and 'true' section defined")
            if len(INSTRUCTIONS_SET[inst]['true']) > 16:
                raise Exception("Total 'true' steps greater than 16 in instruction '" + inst + "'")
            
    for inst in INSTRUCTIONS_SET.keys():
        cycles = countCycles(inst)
        INSTRUCTIONS_SET[inst]['cycles'] = cycles[0]
        INSTRUCTIONS_SET[inst]['cycles_true'] = cycles[1]

    return

##################################################################
## Count cycles of an instruction
##
##
def countCycles(inst):
    std_cycles = len(INSTRUCTIONS_SET[inst]['m']) + (len(INSTRUCTIONS_SET[inst]['t0']) if 't0' in INSTRUCTIONS_SET[inst] else len(DEFAULT_T0))
    if 'true' in INSTRUCTIONS_SET[inst]:
        branch_cycles = 0
        branch_found = False
        for t in INSTRUCTIONS_SET[inst]['m']:
            branch_cycles += 1
            if set(CC_CHKC).issubset(set(t)) or set(CC_CHKO).issubset(set(t)) or set(CC_CHKZ).issubset(set(t)) or set(CC_CHKN).issubset(set(t)):
                branch_found = True
                break
        if not branch_found:
            raise Exception("True defined but no condition check found in instruction '" + inst + "'")
        branch_cycles += len(INSTRUCTIONS_SET[inst]['true']) + (len(INSTRUCTIONS_SET[inst]['t0']) if 't0' in INSTRUCTIONS_SET[inst] else len(DEFAULT_T0))
    else:
        branch_cycles = None

    return std_cycles, branch_cycles

##################################################################
## Verify CONTROL_BITS
##
def verifyControlBits():
    rev_dict = {}
    for key, value in CONTROL_BITS.items():
        rev_dict.setdefault((value['eeprom'],value['bit']), set()).add(key)
    result = [key for key, values in rev_dict.items() if len(values) > 1]
    if len(result) > 0:
        raise Exception("Duplicated entry in CONTROL_BITS (eeprom,bit): " + str(result))
    
    return

##################################################################
## Generate Instructions
##
##
def generateInstructions(ihs):
    for i in INSTRUCTIONS_SET:
        print("-> 0x{:02X} - {} - {} - {}".format(INSTRUCTIONS_SET[i]['c'], i, INSTRUCTIONS_SET[i]['f'] if 'f' in INSTRUCTIONS_SET[i] else '[]', INSTRUCTIONS_SET[i]['d']))
        offset = INSTRUCTIONS_SET[i]['c'] << 5
        if (not 't0' in INSTRUCTIONS_SET[i]):
            ist = DEFAULT_T0 + INSTRUCTIONS_SET[i]['m'] # add T0/T1..
        else:
            ist = INSTRUCTIONS_SET[i]['t0'] + INSTRUCTIONS_SET[i]['m']
        ist[-1] = ist[-1] + CC_LAST_T # add NOP
        for x in ist:
            cw = getControlWord(x)
            for e in range(CONTROL_ROMS_COUNT):
                ihs[e][offset] = cw[e]
            offset += 1

        # conditional true
        if ('true' in INSTRUCTIONS_SET[i]):
            offset = INSTRUCTIONS_SET[i]['c'] << 5
            offset += 0x10  # true mc is stored from 0x10 address
            ist = INSTRUCTIONS_SET[i]['true']  
            ist[-1] = ist[-1] + CC_LAST_T # add NOP
            for x in ist:
                cw = getControlWord(x)
                for e in range(CONTROL_ROMS_COUNT):
                    ihs[e][offset] = cw[e]
                offset += 1          

##################################################################
## Generate ruldef.asm file
##
## 
def generateRuldef():
    with open('assembly/ruledef.asm', 'w') as f:
        f.write("; This file is autogenerated, do not edit.\n")
        f.write('#once\n')
        f.write('#ruledef\n')
        f.write('{\n')
        for i in INSTRUCTIONS_SET:
            flags = ('[' + ' '.join(INSTRUCTIONS_SET[i]['f'])  + ']') if 'f' in INSTRUCTIONS_SET[i] else ''

            f.writelines([  '\t; ' + INSTRUCTIONS_SET[i]['d'], ' ', flags , '\n',
                            '\t', i[:3], 
                            (' (' if i[3:6] == 'ind' else ' ') + 
                            #('#' if len(i) == 4 and i[3] == 'i' else '') +
                            (('{value: ' + INSTRUCTIONS_SET[i]['v'] + '}') if 'v' in INSTRUCTIONS_SET[i] else '') +  
                            ((INSTRUCTIONS_SET[i]['op']) if 'op' in INSTRUCTIONS_SET[i] else ''),
                            (')' if i[3:6] == 'ind' else ''),    
                            (',' + INSTRUCTIONS_SET[i]['i'] + ' ') if 'i' in INSTRUCTIONS_SET[i] else '',                             
                            ' => { \n',
                            ('\t\tassert(value >= 0)\n\t\tassert(value <= 0xff)\n') if 'v' in INSTRUCTIONS_SET[i] and INSTRUCTIONS_SET[i]['v'] == 'u8' else '',
                            ('\t\tassert(value >= 0x100)\n\t\tassert(value <= 0xffff)\n') if 'v' in INSTRUCTIONS_SET[i] and INSTRUCTIONS_SET[i]['v'] == 'u16' else '',
                            ('\t\tassert(value >= 0x10000)\n\t\tassert(value <= 0xffffff)\n') if 'v' in INSTRUCTIONS_SET[i] and INSTRUCTIONS_SET[i]['v'] == 'u24' else '',
                            '\t\t0x', '{:02X}'.format(INSTRUCTIONS_SET[i]['c']), 
                            (' @ value') if 'v' in INSTRUCTIONS_SET[i] else '', 
                            (' @ (value + 1)`16' ) if 'w' in INSTRUCTIONS_SET[i] else '',
                            ''.join([' @ ' + '0x' + '{:02X}'.format(x) for x in INSTRUCTIONS_SET[i]['b']]) if 'b' in INSTRUCTIONS_SET[i] else '',
                            '\n \t} \n'
                        ])
            
            if len(i) == 4 and i[3] == 'i': # immediate addressing, create alias with # prefix
                f.writelines([  '\t', 
                                i[:3] + (' #{value: ' + INSTRUCTIONS_SET[i]['v'] + '}') +  
                                ' => asm { ' + i[:3] + (' {value} }'),
                                '\n'
                            ])
        f.write('}\n')

##################################################################
## Generate istructions.csv file (for reference)
##
## 
def generateIstructionsCsv():

    modes = {
        '' : '',
        'i': 'immediate',
        'a': 'absolute',
        'p': 'zero page',
        'acc': 'accumulator',
        'indp': 'indirect - zero page',
        'inda': 'indirect - absolute',
        'indpx': 'indirect - zero page - X index',
        'indpy': 'indirect - zero page - Y index',
        'depx': 'DE pointer - zero page - X index',
        'ydeax': 'YDE pointer - absolute - X index',

        'px': 'zero page - X index',
        'py': 'zero page - Y index',
        'ax': 'absolute - X index',
        'ay': 'absolute - Y index',

        'xr': 'X registry',
        'yr': 'Y registry',
        'dr': 'D registry',
        'er': 'E registry'
    }

    sample_values = {
        'u8': '0x07',
        'u16': '0x7503',
        'u24': '0x2234FA'
    }

    values_len = {
        'u8': 1,
        'u16': 2,
        'u24': 3
    }

    with open('istructions.csv', 'w') as f:
        f.write("Opcode,Instruction,Mode,Cycles,Cycles (true condition),Len,Flags,Description,Example\n")
        for i in INSTRUCTIONS_SET:
            f.write("0x{:02X},{},{},{},{},{},{},{},{}\n".format(
                INSTRUCTIONS_SET[i]['c'], 
                '"' + i[:3] + '"',
                '"' + modes[i[3:]] + '"', 
                INSTRUCTIONS_SET[i]['cycles'],
                INSTRUCTIONS_SET[i]['cycles_true'] if INSTRUCTIONS_SET[i]['cycles_true'] != None else 'N/A',
                1 + (len(INSTRUCTIONS_SET[i]['b']) if 'b' in INSTRUCTIONS_SET[i] else 0) + (values_len[INSTRUCTIONS_SET[i]['v']] if 'v' in INSTRUCTIONS_SET[i] else 0) + (values_len[INSTRUCTIONS_SET[i]['v']] if 'w' in INSTRUCTIONS_SET[i] else 0),
                '"' + ' '.join(INSTRUCTIONS_SET[i]['f'] if 'f' in INSTRUCTIONS_SET[i] else []) + '"', 
                '"' + INSTRUCTIONS_SET[i]['d'] + '"',   
                '"' + i[:3] 
                      + (' (' if i[3:6] == 'ind' else ' ')
                      + ((sample_values[INSTRUCTIONS_SET[i]['v']]) if 'v' in INSTRUCTIONS_SET[i] else '')
                      + ((INSTRUCTIONS_SET[i]['op'].upper()) if 'op' in INSTRUCTIONS_SET[i] else '') 
                      + (')' if i[3:6] == 'ind' else '')
                      + ((',' + INSTRUCTIONS_SET[i]['i'].upper()) if 'i' in INSTRUCTIONS_SET[i] else '') 
                      + '"'
                      )
            )

##################################################################
## Generate istructions.asm file (for kernel assembly dump)
##
## 
def generateIstructionsAsm():
    value_length = {
        'u8': 1,
        'u16': 2,
        'u24': 3
    }

    with open('kernel/istructions.asm', 'w') as f:
        f.write("; This file is autogenerated, do not edit.\n")
        f.write("#once\n#bank kernel\n\n")
        f.write("ISTRUCTIONS:\n\n")
        f.write("; **********************************************************\n")
        f.write(";  Opcode description (prefix, value size, postfix)\n\n")
        for x in range(256):
            for i in INSTRUCTIONS_SET:
                if INSTRUCTIONS_SET[i]['c'] == x:
                    f.write(".OPCODE_0x{:02X}: \n    #d  0x{:02X}, 0x{:02X}, \"{}\", 0x00, \"{}\", 0x00\n".format(
                            INSTRUCTIONS_SET[i]['c'], 
                            ((value_length[INSTRUCTIONS_SET[i]['v']]) if 'v' in INSTRUCTIONS_SET[i] else 0) + ((value_length[INSTRUCTIONS_SET[i]['v']]) if 'w' in INSTRUCTIONS_SET[i] else 0) + (len(INSTRUCTIONS_SET[i]['b']) if 'b' in INSTRUCTIONS_SET[i] else 0),
                            ((value_length[INSTRUCTIONS_SET[i]['v']]) if 'v' in INSTRUCTIONS_SET[i] else 0),
                            i[:3]  + (' (' if i[3:6] == 'ind' else ''),
                            (' ' if (('op' in INSTRUCTIONS_SET[i]) and (i[3:6] != 'ind')) else '')    
                                + ((INSTRUCTIONS_SET[i]['op'].upper()) if 'op' in INSTRUCTIONS_SET[i] else '') 
                                + (')' if i[3:6] == 'ind' else '')
                                + ((',' + INSTRUCTIONS_SET[i]['i'].upper()) if 'i' in INSTRUCTIONS_SET[i] else '')  
                        )
                    )
        f.write(".OPCODE_NOTVALID: \n    #d  0x00, 0x00, \"NOT VALID\", 0x00, \"\", 0x00\n\n\n") 
        f.write("; **********************************************************\n")
        f.write(";  Opcode description lookup table MSB\n\n")
        f.write(".OPCODE_MSB:\n")  
        for x in range(256):
            opcode_exists = False
            for i in INSTRUCTIONS_SET:
                if INSTRUCTIONS_SET[i]['c'] == x:
                    opcode_exists = True
                    f.write("    #d .OPCODE_0x{:02X}[15:8]\n".format( 
                        INSTRUCTIONS_SET[i]['c'])        
                    )  
            if not opcode_exists:
                f.write("    #d .OPCODE_NOTVALID[15:8]\n".format(x))  
        f.write("\n\n")
        f.write("; **********************************************************\n")
        f.write(";  Opcode description lookup table LSB\n\n")
        f.write(".OPCODE_LSB:\n")  
        for x in range(256):
            opcode_exists = False
            for i in INSTRUCTIONS_SET:
                if INSTRUCTIONS_SET[i]['c'] == x:
                    opcode_exists = True
                    f.write("    #d .OPCODE_0x{:02X}[7:0]\n".format( 
                        INSTRUCTIONS_SET[i]['c'])        
                    )  
            if not opcode_exists:
                f.write("    #d .OPCODE_NOTVALID[7:0]\n".format(x))  

##################################################################
## Clean & Preset
##
## This is used to set T1/T2 of all available instructions
def cleanAndPreset(ihs):
    a = getControlWord(CC_LOAD_PC_POINTED_RAM_INTO_IR)
    b = getControlWord(CC_PC_INCREMENT + CC_LAST_T)
    c = getControlWord(CC_LAST_T) # safety
    for x in range(256):
        for e in range(CONTROL_ROMS_COUNT):
            ihs[e][x*32] = a[e]  
            ihs[e][x*32 + 1] = b[e]  
            for i in range(30):
                ihs[e][x*32 + 2 + i] = c[e]

##################################################################
## Main
##
##
if __name__ == "__main__":

    print("\nCustom-SAP - EEPROM microcode generator")

    ## Check  
    print("Verifing the instruction set")
    verifyInstructionSet()
    verifyControlBits()
    
    ## Generate rom files (microcode)
    ihs = []
    for e in range(CONTROL_ROMS_COUNT):
        ih = IntelHex()
        ihs.append(ih)
    cleanAndPreset(ihs)

    print("Generating instructions")
    generateInstructions(ihs)

    for e in range(CONTROL_ROMS_COUNT):
        ihs[e].write_hex_file("roms/cw{0}-rom.hex".format(e+1))
        ihs[e].tobinfile("roms/cw{0}-rom.bin".format(e+1))

    print("Generating customasm ruledef.asm file")
    generateRuldef()

    print("Generating istructions.csv file")
    generateIstructionsCsv()   

    print("Generating istructions.asm file")
    generateIstructionsAsm()     

    print("All done, {} instructions generated\n".format(len(INSTRUCTIONS_SET)))