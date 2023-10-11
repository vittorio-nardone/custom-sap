
from intelhex import IntelHex

##################################################################
## Configuration
##
##
CONTROL_ROMS_COUNT = 2

##################################################################
## Control bits
##
##
CONTROL_BITS = {
    "LIR":          { "eeprom": 0, "bit": 0, "lowActive": False },
    "notERAM":      { "eeprom": 0, "bit": 1, "lowActive": True },
    "notEPCRAM":    { "eeprom": 0, "bit": 2, "lowActive": True },
    "CPC":          { "eeprom": 0, "bit": 3, "lowActive": False },
    "LACC":         { "eeprom": 0, "bit": 4, "lowActive": False },
    "notEACC":      { "eeprom": 0, "bit": 5, "lowActive": True },
    "notHLT":       { "eeprom": 0, "bit": 6, "lowActive": True },
    "notNOP":       { "eeprom": 0, "bit": 7, "lowActive": True },

    "LMARL":        { "eeprom": 1, "bit": 0, "lowActive": False },
    "LMARH":        { "eeprom": 1, "bit": 1, "lowActive": False },
    "notEMAR":      { "eeprom": 1, "bit": 2, "lowActive": True },
}

##################################################################
## Common Control Words
##
##
CC_LOAD_PC_POINTED_RAM_INTO_IR      = ['LIR','notERAM','notEPCRAM']
CC_PC_INCREMENT                     = ['CPC']
CC_LAST_T                           = ['notNOP']

##################################################################
## Istructions
##
##
ISTRUCTIONS_SET = {
    "HLT": {    "c": 0x00,  
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

    "NOP": {    "c": 0xFF,  
                "d": "No Operation",     
                "m": [ [] ] },                         
}

##################################################################
## Get istruction code
##
##
def getCode(S):
    return ISTRUCTIONS_SET[S]['c']

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
## Generate Istructions
##
##
def generateIstructions(ihs):
    for i in ISTRUCTIONS_SET:
        offset = ISTRUCTIONS_SET[i]['c'] << 5
        ist = [ CC_LOAD_PC_POINTED_RAM_INTO_IR, CC_PC_INCREMENT ] + ISTRUCTIONS_SET[i]['m'] # add T1
        ist[-1] += CC_LAST_T # add NOP
        for x in ist:
            cw = getControlWord(x)
            for e in range(CONTROL_ROMS_COUNT):
                ihs[e][offset] = cw[e]
            offset += 1

##################################################################
## Clean & Preset
##
## This is used to set T1/T2 of all available istructions
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
    ## Generate rom files (microcode)
    ihs = []
    for e in range(CONTROL_ROMS_COUNT):
        ih = IntelHex()
        ihs.append(ih)
    
    cleanAndPreset(ihs)
    generateIstructions(ihs)

    for e in range(CONTROL_ROMS_COUNT):
        ihs[e].write_hex_file("roms/cw{0}-rom.hex".format(e+1))

    ## Kernel rom
    ih = IntelHex()
    ih[0] = getCode('LDAa')
    ih[1] = 0x80
    ih[2] = 0x00
    ih[3] = getCode('HLT')
    ih[0x10] = 0xAA
    ih.write_hex_file("roms/kernel-rom.hex")