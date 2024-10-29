CFLAGS=-Wall -Werror

.PHONY: royale all

DEF = -D'MAP_BASE=0x0' -D'MAP_SIZE=0x100000000' -D'MAX_TIME=5'

SOURCES = $(wildcard entry/*.asm)

BINS = $(SOURCES:.asm=.bin)

all: battle boot.elf $(BINS)

royale: all
	./battle $(BINS)

one-%: entry/%.bin battle boot.elf
	./battle $<
two-%: entry/%.bin battle boot.elf
	./battle $< $<
run-%: all
	./battle $(patsubst %,entry/%.bin,$(subst -, ,$*))

battle: battle.c boot.elf Makefile 
	${CC} ${CFLAGS} ${DEF} $< -o $@

boot.elf: boot.asm Makefile
	nasm ${DEF} -f elf64 $< -o boot.o
	ld --section-start=.text=0x100000000 boot.o -o $@
	chmod 755 $@

%.bin: %.asm
	nasm ${DEF} $< -o $@

debug-%: entry/%.bin battle boot.elf
	DEBUG=1 ./battle $<

gdb-%:
	gdb -p $* -ex 'set arch i386' -ex 'p $$eip += 2'

clean:
	rm -f *.o boot.elf battle test
