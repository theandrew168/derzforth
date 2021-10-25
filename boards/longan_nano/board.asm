# include definitions related to the GigaDevice GD32VF103 family of chips
#  (the --include-definitions flag to bronzebeard puts this on the path)
include GD32VF103.asm

# 32KB @ 0x20000000
RAM_BASE_ADDR = 0x20000000
RAM_SIZE = 32 * 1024

# 128KB @ 0x08000000
ROM_BASE_ADDR = 0x08000000
ROM_SIZE = 128 * 1024

# 8MHz is the default GD32VF103 clock freq
CLOCK_FREQ = 8000000


# Func: gpio_config
# Arg: a0 = GPIO port base addr
# Arg: a1 = GPIO pin number
# Arg: a2 = GPIO config (4 bits)
gpio_config:
    # advance to CTL0
    addi t0, a0, GPIO_CTL0_OFFSET
    # if pin number is less than 8, CTL0 is correct
    slti t1, a1, 8
    bnez t1, gpio_config_store
    # else we need CTL1 and then subtract 8 from the pin number
    addi t0, t0, 4
    addi a1, a1, -8
gpio_config_store:
    # multiply pin number by 4 to get shift amount
    slli a1, a1, 2
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
gpio_config_done:
    ret


# Func: serial_init
# Arg: a0 = baud rate
serial_init:
    # save return addr (since serial_init calls other funcs)
    mv SAVED0, ra

    # setup RCU base addr in t0
    li t0, RCU_BASE_ADDR

    # enable RCU (USART0, GPIOA, and AFIO)
    li t1, RCU_APB2EN_USART0EN | RCU_APB2EN_PAEN | RCU_APB2EN_AFEN
    sw t1, RCU_APB2EN_OFFSET(t0)

    # setup USART0 base addr in t0
    li t0, USART_BASE_ADDR_0

    # calculate and store clkdiv (CLKDIV = CLOCK // BAUD)
    li t1, CLOCK_FREQ
    div t1, t1, a0
    sw t1, USART_BAUD_OFFSET(t0)

    # enable USART (USART, TX, and RX)
    li t1, USART_CTL0_UEN | USART_CTL0_TEN | USART_CTL0_REN
    sw t1, USART_CTL0_OFFSET(t0)

    # configure TX pin
    li a0, GPIO_BASE_ADDR_A
    li a1, 9
    li a2, GPIO_CONFIG_AF_PP_50MHZ
    call gpio_config

    # configure RX pin
    li a0, GPIO_BASE_ADDR_A
    li a1, 10
    li a2, GPIO_CONFIG_IN_FLOAT
    call gpio_config

serial_init_done:
    # restore return addr and return
    mv ra, SAVED0
    ret


# Func: serial_getc
# Ret: a0 = character received
serial_getc:
    li t0, USART_BASE_ADDR_0      # load USART base addr into t0
serial_getc_loop:
    lw t1, USART_STAT_OFFSET(t0)  # load status into t1
    andi t1, t1, USART_STAT_RBNE  # isolate read buffer not empty (RBNE) bit
    beqz t1, serial_getc_loop     # keep looping until ready to recv
    lw a0, USART_DATA_OFFSET(t0)  # load char into a0
    andi a0, a0, 0xff             # isolate bottom 8 bits
serial_getc_done:
    ret


# Func: serial_putc
# Arg: a0 = character to send
serial_putc:
    li t0, USART_BASE_ADDR_0      # load USART base addr into t0
serial_putc_loop:
    lw t1, USART_STAT_OFFSET(t0)  # load status into t1
    andi t1, t1, USART_STAT_TBE   # isolate transmit buffer empty (TBE) bit
    beqz t1, serial_putc_loop     # keep looping until ready to send
    andi a0, a0, 0xff             # isolate bottom 8 bits
    sw a0, USART_DATA_OFFSET(t0)  # write char from a0
serial_putc_done:
    ret
