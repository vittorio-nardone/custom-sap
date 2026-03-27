program Constants;
const
  maxsize = 5;
  minval = -10;
  offset = 100;
var
  data: array[1..maxsize] of integer;
  i, n: integer;
begin
  for i := 1 to maxsize do
    data[i] := i * offset + minval;

  for i := 1 to maxsize do
    writeln(data[i]);

  writeln(maxsize);
  writeln(minval);
  writeln(offset);

  { Test repeat..until }
  n := 3;
  repeat
    writeln(n);
    n := n - 1
  until n = 0
end.
