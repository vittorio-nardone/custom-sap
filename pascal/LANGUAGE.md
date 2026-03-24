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
| 2 | `*`, `div`, `mod`, `and` | Multiplication, integer division, modulo, logical AND |
| 3 | `+`, `-`, `or` | Addition, subtraction, logical OR |
| 4 (lowest) | `=`, `<>`, `<`, `>`, `<=`, `>=` | Relational operators |

Parentheses `( )` can be used to override precedence.

### Relational Operators

| Operator | Description |
|----------|-------------|
| `=` | Equal |
| `<>` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

Relational operators compare two integer expressions and produce a boolean result (0 = false, 1 = true) used by control flow statements.

### Boolean Operators

| Operator | Description |
|----------|-------------|
| `and` | Logical AND (both operands must be non-zero) |
| `or` | Logical OR (at least one operand must be non-zero) |
| `not` | Logical NOT (zero becomes 1, non-zero becomes 0) |

Boolean operators work on integer values: any non-zero value is considered true, zero is false.

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

- No procedures or functions — planned for Milestone 4
- No `string` type — only string literals in write/writeln
- No arrays or records
- No `readln` / input
- No dedicated boolean type (integers are used: 0 = false, non-zero = true)
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
