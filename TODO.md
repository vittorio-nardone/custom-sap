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

## Milestone 2 — Integer variables, assignments, arithmetic expressions

Extend the language to support integer data types and basic computation.

- [ ] New P-code opcodes: `LOAD` (push variable value), `STORE` (pop to variable), `ADD`, `SUB`, `MUL`, `DIV`, `NEG`
- [ ] P-Machine RAM allocation for variable storage (frame at 0xB200+)
- [ ] Compiler: `var` block parsing with integer type declarations
- [ ] Compiler: assignment statements (`x := expr`)
- [ ] Compiler: arithmetic expression parsing with operator precedence
- [ ] Compiler: `write(integer_expr)` and `writeln(integer_expr)` — numeric output via `ACIA_SEND_DECIMAL`
- [ ] New CSP for integer output (decimal string conversion)
- [ ] Example: `pascal/examples/calc.pas` — simple calculations with variables

```pascal
program Calc;
var
  a, b, result: integer;
begin
  a := 10;
  b := 25;
  result := a + b * 2;
  writeln('Result: ');
  writeln(result);
end.
```

## Milestone 3 — Control flow (`if/then/else`, `while/do`, `for`)

Add branching and looping constructs.

- [ ] New P-code opcodes: `JMP` (unconditional jump), `JPC` (jump if condition false)
- [ ] Comparison opcodes: `EQ`, `NE`, `LT`, `GT`, `LE`, `GE`
- [ ] Boolean logic opcodes: `AND`, `OR`, `NOT`
- [ ] Compiler: `if ... then ... else` parsing and code generation
- [ ] Compiler: `while ... do` loop
- [ ] Compiler: `for ... to/downto ... do` loop
- [ ] Compiler: relational and boolean expressions
- [ ] Example: `pascal/examples/fizzbuzz.pas` or similar loop-based program

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

## Milestone 4 — Procedures and functions

Support modular programming with user-defined subroutines.

- [ ] New P-code opcodes: `CALL` (call procedure/function), `RET` (return), `ENTER` (allocate frame), `LEAVE` (deallocate frame)
- [ ] P-Machine call stack and activation records (separate from eval stack)
- [ ] Compiler: `procedure` and `function` declarations
- [ ] Compiler: parameter passing (by value)
- [ ] Compiler: local variable scoping
- [ ] Compiler: `function` return values
- [ ] New CSP: `readln` for serial input (integer and string)
- [ ] Example: `pascal/examples/functions.pas`

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

## Milestone 5 — On-board editor/compiler

Enable programming directly on Otto hardware without a host PC.

- [ ] Evaluate approach: editor/compiler as kernel extension vs standalone app in RAM
- [ ] Line editor with serial terminal I/O (VT100 escape sequences)
- [ ] On-board tokenizer and P-code generator (subset of Python compiler, in Otto assembly)
- [ ] Source code storage in RAM expansion pages (0x010000-0x02FFFF, 128 KB)
- [ ] Direct P-code generation and execution without intermediate files
- [ ] Save/load programs via XMODEM
