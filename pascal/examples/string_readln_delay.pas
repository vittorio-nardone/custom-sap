{ Demo: string, readln(string), delay(ms). }
program StringReadlnDelay;
var
  a, b: string;
  i: integer;
begin
  writeln('--- string + readln + delay ---');
  a := 'Hello';
  b := a;
  write('b = ');
  writeln(b);
  write('length(a)=');
  writeln(length(a));
  if a = 'Hello' then writeln('ok: a = Hello')
  else writeln('unexpected');
  if a <> b then writeln('unexpected2');

  writeln;
  writeln('Type a word and press Enter:');
  readln(a);
  writeln('You typed:');
  writeln(a);
  write('length was ');
  writeln(length(a));

  writeln;
  writeln('Dots with delay(200) ms each:');
  for i := 1 to 10 do
  begin
    write('.');
    delay(200)
  end;
  writeln;
  writeln('Done.')
end.
