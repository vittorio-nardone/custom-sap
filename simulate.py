from microcode import INSTRUCTIONS_SET, verifyInstructionSet
from serial import Serial
from virtualserialports import VirtualSerialPorts
import sys
import select
import tty
import termios
import argparse
from watchdog.observers import Observer 
from watchdog.events import FileSystemEventHandler 
import os

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
        self.KEY = []  # Keyboard input queue (FIFO)
        self.serial_io = None  # Serial port

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
            'rom': {'start': 0x0000, 'stop': 0x3FFF, 'read_only': True, 'io': False},
            'forth': {'start': 0x4000, 'stop': 0x5FFF, 'read_only': True, 'io': False},
            'ram': {'start': 0x8000, 'stop': 0xFFFF, 'read_only': False, 'io': False},
            'ram_ext_1': {'start': 0x010000, 'stop': 0x01FFFF, 'read_only': False, 'io': False},
            'ram_ext_2': {'start': 0x020000, 'stop': 0x02FFFF, 'read_only': False, 'io': False},
            'acia_1': {'start': 0x6020, 'stop': 0x6021, 'read_only': False, 'io': True},
        }
        
        # Initialize instruction set
        self.instructions = {}
        self._init_instructions()
        self.cycles = 0
    
    def _init_instructions(self):
        """Initialize the instruction set"""
        verifyInstructionSet()
        for key, value in INSTRUCTIONS_SET.items():
            if value.get('sim',None) is not None:
                self.instructions[value['c']] = {
                    'sim': value['sim'], 
                    'cycles': value['cycles'], 
                    'cycles_true': value['cycles_true']
                }
            else:
                print(f"-> warning: instruction 0x{value['c']:02X} - {key[:3]} not implemented")
    
    def set_serial_port(self, serial_port):
        """Set the serial port for I/O simulation"""
        self.serial_io = Serial(serial_port, 115200, timeout=0)

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

    def load_binary(self, filename, address):
        """Load a binary file into memory at a specific address"""
        try:
            with open(filename, 'rb') as f:
                data = f.read()
        except FileNotFoundError:
            raise FileNotFoundError(f"Could not open binary file: {filename}")
        
        # Check if the address is within a valid, not read-only region
        valid_region = None
        for region_name, region in self.memory_regions.items():
            if region['start'] <= address <= region['stop']:
                valid_region = region
                break
        
        if not valid_region:
            raise ValueError(f"Address {hex(address)} is not within a valid region")
        
        # Check if the file will fit in the region
        end_address = address + len(data) - 1
        if end_address > valid_region['stop']:
            raise ValueError(
                f"Binary file ({len(data)} bytes) too large for region {region_name} "
                f"starting at address {hex(address)} (space available: {valid_region['stop'] - address + 1} bytes)"
            )
        
        # Perform the load
        for i, byte in enumerate(data):
            self.memory[address + i] = byte

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
        self.true_condition = False
        if opcode in self.instructions:
            exec(self.instructions[opcode]['sim'])
            self.cycles += self.instructions[opcode]['cycles_true'] if self.true_condition else self.instructions[opcode]['cycles']
        else:
            raise Exception(f"Unknown opcode: 0x{opcode:02X}")
    
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

    def load_from_memory(self, immediate=None, mem_operands_size=None, registry_operands=None, index=None, indirect=None):
        if (immediate):
            result = self.read_byte(self.PC+1)
            self.PC += 2
        elif (indirect) and (mem_operands_size in [2,4]):
            self.MAR = self.get_address_from_operands(2)
            self.PC += mem_operands_size + 1

            MARl = self.read_byte(self.MAR)
            self.MAR += 1
            self.MAR = self.read_byte(self.MAR) * 256 + MARl + (index if index != None else 0)

            result = self.read_byte(self.MAR)            
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

    def store_in_memory(self, value, mem_operands_size=None, registry_operands=None, index=None, indirect=None):
        if (indirect) and (mem_operands_size == 2):
            self.MAR = self.get_address_from_operands(mem_operands_size)
            self.PC += mem_operands_size + 1
            MARl = self.read_byte(self.MAR)
            self.MAR += 1
            self.MAR = self.read_byte(self.MAR) * 256 + MARl + (index if index != None else 0)
        elif (mem_operands_size):
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
            self.PC -= 1
            self.PC = self.get_address_from_operands(mem_operands_size)   

    def rts(self):
        self.PC = self.pop() + (self.pop() << 8) + (self.pop() << 16) + 4

    def math_operation(self, operation, current_value=None, 
                       operator_immediate=None, operator_registry=None, operator_mem_operands_size=None, operator_index=None, 
                       extra_bytes=0, indirect=None, flags=['Z', 'N']):

        operator = None
        if (operator_immediate):
            operator = self.read_byte(self.PC+1)
            self.PC += 2 + extra_bytes
        elif (indirect) and (operator_mem_operands_size == 2):
            self.MAR = self.get_address_from_operands(operator_mem_operands_size)        
            MARl = self.read_byte(self.MAR)
            self.MAR += 1
            self.MAR = self.read_byte(self.MAR) * 256 + MARl + (operator_index if operator_index != None else 0)    
            operator = self.read_byte(self.MAR)
            self.PC += operator_mem_operands_size + 1 + extra_bytes  
        elif (operator_mem_operands_size == 4):
            self.MAR = self.get_address_from_operands(2)
            operator = self.read_byte(self.MAR) + self.read_byte(self.MAR +1) * 256
            self.PC += operator_mem_operands_size + 1 + extra_bytes
        elif (operator_mem_operands_size):
            self.MAR = self.get_address_from_operands(operator_mem_operands_size, operator_index)
            operator = self.read_byte(self.MAR)
            self.PC += operator_mem_operands_size + 1 + extra_bytes
        elif (operator_registry):
            operator = getattr(self, operator_registry)
            self.PC += 1 + extra_bytes
        else:
            self.PC += 1 + extra_bytes

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
            case 'asl':
                if current_value == None:
                    if operator == None:
                        raise ValueError("current_value must be provided for ASL operation")
                    else:
                        current_value = operator
                result = (current_value << 1)
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
                        raise ValueError("current_value must be provided for LSR operation")
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
                if operator_mem_operands_size == 4:
                    self.C = result > 0xFFFF
                    self.write_byte(self.MAR, result & 0xFF)
                    self.write_byte(self.MAR + 1, result >> 8)
                elif operator_mem_operands_size:
                    self.write_byte(self.MAR, result)
                elif operator_registry:
                    setattr(self, operator_registry, result & 0xFF)
                else:
                    raise ValueError("operator_immediate not supported for INC operation")
            case 'dec':
                result = operator - 1
                if operator_mem_operands_size == 4:
                    self.C = result >= 0
                    self.write_byte(self.MAR, result & 0xFF)
                    self.write_byte(self.MAR + 1, result >> 8)
                if operator_mem_operands_size:
                    self.write_byte(self.MAR, result)
                elif operator_registry:
                    setattr(self, operator_registry, result & 0xFF)
                else:
                    raise ValueError("operator_immediate not supported for DEC operation")
            case _:
                raise ValueError(f"Invalid operation: {operation}")
    
        result &= 0xFF
        if 'Z' in flags:
            self.update_zero_flag(result)
        if 'N' in flags:
            self.update_negative_flag(result)
        return result

    def get_address_from_operands(self, size, index=None):
        """Calculate the address from operands with optional index"""
        if index != None:
            self.O = (self.memory[self.PC + size] + index) > 0xFF
        match size:
            case 2:
                return self.memory[self.PC + 1] * 256 + self.memory[self.PC + 2] + (index if index != None else 0)
            case 3:
                return self.memory[self.PC + 1] * 65536 + self.memory[self.PC + 2] * 256 + self.memory[self.PC + 3] + (index if index != None else 0)
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
                        if self.serial_io != None:
                            if self.serial_io.in_waiting > 0:
                                return self.serial_io.read(1)[0]
                            else:
                                return 0x00
                        elif len(self.KEY) == 0:
                            return 0x00
                        else:
                            return self.KEY.pop(0)
                    elif address == 0x6020:
                        if self.serial_io != None:
                            return 0x03 if self.serial_io.in_waiting > 0 else 0x02
                        else:
                            return 0x03 if len(self.KEY) > 0 else 0x02
                    
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
                        if self.serial_io != None:
                            self.serial_io.write(bytes([value]))
                        else:
                            print(f"{chr(value)}", end="")
                            sys.stdout.flush()
                return

        # TODO add support for IO regions

        raise Exception(f"Invalid memory write at {hex(address)}")
    
    def push_key(self, key):
        if key == 10:
            key = 13
        self.KEY.append(key)


