include gd32vf103.asm

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

ROM_BASE_ADDR = 0x08000000
RAM_BASE_ADDR = 0x20000000

INTERPRETER_BASE  = 0x0000
TIB_BASE          = 0x1c00
DATA_STACK_BASE   = 0x2000
RETURN_STACK_BASE = 0x3000

INTERPRETER_SIZE  = 0x1c00  # 7K
TIB_SIZE          = 0x0400  # 1K
DATA_STACK_SIZE   = 0x1000  # 4K
RETURN_STACK_SIZE = 0x1000  # 4K

# serial config
CLOCK_FREQ = 8000000  # default GD32BF103 clock freq
USART_BAUD = 115200   # desired USART baud rate

# word flags
F_IMMEDIATE = 0b10000000
F_HIDDEN    = 0b01000000
F_LENGTH    = 0b00111111

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
    lw t0, USART_STAT_OFFSET(a0)  # load status into t0
    andi t0, t0, (1 << USART_STAT_RBNE_BIT)  # isolate read buffer not empty (RBNE) bit
    beqz t0, getc                 # keep looping until ready to recv
    lw a1, USART_DATA_OFFSET(a0)  # load char into a1

    ret


# Func: putc
# Arg: a0 = USART base addr
# Arg: a1 = character to send
# Ret: none
putc:
    lw t0, USART_STAT_OFFSET(a0)  # load status into t0
    andi t0, t0, (1 << USART_STAT_TBE_BIT)  # isolate transmit buffer empty (TBE) bit
    beqz t0, putc                 # keep looping until ready to send
    sw a1, USART_DATA_OFFSET(a0)  # write char from a1

    ret


# Func: memclr
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: none
memclr:
    beqz a1, memclr_done  # loop til size == 0
    sw 0, 0(a0)      # 0 -> [addr]
    addi a0, a0, 4   # addr += 4
    addi a1, a1, -4  # size -= 4
    j memclr
memclr_done:
    ret


# Func: memcpy
# Arg: a0 = src buffer addr
# Arg: a1 = dst buffer addr
# Arg: a2 = buffer size
# Ret: none
memcpy:
    beqz a2, memcpy_done  # loop til size == 0
    lw t0, 0(a0)     # t0 <- [src]
    sw t0, 0(a1)     # t0 -> [dst]
    addi a0, a0, 4   # src += 4
    addi a1, a1, 4   # dst += 4
    addi a2, a2, -4  # size -= 4
    j memcpy
memcpy_done:
    ret


# Func: tpop_hash
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: a0 = hash value
tpop_hash:
    li t0, 0   # t0 = hash value
    li t1, 37  # t1 = prime multiplier

tpop_hash_loop:
    beqz a1, tpop_hash_done
    lbu t2, 0(a0)   # c <- [addr]
    mul t0, t1, t0  # h = 37 * h
    add t0, t0, t2  # h = h + c

    addi a0, a0, 1   # addr += 1
    addi a1, a1, -1  # size -= 1
    j tpop_hash_loop

tpop_hash_done:
    mv a0, t0  # setup return value
    ret


# Func: perl_hash
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: a0 = hash value
perl_hash:
    li t0, 0   # t0 = hash value
    li t1, 33  # t1 = prime multiplier

perl_hash_loop:
    beqz a1, perl_hash_done
    lbu t2, 0(a0)   # c <- [addr]
    mul t0, t1, t0  # h = 33 * h
    add t0, t0, t2  # h = h + c
    srai t3, t0, 5  # tmp = h >> 5
    add t0, t0, t3  # h = h + tmp

    addi a0, a0, 1   # addr += 1
    addi a1, a1, -1  # size -= 1
    j perl_hash_loop

perl_hash_done:
    mv a0, t0  # setup return value
    ret


###
### interpreter
###

