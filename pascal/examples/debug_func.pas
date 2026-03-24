program DebugFunc;

function double(x: integer): integer;
begin
  writeln('In double');
  double := x + x
end;

begin
  writeln('Before call');
  writeln(double(5));
  writeln('After call')
end.
