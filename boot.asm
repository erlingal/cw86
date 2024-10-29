bits 64

_start:

; alarm() so we die even if the runner fails.
 
         mov rdi, (MAX_TIME+2)
         mov rax, 37   ; SYS_alarm
         syscall

; Get the offset from argv[1]

         pop rax    ; argc
         pop rsi    ; argv[1]
         mov rcx, 10
         xor rax, rax
         xor r8, r8
digit:
         lodsb
         sub al, 48
         jb done
         lea r8, [r8*4 + r8]
         lea r8, [r8*2 + rax]
         jmp digit
done:    push r8


; Start mapping from MAP_BASE, in chunks of MAP_SIZE, until we wrap

         mov rdi, MAP_BASE
loop:
         mov rsi, MAP_SIZE
         mov rdx, 0x7   ; PROT_READ | PROT_WRITE | PROT_EXEC
         mov r10, 0x11  ; MAP_SHARED | MAP_FIXED
         mov r8,  42    ; fd
         mov r9,  0     ; offset
         mov rax, 9     ; SYS_mmap
         syscall
         
         cmp rax, rdi
         jnz bad

         add rdi, rsi
         mov rax, rdi
         shr rax, 32
         jz loop

; close(42)

         mov rdi,  42    ; fd
         mov rax,  3     ; close
         syscall
         
; Enable seccomp. No more syscalls for us.

         mov rdi, 22  ; PR_SET_SECCOMP
         mov rsi, 1   ; SECCOMP_MODE_STRICT
         mov rax, 157 ; SYS_prctl
         syscall
         test rax, rax
         jnz bad

; Segment registers

         mov ax, 0x2b
         mov ds, ax
         mov es, ax
         mov fs, ax
         mov gs, ax
         mov ss, ax

         pop rax

; Clean up registers

         mov r15, rsp
         
         mov rcx, rax
         mov rdx, rax
         mov rbx, rax
         mov rsp, rax
         mov rbp, rax
         mov rsi, rax
         mov rdi, rax
         mov r8, rax
         mov r9, rax
         mov r10, rax
         mov r11, rax
         mov r12, rax
         mov r13, rax
         mov r14, rax

; Set up far jump to switch to 32-bit mode

         mov qword [r15], rdi
         mov word [r15+8], 0x23

; Wait for the start signal

         mov rbx, qword [0]
         lock inc qword [0+8]
         
waiting: cmp qword [0], rbx
         jz waiting
         
         mov rbx, rax
         
         jmp far [r15]

bad:     mov rax, 60  ; SYS_exit
         mov rdi, 1
         syscall
