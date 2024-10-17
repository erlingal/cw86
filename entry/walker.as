   bits 32
   
start:
   add edi, (after - start) ; (b)
   mov al, 0xAA  ; stosb
   stosb ; (a)
after:
