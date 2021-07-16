.POSIX:
.SUFFIXES:

default: build

.PHONY: build
build: derzforth.asm
	bronzebeard -c --include-chips derzforth.asm

.PHONY: build_verbose
build_verbose: derzforth.asm
	bronzebeard -cv --include-chips derzforth.asm

.PHONY: program_dfu
program_dfu: build
	python3 -m bronzebeard.dfu 28e9:0189 bb.out

.PHONY: program_stm32
program_stm32: build
	stm32loader -p /dev/cu.usbserial-0001 -ewv bb.out

.PHONY: serial_windows
serial_windows:
	python3 -m serial.tools.miniterm COM3 115200

.PHONY: serial_macos
serial_macos:
	python3 -m serial.tools.miniterm /dev/cu.usbserial-0001 115200

.PHONY: serial_linux
serial_linux:
	python3 -m serial.tools.miniterm /dev/ttyUSB0 115200

.PHONY: clean
clean:
	rm -fr *.out
