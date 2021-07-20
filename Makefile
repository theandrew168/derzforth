.POSIX:
.SUFFIXES:

default: build_longan_nano


.PHONY: build_longan_nano
build_longan_nano: derzforth.asm
	bronzebeard -c -i boards/longan_nano/ --include-definitions derzforth.asm

.PHONY: build_wio_lite
build_wio_lite: derzforth.asm
	bronzebeard -c -i boards/wio_lite/ --include-definitions derzforth.asm

.PHONY: build_gd32_dev_board
build_gd32_dev_board: derzforth.asm
	bronzebeard -c -i boards/gd32_dev_board/ --include-definitions derzforth.asm

.PHONY: build_hifive1_rev_b
build_hifive1_rev_b: derzforth.asm
	bronzebeard -c -i boards/hifive1_rev_b/ --include-definitions derzforth.asm


.PHONY: program_dfu
program_dfu:
	python3 -m bronzebeard.dfu 28e9:0189 bb.out

.PHONY: program_stm32
program_stm32:
	stm32loader -p /dev/cu.usbserial-0001 -ewv bb.out

.PHONY: program_hifive1_rev_b
program_hifive1_rev_b:
	bin2hex.py --offset 0x20010000 bb.out bb.hex
	JLinkExe -device FE310 -if JTAG -speed 4000 -jtagconf -1,-1 -autoconnect 1 scripts/hifive1_rev_b.jlink


.PHONY: serial_windows
serial_windows:
	python3 -m serial.tools.miniterm COM3 115200

.PHONY: serial_macos
serial_macos:
	python3 -m serial.tools.miniterm /dev/cu.usbserial-0001 115200

.PHONY: serial_macos_hifive1_rev_b
serial_macos_hifive1_rev_b:
	python3 -m serial.tools.miniterm /dev/cu.usbmodem0009790147671 115200

.PHONY: serial_linux
serial_linux:
	python3 -m serial.tools.miniterm /dev/ttyUSB0 115200


.PHONY: clean
clean:
	rm -fr *.bin *.hex *.out
