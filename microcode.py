
from intelhex import IntelHex

##################################################################
## Configuration
##
##
CONTROL_ROMS_COUNT = 4

##################################################################
## Control bits
##
##
CONTROL_BITS = {
    ## EEPROM #1
    "LIR":          { "eeprom": 0, "bit": 0, "lowActive": False },
    "notERAM":      { "eeprom": 0, "bit": 1, "lowActive": True },
    "notEPCRAM":    { "eeprom": 0, "bit": 2, "lowActive": True },
    "CPC":          { "eeprom": 0, "bit": 3, "lowActive": False },
    "LACC":         { "eeprom": 0, "bit": 4, "lowActive": False },
    "notEACC":      { "eeprom": 0, "bit": 5, "lowActive": True },
    "notHLT":       { "eeprom": 0, "bit": 6, "lowActive": True },
    "notNOP":       { "eeprom": 0, "bit": 7, "lowActive": True },
    ## EEPROM #2
    "LMARL":        { "eeprom": 1, "bit": 0, "lowActive": False },
    "LMARH":        { "eeprom": 1, "bit": 1, "lowActive": False },
    "notEMAR":      { "eeprom": 1, "bit": 2, "lowActive": True },
    "notWRAM":      { "eeprom": 1, "bit": 3, "lowActive": True },
    "notLPCH":      { "eeprom": 1, "bit": 4, "lowActive": True },
    "notLPCL":      { "eeprom": 1, "bit": 5, "lowActive": True },
    "LTMP":         { "eeprom": 1, "bit": 6, "lowActive": False },
    "LRALU":        { "eeprom": 1, "bit": 7, "lowActive": False }, 
    ## EEPROM #3
    "ALUS0":        { "eeprom": 2, "bit": 0, "lowActive": False },   
    "ALUS1":        { "eeprom": 2, "bit": 1, "lowActive": False },   
    "ALUS2":        { "eeprom": 2, "bit": 2, "lowActive": False },   
    "ALUS3":        { "eeprom": 2, "bit": 3, "lowActive": False },   
    "ALUCN":        { "eeprom": 2, "bit": 4, "lowActive": False },   
    "ALUM":         { "eeprom": 2, "bit": 5, "lowActive": False },
    "notERALU":     { "eeprom": 2, "bit": 6, "lowActive": True },
    "LOUT":         { "eeprom": 2, "bit": 7, "lowActive": False },
    ## EEPROM #4
    "notEX":        { "eeprom": 3, "bit": 0, "lowActive": True },
    "LX":           { "eeprom": 3, "bit": 1, "lowActive": False },
    "notEY":        { "eeprom": 3, "bit": 2, "lowActive": True },
    "LY":           { "eeprom": 3, "bit": 3, "lowActive": False },
    "LFR":          { "eeprom": 3, "bit": 4, "lowActive": False },
    "notZCPC":      { "eeprom": 3, "bit": 5, "lowActive": True },
    "notZNOP":      { "eeprom": 3, "bit": 6, "lowActive": True },
}

##################################################################
## Common Control Words
##
##
CC_LOAD_PC_POINTED_RAM_INTO_IR      = ['LIR','notERAM','notEPCRAM']
CC_PC_INCREMENT                     = ['CPC']
CC_LAST_T                           = ['notNOP']

CC_TMP_TO_BUS                  = ['notERALU', 'ALUCN', 'LRALU']  # Allow TMP register to output to bus

