import argparse
import time

import serial


def cli_main():
    parser = argparse.ArgumentParser(description='autotype Forth words over serial')
    parser.add_argument('files', type=str, nargs='+', help='source file(s) to send')
    parser.add_argument('-p', '--port', type=str, default='/dev/cu.usbserial-0001', help='device serial port')
    parser.add_argument('-b', '--baud', type=int, default=115200, help='serial baud rate')
    args = parser.parse_args()

    lines = []
    for file in args.files:
        with open(file) as f:
            lines.extend(f.readlines())

    # skip comments and empty lines
    lines = [line for line in lines if not line.startswith('\\')]
    lines = [line for line in lines if len(line.strip()) > 0]

    with serial.Serial(args.port, args.baud, timeout=0.01) as ser:
        for line in lines:
            ser.write(line.encode())
            resp = ser.read(256)
            print(resp.decode(), end='')


if __name__ == '__main__':
    cli_main()
