  bits 32
  std
start:
  lea edi, [ebx-7]
  mov ecx, 0x3FFFFFF0
  mov eax, 0xf1f1f1f1
  rep stosd
  jmp start
end: