program FloatFunc;
var
  x: real;

function double(v: real): real;
begin
  double := v * 2.0
end;

function add_ints(a, b: integer): real;
begin
  add_ints := a + b
end;

function circle_area(r: real): real;
begin
  circle_area := 3.14159 * r * r
end;

begin
  x := 3.5;
  writeln(double(x));
  writeln(double(1.25));
  writeln(add_ints(3, 7));
  writeln(circle_area(5.0));

  { Real to int coercion }
  x := 7.9;
  write('trunc: ');
  writeln(x div 1);

  { Comparison }
  if double(x) > 15.0 then
    writeln('double > 15')
  else
    writeln('double <= 15')
end.
