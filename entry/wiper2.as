  bits 32
start:
  add edi, 0x40
  mov ecx, 0x3FFFFFF0
  mov eax, 0xf1f1f1f1
  rep stosd
  jmp start
end: