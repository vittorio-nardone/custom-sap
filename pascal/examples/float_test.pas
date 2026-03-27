program FloatTest;
var
  a, b: real;
  c: integer;
begin
  a := 3.14;
  b := 2.0;
  writeln(a);
  writeln(b);
  writeln(a + b);
  writeln(a - b);
  writeln(a * b);
  writeln(a / b);

  { Integer to real coercion }
  c := 10;
  writeln(a + c);
  writeln(c);

  { Comparisons }
  if a > b then
    writeln('a > b')
  else
    writeln('a <= b');

  { abs }
  a := -5.5;
  writeln(abs(a));

  { Mixed function }
  writeln(a * 2)
end.
