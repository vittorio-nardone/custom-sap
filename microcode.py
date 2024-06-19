
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
    "ALUCN":        { "eeprom": 1, "bit": 6, "lowActive": False },
    "ALUM":         { "eeprom": 1, "bit": 7, "lowActive": False }, 
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

######## 
CC_LOAD_PC_POINTED_RAM_INTO_IR      = ['LIR','ERAM','EPCADDR', 'MEMADDRVALID']
CC_PC_INCREMENT                     = ['CPC']
CC_LAST_T                           = ['notNOP']

CC_INC_STACK_POINTER           = ['SPD', 'notCSP']
CC_DEC_STACK_POINTER           = ['notCSP']

CC_ALU_DETECT_ZERO             = ['LRALU-IN', 'ALUCN', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3']

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

INSTRUCTIONS_SET = {
    "HLT": {    "c": 0xFF,  
                "d": "Freeze CPU",     
                "m": [ ['notHLT'] ] },

    "SCS": {    "c": 0x01,  
                "d": "Set CPU speed to SLOW",     
                "m": [ CC_notLOWSPEED ] },

    "SCF": {    "c": 0x02,  
                "d": "Set CPU speed to FAST",     
                "m": [ CC_HIGHSPEED ] },

    "LDAi": {   "c": 0xA9,  
                "d": "Load Accumulator with Memory (immediate)", 
                "f": ['Z'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR'] + CC_LACC + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },

    "LDAp": {   "c": 0xAD,  
                "d": "Load Accumulator with Memory (zero page)", 
                "f": ['Z'],
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },

    "LDAa": {   "c": 0xA7,  
                "d": "Load Accumulator with Memory (absolute)", 
                "f": ['Z'],
                "v": "u24",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },

    "LDApx": {  "c": 0xBD,  # Cross page not supported
                "d": "Load Accumulator with Memory (page,X)", 
                "f": ['Z','O'],
                "v": "u16",
                "i": "x",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LACC,  
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,       
                        ['LMARH'] + CC_notEACC,
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEACC,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },      

    "LDAax": {  "c": 0xBE,  # Cross page not supported
                "d": "Load Accumulator with Memory (absolute,X)", 
                "f": ['Z','O'],
                "v": "u24",
                "i": "x",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR'],
                        ['CPC'],
                        ['ERAM', 'EPCADDR'] + CC_LACC,  
                        ['CPC'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX, 
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
                "d": "Load Index X with Memory (immediate)", 
                "f": ['Z'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR'] + CC_LX + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },               

    "LDXp": {   "c": 0xA3,  
                "d": "Load Index X with Memory (zero page)", 
                "f": ['Z'],
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },

    "LDXa": {   "c": 0xA4,  
                "d": "Load Index X with Memory (absolute)", 
                "f": ['Z'],
                "v": "u24",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR'],
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR'],
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'LZN', 'MEMADDRVALID'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },

    "LDYi": {   "c": 0xA0,  
                "d": "Load Index Y with Memory (immediate)", 
                "f": ['Z'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR'] + CC_LY + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },   

    "LDDi": {   "c": 0xA5,  
                "d": "Load Index D with Memory (immediate)", 
                "f": ['Z'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR'] + CC_LD + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },   

    "LDEi": {   "c": 0xA6,  
                "d": "Load Index E with Memory (immediate)", 
                "f": ['Z'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LZN', 'EPCADDR'] + CC_LE + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },   

    "STAp": {   "c": 0x8D,  
                "d": "Store Accumulator in Memory (zero page)", 
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ] },      

    "STAa": {   "c": 0x8E,  
                "d": "Store Accumulator in Memory (absolute)", 
                "v": "u24",
                "m": [  
                        ['ERAM', 'LMARPAGE', 'EPCADDR'], 
                        ['CPC'],
                        ['ERAM', 'LMARH', 'EPCADDR'], 
                        ['CPC'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ] },  

    "STApx": {  "c": 0x9D,  # Cross page not supported
                "d": "Store Accumulator in Memory (page,X)", 
                "v": "u16",
                "i": "x",
                "f": ['O'],
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP, 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX, 
                        ['ERALU-OUT', 'LMARL'] + CC_CHKO,  
                        ['LMARH'] + CC_notETMP,
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['ERALU-OUT', 'LMARH'],
                        ['EMAR', 'WRAM', 'MEMADDRVALID'] + CC_notEACC,
                    ] },   

    "TAO":  {   "c": 0xAB,  
                "d": "Transfer Accumulator to Output", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LOUT + CC_notEACC  
                    ] },     

    "TIA":  {   "c": 0xAC,  
                "d": "Transfer Interrupt register to Accumulator", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + ['EINT-OUT'] + CC_LACC 
                    ] }, 

    "TAI":  {   "c": 0xAE,  
                "d": "Transfer Accumulator to Interrupt mask register", 
                "m": [  
                        ['LINT-MASK'] + CC_notEACC, 
                    ] }, 

    "TXA":  {   "c": 0x8A,  
                "d": "Transfer Index X to Accumulator", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LACC + CC_notEX 
                    ] },     

    "TAX":  {   "c": 0xAA,  
                "d": "Transfer Accumulator to Index X", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LX + CC_notEACC 
                    ] },   


    "TYA":  {   "c": 0xBA,  
                "d": "Transfer Index Y to Accumulator", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LACC + CC_notEY  
                    ] },  

    "TAY":  {   "c": 0xBB,  
                "d": "Transfer Accumulator to Index Y", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LY + CC_notEACC  
                    ] },  

    "TYE":  {   "c": 0x8B,  
                "d": "Transfer Index Y to Index E", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LE + CC_notEY 
                    ] },                                     

    "TEY":  {   "c": 0x8C,  
                "d": "Transfer Index E to Index Y", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LY + CC_notEE 
                    ] },   

    "TXD":  {   "c": 0x9B,  
                "d": "Transfer Index X to Index D", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LD + CC_notEX 
                    ] },                                     

    "TDX":  {   "c": 0x9C,  
                "d": "Transfer Index D to Index X", 
                "m": [  
                        ['LZN'] + CC_ALU_DETECT_ZERO + CC_LX + CC_notED 
                    ] },   

    "ADCi": {   "c": 0x69,  
                "d": "Add Memory to Accumulator with Carry (immediate)",   
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR'] + CC_CHKC, 
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO
                    ] },     

    "ADCp": {   "c": 0x6D,  
                "d": "Add Memory to Accumulator with Carry (zero page)",   
                "f": ['Z', 'C'],
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['EMAR', 'ERAM', 'LRALU-IN', 'MEMADDRVALID'] + CC_CHKC,                                           
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     

    "ADCdr": {  "c": 0x6F,  
                "d": "Add Index D to Accumulator with Carry (Index D)",   
                "f": ['Z', 'C'],
                "op": "d",
                "m": [  
                        ['LRALU-IN'] + CC_CHKC + CC_notED,
                        ['ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC,
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO
                    ] },  

    "SBCi": {   "c": 0xE9,  
                "d": "Subtract Memory from Accumulator with Borrow (immediate)",   
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['LRALU-IN'] + CC_notEACC + CC_CHKC, 
                        ['ERAM', 'ALUCN', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'EPCADDR'],
                        ['CPC', 'ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ], 
                "true": [
                        ['ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'EPCADDR'],
                        ['CPC', 'ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     

    "SBCp": {   "c": 0xED,  
                "d": "Subtract Memory from Accumulator with Borrow (zero page)",  
                "f": ['Z', 'C'], 
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'], 
                        ['CPC', 'LMARPAGEZERO'],  
                        ['ERAM', 'LMARL', 'EPCADDR'],                     
                        ['CPC', 'LRALU-IN'] + CC_notEACC + CC_CHKC, 
                        ['EMAR', 'ERAM', 'ALUCN', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['EMAR', 'ERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC', 'MEMADDRVALID'],
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },  

    "SBXer": {  "c": 0xEF,  
                "d": "Subtract Index E from Index X with Borrow (Index X)",   
                "f": ['Z', 'C'],
                "op": "e",
                "m": [  
                        ['LRALU-IN'] + CC_notEX + CC_CHKC, 
                        ['ALUCN', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEE,
                        ['ERALU-OUT', 'LZN'] + CC_LX + CC_ALU_DETECT_ZERO  
                    ], 
                "true": [
                        ['ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEE,
                        ['ERALU-OUT', 'LZN'] + CC_LX + CC_ALU_DETECT_ZERO  
                    ] },    

    "INCp": {   "c": 0xEE,  
                "d": "Increment Memory by One (zero page)",  
                "f": ['Z'],  
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'MEMADDRVALID'], 
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'MEMADDRVALID'],
                        ['EMAR', 'ERAM', 'MEMADDRVALID', 'LZN']  + CC_ALU_DETECT_ZERO  
                    ] },     

    "INX": {   "c": 0xE8,  
                "d": "Increment Index X by One",  
                "f": ['Z'],  
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEX, 
                        ['ERALU-OUT', 'LZN'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },     

    "INY": {   "c": 0xC8,  
                "d": "Increment Index Y by One",  
                "f": ['Z'],  
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEY, 
                        ['ERALU-OUT', 'LZN'] + CC_LY + CC_ALU_DETECT_ZERO 
                    ] },                    

    "DECp": {   "c": 0xCE,  
                "d": "Decrement Memory by One (zero page)",  
                "f": ['Z'],  
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'LRALU-IN', 'LRALU-OUT', 'ALUCN', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3', 'MEMADDRVALID'], 
                        ['ERALU-OUT', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_ALU_DETECT_ZERO
                    ] },   

    "DEX": {   "c": 0xCA,  
                "d": "Decrement Index X by One",  
                "f": ['Z'],  
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT', 'ALUCN', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3'] + CC_notEX, 
                        ['ERALU-OUT', 'LZN'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },   

    "DEY": {   "c": 0xCB,  
                "d": "Decrement Index Y by One",  
                "f": ['Z'],  
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT', 'ALUCN', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3'] + CC_notEY, 
                        ['ERALU-OUT', 'LZN'] + CC_LY + CC_ALU_DETECT_ZERO 
                    ] },   

    "EORi": {   "c": 0x49,  
                "d": "Exclusive-OR Memory with Accumulator (immediate)",  
                "f": ['Z'],  
                "v": "u8",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'LRALU-OUT', 'ALUM', 'ALUS1', 'ALUS2'] + CC_notEACC, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },   

    "ANDi": {   "c": 0x29,  
                "d": "AND Memory with Accumulator (immediate)",  
                "f": ['Z'],  
                "v": "u8",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'LRALU-OUT', 'ALUM', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC, 
                        ['ERALU-OUT', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },  

    "ROLacc": { "c": 0x2A,  #carry is NOT set with removed bit value (!= 6502)
                "d": "Rotate One Bit Left (accumulator)",
                "op": "a",  
                "f": ['Z', 'N'], 
                "m": [  
                        CC_LTMP + CC_notEACC, 
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  

    "ROLer": { "c": 0x2B,  #carry is NOT set with removed bit value (!= 6502)
                "d": "Rotate One Bit Left (Index E)",
                "op": "e",  
                "f": ['Z', 'N'], 
                "m": [  
                        CC_LTMP + CC_notEE, 
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LE + CC_ALU_DETECT_ZERO 
                    ] }, 

    "ROLdr": { "c": 0x2C,  #carry is NOT set with removed bit value (!= 6502)
                "d": "Rotate One Bit Left (Index D)",
                "op": "d",  
                "f": ['Z', 'N'], 
                "m": [  
                        CC_LTMP + CC_notED, 
                        ['tmpS1', 'LZN'] + CC_notETMP + CC_LD + CC_ALU_DETECT_ZERO 
                    ] }, 

    "ROLp": {   "c": 0x26,  #carry is NOT set with removed bit value (!= 6502)
                "d": "Rotate One Bit Left (zero page)", 
                "f": ['Z', 'N'], 
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP,
                        ['tmpS1', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO
                    ] },


    "RORacc": { "c": 0x6A, #carry is NOT set with removed bit value (!= 6502) 
                "d": "Rotate One Bit Right (accumulator)",
                "op": "a",  
                "f": ['Z', 'N'], 
                "m": [  
                        CC_LTMP + CC_notEACC, 
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },  
     
    "RORer": {  "c": 0x6B,  #carry is NOT set with removed bit value (!= 6502)
                "d": "Rotate One Bit Right (Index E)",
                "op": "e",  
                "f": ['Z', 'N'], 
                "m": [  
                        CC_LTMP + CC_notEE, 
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LE + CC_ALU_DETECT_ZERO 
                    ] }, 

    "RORdr": {  "c": 0x6C,  #carry is NOT set with removed bit value (!= 6502)
                "d": "Rotate One Bit Right (Index D)",
                "op": "d",  
                "f": ['Z', 'N'], 
                "m": [  
                        CC_LTMP + CC_notED, 
                        ['tmpS0', 'LZN'] + CC_notETMP + CC_LD + CC_ALU_DETECT_ZERO 
                    ] }, 

    "RORp": {   "c": 0x66, #carry is NOT set with removed bit value (!= 6502) 
                "d": "Rotate One Bit Right (zero page)", 
                "f": ['Z', 'N'], 
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LTMP,
                        ['tmpS0', 'EMAR', 'WRAM', 'LZN', 'MEMADDRVALID'] + CC_notETMP + CC_ALU_DETECT_ZERO
                    ] },

    "CMPi": {   "c": 0xC9,  
                "d": "Compare Memory with Accumulator (immediate)", 
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notEACC,
                    ] },      

    "CMPp": {   "c": 0x5C,  
                "d": "Compare Memory with Accumulator (zero page)", 
                "f": ['Z', 'C'],
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'],
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'MEMADDRVALID', 'LRALU-IN'],
                        ['ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notEACC,
                    ] },   

    "CPXi": {   "c": 0xE0,  
                "d": "Compare Memory and Index X (immediate)", 
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notEX,
                    ] },      

    "CPXyr": {  "c": 0xE1,  
                "d": "Compare Index Y and Index X (Index Y)", 
                "f": ['Z', 'C'],
                "op": "y",
                "m": [  
                        ['LRALU-IN'] + CC_notEY, 
                        ['ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notEX,
                    ] },   

    "CPXer": {  "c": 0xE2,  
                "d": "Compare Index E and Index X (Index E)", 
                "f": ['Z', 'C'],
                "op": "e",
                "m": [  
                        ['LRALU-IN'] + CC_notEE, 
                        ['ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notEX,
                    ] },   

    "CPXdr": {  "c": 0xEB,  
                "d": "Compare Index E and Index X (Index D)", 
                "f": ['Z', 'C'],
                "op": "d",
                "m": [  
                        ['LRALU-IN'] + CC_notED, 
                        ['ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notEX,
                    ] },   

    "CPYi": {   "c": 0xE3,  
                "d": "Compare Memory and Index Y (immediate)", 
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notEY,
                    ] },      

    "CPEi": {   "c": 0xE4,  
                "d": "Compare Memory with Index E (immediate)", 
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notEE,
                    ] },   

    "CPDi": {   "c": 0xE5,  
                "d": "Compare Memory with Index D (immediate)", 
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['ERAM', 'LRALU-IN', 'EPCADDR'], 
                        ['CPC', 'ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZN'] + CC_notED,
                    ] },   

    "JMPp": {   "c": 0x4C,  
                "d": "Jump to New Location (zero page)", 
                "v": "u16",
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR, CC_PC_INCREMENT ],
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCHP0
                    ] },     

    "JMPa": {   "c": 0x4D,  
                "d": "Jump to New Location (absolute)", 
                "v": "u24",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE 
                    ] },       

    "JSRp": {   "c": 0x20,  
                "d": "Jump to New Location Saving Return Address (zero page)", 
                "v": "u16",
                "b": [0x00],
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR, CC_PC_INCREMENT ],
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCPAGE,
                        CC_INC_STACK_POINTER,
                        ['ERAM', 'EPCADDR'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0  
                    ] },      

    "JSRa": {   "c": 0x21,  
                "d": "Jump to New Location Saving Return Address (absolute)", 
                "v": "u24",
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR, CC_PC_INCREMENT ],
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'WRAM'] + CC_notEPCPAGE,
                        CC_INC_STACK_POINTER,
                        ['ERAM', 'EPCADDR'] + CC_LTMP,
                        ['ESP', 'WRAM'] + CC_notETMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_LTMP,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCH,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE  
                    ] },    

    "RTS":  {   "c": 0x60,  
                "d": "Return from Subroutine", 
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR, CC_PC_INCREMENT ],
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
                "m": [  
                        ['ESP', 'WRAM'] + CC_notEACC,
                        CC_INC_STACK_POINTER,
                    ] },      

    "PLA":  {   "c": 0x68,  
                "d": "Pull Accumulator from Stack", 
                "f": ['Z'],
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM', 'LZN'] + CC_LACC + CC_ALU_DETECT_ZERO
                    ] },      

    "BEQp": {   "c": 0xF0,  
                "d": "Branch on Result Zero (zero page)", 
                "v": "u16",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP + CC_CHKZ,
                        ['CPC'], 
                        ['CPC']
                    ],
                "true": [
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0 
                    ] },   

    "BNEp": {   "c": 0xD0,  
                "d": "Branch on Result not Zero (zero page)", 
                "v": "u16",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP + CC_CHKZ,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP + CC_notLPCHP0 
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                    ] },   

    "BCSp": {   "c": 0xB0,  
                "d": "Branch on Carry Set (zero page)", 
                "v": "u16",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP + CC_CHKC,
                        ['CPC'], 
                        ['CPC']
                    ],
                "true": [
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0 
                    ] },    

    "BCCp": {   "c": 0x90,  
                "d": "Branch on Carry Clear (zero page)", 
                "v": "u16",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP + CC_CHKC,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                    ] },                                          

    "BMI": {   "c": 0x30,  
                "d": "Branch on Result Minus (zero page)", 
                "v": "u16",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP + CC_CHKN,
                        ['CPC'], 
                        ['CPC']
                    ],
                "true": [
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0 
                    ] }, 

    "BPLp": {   "c": 0x10,  
                "d": "Branch on Result Plus (zero page)", 
                "v": "u16",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LTMP + CC_CHKN,
                        ['CPC'], 
                        ['ERAM', 'EPCADDR'] + CC_notLPCL, 
                        CC_notETMP  + CC_notLPCHP0
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                    ] },                                          
   

    "LDOi": {   "c": 0xFE,  
                "d": "Load Output with Memory (immediate)", 
                "v": "u8",
                "m": [  
                        ['ERAM', 'EPCADDR'] + CC_LOUT, 
                        ['CPC']  
                    ] },

    "LDOp": {   "c": 0xFD,  
                "d": "Load Output with Memory (zero page)", 
                "v": "u16",
                "m": [  
                        ['ERAM', 'LMARH', 'EPCADDR'], 
                        ['CPC', 'LMARPAGEZERO'],
                        ['ERAM', 'LMARL', 'EPCADDR'], 
                        ['CPC', 'EMAR', 'ERAM', 'MEMADDRVALID'] + CC_LOUT  
                    ] },

    "CLC": {    "c": 0x18,  
                "d": "Clear Carry Flag", 
                "f": ['C'],
                "m": [  
                        ['notCLC'], 
                    ] },                    

    "SEC": {    "c": 0x38,  
                "d": "Set Carry Flag", 
                "f": ['C'],
                "m": [  
                        CC_SEC, 
                     ] },                    

    "NOP": {    "c": 0xEA,  
                "d": "No Operation",     
                "m": [ [] ] },     

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
                        ['ALUM', 'ALUS0', 'ALUS1', 'LRALU-OUT']  + CC_notEACC,   # 0x0000
                        ['ERALU-OUT'] + CC_notLPCHP0,
                        ['ALUM', 'ALUS2', 'ALUS3', 'LRALU-OUT']  + CC_notEACC,   # 0xFF
                        ['ERALU-OUT', 'notDISI'] + CC_notLPCL
                     ] },    

    "RTI":  {   "c": 0x40,  
                "d": "Return from Interrupt", 
                "f": ['I'],
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR ], # don't check I to resume next op
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCPAGE,
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCH,
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM'] + CC_notLPCL,
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'ERAM', 'LC', 'LZN', 'notENAI'] + CC_EFRIN  
                    ] },           

    "SEI":  {   "c": 0x78,  
                "d": "Set interrupt disable", 
                "f": ['I'],
                "m": [  
                        ['notDISI']     
                    ] },         

    "CLI":  {   "c": 0x58,  
                "d": "Clear interrupt disable", 
                "f": ['I'],
                "m": [  
                        ['notENAI']     
                    ] },                                                                      
                                
}

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
    result = [key for key, values in rev_dict.items() if len(values) > 1]
    if len(result) > 0:
        raise Exception("Duplicated op code in INSTRUCTIONS_SET: " + str(result))

    for inst in INSTRUCTIONS_SET.keys():
        for wset in ['m','true','t0']:
            if wset in INSTRUCTIONS_SET[inst]:
                for w in INSTRUCTIONS_SET[inst][wset]:
                    for b in w:
                        if not b in CONTROL_BITS.keys():
                            raise Exception("Unknown control bit '" + b + "' in instruction '" + inst + "'")
    return

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
    with open('ruledef.asm', 'w') as f:
        f.write('#once\n')
        f.write('#ruledef\n')
        f.write('{\n')
        for i in INSTRUCTIONS_SET:
            flags = ('[' + ' '.join(INSTRUCTIONS_SET[i]['f'])  + ']') if 'f' in INSTRUCTIONS_SET[i] else ''

            f.writelines([  '\t; ' + INSTRUCTIONS_SET[i]['d'], ' ', flags , '\n',
                            '\t', i[:3], 
                            (' {value: ' + INSTRUCTIONS_SET[i]['v'] + '}') if 'v' in INSTRUCTIONS_SET[i] else '', 
                            (',' + INSTRUCTIONS_SET[i]['i'] + ' ') if 'i' in INSTRUCTIONS_SET[i] else '', 
                            (' ' + INSTRUCTIONS_SET[i]['op']) if 'op' in INSTRUCTIONS_SET[i] else '',
                            ' => { \n',
                            ('\t\tassert(value >= 0)\n\t\tassert(value <= 0xff)\n') if 'v' in INSTRUCTIONS_SET[i] and INSTRUCTIONS_SET[i]['v'] == 'u8' else '',
                            ('\t\tassert(value >= 0)\n\t\tassert(value <= 0xffff)\n') if 'v' in INSTRUCTIONS_SET[i] and INSTRUCTIONS_SET[i]['v'] == 'u16' else '',
                            ('\t\tassert(value >= 0x10000)\n\t\tassert(value <= 0xffffff)\n') if 'v' in INSTRUCTIONS_SET[i] and INSTRUCTIONS_SET[i]['v'] == 'u24' else '',
                            '\t\t0x', '{:02X}'.format(INSTRUCTIONS_SET[i]['c']), 
                            (' @ value') if 'v' in INSTRUCTIONS_SET[i] else '', 
                            ''.join([' @ ' + '0x' + '{:02X}'.format(x) for x in INSTRUCTIONS_SET[i]['b']]) if 'b' in INSTRUCTIONS_SET[i] else '',
                            '\n \t} \n'
                        ])
        f.write('}\n')

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

    print("All done, {} instructions generated\n".format(len(INSTRUCTIONS_SET)))