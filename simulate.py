from pathlib import Path
import sys

_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(_ROOT / "scripts" / "python"))
from microcode import INSTRUCTIONS_SET, verifyInstructionSet
from ch376_sim import Ch376Sim
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
import random as pyrandom
import time

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
        self._timer_cycle_debt = 0
        self.ch376 = None  # optional Ch376Sim when --ch376 is set

        # Kernel INT_TIMER_COUNTER @ 10 Hz (see kernel/interrupt.asm)
        self.TIMER_COUNTER_LSB = 0x83F7
        self.TIMER_COUNTER_MSB = 0x83F6
        self.CYCLES_PER_TIMER_TICK = 100_000

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
            'random': {'start': 0x6010, 'stop': 0x6012, 'read_only': False, 'io': True},
            'acia_1': {'start': 0x6020, 'stop': 0x6021, 'read_only': False, 'io': True},
            # ACIA #2 hosts the CH376 USB module (optional --ch376 emulator).
            'acia_2': {'start': 0x6022, 'stop': 0x6023, 'read_only': False, 'io': True},
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
    
    def set_serial_port(self, serial_port, baud=115200):
        """Attach a pyserial port (device path or Serial instance) for ACIA I/O."""
        if isinstance(serial_port, Serial):
            self.serial_io = serial_port
        else:
            # dsrdtr=False: do not toggle DTR on open (would reset ESP32 / VGA32)
            self.serial_io = Serial(
                serial_port, baud, timeout=0,
                dsrdtr=False, rtscts=False,
            )
            self.serial_io.dtr = False
            self.serial_io.rts = False
            self.serial_io.reset_input_buffer()
            self.serial_io.reset_output_buffer()

    def close_serial_port(self):
        if self.serial_io is not None:
            self.serial_io.close()
            self.serial_io = None

    def push(self, value):
        """Push a value onto the stack"""
        self.write_byte(self.SP, value)
        self.SP -= 1

    def pop(self, update_flags=True):
        """Pop a value from the stack"""
        self.SP += 1
        result = self.read_byte(self.SP)
        if update_flags:
            self.update_zero_flag(result)
            self.update_negative_flag(result)
        return result

    def load_binary(self, filename, address, auto_detect_header=True):
        """Load a binary file into memory at a specific address.
        
        If auto_detect_header is True and the file starts with the OT magic
        (0x4F 0x54), the 6-byte header is stripped and the address encoded in
        the header is returned (but the caller-provided address is used for
        loading when it was explicitly given).
        Returns the effective load address.
        """
        try:
            with open(filename, 'rb') as f:
                data = f.read()
        except FileNotFoundError:
            raise FileNotFoundError(f"Could not open binary file: {filename}")

        effective_address = address
        if auto_detect_header and len(data) >= 6 and data[0] == 0x4F and data[1] == 0x54:
            header_address = (data[3] << 16) | (data[4] << 8) | data[5]
            data = data[6:]
            if address is None:
                effective_address = header_address
                print(f"   OT header detected: loading at {hex(effective_address)}")
            else:
                effective_address = address
                print(f"   OT header stripped (header address {hex(header_address)}, using {hex(effective_address)})")

        if effective_address is None:
            effective_address = 0x8400

        # Check if the address is within a valid, not read-only region
        valid_region = None
        for region_name, region in self.memory_regions.items():
            if region['start'] <= effective_address <= region['stop']:
                valid_region = region
                break
        
        if not valid_region:
            raise ValueError(f"Address {hex(effective_address)} is not within a valid region")
        
        # Check if the file will fit in the region
        end_address = effective_address + len(data) - 1
        if end_address > valid_region['stop']:
            raise ValueError(
                f"Binary file ({len(data)} bytes) too large for region {region_name} "
                f"starting at address {hex(effective_address)} (space available: {valid_region['stop'] - effective_address + 1} bytes)"
            )
        
        # Perform the load
        for i, byte in enumerate(data):
            self.memory[effective_address + i] = byte

        return effective_address

    def reset(self):
        """Reset the CPU to its initial state"""
        self.__init__()
        self.PC = 0x0000
        self.SP = 0xFFFF
    
    def _tick_sim_timer(self):
        lsb = self.memory[self.TIMER_COUNTER_LSB] + 1
        self.memory[self.TIMER_COUNTER_LSB] = lsb & 0xFF
        if lsb > 0xFF:
            self.memory[self.TIMER_COUNTER_MSB] = (self.memory[self.TIMER_COUNTER_MSB] + 1) & 0xFF

    def step(self):
        """Execute one instruction"""
        # Fetch
        opcode = self.memory[self.PC]
        self.IR = opcode
        # Decode and Execute
        self.true_condition = False
        if opcode in self.instructions:
            exec(self.instructions[opcode]['sim'])
            added = self.instructions[opcode]['cycles_true'] if self.true_condition else self.instructions[opcode]['cycles']
            self.cycles += added
            self._timer_cycle_debt += added
        else:
            raise Exception(f"Unknown opcode: 0x{opcode:02X}")
        while self._timer_cycle_debt >= self.CYCLES_PER_TIMER_TICK:
            self._timer_cycle_debt -= self.CYCLES_PER_TIMER_TICK
            if not self.I:
                self._tick_sim_timer()
    
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
        self.PC = self.pop(update_flags=False) + (self.pop(update_flags=False) << 8) + (self.pop(update_flags=False) << 16) + 4

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
        """Calculate the address from registries with optional index.

        DE,X / YDE,X: hardware does not support page-cross when E+index overflows
        (microcode: "Cross page not supported"). Match that unless
        self.allow_index_page_cross is True (legacy sim leniency).
        """
        if index:
            self.O = (self.E + index) > 0xFF
        match registries:
            case 'yde':
                if index and not getattr(self, 'allow_index_page_cross', False) and (self.E + index) > 0xFF:
                    return self.Y * 65536 + self.D * 256 + ((self.E + index) & 0xFF)
                return self.Y * 65536 + self.D * 256 + self.E + (index if index else 0)
            case 'de':
                if index and not getattr(self, 'allow_index_page_cross', False) and (self.E + index) > 0xFF:
                    return self.D * 256 + ((self.E + index) & 0xFF)
                return self.D * 256 + self.E + (index if index else 0)
            case _:
                raise ValueError(f"Invalid operand registries: {registries}")
    
    # Memory access methods
    def flush_serial_rx(self):
        """Drain pending bytes on the real serial port."""
        if self.serial_io is not None:
            self.serial_io.reset_input_buffer()

    def read_byte(self, address):
        """Read a byte from memory"""
        address &= 0xFFFFFF  # 24-bit address bus

        for region in self.memory_regions.values():
            if region['start'] <= address <= region['stop']:
                if region['io'] == False:
                    return self.memory[address]
                else:
                    if address == 0x6010 or address == 0x6011:
                        return pyrandom.randint(0, 255)
                    elif address == 0x6012:
                        return 0x00
                    elif address == 0x6021:
                        if self.serial_io != None:
                            if self.serial_io.in_waiting > 0:
                                return self.serial_io.read(1)[0]
                        if len(self.KEY) > 0:
                            return self.KEY.pop(0)
                        return 0x00
                    elif address == 0x6020:
                        if self.serial_io != None:
                            return 0x03 if self.serial_io.in_waiting > 0 else 0x02
                        if len(self.KEY) > 0:
                            return 0x03
                        return 0x02
                    elif address == 0x6022:
                        if self.ch376 is not None:
                            return self.ch376.read_status()
                        return 0x02  # TX empty, no RX
                    elif address == 0x6023:
                        if self.ch376 is not None:
                            return self.ch376.read_data()
                        return 0x00
                    
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
                    if address == 0x6012:
                        if value == 0xFD:
                            self.flush_serial_rx()
                    elif address == 0x6021:
                        if self.serial_io != None:
                            self.serial_io.write(bytes([value]))
                            self.serial_io.flush()
                        else:
                            print(f"{chr(value)}", end="")
                            sys.stdout.flush()
                    elif address == 0x6022:
                        pass  # ACIA #2 control writes ignored
                    elif address == 0x6023:
                        if self.ch376 is not None:
                            self.ch376.write_data(value)
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


