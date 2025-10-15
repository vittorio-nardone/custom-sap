: FATTORIALE ( n -- n! )
   DUP 0= IF          \ Se n è 0,
      DROP 1          \ il fattoriale è 1.
   ELSE               \ Altrimenti,
      DUP 1-          \ duplica n e calcola n-1.
      FATTORIALE         \ Calcola ricorsivamente il fattoriale di n-1.
      * \ Moltiplica n per (n-1)!.
   THEN ;



   10 0 do i 5 > if i . then cr loop

: RECTANGLE  128 0 DO   I 16 MOD 0= IF  CR  THEN                           ." *"                    LOOP ;