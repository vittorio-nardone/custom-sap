# Tiny Pascal Language Reference

Tiny Pascal is a minimal subset of Standard Pascal designed for the Project Otto 8-bit homebrew computer. Programs are compiled on a host PC using `pascal_compiler.py` and executed on Otto's P-Machine bytecode interpreter.

## Program Structure

```pascal
program ProgramName;
var
  { variable declarations }
begin
  { statements }
end.
```

The `var` block is optional. If present, it must appear between the `program` header and `begin`.

## Data Types

| Type | Size | Range | Description |
|------|------|-------|-------------|
| `integer` | 16-bit | -32768 to 32767 | Signed two's complement integer |

String literals can be used in `write`/`writeln` calls but there is no `string` variable type.

## Variable Declarations

```pascal
var
  x: integer;
  a, b, result: integer;
```

Multiple variables of the same type can be declared on one line, separated by commas. Each declaration line ends with a semicolon. Maximum 128 variables per program.

## Statements

### Assignment

```pascal
variable := expression;
```

### write / writeln

```pascal
write('text');           { print string, no newline }
write(expression);       { print integer value, no newline }
writeln('text');          { print string + newline }
writeln(expression);     { print integer value + newline }
writeln;                 { print newline only }
```

The argument type (string literal vs integer expression) is detected automatically by the compiler.

## Expressions

### Operators (by precedence, highest first)

| Precedence | Operators | Description |
|------------|-----------|-------------|
| 1 (highest) | `-` (unary) | Negation |
| 2 | `*`, `div`, `mod` | Multiplication, integer division, modulo |
| 3 (lowest) | `+`, `-` | Addition, subtraction |

Parentheses `( )` can be used to override precedence.

### Integer Literals

Decimal integers: `0`, `42`, `255`, `32767`.
Negative literals: `-1`, `-100` (parsed as unary minus applied to a positive literal).

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

- No control flow (`if`, `while`, `for`) — planned for Milestone 3
- No procedures or functions — planned for Milestone 4
- No `string` type — only string literals in write/writeln
- No arrays or records
- No `readln` / input
- No boolean type or relational operators
- Integer overflow is silently truncated to 16 bits

## Compilation and Execution

```bash
# Compile
python pascal_compiler.py program.pas -o roms/apps/pascal/program.bin

# Run in simulator
python simulate.py --autorun --program roms/apps/pascal/program.bin --max-cycles 1000000 --quiet

# Or load interactively and use 'r' (run) or 'p' (Pascal) from kernel menu
python simulate.py --program roms/apps/pascal/program.bin
```

## Complete Example

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
