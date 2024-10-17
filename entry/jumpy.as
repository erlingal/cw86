
   bits 32
start:
   sub edi, 200000
   mov [edi-200000], eax  ; prefault
   mov [edi], eax
_wait:
   cmp [edi], eax
   jz _wait
   sub edi, 200000
   mov ecx, end-start
   rep movsb
   sub edi, end-start
   mov esi, edi
   jmp edi
end:

