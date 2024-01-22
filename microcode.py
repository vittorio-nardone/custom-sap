
from intelhex import IntelHex

##################################################################
## Configuration
##
##
CONTROL_ROMS_COUNT = 9

##################################################################
## Control bits
##
##
CONTROL_BITS = {
    ## EEPROM #1
    "e10":          { "eeprom": 0, "bit": 0, "lowActive": False },
    "notERAM":      { "eeprom": 0, "bit": 1, "lowActive": True },
    "e12":          { "eeprom": 0, "bit": 2, "lowActive": False },
    "e13":          { "eeprom": 0, "bit": 3, "lowActive": False },
    "e14":          { "eeprom": 0, "bit": 4, "lowActive": False },
    "e15":          { "eeprom": 0, "bit": 5, "lowActive": False },
    "e16":          { "eeprom": 0, "bit": 6, "lowActive": False },
    "e17":          { "eeprom": 0, "bit": 7, "lowActive": False },
    ## EEPROM #2
    "LMARL":        { "eeprom": 1, "bit": 0, "lowActive": False },
    "LMARH":        { "eeprom": 1, "bit": 1, "lowActive": False },
    "notEMAR":      { "eeprom": 1, "bit": 2, "lowActive": True },
    "notWRAM":      { "eeprom": 1, "bit": 3, "lowActive": True },
    "e24":          { "eeprom": 1, "bit": 4, "lowActive": False },
    "e25":          { "eeprom": 1, "bit": 5, "lowActive": False },
    "LRALU-IN":     { "eeprom": 1, "bit": 6, "lowActive": False },
    "LRALU-OUT":    { "eeprom": 1, "bit": 7, "lowActive": False }, 
    ## EEPROM #3
    "ALUS0":        { "eeprom": 2, "bit": 0, "lowActive": False },   
    "ALUS1":        { "eeprom": 2, "bit": 1, "lowActive": False },   
    "ALUS2":        { "eeprom": 2, "bit": 2, "lowActive": False },   
    "ALUS3":        { "eeprom": 2, "bit": 3, "lowActive": False },   
    "ALUCN":        { "eeprom": 2, "bit": 4, "lowActive": False },   
    "ALUM":         { "eeprom": 2, "bit": 5, "lowActive": False },
    "notERALU-OUT": { "eeprom": 2, "bit": 6, "lowActive": True },
    "e37":          { "eeprom": 2, "bit": 7, "lowActive": False },
    ## EEPROM #4
    "e40":          { "eeprom": 3, "bit": 0, "lowActive": False },
    "e41":          { "eeprom": 3, "bit": 1, "lowActive": False },
    "e42":          { "eeprom": 3, "bit": 2, "lowActive": False },
    "e43":          { "eeprom": 3, "bit": 3, "lowActive": False },
    "LC":           { "eeprom": 3, "bit": 4, "lowActive": False },
    "CHKZ":         { "eeprom": 3, "bit": 5, "lowActive": False },
    "CHKC":         { "eeprom": 3, "bit": 6, "lowActive": False },
    "notCLC":       { "eeprom": 3, "bit": 7, "lowActive": True },
    ## EEPROM #5
    "notSEC":       { "eeprom": 4, "bit": 0, "lowActive": True },
    "LZ":           { "eeprom": 4, "bit": 1, "lowActive": False },
    "e52":          { "eeprom": 4, "bit": 2, "lowActive": False },
    "e53":          { "eeprom": 4, "bit": 3, "lowActive": False },
    "e54":          { "eeprom": 4, "bit": 4, "lowActive": False },
    "e55":          { "eeprom": 4, "bit": 5, "lowActive": False },
    "e56":          { "eeprom": 4, "bit": 6, "lowActive": False },
    "e57":          { "eeprom": 4, "bit": 7, "lowActive": False },
    ## EEPROM #6
    "e60":          { "eeprom": 5, "bit": 0, "lowActive": False },
    "e61":          { "eeprom": 5, "bit": 1, "lowActive": False },
    "e62":          { "eeprom": 5, "bit": 2, "lowActive": False },
    "e63":          { "eeprom": 5, "bit": 3, "lowActive": False },
    "LO":           { "eeprom": 5, "bit": 4, "lowActive": False },
    "CHKO":         { "eeprom": 5, "bit": 5, "lowActive": False },
    "notEFR-OUT":   { "eeprom": 5, "bit": 6, "lowActive": True },
    "EFR-IN":       { "eeprom": 5, "bit": 7, "lowActive": False },
    ## EEPROM #7 - Registers board
    "rL0":          { "eeprom": 6, "bit": 0, "lowActive": False },
    "rL1":          { "eeprom": 6, "bit": 1, "lowActive": False },
    "rL2":          { "eeprom": 6, "bit": 2, "lowActive": False },
    "rE0":          { "eeprom": 6, "bit": 3, "lowActive": False },
    "rE1":          { "eeprom": 6, "bit": 4, "lowActive": False },
    "rE2":          { "eeprom": 6, "bit": 5, "lowActive": False },
    "e76":          { "eeprom": 6, "bit": 6, "lowActive": False },
    "e77":          { "eeprom": 6, "bit": 7, "lowActive": False },
    ## EEPROM #8 - Instructions board
    "LIR":          { "eeprom": 7, "bit": 0, "lowActive": False },
    "CHKI":         { "eeprom": 7, "bit": 1, "lowActive": False },
    "notHLT":       { "eeprom": 7, "bit": 2, "lowActive": True },
    "notENAI":      { "eeprom": 7, "bit": 3, "lowActive": True },
    "LINT-MASK":    { "eeprom": 7, "bit": 4, "lowActive": False },
    "EINT-OUT":     { "eeprom": 7, "bit": 5, "lowActive": False }, 
    "notDISI":      { "eeprom": 7, "bit": 6, "lowActive": True },
    "notNOP":       { "eeprom": 7, "bit": 7, "lowActive": True },
    ## EEPROM #9 - PC/SP board
    "LPCL":         { "eeprom": 8, "bit": 0, "lowActive": False },
    "LPCH":         { "eeprom": 8, "bit": 1, "lowActive": False },
    "CPC":          { "eeprom": 8, "bit": 2, "lowActive": False },
    "notCSP":       { "eeprom": 8, "bit": 3, "lowActive": True },
    "SPD":          { "eeprom": 8, "bit": 4, "lowActive": False },
    "ESP":          { "eeprom": 8, "bit": 5, "lowActive": False }, 
    "pcE1":         { "eeprom": 8, "bit": 6, "lowActive": False },
    "pcE0":         { "eeprom": 8, "bit": 7, "lowActive": False },
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
#CC_avail  = ['rE2', 'rE1', 'rE0]

# Load (C) MUX
CC_LACC    = ['rL0']
CC_LX      = ['rL1']
CC_LY      = ['rL1', 'rL0']
CC_LTMP    = ['rL2']
CC_LED     = ['rL2', 'rL0']
CC_LEE     = ['rL2', 'rL1']
CC_LOUT    = ['rL2', 'rL1', 'rL0']

######## In PC/SP board
# Enable (OE) MUX
CC_notEPCL      = ['pcE0']
CC_notEPCH      = ['pcE1']
CC_notEPCADDR   = ['pcE1', 'pcE0']

######## 
CC_LOAD_PC_POINTED_RAM_INTO_IR      = ['LIR','notERAM'] + CC_notEPCADDR
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
    #             "b": [0x12, 0x34],                            <- add bytes after op code (only if v is not defined, else ignored)
    #             "f": ['Z'],                                   <- flags affected
    #             "v": "u8",                                    <- operand value definition (u8/u16)
    #             "op": "a",                                    <- operand label (no real value) (only if v is not defined, else ignored)
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

    "LDAi": {   "c": 0xA9,  
                "d": "Load Accumulator with Memory (immediate)", 
                "f": ['Z'],
                "v": "u8",
                "m": [  
                        ['notERAM', 'LZ'] + CC_LACC + CC_notEPCADDR + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },

    "LDAa": {   "c": 0xAD,  
                "d": "Load Accumulator with Memory (absolute)", 
                "f": ['Z'],
                "v": "u16",
                "m": [  
                        ['notERAM', 'LMARH'] + CC_notEPCADDR, 
                        ['CPC'],
                        ['notERAM', 'LMARL'] + CC_notEPCADDR, 
                        ['CPC', 'notEMAR', 'notERAM', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },

    "LDAax": {  "c": 0xBD,  
                "d": "Load Accumulator with Memory (absolute,X)", 
                "f": ['Z','O'],
                "v": "u16",
                "i": "x",
                "m": [  
                        ['notERAM'] + CC_LACC + CC_notEPCADDR,  
                        ['CPC'],
                        ['notERAM', 'LRALU-IN'] + CC_notEPCADDR, 
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX, 
                        ['notERALU-OUT', 'LMARL', 'CHKO'],       
                        ['LMARH'] + CC_notEACC,
                        ['notEMAR', 'notERAM', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ],
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEACC,
                        ['notERALU-OUT', 'LMARH'],
                        ['notEMAR', 'notERAM', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },                    

    "LDXi": {   "c": 0xA2,  
                "d": "Load Index X with Memory (immediate)", 
                "f": ['Z'],
                "v": "u8",
                "m": [  
                        ['notERAM', 'LZ'] + CC_LX + CC_notEPCADDR + CC_ALU_DETECT_ZERO, 
                        ['CPC']  
                    ] },               

    "STAa": {   "c": 0x8D,  
                "d": "Store Accumulator in Memory (absolute)", 
                "v": "u16",
                "m": [  
                        ['notERAM', 'LMARH'] + CC_notEPCADDR, 
                        ['CPC'],
                        ['notERAM', 'LMARL'] + CC_notEPCADDR, 
                        ['CPC', 'notEMAR', 'notWRAM'] + CC_notEACC  
                    ] },      

    "STAax": {  "c": 0x9D,  
                "d": "Store Accumulator in Memory (absolute,X)", 
                "v": "u16",
                "i": "x",
                "f": ['O'],
                "m": [  
                        ['notERAM'] + CC_LTMP + CC_notEPCADDR, 
                        ['CPC'],
                        ['notERAM', 'LRALU-IN'] + CC_notEPCADDR, 
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LO'] + CC_notEX, 
                        ['notERALU-OUT', 'LMARL', 'CHKO'],  
                        ['LMARH'] + CC_notETMP,
                        ['notEMAR', 'notWRAM'] + CC_notEACC  
                    ],               
                "true": [
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notETMP,
                        ['notERALU-OUT', 'LMARH'],
                        ['notEMAR', 'notWRAM'] + CC_notEACC,
                    ] },   

    "TAO":  {   "c": 0xAB,  
                "d": "Transfer Accumulator to Output", 
                "m": [  
                        CC_LOUT + CC_notEACC  
                    ] },     

    "TIA":  {   "c": 0xAC,  
                "d": "Transfer Interrupt register to Accumulator", 
                "m": [  
                        ['EINT-OUT'] + CC_LACC 
                    ] }, 

    "TAI":  {   "c": 0xAE,  
                "d": "Transfer Accumulator to Interrupt mask register", 
                "m": [  
                        ['LINT-MASK'] + CC_notEACC, 
                    ] }, 

    "TXA":  {   "c": 0x8A,  
                "d": "Transfer Index X to Accumulator", 
                "m": [  
                        CC_LACC + CC_notEX 
                    ] },     

    "TAX":  {   "c": 0xAA,  
                "d": "Transfer Accumulator to Index X", 
                "m": [  
                        CC_LX + CC_notEACC 
                    ] },                                     

    "ADCi": {   "c": 0x69,  
                "d": "Add Memory to Accumulator with Carry (immediate)",   
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['notERAM', 'LRALU-IN', 'CHKC'] + CC_notEPCADDR, 
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC,
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC']  + CC_notEACC,
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO
                    ] },     

    "ADCa": {   "c": 0x6D,  
                "d": "Add Memory to Accumulator with Carry (absolute)",   
                "f": ['Z', 'C'],
                "v": "u16",
                "m": [  
                        ['notERAM', 'LMARH'] + CC_notEPCADDR, 
                        ['CPC'],  
                        ['notERAM', 'LMARL'] + CC_notEPCADDR, 
                        ['notEMAR', 'notERAM', 'LRALU-IN', 'CHKC'],                                           
                        ['CPC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC,
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['CPC', 'ALUS0', 'ALUS3', 'LRALU-OUT', 'LC'] + CC_notEACC,
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     

    "SBCi": {   "c": 0xE9,  
                "d": "Subtract Memory from Accumulator with Borrow (immediate)",   
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['LRALU-IN', 'CHKC'] + CC_notEACC, 
                        ['notERAM', 'ALUCN', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEPCADDR,
                        ['CPC', 'notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ], 
                "true": [
                        ['notERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'] + CC_notEPCADDR,
                        ['CPC', 'notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },     

    "SBCa": {   "c": 0xED,  
                "d": "Subtract Memory from Accumulator with Borrow (absolute)",  
                "f": ['Z', 'C'], 
                "v": "u16",
                "m": [  
                        ['notERAM', 'LMARH'] + CC_notEPCADDR, 
                        ['CPC'],  
                        ['notERAM', 'LMARL'] + CC_notEPCADDR,                     
                        ['CPC', 'LRALU-IN', 'CHKC'] + CC_notEACC, 
                        ['notEMAR', 'notERAM', 'ALUCN', 'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'],
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ], 
                "true": [
                        ['notEMAR', 'notERAM',  'ALUS1', 'ALUS2', 'LRALU-OUT', 'LC'],
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },  


    "INCa": {   "c": 0xEE,  
                "d": "Increment Memory by One (absolute)",  
                "f": ['Z'],  
                "v": "u16",
                "m": [  
                        ['notERAM', 'LMARH'] + CC_notEPCADDR, 
                        ['CPC'],
                        ['notERAM', 'LMARL'] + CC_notEPCADDR, 
                        ['CPC', 'notEMAR', 'notERAM', 'LRALU-IN', 'LRALU-OUT'], 
                        ['notERALU-OUT', 'notEMAR', 'notWRAM', 'LZ'] + CC_ALU_DETECT_ZERO  
                    ] },     

    "INX": {   "c": 0xE8,  
                "d": "Increment Index X by One",  
                "f": ['Z'],  
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT'] + CC_notEX, 
                        ['notERALU-OUT', 'LZ'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },                     

    "DECa": {   "c": 0xCE,  
                "d": "Decrement Memory by One (absolute)",  
                "f": ['Z'],  
                "v": "u16",
                "m": [  
                        ['notERAM', 'LMARH'] + CC_notEPCADDR, 
                        ['CPC'],
                        ['notERAM', 'LMARL'] + CC_notEPCADDR, 
                        ['CPC', 'notEMAR', 'notERAM', 'LRALU-IN', 'LRALU-OUT', 'ALUCN', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3'], 
                        ['notERALU-OUT', 'notEMAR', 'notWRAM', 'LZ'] + CC_ALU_DETECT_ZERO
                    ] },   

    "DEX": {   "c": 0xCA,  
                "d": "Decrement Index X by One",  
                "f": ['Z'],  
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT', 'ALUCN', 'ALUS0', 'ALUS1', 'ALUS2', 'ALUS3'] + CC_notEX, 
                        ['notERALU-OUT', 'LZ'] + CC_LX + CC_ALU_DETECT_ZERO 
                    ] },   

    "EORi": {   "c": 0x49,  
                "d": "Exclusive-OR Memory with Accumulator (immediate)",  
                "f": ['Z'],  
                "v": "u8",
                "m": [  
                        ['notERAM', 'LRALU-IN'] + CC_notEPCADDR, 
                        ['CPC', 'LRALU-OUT', 'ALUM', 'ALUS1', 'ALUS2'] + CC_notEACC, 
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO 
                    ] },   

    "ANDi": {   "c": 0x29,  
                "d": "AND Memory with Accumulator (immediate)",  
                "f": ['Z'],  
                "v": "u8",
                "m": [  
                        ['notERAM', 'LRALU-IN'] + CC_notEPCADDR, 
                        ['CPC', 'LRALU-OUT', 'ALUM', 'ALUS1', 'ALUS3', 'ALUS0'] + CC_notEACC, 
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },  

    # Note: On Shift Left, the ALU:
    ## set carry if removed bit is 0
    ## clear carry if removed bit is 1
    "ASLacc": { "c": 0x0A,  
                "d": "Shift Left One Bit (accumulator)",
                "op": "a",  
                "f": ['Z', 'C'], 
                "m": [  
                        ['LRALU-IN', 'LRALU-OUT', 'ALUCN', 'ALUS3', 'ALUS2', 'LC'] + CC_notEACC, 
                        ['notERALU-OUT', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO  
                    ] },   

    "CMPi": {   "c": 0xC9,  
                "d": "Compare Memory with Accumulator (immediate)", 
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['notERAM', 'LRALU-IN'] + CC_notEPCADDR, 
                        ['CPC', 'ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZ'] + CC_notEACC,
                    ] },      

    "CPXi": {   "c": 0xE0,  
                "d": "Compare Memory and Index X (immediate)", 
                "f": ['Z', 'C'],
                "v": "u8",
                "m": [  
                        ['notERAM', 'LRALU-IN'] + CC_notEPCADDR, 
                        ['CPC', 'ALUCN', 'ALUS1', 'ALUS2', 'LC', 'LZ'] + CC_notEX,
                    ] },      

    "JMPa": {   "c": 0x4C,  
                "d": "Jump to New Location (absolute)", 
                "v": "u16",
                "m": [  
                        ['notERAM'] + CC_LTMP + CC_notEPCADDR,
                        ['CPC'], 
                        ['notERAM', 'LPCL'] + CC_notEPCADDR, 
                        ['LPCH'] + CC_notETMP 
                    ] },       

    "JSRa": {   "c": 0x20,  
                "d": "Jump to New Location Saving Return Address (absolute)", 
                "v": "u16",
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR, CC_PC_INCREMENT ],
                "m": [  
                        ['ESP', 'notWRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER,
                        ['ESP', 'notWRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER,
                        ['notERAM'] + CC_LTMP + CC_notEPCADDR,
                        ['CPC'], 
                        ['notERAM', 'LPCL'] + CC_notEPCADDR, 
                        ['LPCH'] + CC_notETMP   
                    ] },         

    "RTS":  {   "c": 0x60,  
                "d": "Return from Subroutine", 
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR, CC_PC_INCREMENT ],
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'notERAM', 'LPCH'],
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'notERAM', 'LPCL'],     
                        ['CPC'],   
                        ['CPC']                
                    ] },      

    "PHA":  {   "c": 0x48,  
                "d": "Push Accumulator on Stack", 
                "m": [  
                        ['ESP', 'notWRAM'] + CC_notEACC,
                        CC_INC_STACK_POINTER,
                    ] },      

    "PLA":  {   "c": 0x68,  
                "d": "Pull Accumulator from Stack", 
                "f": ['Z'],
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'notERAM', 'LZ'] + CC_LACC + CC_ALU_DETECT_ZERO
                    ] },      

    "BEQa": {   "c": 0xF0,  
                "d": "Branch on Result Zero (absolute)", 
                "v": "u16",
                "m": [  
                        ['notERAM', 'CHKZ'] + CC_LTMP + CC_notEPCADDR,
                        ['CPC'], 
                        ['CPC']
                    ],
                "true": [
                        ['CPC'], 
                        ['notERAM', 'LPCL'] + CC_notEPCADDR, 
                        ['LPCH'] + CC_notETMP 
                    ] },   

    "BNEa": {   "c": 0xD0,  
                "d": "Branch on Result not Zero (absolute)", 
                "v": "u16",
                "m": [  
                        ['notERAM', 'CHKZ'] + CC_LTMP + CC_notEPCADDR,
                        ['CPC'], 
                        ['notERAM', 'LPCL'] + CC_notEPCADDR, 
                        ['LPCH'] + CC_notETMP 
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                    ] },   

    "BCSa": {   "c": 0xB0,  
                "d": "Branch on Carry Set (absolute)", 
                "v": "u16",
                "m": [  
                        ['notERAM', 'CHKC'] + CC_LTMP + CC_notEPCADDR,
                        ['CPC'], 
                        ['CPC']
                    ],
                "true": [
                        ['CPC'], 
                        ['notERAM', 'LPCL'] + CC_notEPCADDR, 
                        ['LPCH'] + CC_notETMP 
                    ] },    

    "BCCa": {   "c": 0x90,  
                "d": "Branch on Carry Clear (absolute)", 
                "v": "u16",
                "m": [  
                        ['notERAM', 'CHKC'] + CC_LTMP + CC_notEPCADDR,
                        ['CPC'], 
                        ['notERAM', 'LPCL'] + CC_notEPCADDR, 
                        ['LPCH'] + CC_notETMP 
                    ],
                "true": [
                        ['CPC'], 
                        ['CPC'], 
                    ] },                                          

    "LDOi": {   "c": 0xFE,  
                "d": "Load Output with Memory (immediate)", 
                "v": "u8",
                "m": [  
                        ['notERAM'] + CC_LOUT + CC_notEPCADDR, 
                        ['CPC']  
                    ] },

    "LDOa": {   "c": 0xFD,  
                "d": "Load Output with Memory (absolute)", 
                "v": "u16",
                "m": [  
                        ['notERAM', 'LMARH'] + CC_notEPCADDR, 
                        ['CPC'],
                        ['notERAM', 'LMARL'] + CC_notEPCADDR, 
                        ['CPC', 'notEMAR', 'notERAM'] + CC_LOUT  
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
                        ['notSEC'], 
                    ] },                    

    "NOP": {    "c": 0xEA,  
                "d": "No Operation",     
                "m": [ [] ] },     

    "BRK": {    "c": 0x00,  
                "d": "Jump to interrupt handler routine", 
                "f": ['I'],
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR ], # don't check I to resume next op
                "m": [
                        ['ESP', 'notEFR-OUT', 'notWRAM'],
                        CC_INC_STACK_POINTER, 
                        ['ESP', 'notWRAM'] + CC_notEPCL,
                        CC_INC_STACK_POINTER, 
                        ['ESP', 'notWRAM'] + CC_notEPCH,
                        CC_INC_STACK_POINTER, 
                        ['ALUM', 'ALUS0', 'ALUS1', 'LRALU-OUT']  + CC_notEACC,
                        ['notERALU-OUT', 'LPCH'],
                        ['ALUM', 'ALUS2', 'ALUS3', 'LRALU-OUT']  + CC_notEACC,
                        ['notERALU-OUT', 'LPCL', 'notDISI']
                     ] },    

    "RTI":  {   "c": 0x40,  
                "d": "Return from Interrupt", 
                "f": ['I'],
                "t0": [ CC_LOAD_PC_POINTED_RAM_INTO_IR ], # don't check I to resume next op
                "m": [  
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'notERAM', 'LPCH'],
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'notERAM', 'LPCL'],
                        CC_DEC_STACK_POINTER,
                        ['ESP', 'notERAM', 'EFR-IN', 'LC', 'LZ', 'notENAI'],  
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
            if ('v' in INSTRUCTIONS_SET[i]):
                f.writelines(['\t', i[:3], ' {value: ', INSTRUCTIONS_SET[i]['v'] ,'}', (',' + INSTRUCTIONS_SET[i]['i'] + ' ') if 'i' in INSTRUCTIONS_SET[i] else '', ' => 0x', '{:02X}'.format(INSTRUCTIONS_SET[i]['c']), ' @ value \t; ', INSTRUCTIONS_SET[i]['d'], ' ', flags , '\n'])
            else:
                f.writelines(['\t', i[:3], (' ' + INSTRUCTIONS_SET[i]['op']) if 'op' in INSTRUCTIONS_SET[i] else '', ' => 0x', '{:02X}'.format(INSTRUCTIONS_SET[i]['c']), 
                              ''.join([' @ ' + hex(x) for x in INSTRUCTIONS_SET[i]['b']]) if 'b' in INSTRUCTIONS_SET[i] else ''  
                              , '  ; ', INSTRUCTIONS_SET[i]['d'], ' ', flags, '\n'])
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