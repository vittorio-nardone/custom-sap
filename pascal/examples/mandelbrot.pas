{ Mandelbrot set renderer in ASCII art.
  Each pixel (px, py) maps to a point c = (cx, cy) on the complex plane.
  Starting from z = 0, iterate z := z^2 + c until |z|^2 > 4 (escape)
  or maxiter is reached (inside the set). The iteration count determines
  which ASCII character to print, producing a density gradient. }

program Mandelbrot;
var
  chars: array[0..9] of integer;
  px, py, iter, maxiter: integer;
  w, h, choice, ci: integer;
  cx, cy, zx, zy, zxsq, zysq: real;
  xmin, xstep, ymin, ystep, tmp: real;

begin
  { 10-level density gradient from sparse to dense: ' .:-=+*#%@' }
  chars[0] := 32;  chars[1] := 46;  chars[2] := 58;
  chars[3] := 45;  chars[4] := 61;  chars[5] := 43;
  chars[6] := 42;  chars[7] := 35;  chars[8] := 37;
  chars[9] := 64;

  maxiter := 30;
  { visible region: x in [-2.0, 1.0], y centered at 0 }
  xmin := -2.0;

  writeln('Mandelbrot ASCII Art');
  writeln('--------------------');
  writeln('1) 40x20  (fast)');
  writeln('2) 60x24  (medium)');
  writeln('3) 80x24  (large)');
  write('Choice: ');
  readln(choice);
  writeln;

  if choice = 2 then
  begin
    w := 60;
    h := 24
  end
  else if choice = 3 then
  begin
    w := 80;
    h := 24
  end
  else
  begin
    w := 40;
    h := 20
  end;

  { x spans 3.0 units (-2..1); ystep is 2x xstep to correct for
    terminal characters being roughly twice as tall as wide }
  xstep := 3.0 / w;
  ystep := xstep * 2.0;
  ymin := 0.0 - (h / 2.0) * ystep;

  for py := 0 to h - 1 do
  begin
    cy := ymin + py * ystep;
    for px := 0 to w - 1 do
    begin
      cx := xmin + px * xstep;
      zx := 0.0;
      zy := 0.0;
      zxsq := 0.0;
      zysq := 0.0;
      iter := 0;

      { z = zx + zy*i; iterate z := z^2 + c where:
        Re(z^2+c) = zx^2 - zy^2 + cx
        Im(z^2+c) = 2*zx*zy + cy
        zxsq/zysq are cached to avoid recomputing in the loop condition }
      while (iter < maxiter) and (zxsq + zysq < 4.0) do
      begin
        tmp := zxsq - zysq + cx;
        zy := 2.0 * zx * zy + cy;
        zx := tmp;
        zxsq := zx * zx;
        zysq := zy * zy;
        iter := iter + 1
      end;

      { points inside the set (never escaped) render as space;
        escaped points use iteration count mod 10 as gradient index }
      if iter = maxiter then
        write(chr(32))
      else
      begin
        ci := iter mod 10;
        write(chr(chars[ci]))
      end
    end;
    writeln
  end
end.