def autorun_command_bytes(load_address):
    if load_address == 0x8400:
        return b"r\r"
    addr_hex = f"{load_address:06x}" if load_address > 0xFFFF else f"{load_address:04x}"
    return f"r{addr_hex}\r".encode()


def push_input(cpu, data):
    """Queue bytes as Otto ACIA RX (keyboard / peer → Otto), not TX to the display."""
    for byte in data:
        cpu.push_key(byte)


def run_cpu_loop(cpu, args):
    """Run the CPU until HLT or autorun completion. Returns (exit_code, stop_reason)."""
    exit_code = 0
    stop_reason = "completed"
    try:
        while cpu.HLT == False:
            cpu.step()
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
    return exit_code, stop_reason

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
    parser.add_argument("--address", type=lambda x: int(x, 0), default=None, help="Memory address to load the program (default: auto-detect from OT header, fallback 0x8400)")
    parser.add_argument("--simulate-serial", action="store_true", help="Create a virtual serial port pair (connect minicom to the printed device)")
    parser.add_argument("--serial-device", type=str, default=None, metavar="PATH", help="Use a real serial device for ACIA I/O (e.g. FTDI to VGA32: /dev/cu.usbserial-...)")
    parser.add_argument("--serial-baud", type=int, default=115200, help="Baud rate for --serial-device (default: 115200)")
    parser.add_argument("--headless", action="store_true", help="Run without TTY (no stdin, no termios). Compatible with batch/CI usage")
    parser.add_argument("--autorun", action="store_true", help="Automatically run the loaded program after kernel boot (implies --headless)")
    parser.add_argument("--max-cycles", type=int, default=0, help="Maximum CPU cycles before forced exit (0 = unlimited)")
    parser.add_argument("--quiet", action="store_true", help="Suppress kernel output, show only application output (address >= 0x8400)")
    parser.add_argument("--dump-regs", type=str, default=None, help="Dump CPU registers to a file on exit (JSON format)")
    parser.add_argument("--input", type=str, default=None, help="Pre-load keyboard buffer with this string (use \\r for CR)")
    parser.add_argument("--ch376", action="store_true", help="Emulate a CH376S USB module on ACIA #2 (0x6022/0x6023)")
    parser.add_argument("--ch376-dir", type=str, default=None,
                        help="Host directory used as the USB stick root (default: roms/sim/ch376/)")
    args = parser.parse_args()

    if args.simulate_serial and args.serial_device:
        parser.error("cannot use both --simulate-serial and --serial-device")

    # --autorun implies --headless
    if args.autorun:
        args.headless = True

    print("\nProject OTTO - Simulator v1.4.0")
    # Create a new OttoCPU instance
    cpu = OttoCPU()

    if args.ch376:
        stick_root = args.ch376_dir or str(_ROOT / "roms" / "sim" / "ch376")
        cpu.ch376 = Ch376Sim(stick_root)
        print(f"-> CH376 emulator: virtual USB stick at {stick_root}")

    # Load unified ROM (kernel + P-Machine) into memory
    print("-> loading ROM into memory")
    cpu.load_binary("roms/system/kernel-rom.bin", cpu.memory_regions['rom']['start'], auto_detect_header=False)

    # Load a program into memory if provided
    effective_address = args.address if args.address is not None else 0x8400
    if args.program:
        print(f"-> loading program {args.program} into memory")
        effective_address = cpu.load_binary(args.program, args.address)

    # App execution tracking: detect when the program starts (PC enters app space)
    # and when it returns (PC back in kernel AND SP restored above JSR level).
    # Uses effective_address (resolved after OT header auto-detection).
    if args.autorun or args.quiet:
        cpu._app_running = False
        cpu._app_started = False
        cpu._app_sp = 0
        cpu._app_address = effective_address
        cpu._app_track_enabled = not args.autorun
        _original_step = cpu.step
        def _tracking_step():
            if args.autorun and not cpu._app_track_enabled:
                if cpu.serial_io is not None or len(cpu.KEY) == 0:
                    cpu._app_track_enabled = True
            if cpu._app_track_enabled and not cpu._app_running and not cpu._app_started \
                    and cpu.PC >= cpu._app_address:
                cpu._app_running = True
                cpu._app_started = True
                cpu._app_sp = cpu.SP
            elif cpu._app_running and cpu.PC < cpu._app_address and cpu.SP > cpu._app_sp:
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

        # Set up file change handler (not needed in headless mode)
        if not args.headless:
            event_handler = FileChangeHandler(cpu, args.program, args.address)
            observer = Observer()
            observer.schedule(event_handler, path=os.path.dirname(args.program), recursive=False)
            observer.start()

    if args.serial_device:
        cpu.set_serial_port(args.serial_device, baud=args.serial_baud)
        print(f"-> ACIA on serial {args.serial_device} @ {args.serial_baud} 8N1")

    # In autorun mode, send 'r' + CR (or rADDR) to run the loaded program
    if args.autorun:
        push_input(cpu, autorun_command_bytes(effective_address))

    # Pre-load additional keyboard/serial input if provided
    if args.input:
        input_bytes = args.input.encode().decode('unicode_escape')
        push_input(cpu, bytes(ord(c) for c in input_bytes))

    # Run the simulator
    print("-> system boot")
    exit_code = 0
    stop_reason = "completed"

    try:
        if args.headless:
            exit_code, stop_reason = run_cpu_loop(cpu, args)
        elif args.simulate_serial:
            with VirtualSerialPorts(2, False, False) as ports:
                cpu.set_serial_port(ports[0])
                print(f"-> use serial port {ports[1]} to communicate with the CPU")
                sys.stdout.flush()
                while cpu.HLT == False:
                    cpu.step()
                    time.sleep(0)
        elif args.serial_device:
            while cpu.HLT == False:
                cpu.step()
                time.sleep(0)
        else:
            old_settings = termios.tcgetattr(sys.stdin)
            try:
                tty.setcbreak(sys.stdin.fileno())
                while cpu.HLT == False:
                    while keyboard_hit():
                        key = ord(sys.stdin.read(1))
                        cpu.push_key(key)
                    cpu.step()
                    time.sleep(0)
            finally:
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
    except Exception as e:
        print(f"\nError executing opcode 0x{cpu.IR:02X}: {e}", end="")
        stop_reason = "error"
        exit_code = 2

    print(f"\nSystem halted. OUT registry: 0x{cpu.OUT:02X} (cycles: {cpu.cycles})")

    if args.dump_regs:
        import json
        regs = {
            "A": cpu.A, "X": cpu.X, "Y": cpu.Y,
            "D": cpu.D, "E": cpu.E, "OUT": cpu.OUT,
            "PC": cpu.PC, "SP": cpu.SP,
            "flags": {"Z": cpu.Z, "N": cpu.N, "C": cpu.C, "I": cpu.I, "O": cpu.O},
            "cycles": cpu.cycles,
            "stop_reason": stop_reason,
        }
        with open(args.dump_regs, 'w') as f:
            json.dump(regs, f, indent=2)
        print(f"-> registers dumped to {args.dump_regs}")

    cpu.close_serial_port()
    if args.headless:
        sys.exit(exit_code)
            
 
    