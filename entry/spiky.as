   bits 32
start:
   add edi, next-start
   mov eax, 0xABCCCC80  ;; ignore two; crash; crash; stosd
   stosd
next:
