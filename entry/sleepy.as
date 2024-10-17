   bits 32
   push 0
   push 0
   push 0
   push 16
   mov ebx, esp
   sub ecx, ecx
   mov eax, 162
   int 0x80
d:
   jmp d