##################################################################
## Instructions
##
##
INSTRUCTIONS_SET = {
    "HLT": {    "c": 0xFF,  
                "d": "Freeze CPU",     
                "m": [ ['notHLT'] ] },

    "LDAi": {   "c": 0xA9,  
                "d": "Load Accumulator with Memory (immediate)", 
                "m": [  
                        ['notEPCRAM', 'notERAM', 'LACC'], 
                        ['CPC']  
                    ] },

    "LDAa": {   "c": 0xAD,  
                "d": "Load Accumulator with Memory (absolute)", 
                "m": [  
                        ['notEPCRAM', 'notERAM', 'LMARH'], 
                        ['CPC'],
                        ['notEPCRAM', 'notERAM', 'LMARL'], 
                        ['CPC', 'notEMAR', 'notERAM', 'LACC']  
                    ] },

    "STAa": {   "c": 0x8D,  
                "d": "Store Accumulator in Memory (absolute)", 
                "m": [  
                        ['notEPCRAM', 'notERAM', 'LMARH'], 
                        ['CPC'],
                        ['notEPCRAM', 'notERAM', 'LMARL'], 
                        ['CPC', 'notEMAR', 'notWRAM', 'notEACC']  
                    ] },      

    "ADCi": {   "c": 0x69,  
                "d": "Add Memory to Accumulator with Carry (immediate)",   #TODO Carry not supported
                "m": [  
                        ['notEPCRAM', 'notERAM', 'LTMP'], 
                        ['CPC', 'notEACC', 'ALUCN', 'ALUS0', 'ALUS3', 'LRALU'],
                        ['notERALU', 'LACC'], 
                    ] },      

    "CMPi": {   "c": 0xC9,  
                "d": "Compare Memory with Accumulator (immediate)", 
                "m": [  
                        ['notEPCRAM', 'notERAM', 'LTMP'], 
                        ['CPC', 'notEACC', 'ALUCN', 'ALUS1', 'ALUS2', 'LFR'],
                    ] },      

    "JMPa": {   "c": 0x4C,  
                "d": "Jump to New Location (absolute)", 
                "m": [  
                        ['notEPCRAM', 'notERAM', 'LTMP'],
                        ['CPC'], 
                        ['notEPCRAM', 'notERAM', 'notLPCL'], 
                        ['notLPCH'] + CC_TMP_TO_BUS 
                    ] },         

    "BEQa": {   "c": 0xF0,  
                "d": "Branch on Result Zero (absolute)", 
                "m": [  
                        ['notEPCRAM', 'notERAM', 'LTMP', 'notZCPC'],
                        ['CPC', 'notZNOP'], 
                        ['notEPCRAM', 'notERAM', 'notLPCL'], 
                        ['notLPCH'] + CC_TMP_TO_BUS 
                    ] },                                   

    "LDOi": {   "c": 0xFE,  
                "d": "Load Output with Memory (immediate)", 
                "m": [  
                        ['notEPCRAM', 'notERAM', 'LOUT'], 
                        ['CPC']  
                    ] },

    "NOP": {    "c": 0x00,  
                "d": "No Operation",     
                "m": [ [] ] },     
                                
}

##################################################################
## Get instruction code
##
##
def getCode(S):
    return INSTRUCTIONS_SET[S]['c']

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
        offset = INSTRUCTIONS_SET[i]['c'] << 5
        ist = [ CC_LOAD_PC_POINTED_RAM_INTO_IR, CC_PC_INCREMENT ] + INSTRUCTIONS_SET[i]['m'] # add T1
        ist[-1] += CC_LAST_T # add NOP
        for x in ist:
            cw = getControlWord(x)
            for e in range(CONTROL_ROMS_COUNT):
                ihs[e][offset] = cw[e]
            offset += 1

##################################################################
## Clean & Preset
##
## This is used to set T1/T2 of all available instructions
def cleanAndPreset(ihs):
    a = getControlWord(CC_LOAD_PC_POINTED_RAM_INTO_IR)
    b = getControlWord(CC_PC_INCREMENT + CC_LAST_T)
    for x in range(256):
        for e in range(CONTROL_ROMS_COUNT):
            ihs[e][x*32] = a[e]  
            ihs[e][x*32 + 1] = b[e]  
            for i in range(30):
                ihs[e][x*32 + 2 + i] = 0x00

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
    print("Generating roms files")
    ihs = []
    for e in range(CONTROL_ROMS_COUNT):
        ih = IntelHex()
        ihs.append(ih)
    
    cleanAndPreset(ihs)
    generateInstructions(ihs)

    for e in range(CONTROL_ROMS_COUNT):
        ihs[e].write_hex_file("roms/cw{0}-rom.hex".format(e+1))
    print("All done\n")