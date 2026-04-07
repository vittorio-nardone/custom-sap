{ Demo: procedure built-in vt100, vt100_pos, vt100_scroll (+ delay).
  Richiede terminale seriale che interpreti le sequenze VT100 del kernel.
  Compilazione: python pascal_compiler.py pascal/examples/vt100_demo.pas -o roms/apps/pascal/vt100_demo.bin
  Simulatore:  python simulate.py --autorun --program roms/apps/pascal/vt100_demo.bin --max-cycles 12000000 --quiet
  Su hardware reale puoi inserire piu' delay(ms) tra le sezioni per rallentare. }
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

  { Cursore: argomenti vt100_pos(riga, colonna) come in kernel VT100_CURSOR_POSITION }
  vt100($0A);
  vt100_pos(6, 4);
  writeln('At row 6, col 4');

  { Regione di scroll righe 10-20 (vedi VT100_SCROLL_SCREEN_REGION) }
  vt100($0A);
  vt100_scroll(10, 20);
  vt100_pos(12, 0);
  writeln('Scroll region 10-20; this line inside region.');

  { Ripristino: scroll pieno schermo }
  vt100($1F);
  vt100($0A);
  vt100_pos(22, 0);
  writeln('Full-screen scroll restored.');

  { delay(): pochi ms; su simulatore Python costa molti cicli — opzionale }
  delay(2000);

  { Tabella subcodici: vedi pascal/LANGUAGE.md e .csp_vt100 in pmachine.asm }
  writeln;
  writeln('Subcode examples (hex):');
  writeln('$00 erase  $01 home  $03-06 arrows');
  writeln('$0A reset  $0B bold  $0F-$16 FG colors');
  writeln('$17-$1E BG colors  $1F scroll full');
  writeln('$20 scroll region + vt100_scroll(top,bot)');
  writeln('Done.')
end.
