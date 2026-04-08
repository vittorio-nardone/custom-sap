{ Demo: vt100, vt100_pos, vt100_scroll, delay. }
program Vt100Demo;
begin
  vt100(0);
  vt100(1);
  writeln('VT100 demo (Otto Tiny Pascal)');

  { $0A = text reset, $0B = bold, $11 = foreground green }
  vt100($0A);
  vt100($0B);
  vt100($11);
  writeln('Green + bold line');

  vt100($0A);
  vt100($10);
  writeln('Red (normal weight)');

  { Cursore: vt100_pos(riga, colonna) }
  vt100($0A);
  vt100_pos(6, 4);
  writeln('At row 6, col 4');

  { Regione di scroll righe 10-20 (vedi VT100_SCROLL_SCREEN_REGION) }
  vt100($0A);
  vt100_scroll(10, 20);
  vt100_pos(12, 0);
  writeln('Scroll region 10-20');

  { Ripristino: scroll pieno schermo }
  vt100($1F);
  vt100($0A);
  vt100_pos(22, 0);
  writeln('Full-screen scroll restored.');

  { delay(): pochi ms }
  delay(2000);

  { Subcode table: see pascal/LANGUAGE.md }
  writeln;
  writeln('Subcodes: see LANGUAGE.md');
  writeln('Done.')
end.
