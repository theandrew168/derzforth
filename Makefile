.POSIX:
.SUFFIXES:

default: build

.PHONY: build
build: derzforth.asm
	bronzebeard derzforth.asm -o derzforth.bin

.PHONY: program
program: build
	python3 -m bronzebeard.dfu 28e9:0189 derzforth.bin

.PHONY: clean
clean:
	rm -fr derzforth.bin
