import argparse
import time

import serial


def cli_main():
    parser = argparse.ArgumentParser(description='autotype Forth words over serial')
    parser.add_argument('source_file', type=str, help='source file to send')
    parser.add_argument('-p', '--port', type=str, default='/dev/cu.usbserial-0001', help='device serial port')
    parser.add_argument('-b', '--baud', type=int, default=115200, help='serial baud rate')
    args = parser.parse_args()

    with open(args.source_file, 'rb') as f:
        lines = f.readlines()

    lines = [line for line in lines if not line.startswith(b'\\')]
    lines = [line for line in lines if len(line.strip()) > 0]

    with serial.Serial(args.port, args.baud) as ser:
        for line in lines:
            ser.write(line)
            resp = ser.readline()
            print(resp.decode(), end='')
            time.sleep(0.1)


if __name__ == '__main__':
    cli_main()
