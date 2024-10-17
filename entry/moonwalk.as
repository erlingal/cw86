      bits 32
a_0:  pop eax
a_1:  pop eax
a_2:  push eax
a_3:  db 0x38    ;; skip the HLT
b_0:  hlt
b_1:  push eax
b_23: jmp a_1
