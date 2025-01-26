#bankdef low_kernel
{
    #addr 0x0000
    #size 0x0200
    #outp 0
}

#bankdef kernel
{
    #addr 0x0200
    #size 0x5E00
    #outp 8 * 0x0200
}