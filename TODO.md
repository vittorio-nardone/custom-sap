# TODO

This file is used to track possible enhancements.

## [DONE] [assembly] CMP 
Index address mode for CMP. Example:

```sh
CMP 0x0000,y 
```

## [DONE] [assembly] ADC /SBC
Index address mode for ADC/SBC. Replace ADD/SUB. Example:

```sh
ADC 0x0000,y 
```

## [assembly] INC/DEC 
Index address mode for INC and DEC. Example:

```sh
INC 0x0000,x 
```

## [assembly] INC/DEC for A
INC and DEC for A registry. One of the following syntax:

```sh
INC A  
INA      
```

## [assembly] INC/DEC for 16bit 
INC and DEC for a 16bit integer in memory. The u16/u24 value is the address of the LSB.

Example: INW meaning is "increment word" (unsigned 16bit integer)
```sh
INW 0x0112 
DEW 0x0112     
```

## [assembly] JEQ / JNE  
Jump on Result Zero to New Location Saving Return Address.
* JEQ as a combination of BEQ and JSR istructions
* JNE as a combination of BNE and JSR istructions

Support both absolute / zero-page address modes.
Evaluate the equivalent istruction for other conditions, like JCS (BCS + JSR)

Example:
```sh
LDA 0x8600
JEQ 0x8900  ; do something if A == 0 then RTS
...         
...
```

## [DONE] [assembly] INC/DEC/INX.. should set N flag
INC and DEC operations set Z flag only but should set N flag too (according to the 6502 datasheet)

## [hardware] PAL/NTSC video board
Add a video card to Otto!

## [hardware] Keyboard interface board
The keyboard interface board was tested quickly but is not working as expected.

## [hardware] Add Commodore IEC interface
Add a Commodore IEC interface to Otto and use it for storage on FDD/SD

---

# Tiny Pascal Development Roadmap

Tiny Pascal is a minimal Pascal implementation for Project Otto, replacing the deprecated FORTH interpreter. It consists of a P-Machine bytecode interpreter in ROM #3 and a Python cross-compiler.

## [DONE] Milestone 1 — Hello World (`writeln` and strings)

Basic infrastructure to compile and execute a Pascal program that prints text via serial.

