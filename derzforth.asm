include gd32vf103.asm

CLOCK_FREQ = 8000000  # default GD32BF103 clock freq
USART_BAUD = 115200   # desired USART baud rate
ROM_BASE_ADDR = 0x08000000
RAM_BASE_ADDR = 0x20000000

# "The Classical Forth Registers"
W   = s0  # working register
IP  = gp  # interpreter pointer
DSP = sp  # data stack pointer
RSP = tp  # return stack pointer

# variable registers
STATE  = s1  # 0 = execute, 1 = compile
TIB    = s2  # text input buffer addr
TBUF   = s3  # text buffer addr
TLEN   = s4  # text buffer length
TPOS   = s5  # text buffer current position
HERE   = s6  # next dict entry addr
LATEST = s7  # latest dict entry addr

#  16KB      Memory Map
# 0x0000 |----------------|
#        |                |
#        |  Interpreter   |
#        |       +        | 7K
#        |   Dictionary   |
#        |                |
# 0x1c00 |----------------|
#        |      TIB       | 1K
# 0x2000 |----------------|
#        |                |
#        |   Data Stack   | 4K
#        |                |
# 0x3000 |----------------|
#        |                |
#        |  Return Stack  | 4K
#        |                |
# 0x3FFF |----------------|

INTERPRETER_BASE  = 0x0000
TIB_BASE          = 0x1c00
DATA_STACK_BASE   = 0x2000
RETURN_STACK_BASE = 0x3000

INTERPRETER_SIZE  = 0x1c00  # 7K
TIB_SIZE          = 0x0400  # 1K
DATA_STACK_SIZE   = 0x1000  # 4K
RETURN_STACK_SIZE = 0x1000  # 4K

F_IMMEDIATE = 0b10000000
F_HIDDEN    = 0b01000000
F_LENGTH    = 0b00111111


# jump to "main" since programs execute top to bottom
# we do this to enable writing helper funcs at the top
j main


# Func: rcu_init
# Arg: a0 = RCU base addr
# Arg: a1 = RCU config
# Ret: none
rcu_init:
    # store config
    sw a1, RCU_APB2EN_OFFSET(a0)

    ret


# Func: gpio_init
# Arg: a0 = GPIO port base addr
# Arg: a1 = GPIO pin number
# Arg: a2 = GPIO config (4 bits)
# Ret: none
gpio_init:
    # advance to CTL0
    addi t0, a0, GPIO_CTL0_OFFSET

    # if pin number is less than 8, CTL0 is correct
    slti t1, a1, 8
    bnez t1, gpio_init_config

    # else we need CTL1 and then subtract 8 from the pin number
    addi t0, t0, 4
    addi a1, a1, -8

gpio_init_config:
    # multiply pin number by 4 to get shift amount
    addi t1, zero, 4
    mul a1, a1, t1

    # load current config
    lw t1, 0(t0)

    # align and clear existing pin config
    li t2, 0b1111
    sll t2, t2, a1
    not t2, t2
    and t1, t1, t2

    # align and apply new pin config
    sll a2, a2, a1
    or t1, t1, a2

    # store updated config
    sw t1, 0(t0)

    ret


# Func: usart_init
# Arg: a0 = USART base addr
# Arg: a1 = USART clkdiv
# Ret: none
usart_init:
    # store clkdiv
    sw a1, USART_BAUD_OFFSET(a0)

    # enable USART (enable RX, enable TX, enable USART)
    li t0, (1 << USART_CTL0_REN_BIT) | (1 << USART_CTL0_TEN_BIT) | (1 << USART_CTL0_UEN_BIT)
    sw t0, USART_CTL0_OFFSET(a0)

    ret


# Func: getc
# Arg: a0 = USART base addr
# Ret: a1 = character received (a1 here for simpler getc + putc loops)
getc:
    lw t0 USART_STAT_OFFSET(a0)  # load status into t0
    andi t0 t0 (1 << USART_STAT_RBNE_BIT)  # isolate read buffer not empty (RBNE) bit
    beqz t0 getc                 # keep looping until ready to recv
    lw a1 USART_DATA_OFFSET(a0)  # load char into a1

    ret


# Func: putc
# Arg: a0 = USART base addr
# Arg: a1 = character to send
# Ret: none
putc:
    lw t0 USART_STAT_OFFSET(a0)  # load status into t0
    andi t0 t0 (1 << USART_STAT_TBE_BIT)  # isolate transmit buffer empty (TBE) bit
    beqz t0 putc                 # keep looping until ready to send
    sw a1 USART_DATA_OFFSET(a0)  # write char from a1

    ret


main:
    # enable RCU (AFIO, GPIO port A, and USART0)
    li a0, RCU_BASE_ADDR
    li a1, 0b0100000000000101
    call rcu_init

    # enable TX pin
    li a0, GPIO_BASE_ADDR_A
    li a1, 9
    li a2, (GPIO_CTL_OUT_ALT_PUSH_PULL << 2 | GPIO_MODE_OUT_50MHZ)
    call gpio_init

    # enable RX pin
    li a0, GPIO_BASE_ADDR_A
    li a1, 10
    li a2, (GPIO_CTL_IN_FLOATING << 2 | GPIO_MODE_IN)
    call gpio_init

    # enable USART0
    li a0, USART_BASE_ADDR_0
    li a1, (CLOCK_FREQ // USART_BAUD)
    call usart_init

    # setup HERE and LATEST vars (will be in RAM)
    li HERE, %position(here, RAM_BASE_ADDR)
    li LATEST, %position(latest, RAM_BASE_ADDR)

    j init

error:
    li a0, USART_BASE_ADDR_0

    # print " ?" and fall into init
    li a1, ' '
    call putc
    li a1, '?'
    call putc
    li a1, '\n'
    call putc

init:
    li W, 0
    li STATE, 0
    li DSP, RAM_BASE_ADDR + DATA_STACK_BASE
    li RSP, RAM_BASE_ADDR + RETURN_STACK_BASE
    li TIB, RAM_BASE_ADDR + TIB_BASE

    j interpreter

interpreter_ok:
    li a0, USART_BASE_ADDR_0

    # print "ok" and fall into interpreter
    li a1, ' '
    call putc
    li a1, 'o'
    call putc
    li a1, 'k'
    call putc
    li a1, '\n'
    call putc

interpreter:
    li a0, USART_BASE_ADDR_0
    call getc
    call putc
    j interpreter

latest:
here:
