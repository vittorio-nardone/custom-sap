{ Regression: Python + IDE (lo). See AGENTS.md (TinyPascal regression suite).
  Lines <= 79 chars; ~255 max. }
program TinyPascalSuite;
const
  C = 10;
var
  i, j, k: integer;
  x: real;
  s, t: string;
  a: array[1..4] of integer;
procedure hello;
begin
  writeln('proc_ok');
end;
function incn(n: integer): integer;
begin
  incn := n + 1;
end;
function twice(r: real): real;
begin
  twice := r * 2.0;
end;
begin
  writeln('--- suite ---');
  writeln(C);
  writeln(incn(C));
  x := 2.5;
  writeln(twice(x));
  writeln(twice(1.25));
  hello;
  s := 'ab';
  t := s;
  writeln(length(s));
  if s = 'ab' then writeln('str_eq') else writeln('str_bad');
  for i := 1 to 4 do
    a[i] := i * 2;
  j := 0;
  for i := 1 to 4 do
    j := j + a[i];
  writeln(j);
  i := 0;
  while i < 3 do
  begin
    i := i + 1;
    k := i;
  end;
  writeln(k);
  if not (i = 0) then writeln('not_ok');
  writeln('--- done ---');
end.
