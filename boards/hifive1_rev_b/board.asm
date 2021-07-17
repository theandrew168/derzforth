# include definitions related to the SiFive FE310-G002 chip
# passing the --include-chips flag to bronzebeard puts this on the path
include FE310-G002.asm

# FE310-G002 Manual: Section 18.2
UART_BASE_ADDR_0 = 0x10013000
UART_BASE_ADDR_1 = 0x10023000

# FE310-G002 Manual: Section 18.3
UART_TXDATA_OFFSET = 0x00
UART_RXDATA_OFFSET = 0x04
UART_TXCTRL_OFFSET = 0x08
UART_RXCTRL_OFFSET = 0x0c
UART_IE_OFFSET     = 0x10
UART_IP_OFFSET     = 0x14
UART_DIV_OFFSET    = 0x18


# 16KB @ 0x80000000
RAM_BASE_ADDR = 0x80000000
RAM_SIZE = 16 * 1024

# 4MB @ 0x20000000
ROM_BASE_ADDR = 0x20000000
ROM_SIZE = 4 * 1024 * 1024

# NOTE: The first 64KB of Flash is occupied by the bootloader
# (which jumps to 0x20010000 at the end). That leaves
# (4MB - 64KB = 4032KB) starting at 0x20010000 for programs.
ROM_BASE_ADDR = ROM_BASE_ADDR + (64 * 1024)
ROM_SIZE = ROM_SIZE - (64 * 1024)


# Func: serial_init
# Arg: a0 = baud rate
serial_init:
    ret


# Func: serial_getc
# Ret: a0 = character received
serial_getc:
    ret


# Func: serial_putc
# Arg: a0 = character to send
serial_putc:
    ret
