
##################################################################
## Generate square table
##
## 
def generateSquareTable():

    with open('square.asm', 'w') as f:
        f.write("#once\n\n")
        f.write("; **********************************************************\n")
        f.write("; SQUARE LOOKUP TABLE\n")
        f.write(";\n")
        f.write("; DESCRIPTION:\n")
        f.write(";;   This table store the results of X*X operation\n")
        f.write(";;\n\n")
        f.write("SQTAB_LSB:\n")
        for i in range(256):
            f.write("    #d8  0x{:02X} ; lsb of 0x{:02X}\n".format((i*i) & 0xFF, (i*i)))
        f.write("\nSQTAB_MSB:\n")
        for i in range(256):
            f.write("    #d8 0x{:02X} ; msb of 0x{:02X}\n".format(((i*i) & 0xFF00) >> 8, (i*i)))

##################################################################
## Generate power of 2 table
##
## 
def generatePowerOfTwoTable():

    with open('power2.asm', 'w') as f:
        f.write("#once\n\n")
        f.write("; **********************************************************\n")
        f.write("; POWER OF 2 LOOKUP TABLE\n")
        f.write(";\n")
        f.write("; DESCRIPTION:\n")
        f.write(";;   This table store the results of 2*X operation\n")
        f.write(";;\n\n")
        f.write("POW2_LSB:\n")
        for i in range(16):
            f.write("    #d8  0x{:02X} ; lsb of 0x{:02X}\n".format((2 ** i) & 0xFF, (2 ** i)))
        f.write("\nPOW2_MSB:\n")
        for i in range(16):
            f.write("    #d8 0x{:02X} ; msb of 0x{:02X}\n".format(((2 ** i) & 0xFF00) >> 8, (2 ** i)))


##################################################################
## Main
##
##
if __name__ == "__main__":

    print("Custom-SAP - Lookup tables generator")

    print("Generating Square table file square.asm")
    generateSquareTable()   

    print("Generating Power of 2 table file power2.asm")
    generatePowerOfTwoTable()

    print("All done\n")