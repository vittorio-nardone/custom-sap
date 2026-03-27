program VarParams;
var a, b: integer;

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

begin
  a := 10;
  b := 20;
  writeln(a);
  writeln(b);
  swap(a, b);
  writeln(a);
  writeln(b);
  inc_by(a, 5);
  writeln(a);
  inc_by(b, 100);
  writeln(b)
end.
