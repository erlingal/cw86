CFLAGS=-Wall -Werror

.PHONY: t

DEF = -D'MAP_BASE=0x0' -D'MAP_SIZE=(0x100000000-MAP_BASE)'

DEF += -D'MAX_TIME=4'

SOURCES = $(wildcard samples/*.as)
BINS = $(SOURCES:.as=.bin)

all: battle boot.elf $(BINS)

royale: all
	./battle $(BINS)

one-%: samples/%.bin battle boot.elf
	./battle $<
two-%: samples/%.bin battle boot.elf
	./battle $< $<
run-%: all
	./battle $(patsubst %,samples/%.bin,$(subst -, ,$*))

battle: battle.c boot.elf Makefile 
	${CC} ${CFLAGS} ${DEF} $< -o $@

boot.elf: boot.as Makefile
	nasm ${DEF} -f elf64 $< -o boot.o
	ld --section-start=.text=0x100000000 boot.o -o $@
	chmod 755 $@

%.bin: %.as
	nasm ${DEF} $< -o $@

debug-%: samples/%.bin battle boot.elf
	DEBUG=1 ./battle $<
gdb-%:
	gdb -p $* -ex 'set arch i386' -ex 'p $$eip += 2'
clean:
	rm *.o boot.elf battle test
