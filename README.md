# DerzForth
Bare-metal Forth implementation for RISC-V RV32I core.

## About
Forth was initially designed and created by [Charles Moore](https://en.wikipedia.org/wiki/Charles_H._Moore).
Many folks have adapted its ideas and principles to solve their own problems.
[Moving Forth](http://www.bradrodriguez.com/papers/moving1.htm) by Brad Rodriguez is an amazing source of Forth implementation details and tradeoffs.
If you are looking for some introductory content surrounding the Forth language in general, I recommend the book [Starting Forth](https://www.forth.com/starting-forth/) by Leo Brodie.

This implementation's general structure is based on [Sectorforth](https://github.com/cesarblum/sectorforth) by Cesar Blum.
He took inspiration from a [1996 Usenet thread](https://groups.google.com/g/comp.lang.forth/c/NS2icrCj1jQ/m/ohh9v4KphygJ) wherein folks discussed requirements for a minimal yet fully functional Forth implementation.

## Requirements
The hardware requirements for running DerzForth are minimal and straightforward:
* At least 16KB of RAM (define `RAM_BASE_ADDR` and `RAM_SIZE`)
* At least 16KB of ROM (define `ROM_BASE_ADDR` and `ROM_SIZE`)
* Serial UART (implement `serial_init`, `serial_getc`, and `serial_putc`)

DerzForth has been tested on the following RISC-V development boards:
* [Longan Nano](https://www.seeedstudio.com/Sipeed-Longan-Nano-RISC-V-GD32VF103CBT6-DEV-Board-p-4725.html)
* [Longan Nano Lite](https://docs.platformio.org/en/latest/boards/gd32v/sipeed-longan-nano-lite.html)
* [Wio Lite](https://www.seeedstudio.com/Wio-Lite-RISC-V-GD32VF103-p-4293.html)
* [GD32 Dev Board](https://www.seeedstudio.com/SeeedStudio-GD32-RISC-V-kit-with-LCD-p-4303.html)
* [HiFive1 Rev B](https://www.sifive.com/boards/hifive1-rev-b)

## Setup
If you are unfamiliar with [virtual environments](https://docs.python.org/3/library/venv.html), I suggest taking a brief moment to learn about them and set one up.
The Python docs provide a great [tutorial](https://docs.python.org/3/tutorial/venv.html) for getting started with virtual environments and packages.

DerzForth is an assembly program based on the [Bronzebeard](https://github.com/theandrew168/bronzebeard) project.
Consult Bronzebeard's project page for how to get it all setup (it's pretty easy and works on all major platforms).

Bronzebeard (and a few other tools) can be installed via pip:
```
pip install -r requirements.txt
```

### Boards
Some boards require a USB to UART cable in order to program and/or interact.
I recommend the [CP2012](https://www.amazon.com/HiLetgo-CP2102-Converter-Adapter-Downloader/dp/B00LODGRV8).

#### Longan Nano [Lite]
For this board, the only setup necessary is a USB to UART cable.

* Attach TX to pin R0 (PA10)
* Attach RX to pin T0 (PA9)
* Attach GND to pin GND
* Attach 3.3V to pin 3V3 (be sure not to supply 5V to 3.3V or vice versa)

#### Wio Lite
For this board, the only setup necessary is a USB to UART cable.

* Attach TX to pin PA10
* Attach RX to pin PA9
* Attach GND to GND
* Attach 3.3V to 3V3 (be sure not to supply 5V to 3.3V or vice versa)

#### GD32 Dev Board
For this board, the only setup necessary is a USB to UART cable.

* Attach TX to pin RXD (PA10)
* Attach RX to pin TXD (PA9)
* Attach GND to GND
* Attach 3.3V to 3V3 (be sure not to supply 5V to 3.3V or vice versa)

#### HiFive1 Rev B
Programming this board requires [Segger's J-Link software](https://www.segger.com/downloads/jlink/#J-LinkSoftwareAndDocumentationPack).
These tools work on all major platforms but depend on [Java](https://openjdk.java.net/install/).

As far as cables go, just a single USB to Micro-USB cable is necessary.

* Plug the Micro-USB cable into the Micro-USB port

## Build
With Bronzebeard installed:
```
bronzebeard -c -i boards/<target_board>/ --include-definitions derzforth.asm
```

## Program
Some boards share a common method of programming and interacting.

### GD32VF103 Boards
Enable boot mode on your given device:
* **Longan Nano** - press BOOT, press RESET, release RESET, release BOOT
* **Wio Lite** - flip BOOT switch to 1, press and release RESET
* **GD32 Dev Board** - swap BOOT0 jumper to 3V3, press and release RESET, swap BOOT0 jumper to GND

To get a list of available serial ports, run the following command:
```
python3 -m serial.tools.list_ports
```

Then, program the device over serial UART:
```
stm32loader -p <device_port> -ewv bb.out
```

Here are some examples:
```
# Windows
stm32loader -p COM3 -ewv bb.out
# macOS
stm32loader -p /dev/cu.usbserial-0001 -ewv bb.out
# Linux
stm32loader -p /dev/ttyUSB0 -ewv bb.out
```

### FE310-G002 Boards
After converting the output binary to [Intel HEX](https://en.wikipedia.org/wiki/Intel_HEX) format, Segger J-Link handles the rest:
```
bin2hex.py --offset 0x20010000 bb.out bb.hex
JLinkExe -device FE310 -if JTAG -speed 4000 -jtagconf -1,-1 -autoconnect 1 scripts/hifive1_rev_b.jlink
```

## Execute

### GD32VF103 Boards
After programming, put the device back into normal mode:
* **Longan Nano** - press and release RESET
* **Wio Lite** - flip BOOT switch to 0, press and release RESET
* **GD32 Dev Board** - TODO how does this board work?

### FE310-G002 Boards
The J-Link command from the previous step will automatically reset the chip after programming!

## Interact
To interact with the device, the same port as above can used with [pySerial's builtin terminal](https://pyserial.readthedocs.io/en/latest/tools.html#module-serial.tools.miniterm):
```
python3 -m serial.tools.miniterm <device_port> 115200
```

Here are some examples:
```
# Windows
python3 -m serial.tools.miniterm COM3 115200
# macOS
python3 -m serial.tools.miniterm /dev/cu.usbserial-0001 115200
# macOS (J-Link Serial over USB)
python3 -m serial.tools.miniterm /dev/cu.usbmodem0009790147671 115200
# Linux
python3 -m serial.tools.miniterm /dev/ttyUSB0 115200
```

## Primitive Words
This minimal selection of primitive words is used to bootstrap the Forth system.

| Word   | Stack Effects | Description                                   |
| ------ | ------------- | --------------------------------------------- |
| `:`    | ( -- )        | Start the definition of a new secondary word  |
| `;`    | ( -- )        | Finish the definition of a new secondary word |
| `@`    | ( addr -- x ) | Fetch memory contents at addr                 |
| `!`    | ( x addr -- ) | Store x at addr                               |
| `sp@`  | ( -- sp )     | Get pointer to top of data stack              |
| `rp@`  | ( -- rp )     | Get pointer to top of return stack            |
| `0=`   | ( x -- flag ) | -1 if top of stack is 0, 0 otherwise          |
| `+`    | ( x y -- z )  | Sum the two numbers at the top of the stack   |
| `nand` | ( x y -- z )  | NAND the two numbers at the top of the stack  |
| `key`  | ( -- x )      | Read ASCII character from serial input        |
| `emit` | ( x -- )      | Write ASCII character to serial output        |
