from microcode import INSTRUCTIONS_SET
import sys
import select
import tty
import termios

class OttoCPU:
    def __init__(self):
        # Initialize registers
        self.A = 0  # Accumulator (8-bit)
        self.D = 0  # D register (8-bit)
        self.E = 0  # E register (8-bit)
        self.X = 0  # X register (8-bit)
        self.Y = 0  # Y register (8-bit)
        self.OUT = 0  # Output register (8-bit)
        self.PC = 0  # Program Counter (24-bit)
        self.MAR = 0  # Memory Address Register (24-bit)
        self.SP = 0xFFFF  # Stack Pointer (12-bit)
        self.INT = 0 # Interrupt vector (8-bit)
        self.IR = 0  # Instruction Register (8-bit)
        
        # I/O simulation
        self.KEY = None  # Keyboard input

        # Initialize flags
        self.Z = False  # Zero flag
        self.C = False  # Carry flag
        self.N = False  # Negative flag
        self.I = False  # Interrupt disable flag
        self.O = False  # Overflow flag
        self.HLT = False  # Halt flag
        
        # Initialize memory
        self.memory = bytearray(0x030000)  # Full 64K * 3 memory space
        
        # Memory regions
        self.memory_regions = {
            'rom': {'start': 0x0000, 'stop': 0x5FFF, 'read_only': True, 'io': False},
            'ram': {'start': 0x8000, 'stop': 0xFFFF, 'read_only': False, 'io': False},
            'ram_ext_1': {'start': 0x010000, 'stop': 0x01FFFF, 'read_only': False, 'io': False},
            'ram_ext_2': {'start': 0x020000, 'stop': 0x02FFFF, 'read_only': False, 'io': False},
            'keyboard': {'start': 0x6020, 'stop': 0x6021, 'read_only': False, 'io': True},
        }
        
        # Initialize instruction set
        self.instructions = {}
        self._init_instructions()
    
    def _init_instructions(self):
        """Initialize the instruction set"""
        for i in INSTRUCTIONS_SET.values():
            if i.get('sim',None) is not None:
                self.instructions[i['c']] = i['sim']
    
    def push(self, value):
        """Push a value onto the stack"""
        self.write_byte(self.SP, value)
        self.SP -= 1

    def pop(self):
        """Pop a value from the stack"""
        self.SP += 1
        result = self.read_byte(self.SP)
        self.update_zero_flag(result)
        self.update_negative_flag(result)
        return result

    def load_binary(self, filename, region, offset=0):
        """Load a binary file into memory"""
        try:
            with open(filename, 'rb') as f:
                data = f.read()
        except FileNotFoundError:
            raise FileNotFoundError(f"Could not open binary file: {filename}")
        
        # Determine the target address
        if region not in self.memory_regions:
            raise ValueError(f"Invalid memory region: {region}")
        
        start_addr, end_addr = self.memory_regions[region]['start'], self.memory_regions[region]['stop']
        load_addr = start_addr + offset
        
        # Check if the offset is within the region
        if offset < 0 or load_addr > end_addr:
            raise ValueError(f"Offset {hex(offset)} is outside region {region}")
        
        # Check if the file will fit in the region
        if load_addr + len(data) > end_addr + 1:
            raise ValueError(
                f"Binary file ({len(data)} bytes) too large for region {region} "
                f"at offset {hex(offset)} (space available: {end_addr - load_addr + 1} bytes)"
            )
        
        # Perform the load
        for i, byte in enumerate(data):
            addr = load_addr + i
            self.memory[addr] = byte

    def reset(self):
        """Reset the CPU to its initial state"""
        self.__init__()
        self.PC = 0x0000
        self.SP = 0xFFFF
    
    def step(self):
        """Execute one instruction"""
        # Fetch
        opcode = self.memory[self.PC]
        self.IR = opcode
        
        # Decode and Execute
        if opcode in self.instructions:
            exec(self.instructions[opcode])
        else:
            raise Exception(f"Unknown opcode: {hex(opcode)}")
    
    def update_zero_flag(self, value):
        """Update Zero flag based on result"""
        self.Z = (value & 0xFF) == 0
    
    def update_negative_flag(self, value):
        """Update Negative flag based on result"""
        self.N = (value & 0x80) != 0

    def update_overflow_flag(self, value):
        """Update Overflow flag based on result"""
        self.O = (value > 0xFF)

    def update_carry_flag(self, value):
        """Update Carry flag based on result"""
        self.C = (value > 0xFF)

    def transfer(self, source, destination):
        """Transfer a value from source to destination"""
        setattr(self, destination, getattr(self, source))
        self.PC += 1
        self.update_zero_flag(getattr(self, source))
        self.update_negative_flag(getattr(self, source))

    def load_from_memory(self, immediate=None, mem_operands_size=None, registry_operands=None, index=None):
        if (immediate):
            result = self.read_byte(self.PC+1)
            self.PC += 2
        elif (mem_operands_size):
            self.MAR = self.get_address_from_operands(mem_operands_size, index)
            self.PC += mem_operands_size + 1
            result = self.read_byte(self.MAR)
        elif (registry_operands):
            self.MAR = self.get_address_from_registries(registry_operands, index)
            self.PC += 1
            result = self.read_byte(self.MAR)
        else:
            raise ValueError("One of immediate, mem_operands_size or registry_operands must be provided")
        
        self.update_zero_flag(result)
        self.update_negative_flag(result)
        return result

    def store_in_memory(self, value, mem_operands_size=None, registry_operands=None, index=None):
        if (mem_operands_size):
            self.MAR = self.get_address_from_operands(mem_operands_size, index)
            self.PC += mem_operands_size + 1
        elif (registry_operands):
            self.MAR = self.get_address_from_registries(registry_operands, index)
            self.PC += 1
        else:
            raise ValueError("One of mem_operands_size or registry_operands must be provided")
        
        self.write_byte(self.MAR, value)

    def branch(self, condition, mem_operands_size):
        match condition:
            case 'beq': jump = self.Z
            case 'bne': jump = not self.Z
            case 'bcs': jump = self.C
            case 'bcc': jump = not self.C
            case 'bmi': jump = self.N
            case 'bpl': jump = not self.N
            case _:
                raise ValueError(f"Invalid branch condition: {condition}")
            
        if jump: 
            self.jump(mem_operands_size)
        else:
            self.PC += mem_operands_size + 1

    def jump(self, mem_operands_size, indirect=False, jsr=False):
        if (jsr == True):
            self.push((self.PC >> 16) & 0xFF)
            self.push((self.PC >> 8) & 0xFF)
            self.push(self.PC & 0xFF)
            
        self.PC = self.get_address_from_operands(mem_operands_size)
        if (indirect == True):
            self.PC = self.get_address_from_operands(mem_operands_size)

    def rts(self):
        self.PC = self.pop() + (self.pop() << 8) + (self.pop() << 16) + 4

    def math_operation(self, operation, current_value=None, operator_immediate=None, operator_registry=None, operator_mem_operands_size=None, operator_index=None):

        operator = None
        if (operator_immediate):
            operator = self.read_byte(self.PC+1)
            self.PC += 2
        elif (operator_mem_operands_size):
            self.MAR = self.get_address_from_operands(operator_mem_operands_size, operator_index)
            operator = self.read_byte(self.MAR)
            self.PC += operator_mem_operands_size + 1
        elif (operator_registry):
            operator = getattr(self, operator_registry)
            self.PC += 1
        else:
            self.PC += 1

        if operator == None:
            if operation in ['adc', 'sbc', 'cmp', 'eor', 'and', 'or', 'inc' ,'dec']:
                raise ValueError(f"One of operator_* must be provided for {operation.upper()} operation")

        if current_value == None:
            if operation in ['adc', 'sbc', 'cmp', 'eor', 'and', 'or']:
                raise ValueError(f"current_value must be provided for {operation.upper()} operation")

        match operation:
            case 'adc':
                result = current_value + operator + (1 if self.C else 0)
                self.C = result > 0xFF
            case 'sbc':
                result = current_value - operator - (0 if self.C else 1)
                self.C = result >= 0
            case 'rol':
                if current_value == None:
                    if operator == None:
                        raise ValueError("current_value must be provided for ROL operation")
                    else:
                        current_value = operator
                result = (current_value << 1) + (1 if self.C else 0)
                self.C = result > 0xFF
                self.update_negative_flag(result & 0xFF)
                if operator_mem_operands_size:
                    self.write_byte(self.MAR, result)
            case 'ror':
                if current_value == None:
                    if operator == None:
                        raise ValueError("current_value must be provided for ROR operation")
                    else:
                        current_value = operator
                result = (current_value >> 1) + (0x80 if self.C else 0)
                self.C = (current_value & 0x01) == 0x01
                self.update_negative_flag(result & 0xFF)
                if operator_mem_operands_size:
                    self.write_byte(self.MAR, result)
            case 'lsr':
                if current_value == None:
                    if operator == None:
                        raise ValueError("current_value must be provided for ROR operation")
                    else:
                        current_value = operator
                result = (current_value >> 1)
                self.C = (current_value & 0x01) == 0x01
                self.update_negative_flag(result & 0xFF)
                if operator_mem_operands_size:
                    self.write_byte(self.MAR, result)
            case 'cmp':
                result = current_value - operator
                self.C = result >= 0
            case 'eor':
                result = current_value ^ operator
            case 'and':
                result = current_value & operator
            case 'or':
                result = current_value | operator
            case 'inc':
                result = operator + 1
                if operator_mem_operands_size:
                    self.write_byte(self.MAR, result)
                elif operator_registry:
                    setattr(self, operator_registry, result & 0xFF)
                else:
                    raise ValueError("operator_immediate not supported for INC operation")
            case 'dec':
                result = operator - 1
                if operator_mem_operands_size:
                    self.write_byte(self.MAR, result)
                elif operator_registry:
                    setattr(self, operator_registry, result & 0xFF)
                else:
                    raise ValueError("operator_immediate not supported for DEC operation")
            case _:
                raise ValueError(f"Invalid operation: {operation}")
    
        result &= 0xFF
        self.update_zero_flag(result)
        self.update_negative_flag(result)
        return result

    def get_address_from_operands(self, size, index=None):
        """Calculate the address from operands with optional index"""
        if index:
            self.O = (self.memory[self.PC + size] + index) > 0xFF
        match size:
            case 2:
                return self.memory[self.PC + 1] * 256 + self.memory[self.PC + 2] + (index if index else 0)
            case 3:
                return self.memory[self.PC + 1] * 65536 + self.memory[self.PC + 2] * 256 + self.memory[self.PC + 3] + (index if index else 0)
            case _:
                raise ValueError(f"Invalid operand size: {size}")

    def get_address_from_registries(self, registries, index=None):
        """Calculate the address from registries with optional index"""
        if index:
            self.O = (self.E + index) > 0xFF
        match registries:
            case 'yde':
                return self.Y * 65536 + self.D * 256 + self.E + (index if index else 0)
            case 'de':
                return self.D * 256 + self.E + (index if index else 0)
            case _:
                raise ValueError(f"Invalid operand registries: {registries}")
    
    # Memory access methods
    def read_byte(self, address):
        """Read a byte from memory"""
        address &= 0xFFFFFF  # 24-bit address bus

        for region in self.memory_regions.values():
            if region['start'] <= address <= region['stop']:
                if region['io'] == False:
                    return self.memory[address]
                else:
                    if address == 0x6021:
                        if self.KEY == None:
                            return 0x00
                        else:
                            key = self.KEY
                            self.KEY = None
                            return key
                    elif address == 0x6020:
                        return 0x03 if self.KEY != None else 0x02
                    
        raise Exception(f"Invalid memory read at {hex(address)}")
    
    def write_byte(self, address, value):
        """Write a byte to memory"""
        address &= 0xFFFFFF  # 24-bit address bus
        value &= 0xFF  # Ensure 8-bit value
        
        for region in self.memory_regions.values():
            if region['start'] <= address <= region['stop']:
                if region['read_only']:
                    raise ValueError(f"Memory region at address {address} is read-only")
                if region['io'] == False:
                    self.memory[address] = value
                else:
                    if address == 0x6021:
                        print(f"{chr(value)}", end="")
                        sys.stdout.flush()
                return

        # TODO add support for IO regions

        raise Exception(f"Invalid memory write at {hex(address)}")
    
    def push_key(self, key):
        if key == 10:
            key = 13
        self.KEY = key


