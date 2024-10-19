CFLAGS=-Wall -Werror
.PHONY: help
help:

# note that map_base + k*map_size must be 4G, otherwise the loader will crash

# DEF = -D'MAP_BASE=0x0' -D'MAP_SIZE=(0x100000000-MAP_BASE)'
# DEF += -D'MAX_TIME=5'

DEF = -D'MAP_BASE=0x0' -D'MAP_SIZE=0x10000000'
DEF += -D'MAX_TIME=1'

SOURCES = $(wildcard entry/*.as)
BINS = $(SOURCES:.as=.bin)

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

boot.elf: boot.as Makefile
	nasm ${DEF} -f elf64 $< -o boot.o
	ld --section-start=.text=0x100000000 boot.o -o $@
	chmod 755 $@

boot.bin: boot.elf
	objcopy -j .text -O binary $^ $@

%.bin: %.as
	nasm ${DEF} $< -o $@

debug-%: entry/%.bin battle boot.elf
	DEBUG=1 ./battle $<
gdb-%:
	gdb -p $* -ex 'set arch i386' -ex 'p $$eip += 2'
clean:
	rm -f *.o boot.elf battle test
