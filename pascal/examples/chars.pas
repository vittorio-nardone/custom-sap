program Chars;
var i: integer;
begin
  { Print alphabet using chr }
  for i := 65 to 90 do
    write(chr(i));
  writeln;

  { Test ord }
  writeln(ord('A'));
  writeln(ord('Z'));

  { Print digits }
  for i := 48 to 57 do
    write(chr(i));
  writeln
end.
