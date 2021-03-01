# derzforth
Bare-metal Forth implementation for RISC-V

## About
Forth was initially designed and created by [Charles Moore](https://en.wikipedia.org/wiki/Charles_H._Moore).
Many folks have adapted its ideas and principles to solve their own problems.
[Moving Forth](http://www.bradrodriguez.com/papers/moving1.htm) by Brad Rodriguez is an amazing source of Forth implementation details and tradeoffs.
If you are looking for some introductory content surrounding the Forth language in general, I recommend the book [Starting Forth](https://www.forth.com/starting-forth/) by Leo Brodie.

This implementation's general structure is based on [Sectorforth](https://github.com/cesarblum/sectorforth) by Cesar Blum.
He took inspiration from a [1996 Usenet thread](https://groups.google.com/g/comp.lang.forth/c/NS2icrCj1jQ/m/ohh9v4KphygJ) wherein folks discussed requirements for a minimal yet fully functional Forth implementation.

## Setup
DerzForth is an assembly program based on the [Bronzebeard](https://github.com/theandrew168/bronzebeard) project.
Consult Bronzebeard's documentation for how to get it all setup (it's pretty easy and works on all major platforms).
If you are unfamiliar with [virtual environments](https://docs.python.org/3/library/venv.html), I suggest taking a brief moment to learn about them and set one up.
The Python docs provide a great [tutorial](https://docs.python.org/3/tutorial/venv.html) for getting started with virtual environments and packages.

Bronzebeard can be installed via pip:
```
pip install bronzebeard
```

## Building
With Bronzebeard installed:
```
python3 -m bronzebeard.asm derzforth.asm derzforth.bin
```

## Longan Nano
This section details how to run DerzForth on the [Longan Nano](https://www.seeedstudio.com/Sipeed-Longan-Nano-RISC-V-GD32VF103CBT6-Development-Board-p-4205.html).

### Cables
1. Attach the USB to USB-C cable for programming via DFU
2. (Optional) Attach the USB to TTL Serial cable ([adafruit](https://www.adafruit.com/product/954), [sparkfun](https://www.sparkfun.com/products/12977))
    * Attach GND to GND
    * Attach TX to RX
    * Attach RX to TX
    * Don't attach VCC (or jump it to the 5V input if you want power via this cable)

### Program
Enable DFU mode on the Longan Nano: press BOOT, press RESET, release RESET, release BOOT.
```
python3 -m bronzebeard.dfu 28e9:0189 derzforth.bin
```

After programming, press and release RESET in order to put the device back into normal mode.

### Interact
If you have flashed a program that includes serial interaction, We can use [pySerial's](https://pyserial.readthedocs.io/en/latest/index.html) built-in terminal to communiate with the device.

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
python3 -m serial.tools.miniterm /dev/TODO_what_goes_here 115200
# Linux
python3 -m serial.tools.miniterm /dev/ttyUSB0 115200
```
