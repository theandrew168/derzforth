# DerzForth
Bare-metal Forth implementation for RISC-V

## About
Forth was initially designed and created by [Charles Moore](https://en.wikipedia.org/wiki/Charles_H._Moore).
Many folks have adapted its ideas and principles to solve their own problems.
[Moving Forth](http://www.bradrodriguez.com/papers/moving1.htm) by Brad Rodriguez is an amazing source of Forth implementation details and tradeoffs.
If you are looking for some introductory content surrounding the Forth language in general, I recommend the book [Starting Forth](https://www.forth.com/starting-forth/) by Leo Brodie.

This implementation's general structure is based on [Sectorforth](https://github.com/cesarblum/sectorforth) by Cesar Blum.
He took inspiration from a [1996 Usenet thread](https://groups.google.com/g/comp.lang.forth/c/NS2icrCj1jQ/m/ohh9v4KphygJ) wherein folks discussed requirements for a minimal yet fully functional Forth implementation.

## Requirements
The hardware requirements for running DerzForth are very minimal and straightforward:
* 16k RAM (and RAM_BASE_ADDR)
* 64k ROM (and ROM_BASE_ADDR)
* Serial UART (optional, but necessary for interaction)

DerzForth has been tested on the following devices:
* [Longan Nano](https://www.seeedstudio.com/Sipeed-Longan-Nano-RISC-V-GD32VF103CBT6-DEV-Board-p-4725.html)
* [Wio Lite](https://www.seeedstudio.com/Wio-Lite-RISC-V-GD32VF103-p-4293.html)

## Setup
If you are unfamiliar with [virtual environments](https://docs.python.org/3/library/venv.html), I suggest taking a brief moment to learn about them and set one up.
The Python docs provide a great [tutorial](https://docs.python.org/3/tutorial/venv.html) for getting started with virtual environments and packages.

DerzForth is an assembly program based on the [Bronzebeard](https://github.com/theandrew168/bronzebeard) project.
Consult Bronzebeard's project page for how to get it all setup (it's pretty easy and works on all major platforms).

Bronzebeard can be installed via pip:
```
pip install bronzebeard
```

### Cables
#### Longan Nano / Wio Lite
1. Attach the USB to USB-C cable for programming via DFU
2. Attach the USB to TTL Serial cable for serial interaction ([adafruit](https://www.adafruit.com/product/954), [sparkfun](https://www.sparkfun.com/products/12977))
    * Attach GND to GND
    * Attach TX to RX
    * Attach RX to TX
    * Don't attach VCC (or jump to a 5V input if you want power via this cable)

## Build
With Bronzebeard installed:
```
# Longan Nano / Wio Lite (GD32VF103CBT6)
python3 -m bronzebeard.asm derzforth.asm derzforth.bin
```

## Program
Enable DFU mode on your given device:
* **Longan Nano** - press BOOT, press RESET, release RESET, release BOOT
* **Wio Lite** - set BOOT switch to 1, press and release RESET

```
python3 -m bronzebeard.dfu 28e9:0189 derzforth.bin
```

## Execute
After programming, put the device back into normal mode:
* **Longan Nano** - press and release RESET
* **Wio Lite** - set BOOT switch to 0, press and release RESET

## Interact
Since DerzForth includes serial interaction via UART, we can use [pySerial's](https://pyserial.readthedocs.io/en/latest/index.html) built-in terminal to communiate with the device.

To get a list of available serial ports, run the following command:
```
python3 -m serial.tools.list_ports
```

One of them should be the device we want to communicate with.
You can specify the device port in the following command in order to initiate the connection.
```
python3 -m serial.tools.miniterm <device_port> 115200
```

Here are a few potential examples:
```
# Windows
python3 -m serial.tools.miniterm COM3 115200
# macOS
python3 -m serial.tools.miniterm /dev/cu.usbserial-0001 115200
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

## FAQ
### Is this project ready to use? Does it work?
As far as simple Forth implementations go, it does work!
It's just so minimal at this point that it's sort of hard to tell.
By default, it only supports the bare minimum builtin words as documented above.
In order to build up the dictionary into something useful, it is necessary to enter most of the commands from [prelude.forth](https://github.com/theandrew168/derzforth/blob/main/prelude.forth).
If you then go on and manually type all the commands in from both [rcu.forth](https://github.com/theandrew168/derzforth/blob/main/rcu.forth) and [gpio.forth](https://github.com/theandrew168/derzforth/blob/main/gpio.forth), you'll be equipped with the word "rled" which turns on the red LED.
I made a quick [demo video](https://www.youtube.com/watch?v=7Q1TXs5Ff9M) for this example.

Obviously, this is an obnoxious amount of manual and tedious typing.
Surely there is a better way!
In the past, I actually hard-coded all three of these "dictionaries" into the binary and interpreted them on startup.
However, this quickly bloated the binary and started adding complexity to address linking and resolution.
In the future I'll need to make the assembler smart enough to handle short / long jumps properly.

Since baking these word definitions into the binary didn't really scale, I needed to find a better option.
Next on my TODO list for this project is to get the SD card working (at least for reads) over SPI.
That way I could store all of these words there and load them easily at runtime.
I really want to implement a simple LOAD / EDIT system as described in [chapter 3 of "Starting Forth"](https://www.forth.com/starting-forth/3-forth-editor-blocks-buffer/) by Leo Brodie.

I'm pretty happy with where this Forth interpreter is but it definitely has a ways to go before I'd call it "useful".
Most of the design is based on Cesar Blum's [sectorforth](https://github.com/cesarblum/sectorforth) project.
His design is based on an [old Usenet thread](https://groups.google.com/g/comp.lang.forth/c/NS2icrCj1jQ) wherein some folks discussed the smallest number of initial builtin words that could be used to bootstrap a full Forth environment.