# Helper function to load a program into memory
def load_program(cpu, program, start_address=0x8000):
    """Load a program into memory"""
    for i, byte in enumerate(program):
        cpu.memory[start_address + i] = byte
    cpu.PC = start_address


def keyboard_hit():
    return select.select([sys.stdin], [], [], 0) == ([sys.stdin], [], [])

##################################################################
## Main
##
##
if __name__ == "__main__":
    # Create a new OttoCPU instance
    cpu = OttoCPU()

    # Load the kernel into memory
    cpu.load_binary("roms/kernel-rom.bin", "rom")
    
    # Load a program into memory
    cpu.load_binary("roms/helloworld.bin", "ram", offset=0x400)
    
    # Run the simulator
    print("Otto CPU Simulator")
    old_settings = termios.tcgetattr(sys.stdin)
    try:
        tty.setcbreak(sys.stdin.fileno())
        while cpu.HLT == False:

            if keyboard_hit():
                key = ord(sys.stdin.read(1))
                cpu.push_key(key)

            cpu.step()
    except Exception as e:
        print(f"\nError executing opcode {cpu.IR:02X}: {e}", end="")

    finally:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
    
    print("\nSystem halted.")

        #print(f"\rPC:{cpu.PC:06X} MAR:{cpu.MAR:06X} SP:{cpu.SP:04X} A:{cpu.A:02X} D:{cpu.D:02X} E:{cpu.E:02X} X:{cpu.X:02X} Y:{cpu.Y:02X} OUT:{cpu.OUT:02X} Z:{'t' if cpu.Z else 'f'} C:{'t' if cpu.C else 'f'} N:{'t' if cpu.N else 'f'} I:{'t' if cpu.I else 'f'} O:{'t' if cpu.O else 'f'}", end="")      
        #sys.stdout.flush()

            
 
    