- [x] Remove Forth from build pipeline and kernel menu (files retained in `forth/`)
- [x] P-Machine interpreter in assembly (`pascal/pmachine.asm`, ROM #3 at 0x4000)
- [x] P-code binary format with header (magic "PM", version, code/data offsets)
- [x] P-code opcodes: `HALT`, `LIT`, `LIT16`, `CSP`
- [x] CSP standard procedures: `write(string)`, `writeln(string)`, `writeln()`
- [x] Python cross-compiler (`pascal_compiler.py`) with lexer, parser, code generator
- [x] Native stub generation for self-executing binaries (run via `r` kernel command)
- [x] Kernel `p` command with auto-detection of native stub vs pure P-code
- [x] Build integration in `generate-all.sh`
- [x] CLAUDE.md and README.md documentation

## Milestone 2 — Integer variables, assignments, arithmetic expressions ✓

Extend the language to support 16-bit signed integer data types and basic computation.

- [x] New P-code opcodes: `LOAD`, `STORE`, `ADD`, `SUB`, `MUL`, `DIV`, `NEG`, `MOD`
- [x] P-Machine RAM allocation for variable storage (frame at 0xB200, 256 bytes)
- [x] Eval stack uniformly 16-bit (2 bytes per value, max 128 values)
- [x] Kernel math routines: `MUL16S`, `DIV16S`, `MOD16S` (signed 16-bit)
- [x] Kernel serial routine: `ACIA_SEND_DECIMAL16S` (signed 16-bit decimal output)
- [x] Compiler: `var` block parsing with integer type declarations
- [x] Compiler: assignment statements (`x := expr`)
- [x] Compiler: arithmetic expression parsing with operator precedence (`+`, `-`, `*`, `div`, `mod`, unary `-`)
- [x] Compiler: polymorphic `write`/`writeln` — string literal vs integer expression
- [x] New CSPs for integer output: `CSP_WRITE_INT` (0x03), `CSP_WRITELN_INT` (0x04)
- [x] Language documentation: `pascal/LANGUAGE.md`
- [x] Example: `pascal/examples/calc.pas`
- [x] Build order fix: `symbols.py` runs after kernel, before P-Machine compilation

```pascal
program Calc;
var
  a, b, result: integer;
begin
  a := 10;
  b := 25;
  result := a + b * 2;
  write('Result: ');
  writeln(result)
end.
```

Output: `Result: 60`

## Milestone 3 — Control flow (`if/then/else`, `while/do`, `for`)

Add branching and looping constructs.

- [x] Kernel: `CMP16S` signed 16-bit comparison routine (result in MATH16_TMP)
- [x] New P-code opcodes: `JMP` (unconditional jump), `JPC` (jump if condition false)
- [x] Comparison opcodes: `EQ`, `NE`, `LT`, `GT`, `LE`, `GE`
- [x] Boolean logic opcodes: `AND`, `OR`, `NOT`
- [x] Compiler: `if ... then ... else` parsing and code generation
- [x] Compiler: `while ... do` loop
- [x] Compiler: `for ... to/downto ... do` loop (overflow-safe, with hidden limit variable)
- [x] Compiler: relational and boolean expressions (standard Pascal precedence)
- [x] Compiler: `begin..end` compound statements
- [x] Example: `pascal/examples/fizzbuzz.pas`

```pascal
program FizzBuzz;
var i: integer;
begin
  for i := 1 to 20 do
  begin
    if (i mod 15) = 0 then writeln('FizzBuzz')
    else if (i mod 3) = 0 then writeln('Fizz')
    else if (i mod 5) = 0 then writeln('Buzz')
    else writeln(i);
  end;
end.
```

## [DONE] Milestone 4 — Procedures and functions

Support modular programming with user-defined subroutines.

- [x] New P-code opcodes: `CALL` (call procedure/function), `RET` (return), `ENTER` (allocate frame)
- [x] New P-code opcodes for lexical scoping: `LOAD_L` (load from outer scope), `STORE_L` (store to outer scope)
- [x] P-Machine call stack and activation records (separate from eval stack)
- [x] Frame pointer (FP) register for FP-relative variable addressing
- [x] Static links for nested scope access
- [x] Compiler: `procedure` and `function` declarations (with nesting)
- [x] Compiler: parameter passing (by value)
- [x] Compiler: local variable scoping with scope stack
- [x] Compiler: `function` return values (`funcname := expr`)
- [x] Compiler: recursive function calls
- [x] New CSP: `readln(var)` for serial integer input
- [x] Kernel: `ACIA_READ_DECIMAL16S` routine for signed integer input
- [x] Example: `pascal/examples/functions.pas` (recursive factorial)
- [x] Simulator fix: `pop()` no longer corrupts CPU flags during `RTS`

```pascal
program Functions;
var n: integer;

function factorial(x: integer): integer;
begin
  if x <= 1 then factorial := 1
  else factorial := x * factorial(x - 1);
end;

begin
  n := 7;
  write('Factorial of ');
  write(n);
  write(' = ');
  writeln(factorial(n));
end.
```

Output: `Factorial of 7 = 5040`

## [DONE] Milestone 4.5 — Arrays

Add one-dimensional array support with compile-time constant bounds.

- [x] New P-code opcodes: `LOAD_A`, `STORE_A` (array element access, FP-relative)
- [x] New P-code opcodes: `LOAD_AL`, `STORE_AL` (array element access via static chain for nested scopes)
- [x] Compiler: `array[low..high] of integer` declarations
- [x] Compiler: array indexing in expressions (`arr[expr]`) and assignments (`arr[expr] := expr`)
- [x] Compiler: adjusted-base optimization (index offset computed at compile time)
- [x] Compiler: lexical scoping for arrays in nested procedures/functions
- [x] Frame allocation with size validation (256-byte limit per scope)
- [x] Example: `pascal/examples/bubblesort.pas` (bubble sort of 10 elements)

```pascal
program BubbleSort;
var
  data: array[1..10] of integer;
  i, j, n, temp: integer;
begin
  n := 10;
  for i := 1 to n do
    data[i] := n - i + 1;
  for i := 1 to n - 1 do
    for j := 1 to n - i do
      if data[j] > data[j + 1] then
      begin
        temp := data[j];
        data[j] := data[j + 1];
        data[j + 1] := temp
      end;
  for i := 1 to n do begin write(data[i]); write(' ') end;
  writeln
end.
```

Output: `1 2 3 4 5 6 7 8 9 10`

## [DONE] Milestone 5 — On-board editor/compiler

Enable programming directly on Otto hardware without a host PC.

### Phase 1: Infrastructure ✓

- [x] Editor/compiler as ROM #3 extension (jump table at 0x4000)
- [x] Line editor with serial terminal I/O: NEW, LIST, INSERT, DELETE, EDIT, LOAD, HELP, QUIT
- [x] Source code storage in Expansion RAM page 1 (0x010000+), 255 lines × 80 chars
- [x] Kernel integration: `e` command in kernel menu launches editor
- [x] LOAD command for copy & paste from terminal (paste program, empty line to stop)

### Phase 2: Core compiler ✓

- [x] On-board single-pass recursive descent compiler (native 6502-style assembly)
- [x] Lexer with on-demand tokenization from expansion RAM source lines
- [x] Parser + code generator for: `var`, integer expressions, `if/then/else`, `while/do`, `for/to/downto`
- [x] `write`/`writeln` (string literals and integer expressions), `readln`
- [x] `begin..end` compound statements
- [x] P-code generation directly into application RAM (0x8400+)
- [x] Error reporting with line number: `Err L N: message`
- [x] RUN command: compile + execute via P-Machine

### Phase 3: Full language ✓

- [x] Procedure and function declarations with parameters (by value)
- [x] Recursive function calls (factorial, etc.)
- [x] Nested procedures/functions with lexical scoping (static links)
- [x] Array declarations: `array[lo..hi] of integer` with compile-time constant bounds
- [x] Array element access: `arr[expr]` in expressions and assignments
- [x] Scoped array access via `LOAD_AL`/`STORE_AL` (static chain traversal)
- [x] Extended symbol table: 16 bytes/entry with kind, scope, frame offset, array bounds
- [x] Nested `for` loops (compiler state saved/restored on stack)

ROM #3 usage: 8189 / 8192 bytes (99.96%, 3 bytes free)

### Not implemented

- [ ] SAVE command (dump source to serial for backup)
- [ ] XMODEM file transfer for source code
