   bits 32
start:
   and edi, 0xffffff00
   mov eax, 0xABCCCC80  ;; ignore two; crash; crash; stosd
   push edi
   stosd
   ret
next:
