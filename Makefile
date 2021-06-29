.POSIX:
.SUFFIXES:

default: build

.PHONY: build
build: derzforth.asm
	bronzebeard derzforth.asm -c -o derzforth.bin

.PHONY: program
program: build
	python3 -m bronzebeard.dfu 28e9:0189 derzforth.bin

.PHONY: serial
serial:
	python3 -m serial.tools.miniterm /dev/ttyUSB0 115200

.PHONY: clean
clean:
	rm -fr derzforth.bin
