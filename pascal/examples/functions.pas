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
