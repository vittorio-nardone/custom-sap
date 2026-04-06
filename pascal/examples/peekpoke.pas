program PeekPoke;
var val: integer;
begin
  { Page 0, RAM address $8100 }
  poke(0, $8100, 42);
  val := peek(0, $8100);
  write('peek $8100 -> ');
  writeln(val);

  poke(0, $8101, 99);
  write('peek $8101 -> ');
  writeln(peek(0, $8101));

  poke(0, $8102, peek(0, $8100) + peek(0, $8101));
  write('peek $8102 (42+99) -> ');
  writeln(peek(0, $8102));

  { Expansion RAM page 1 ($010000) }
  poke(1, $0000, 77);
  write('page 1 $0000 -> ');
  writeln(peek(1, $0000));

  { Expansion RAM page 2 ($020000) }
  poke(2, $0000, 88);
  write('page 2 $0000 -> ');
  writeln(peek(2, $0000));

  { Verify page 1 not overwritten }
  write('page 1 still -> ');
  writeln(peek(1, $0000))
end.