# Helper function to load a program into memory
def load_program(cpu, program, start_address=0x8000):
    """Load a program into memory"""
    for i, byte in enumerate(program):
        cpu.memory[start_address + i] = byte
    cpu.PC = start_address

def keyboard_hit():
    return select.select([sys.stdin], [], [], 0) == ([sys.stdin], [], [])

# Helper class to reload a program into memory when the file changes
class FileChangeHandler(FileSystemEventHandler): 
    def __init__(self, cpu, filepath, address): 
        self.cpu = cpu 
        self.program = filepath
        self.address = address

    def on_modified(self, event):
        if event.src_path == os.path.abspath(self.program):
            print(f"-> file {self.program} is changed, reloading it into memory")
            self.cpu.load_binary(self.program, self.address)

##################################################################
## Main
##
##
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Project OTTO - Simulator")
    parser.add_argument("--program", type=str, help="Path to the binary program file to load")
    parser.add_argument("--address", type=lambda x: int(x, 0), default=0x8400, help="Memory address to load the program (default: 0x8400)")
    parser.add_argument("--simulate-serial", action="store_true", help="Simulate serial ports instead of using stdin/stdout")
    parser.add_argument("--headless", action="store_true", help="Run without TTY (no stdin, no termios). Compatible with batch/CI usage")
    parser.add_argument("--autorun", action="store_true", help="Automatically run the loaded program after kernel boot (implies --headless)")
    parser.add_argument("--max-cycles", type=int, default=0, help="Maximum CPU cycles before forced exit (0 = unlimited)")
    parser.add_argument("--quiet", action="store_true", help="Suppress kernel output, show only application output (address >= 0x8400)")
    parser.add_argument("--dump-regs", type=str, default=None, help="Dump CPU registers to a file on exit (JSON format)")
    parser.add_argument("--input", type=str, default=None, help="Pre-load keyboard buffer with this string (use \\r for CR)")
    args = parser.parse_args()

    # --autorun implies --headless
    if args.autorun:
        args.headless = True

    print("\nProject OTTO - Simulator v1.3.0")
    # Create a new OttoCPU instance
    cpu = OttoCPU()

    # App execution tracking: detect when the program starts (PC enters app space)
    # and when it returns (PC back in kernel AND SP restored above JSR level).
    # Used by --autorun (to exit cleanly on RTS) and --quiet (to suppress kernel output).
    if args.autorun or args.quiet:
        cpu._app_running = False
        cpu._app_started = False
        cpu._app_sp = 0
        _original_step = cpu.step
        def _tracking_step():
            if not cpu._app_running and not cpu._app_started \
                    and cpu.PC >= args.address and len(cpu.KEY) == 0:
                # App started: PC entered app space and autorun input was consumed
                cpu._app_running = True
                cpu._app_started = True
                cpu._app_sp = cpu.SP  # SP right after kernel's JSR to app
            elif cpu._app_running and cpu.PC < 0x8400 and cpu.SP > cpu._app_sp:
                # SP restored above the app call level = app did RTS
                cpu._app_running = False
            _original_step()
        cpu.step = _tracking_step

    # In quiet mode, suppress serial output when app is not running
    if args.quiet:
        _original_write_byte = cpu.write_byte
        def _quiet_write_byte(address, value):
            if address == 0x6021 and not cpu._app_running:
                return
            _original_write_byte(address, value)
        cpu.write_byte = _quiet_write_byte

    # Load the kernel into memory
    print("-> loading kernel into rom memory")
    cpu.load_binary("roms/kernel-rom.bin", cpu.memory_regions['rom']['start'])

    # Load the forth interpreter into memory
    print("-> loading forth interpreter into rom memory")
    cpu.load_binary("roms/forth.bin", cpu.memory_regions['forth']['start'])

    # Load a program into memory if provided
    if args.program:
        print(f"-> loading program {args.program} into memory")
        cpu.load_binary(args.program, args.address)

        # Set up file change handler (not needed in headless mode)
        if not args.headless:
            event_handler = FileChangeHandler(cpu, args.program, args.address)
            observer = Observer()
            observer.schedule(event_handler, path=os.path.dirname(args.program), recursive=False)
            observer.start()

    # In autorun mode, pre-load keyboard buffer with 'r' + CR to trigger program execution
    if args.autorun:
        cpu.KEY = [ord('r'), 0x0D]

    # Pre-load additional keyboard input if provided
    if args.input:
        input_bytes = args.input.encode().decode('unicode_escape')
        cpu.KEY.extend([ord(c) for c in input_bytes])

    # Run the simulator
    print("-> system boot")
    exit_code = 0

    if args.headless:
        # Headless mode: no TTY, no stdin reading
        stop_reason = "completed"
        try:
            while cpu.HLT == False:
                cpu.step()
                # In autorun mode, exit cleanly when the app returns via RTS
                if args.autorun and cpu._app_started and not cpu._app_running:
                    break
                if args.max_cycles > 0 and cpu.cycles >= args.max_cycles:
                    print(f"\n-> max cycles reached ({args.max_cycles}), stopping simulator")
                    stop_reason = "timeout"
                    exit_code = 1
                    break
        except Exception as e:
            print(f"\nError executing opcode 0x{cpu.IR:02X}: {e}", end="")
            stop_reason = "error"
            exit_code = 2

        if cpu.HLT:
            stop_reason = "halted"

        print(f"\nSystem halted. OUT registry: 0x{cpu.OUT:02X} (cycles: {cpu.cycles})")

        # Dump registers to file if requested
        if args.dump_regs:
            import json
            regs = {
                "A": cpu.A, "X": cpu.X, "Y": cpu.Y,
                "D": cpu.D, "E": cpu.E, "OUT": cpu.OUT,
                "PC": cpu.PC, "SP": cpu.SP,
                "flags": {"Z": cpu.Z, "N": cpu.N, "C": cpu.C, "I": cpu.I, "O": cpu.O},
                "cycles": cpu.cycles,
                "stop_reason": stop_reason
            }
            with open(args.dump_regs, 'w') as f:
                json.dump(regs, f, indent=2)
            print(f"-> registers dumped to {args.dump_regs}")

        sys.exit(exit_code)
    else:
        # Interactive mode: original behavior with TTY
        old_settings = termios.tcgetattr(sys.stdin)
        try:
            tty.setcbreak(sys.stdin.fileno())

            if args.simulate_serial:
                with VirtualSerialPorts(2, False, False) as ports:
                    cpu.set_serial_port(ports[0])
                    print(f"-> use serial port {ports[1]} to communicate with the CPU")

                    # Flush stdout, in case the ports are being read in a pipe. Else
                    # Python will buffer it and block.
                    sys.stdout.flush()

                    while cpu.HLT == False:
                        cpu.step()
            else:
                while cpu.HLT == False:
                    while keyboard_hit():
                        key = ord(sys.stdin.read(1))
                        cpu.push_key(key)
                    cpu.step()
        except Exception as e:
            print(f"\nError executing opcode 0x{cpu.IR:02X}: {e}", end="")

        finally:
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)

        print(f"\nSystem halted. OUT registry: 0x{cpu.OUT:02X}")
            
 
    