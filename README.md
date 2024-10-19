# Core War '86

Two programs are loaded at random positions in memory and start
running at the same time. The last program still running wins.

# Requirements

- x86-64
- 4 GB available RAM
- Recent Linux kernel
- Root access
- `sysctl vm.mmap_min_addr=0`

# Setup

To run the local judge, do

```
$ sudo sysctl -w vm.mmap_min_addr=0
$ git clone https://github.com/ealf/x86war
...
$ make royale
...

   1 bytes @ 0xce4f4fca (pid 188043) entry/crash.bin
   2 bytes @ 0x339e4304 (pid 188044) entry/turtle.bin
   6 bytes @ 0xfd985c44 (pid 188045) entry/walker.bin
  14 bytes @ 0x210f73a2 (pid 188046) entry/wiper.bin
  38 bytes @ 0xcfbdb204 (pid 188048) entry/jumpy.bin

0 points: entry/crash.bin (Segmentation fault)
1 points: entry/turtle.bin (Trace/breakpoint trap)
2 points: entry/walker.bin (Trace/breakpoint trap)
4 points: entry/wiper.bin (Survived)
4 points: entry/jumpy.bin (Survived)

$ echo $'bits 32 \n x: jmp x' > entry/hang.as
$ make run-hang-hang-crash
...

    2 bytes @ 0x3c3b952a (pid 1557021) entry/hang.bin
    2 bytes @ 0x868aeb6b (pid 1557022) entry/hang.bin
    1 bytes @ 0xdd2c0f51 (pid 1557023) entry/crash.bin

0 points: entry/crash.bin (Segmentation fault)
2 points: entry/hang.bin (Survived)
2 points: entry/hang.bin (Survived)

```

No eye candy.

# Environment

Everything runs in 32-bit mode, with the entire address space
from `00000000` to `ffffffff` mapped writable and executable.

Each program loads at a random address, and receives that address in
`edi`, `esi`, `edi`, `esp` and `ebp`. And, uh, `eip`.

# Examples

The samples use [NASM](https://www.nasm.us/), but anything that can output a raw binary will do.

## crash

The first program to execute an illegal instruction loses. The battle is in user-land, so HLT is illegal.

```asm
                           bits 32
            F4             hlt
```

## duck
 
This is the simplest program that doesn't immediately lose, although it doesn't exactly *win* either.

```asm
                            bits 32
                        
                        start:
          EBFE  (a)         jmp start 
```

`(a)`: Since the jump is relative (`eb` is jmp, `fe` is -2), this program loops indefinitely, regardless of its memory location.

## walker

This program copies itself forward in memory. 

```asm
                           bits 32
                           
                        start:
        83C706  (b)        add edi, (after - start) 
          B0AA             mov al, 0xAA  ; stosb
            AA  (a)        stosb 
                        after:
```

- `(a)`: This instruction stores another `stosb` at `after`, then increases `edi`, ready to write another one. Like a slug on a clean floor, this will leave behind a trail of `movsb`ses.

- `(b)`: At startup, `edi` points to the first byte of the program (`start` here).

   - We can't use `mov edi, offset after` (that would need relocation support).
   
   - And we can't use `lea rdi, [rip+...]` (which is nice, but only encodable in 64-bit).

## wiper

This program attempts to overwrite all memory (except itself) with instructions that will cause a crash.

```asm
                          bits 32
                          
                        start:
          B0F1  (b)       mov al, 0xF1 
        83C70E  (c)       add edi, (end - start) 
    B9F2FFFFFF  (d)       mov ecx, (start - end) 
          F3AA  (a)       rep stosb 
          EBF2  (e)       jmp start 
                        end:
```

- `(a)`: `rep stosb` writes `ecx` copies of `al` (which contains `f1`, the `int1` instruction) to position `edi`.

   - `(b)`: `int1` kills the victim with a SIGTRAP rather than the normal SEGV. This can be used as a crude way to figure out who killed whom if you have multiple players.

   - `(c)`: `edi` points to `end`. Again with the manual offset calculation.

   - `(d)`: Since `start` is before `end`, the value for `ecx`, being unsigned (or treated as such by `rep`), will wrap and we'll write four gigabytes less the size of this program.

- `(e)`: If we survived this far, `jmp start` does it again. `edi` wrapped around, so it should be ready to go again.

## jumpy

`wiper` is hard to beat. This one tries to detect an approaching linear wipe and move out of the way.

```asm
                        
                           bits 32
                        start:
  81EF400D0300             sub edi, 200000
  8987C0F2FCFF             mov [edi-200000], eax  ; prefault
          8907             mov [edi], eax
                        _wait:
          3907             cmp [edi], eax
          74FC             jz _wait
  81EF400D0300             sub edi, 200000
    B926000000             mov ecx, end-start
          F3A4             rep movsb
        83EF26             sub edi, end-start
          89FE             mov esi, edi
          FFE7             jmp edi
                        end:
                        
```


## empty

I lied about `turtle` being the simplest program. This is a valid program and the permanent winner of the 'points per byte' category.

```asm
                        
                        
```

The arena is zero-filled. `00 00` decodes to `add [eax],al`.

`eax` points to the first byte of the program, or in this case, where
it would have been. `al`, being the lower bits of the load position,
will have a random value. Thus the first byte of the program will be
changed to a random opcode. This is fine: execution will have moved
on. If there's no one else in the address space, when the processor
returns, after doing 2,147,483,648 additions, the byte will *just*
have returned to 0, ready for the next round.

If there *is* another competitor, `empty` will start executing their
code. With a bit of luck this may corrupt the other program, and it
*might* crash first.

