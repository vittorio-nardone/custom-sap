{ Demo: tipo string, readln su stringa, delay (busy-wait ms).
  Compilazione: python pascal_compiler.py pascal/examples/string_readln_delay.pas -o roms/apps/pascal/string_readln_delay.bin
  Simulatore:  python simulate.py --autorun --program roms/apps/pascal/string_readln_delay.bin --max-cycles 8000000 --quiet --input "Otto\r"
  (readln non fa echo su seriale: il terminale puo' avere "local echo" attivo.) }
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
