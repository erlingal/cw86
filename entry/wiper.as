  bits 32
  
start:
  mov al, 0xF1 ; (b)
  add edi, (end - start) ; (c)
  mov ecx, (start - end + MAP_SIZE) ; (d)
  rep stosb ; (a)
  jmp start ; (e)
end:
