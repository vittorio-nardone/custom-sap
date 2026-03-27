# Tiny Pascal Language Reference

Tiny Pascal is a minimal subset of Standard Pascal designed for the Project Otto 8-bit homebrew computer. Programs can be compiled on a host PC using the cross-compiler (`pascal_compiler.py`) or written and compiled directly on Otto hardware using the on-board editor/compiler (ROM #3). Both target Otto's P-Machine bytecode interpreter.

## Program Structure

```pascal
program ProgramName;
var
  { variable declarations }
begin
  { statements }
end.
```

The `var` block is optional. If present, it must appear between the `program` header and `begin`. Procedure and function declarations (see below) appear after the `var` block and before `begin`.

## Data Types

| Type | Size | Range | Description |
|------|------|-------|-------------|
| `integer` | 16-bit | -32768 to 32767 | Signed two's complement integer |
| `real` | 32-bit | ±3.4×10³⁸ | IEEE 754 single-precision floating point |

String literals can be used in `write`/`writeln` calls but there is no `string` variable type.

### Type Coercion

`integer` values are implicitly promoted to `real` when mixed in expressions, assignments, or function returns. Conversely, `real` values are truncated to `integer` when assigned to an integer variable or used with integer-only operators (`div`, `mod`, `and`, `or`, `not`, `odd`).

```pascal
var x: real;
x := 10;          { integer 10 is promoted to 10.00 }
x := x + 3;       { 3 is promoted to 3.00, result is real }
writeln(x div 1); { x is truncated to integer for div }
```

## Constants

Named constants can be declared in a `const` block before `var`. Constants are integer-only and can use negative values:

```pascal
const
  maxsize = 100;
  minval = -10;
  offset = 42;
var
  data: array[1..maxsize] of integer;  { constants usable in array bounds }
```

Constants can be used in any expression where an integer literal is expected. Local `const` blocks are also allowed inside procedures and functions.

## Variable Declarations

```pascal
var
  x: integer;
  a, b, result: integer;
  pi: real;
  temp, avg: real;
```

Multiple variables of the same type can be declared on one line, separated by commas. Each declaration line ends with a semicolon. `integer` and `real` variables can be mixed in the same `var` block. Maximum 128 variables per scope.

## Arrays

One-dimensional arrays of `integer` are supported with compile-time constant bounds:

```pascal
var
  data: array[1..10] of integer;
  table: array[0..49] of integer;
```

Array bounds are inclusive and must be integer constants (negative bounds are allowed, e.g. `array[-5..5]`). Each array declaration must have a single name (no multi-name declarations like `a, b: array[...]`).

### Array Access

```pascal
data[1] := 42;              { store value }
x := data[i];               { load value }
data[i] := data[i-1] + 1;   { read and write in same statement }
writeln(data[5]);            { use in expressions }
```

Array elements can be used anywhere an integer expression is expected. The index expression can be any integer expression evaluated at runtime.

### Scope and Nesting

Arrays declared in an outer scope can be accessed from nested procedures/functions via lexical scoping, just like regular variables:

```pascal
program Example;
var
  arr: array[1..5] of integer;

procedure fillArray;
var i: integer;
begin
  for i := 1 to 5 do
    arr[i] := i * 10
end;
```

### Limitations

- Only `integer` element type
- Only one-dimensional arrays
- Arrays cannot be passed as procedure/function parameters
- No bounds checking at runtime (invalid indices may corrupt memory)
- Maximum ~120 elements per array (limited by 256-byte frame size per scope)
- `readln` does not support array elements — read into a temporary variable first

## Procedures and Functions

### Procedure Declaration

```pascal
procedure ProcName(param1: integer; param2: integer);
var
  localVar: integer;
begin
  { statements }
end;
```

Procedures can have zero or more parameters (passed by value) and an optional `var` block for local variables. The parameter list uses semicolons between parameter groups (not commas).

### Function Declaration

```pascal
function FuncName(x: integer): integer;
var
  temp: integer;
begin
  { statements }
  FuncName := expression;  { assign return value }
end;
```

Functions are like procedures but return a value. The return type (`integer` or `real`) is specified after the parameter list. To set the return value, assign to the function's own name within the body.

```pascal
function circle_area(r: real): real;
begin
  circle_area := 3.14159 * r * r
end;
```

A function returning `real` can accept `integer` arguments — they are promoted automatically. The return value is also coerced if needed (e.g., returning an integer expression from a `real` function).

### Nesting

Procedures and functions can be nested inside other procedures or functions. Inner routines can access variables from enclosing scopes (lexical scoping via static links):

```pascal
program Nested;
var g: integer;

procedure outer(x: integer);
var local: integer;

  function inner(y: integer): integer;
  begin
    inner := x + y + g;  { accesses outer's param and global var }
  end;

begin
  local := inner(10);
  writeln(local)
end;

begin
  g := 100;
  outer(5)
end.
```

### Recursion

Both procedures and functions support recursion:

```pascal
function factorial(x: integer): integer;
begin
  if x <= 1 then factorial := 1
  else factorial := x * factorial(x - 1)
end;
```

### Calling

Procedures are called as statements; functions are called within expressions:

```pascal
myProcedure(arg1, arg2);      { procedure call }
result := myFunction(arg);     { function call in expression }
writeln(factorial(7));          { function call as argument }
```

Arguments are passed by value by default: the called routine receives a copy. Use `var` to pass by reference — changes to the parameter are reflected in the caller's variable:

```pascal
procedure swap(var x, y: integer);
var temp: integer;
begin
  temp := x;
  x := y;
  y := temp
end;

procedure inc_by(var n: integer; amount: integer);
begin
  n := n + amount
end;
```

`var` and value parameters can be mixed in the same parameter list. Each parameter group (separated by `;`) can independently have `var`.

## Statements

### Assignment

```pascal
variable := expression;
```

### write / writeln

```pascal
write('text');           { print string, no newline }
write(intExpr);          { print integer value, no newline }
write(realExpr);         { print real value, no newline }
writeln('text');          { print string + newline }
writeln(intExpr);        { print integer value + newline }
writeln(realExpr);       { print real value + newline }
writeln;                 { print newline only }
```

The argument type (string literal, integer expression, or real expression) is detected automatically by the compiler. Real values are printed with two decimal places (e.g., `3.14`, `-0.50`).

### readln

```pascal
readln(intVar);          { read integer from serial input }
readln(realVar);         { read real from serial input }
```

Reads a value from the serial port and stores it in the given variable. The input is terminated by Enter (CR). For integers: signed decimal, range -32768 to 32767. For reals: decimal with optional fractional part (e.g., `3.14`, `-0.5`).

## Control Flow

### if / then / else

```pascal
if condition then statement;
if condition then statement else statement;
```

The `else` clause is optional. Nested `if` chains are supported:

```pascal
if x = 1 then writeln('one')
else if x = 2 then writeln('two')
else writeln('other')
```

### while / do

```pascal
while condition do statement;
while condition do
begin
  { multiple statements }
end;
```

### for / to / downto

```pascal
for i := 1 to 10 do statement;
for i := 10 downto 1 do statement;
```

The loop variable must be declared in the `var` block. The start and end expressions are evaluated once before the loop begins. The loop is overflow-safe: it correctly handles the boundary case when the loop variable equals the limit.

### repeat / until

```pascal
repeat
  statement1;
  statement2
until condition;
```

Executes the statements at least once, then repeats as long as the condition is false. Unlike `while`, the condition is checked after each iteration and the body does not require `begin..end` for multiple statements.

### Compound Statements (begin..end)

```pascal
begin
  statement1;
  statement2;
  statement3
end
```

Use `begin..end` to group multiple statements where a single statement is expected (e.g., as the body of `if`, `while`, or `for`).

## Expressions

### Operators (by precedence, highest first)

| Precedence | Operators | Description |
|------------|-----------|-------------|
| 1 (highest) | `not`, `-` (unary) | Logical negation, arithmetic negation |
| 2 | `*`, `/`, `div`, `mod`, `and` | Multiplication, real division, integer division, modulo, logical AND |
| 3 | `+`, `-`, `or` | Addition, subtraction, logical OR |
| 4 (lowest) | `=`, `<>`, `<`, `>`, `<=`, `>=` | Relational operators |

Parentheses `( )` can be used to override precedence.

The `/` operator always produces a `real` result (both operands are promoted to `real` if needed). The `div` and `mod` operators always produce an `integer` result (both operands are truncated to integer if needed). The `*`, `+`, `-` operators produce `real` if either operand is `real`, `integer` otherwise.

### Relational Operators

| Operator | Description |
|----------|-------------|
| `=` | Equal |
| `<>` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

Relational operators compare two expressions and produce a boolean result (0 = false, 1 = true) used by control flow statements. Both `integer` and `real` operands are supported; if one operand is `real`, the other is promoted automatically.

### Boolean Operators

| Operator | Description |
|----------|-------------|
| `and` | Logical AND (both operands must be non-zero) |
| `or` | Logical OR (at least one operand must be non-zero) |
| `not` | Logical NOT (zero becomes 1, non-zero becomes 0) |

Boolean operators work on integer values: any non-zero value is considered true, zero is false.

### Built-in Functions

| Function | Argument | Result | Description |
|----------|----------|--------|-------------|
| `abs(x)` | `integer` or `real` | same type | Absolute value |
| `odd(x)` | `integer` | `integer` | 1 if x is odd, 0 if even |
| `ord(c)` | char literal | `integer` | ASCII code of character (e.g., `ord('A')` = 65) |
| `chr(x)` | `integer` | writes char | Output the character with ASCII code x |

```pascal
writeln(abs(-5));        { 5 }
writeln(abs(-3.14));     { 3.14 }
writeln(odd(7));         { 1 }
writeln(ord('A'));       { 65 }
write(chr(65));          { A }
```

### Integer Literals

Decimal integers: `0`, `42`, `255`, `32767`.
Negative literals: `-1`, `-100` (parsed as unary minus applied to a positive literal).

### Real Literals

Decimal numbers with a fractional part: `3.14`, `0.5`, `2.0`, `100.75`.
A digit must appear before and after the decimal point (`0.5` not `.5`, `2.0` not `2.`).
Negative real literals: `-3.14` (parsed as unary minus). No scientific notation.

### Examples

```pascal
result := a + b * 2;         { b*2 computed first, then +a }
result := (a + b) * 2;       { a+b first, then *2 }
result := -x;                { negate x }
result := 100 mod 7;         { remainder = 2 }
result := 100 div 7;         { quotient = 14 }
```

## Comments

Three comment styles are supported:

```pascal
{ curly brace comment }
(* parenthesis-star comment *)
// single-line comment
```

## Limitations (current version)

- No `string` type — only string literals in write/writeln
- No records or multi-dimensional arrays
- Arrays cannot be passed as parameters to procedures/functions
- No `readln` for strings or array elements — only scalar integer/real input
- No dedicated boolean type (integers are used: 0 = false, non-zero = true)
- No runtime bounds checking for array indices
- Integer overflow is silently truncated to 16 bits
- `real` precision is IEEE 754 single-precision (~7 significant decimal digits); some decimal values like 3.14 may display as 3.13 due to binary representation
- No scientific notation for real literals
- `real` arrays are not supported — only `integer` arrays

## Compilation and Execution

### Cross-compiler (host PC)

```bash
# Compile
python pascal_compiler.py program.pas -o roms/apps/pascal/program.bin

# Run in simulator
python simulate.py --autorun --program roms/apps/pascal/program.bin --max-cycles 1000000 --quiet

# Or load interactively and use 'r' (run) or 'p' (Pascal) from kernel menu
python simulate.py --program roms/apps/pascal/program.bin
```

### On-board editor/compiler

Project Otto includes an on-board Pascal editor and single-pass compiler in ROM #3. This allows writing, editing, and running Pascal programs directly on the hardware (or in the simulator) without a host PC.

#### Entering the Editor

From the kernel menu, type `e` + Enter to launch the Pascal editor.

#### Editor Commands

| Command | Description |
|---------|-------------|
| `n` | **New** — clear the source buffer |
| `l` | **List** — display all lines (or `l 3` for line 3, `l 2-5` for range) |
| `i` | **Insert** — insert lines (or `i 3` to insert at line 3). Empty line to stop |
| `d N` | **Delete** — delete line N (or `d 2-5` for range) |
| `e N` | **Edit** — edit line N (shows current content, type new content) |
| `lo` | **Load** — paste a program from terminal. Empty line to stop |
| `r` | **Run** — compile and execute the program |
| `h` | **Help** — show available commands |
| `q` | **Quit** — exit the editor, return to kernel |

Commands are case-insensitive. `L` and `l` both work.

#### Loading a Program via Copy & Paste

The `lo` (load) command allows pasting a complete Pascal program from the terminal:

1. Type `lo` + Enter
2. The editor prints `Paste, end w/empty:` and clears the current program
3. Paste the program text from your clipboard (or type it line by line)
4. Press Enter on an empty line to finish
5. The editor reports the number of lines loaded

```
> lo
Paste, end w/empty:
program Hello;
begin
  writeln('Hello, Otto!')
end.

  4 ok
> r
Compiling..OK(24B)
Hello, Otto!
```

**Notes:**
- Each line is echoed as it is received
- An empty line (just Enter) signals end of input
- The previous program is cleared (equivalent to `n` + paste)
- Maximum 255 lines, 80 characters per line
- Source is stored in Expansion RAM (page 1, 64 KB)

#### Listing a Program

Use `l` to dump the program to the terminal. This can also be used to "save" a program by copying the output from the terminal.

#### Compiling and Running

The `r` command compiles the source and immediately executes the resulting P-code:

```
> r
Compiling..OK(189B)

1
2
3
4
5
```

If there are errors, the compiler reports the line number and error type:

```
> r
Compiling..Err L 4: syntax
```

#### On-board Compiler Limitations

The on-board compiler supports the full Tiny Pascal language (variables, arrays, constants, procedures, functions, recursion, nested scopes, `real` type) with these restrictions compared to the cross-compiler:

- Multiple `var` blocks are not supported — declare all variables (scalars, arrays, integer, real) in a single `var` block, separated by semicolons
- Identifier names are truncated to 7 characters in the symbol table
- Maximum ~60 symbols (variables, constants, procedures, functions) per program
- All parameters are treated as `integer` (no `real` parameters in the on-board compiler)
- Error messages are abbreviated (e.g., `syntax`, `undef`, `type`)

## Complete Examples

### Arithmetic

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

### Control Flow (FizzBuzz)

```pascal
program FizzBuzz;
var
  i: integer;
begin
  for i := 1 to 20 do
  begin
    if (i mod 15) = 0 then writeln('FizzBuzz')
    else if (i mod 3) = 0 then writeln('Fizz')
    else if (i mod 5) = 0 then writeln('Buzz')
    else writeln(i)
  end
end.
```

Output: `1`, `2`, `Fizz`, `4`, `Buzz`, `Fizz`, `7`, `8`, `Fizz`, `Buzz`, `11`, `Fizz`, `13`, `14`, `FizzBuzz`, `16`, `17`, `Fizz`, `19`, `Buzz`

### Recursive Function (Factorial)

```pascal
program Functions;
var n: integer;

function factorial(x: integer): integer;
begin
  if x <= 1 then factorial := 1
  else factorial := x * factorial(x - 1)
end;

begin
  n := 7;
  write('Factorial of ');
  write(n);
  write(' = ');
  writeln(factorial(n))
end.
```

Output: `Factorial of 7 = 5040`

### Floating Point

```pascal
program FloatDemo;
var
  x: real;

function circle_area(r: real): real;
begin
  circle_area := 3.14159 * r * r
end;

begin
  x := 3.5;
  writeln(x);                  { 3.50 }
  writeln(x * 2.0);            { 7.00 }
  writeln(x + 1);              { 4.50 — integer 1 promoted to real }
  writeln(circle_area(5.0));   { 78.53 }
  if x > 3.0 then
    writeln('x is greater than 3')
end.
```

### Constants and repeat..until

```pascal
program Demo;
const
  limit = 5;
var
  n: integer;
begin
  n := limit;
  repeat
    writeln(n);
    n := n - 1
  until n = 0
end.
```

Output: `5`, `4`, `3`, `2`, `1`

### var Parameters

```pascal
program SwapDemo;
var a, b: integer;

procedure swap(var x, y: integer);
var temp: integer;
begin
  temp := x; x := y; y := temp
end;

begin
  a := 10; b := 20;
  swap(a, b);
  writeln(a);    { 20 }
  writeln(b)     { 10 }
end.
```

### Arrays (Bubble Sort)

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

  for i := 1 to n do
  begin
    write(data[i]);
    write(' ')
  end;
  writeln
end.
```

Output: `1 2 3 4 5 6 7 8 9 10`