main:
    # enable RCU (AFIO, GPIO port A, and USART0)
    li a0, RCU_BASE_ADDR
    li a1, (1 << RCU_APB2EN_AFEN_BIT) | (1 << RCU_APB2EN_PAEN_BIT) | (1 << RCU_APB2EN_USART0EN_BIT)
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

tib_clear:
    mv a0, TIB
    li a1, TIB_SIZE
    call memclr

tib_init:
    mv TBUF, TIB  # set TBUF to TIB
    li TLEN, 0    # set TLEN to 0
    li TPOS, 0    # set TPOS to 0

interpreter_repl:
    li a0, USART_BASE_ADDR_0
    call getc
    call putc
    j interpreter

interpreter_interpret:
interpreter_compile:
interpreter_execute:

align 4
interpreter_addr:
    dw %position(interpreter_interpret, RAM_BASE_ADDR)
interpreter_addr_addr:
    dw %position(interpreter_addr, RAM_BASE_ADDR)

# standard forth routine: next
next:
    lw W, 0(IP)
    addi IP, IP, 4
    lw t0, 0(W)
    jr t0

# standard forth routine: enter
enter:
    sw IP, 0(RSP)
    addi RSP, RSP, 4
    addi IP, W, 4  # skip code field
    j next


###
### dictionary
###

align 4
word_exit:
    dw 0
    dw 0x0050a18a
code_exit:
    dw %position(body_exit, RAM_BASE_ADDR)
body_exit:
    addi RSP, RSP, -4
    lw IP, 0(RSP)
    j next

align 4
word_colon:
    dw %position(word_exit, RAM_BASE_ADDR)
    dw 0x0000003a 
code_colon:
    dw %position(body_colon, RAM_BASE_ADDR)
body_colon:
    # TODO: impl this
    j next

align 4
word_semi:
    dw %position(word_colon, RAM_BASE_ADDR)
    dw 0x0000003b
code_semi:
    dw %position(body_semi, RAM_BASE_ADDR)
body_semi:
    j next

align 4
word_at:
    dw %position(word_semi, RAM_BASE_ADDR)
    dw 0x00000040
code_at:
    dw %position(body_at, RAM_BASE_ADDR)
body_at:
    j next

align 4
word_ex:
    dw %position(word_at, RAM_BASE_ADDR)
    dw 0x00000021
code_ex:
    dw %position(body_ex, RAM_BASE_ADDR)
body_ex:
    j next

align 4
word_spat:
    dw %position(word_ex, RAM_BASE_ADDR)
    dw 0x0002776b
code_spat:
    dw %position(body_spat, RAM_BASE_ADDR)
body_spat:
    j next

align 4
word_rpat:
    dw %position(word_spat, RAM_BASE_ADDR)
    dw 0x00027212
code_rpat:
    dw %position(body_rpat, RAM_BASE_ADDR)
body_rpat:
    j next

align 4
word_zeroeq:
    dw %position(word_rpat, RAM_BASE_ADDR)
    dw 0x0000072d
code_zeroeq:
    dw %position(body_zeroeq, RAM_BASE_ADDR)
body_zeroeq:
    j next

align 4
word_plus:
    dw %position(word_zeroeq, RAM_BASE_ADDR)
    dw 0x0000002b
code_plus:
    dw %position(body_plus, RAM_BASE_ADDR)
body_plus:
    j next

align 4
word_nand:
    dw %position(word_plus, RAM_BASE_ADDR)
    dw 0x00571bf9
code_nand:
    dw %position(body_nand, RAM_BASE_ADDR)
body_nand:
    j next

align 4
word_key:
    dw %position(word_nand, RAM_BASE_ADDR)
    dw 0x00024b45
code_key:
    dw %position(body_key, RAM_BASE_ADDR)
body_key:
    j next

align 4
latest:  # mark the latest builtin word
word_emit:
    dw %position(word_key, RAM_BASE_ADDR)
    dw 0x005066b7
code_emit:
    dw %position(body_emit, RAM_BASE_ADDR)
body_emit:
    j next

align 4
here:  # next new word will go here
