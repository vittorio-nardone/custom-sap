
##################################################################
## Generate square table
##
## 
def generateSymbolsFile():

    # Open the input file to read the content
    with open('symbols.txt', 'r') as infile:
        lines = infile.readlines()
    
    # Open the output file to write the modified content
    with open('kernel/symbols.asm', 'w') as f:
        for line in lines:
            # Only add the prefix if the line does not contain a dot (.)
            if '.' not in line:
                f.write('#const ' + line)


##################################################################
## Main
##
##
if __name__ == "__main__":

    print("Custom-SAP - Symbols file generator")

    print("Generating file symbols.asm")
    generateSymbolsFile()   

    print("All done\n")