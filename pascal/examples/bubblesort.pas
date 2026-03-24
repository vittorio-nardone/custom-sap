program BubbleSort;
var
  data: array[1..10] of integer;
  i, j, n, temp: integer;

begin
  n := 10;

  { Initialize with descending values }
  for i := 1 to n do
    data[i] := n - i + 1;

  { Print unsorted }
  write('Before: ');
  for i := 1 to n do
  begin
    write(data[i]);
    write(' ')
  end;
  writeln;

  { Bubble sort }
  for i := 1 to n - 1 do
    for j := 1 to n - i do
      if data[j] > data[j + 1] then
      begin
        temp := data[j];
        data[j] := data[j + 1];
        data[j + 1] := temp
      end;

  { Print sorted }
  write('After:  ');
  for i := 1 to n do
  begin
    write(data[i]);
    write(' ')
  end;
  writeln
end.
