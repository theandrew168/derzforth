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
tail main


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

    ret


# Func: usart_init
# Arg: a0 = USART base addr
# Arg: a1 = USART clkdiv
# Ret: none
usart_init:
    # store clkdiv
    sw a1, USART_BAUD_OFFSET(a0)

    # enable USART (enable RX, enable TX, enable USART)
    li t0, USART_CTL0_REN | USART_CTL0_TEN | USART_CTL0_UEN
    sw t0, USART_CTL0_OFFSET(a0)

    ret


# Func: getc
# Arg: a0 = USART base addr
# Ret: a1 = character received (a1 here for simpler getc + putc loops)
getc:
    lw t0, USART_STAT_OFFSET(a0)  # load status into t0
    andi t0, t0, USART_STAT_RBNE  # isolate read buffer not empty (RBNE) bit
    beqz t0, getc                 # keep looping until ready to recv
    lw a1, USART_DATA_OFFSET(a0)  # load char into a1

    ret


# Func: putc
# Arg: a0 = USART base addr
# Arg: a1 = character to send
# Ret: none
putc:
    lw t0, USART_STAT_OFFSET(a0)  # load status into t0
    andi t0, t0, USART_STAT_TBE   # isolate transmit buffer empty (TBE) bit
    beqz t0, putc                 # keep looping until ready to send
    sw a1, USART_DATA_OFFSET(a0)  # write char from a1

    ret


# Func: memclr
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: none
memclr:
    beqz a1, memclr_done  # loop til size == 0
    sb 0, 0(a0)           # 0 -> [addr]
    addi a0, a0, 1        # addr += 1
    addi a1, a1, -1       # size -= 1
    j memclr              # repeat
memclr_done:
    ret


# Func: memcpy
# Arg: a0 = src buffer addr
# Arg: a1 = dst buffer addr
# Arg: a2 = buffer size
# Ret: none
memcpy:
    beqz a2, memcpy_done  # loop til size == 0
    lb t0, 0(a0)          # t0 <- [src]
    sb t0, 0(a1)          # t0 -> [dst]
    addi a0, a0, 1        # src += 1
    addi a1, a1, 1        # dst += 1
    addi a2, a2, -1       # size -= 1
    j memcpy              # repeat
memcpy_done:
    ret


# test cases:
# ""      -> 0, 0
# " "     -> 0, 0
# "cat "  -> B+0, 3
# "cat"   -> B+0, 3
# " cat " -> B+1, 3
# " cat"  -> B+1, 3

# Func: strtok
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: a0 = token addr (0 if not found)
# Ret: a1 = token size (0 if not found)
strtok:
    addi t0, zero, ' '         # t0 = whitespace threshold

strtok_skip_whitespace:
    beqz a1, strtok_not_found  # not found if we run out of chars
    lbu t1, 0(a0)              # pull the next char
    bgtu t1, t0, strtok_scan   # if not whitespace, start the scan
    addi a0, a0, 1             # else advance ptr by one char
    addi a1, a1, -1            # and reduce size by 1
    j strtok_skip_whitespace   # repeat

strtok_scan:
    mv t2, a0                  # save the token's start addr for later
strtok_scan_loop:
    beqz a1, strtok_found      # early exit if reached EOB
    lbu t1, 0(a0)              # pull the next char
    bleu t1, t0, strtok_found  # if found whitespace, we are done
    addi a0, a0, 1             # else advance ptr by one char
    addi a1, a1, -1            # and reduce size by 1
    j strtok_scan_loop         # repeat

strtok_found:
    sub a1, a0, t2             # a1 = (end - start) = token size
    mv a0, t2                  # a0 = start = token addr
    ret

strtok_not_found:
    addi a0, zero, 0           # a0 = 0 (not found)
    addi a1, zero, 0           # a1 = 0 (not found)
    ret


# Func: lookup
# Arg: a0 = addr of latest entry in word dict
# Arg: a1 = hash of word name to lookup
# Ret: a0 = addr of found word (0 if not found)
lookup:
    beqz a0, lookup_not_found  # not found if next word addr is 0 (end of dict)
    lw t0, 4(a0)               # t0 = hash of word name
    beq t0, a1, lookup_found   # done if hash (dict) matches hash (lookup)
    lw a0, 0(a0)               # follow link to next word in dict
    j lookup                   # repeat

lookup_found:
    ret

lookup_not_found:
    addi a0, zero, 0           # a0 = 0 (not found)
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
    mul t0, t0, t1  # h = h * 37
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
    mul t0, t0, t1  # h = h * 33
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
    li a1, RCU_APB2EN_AFEN | RCU_APB2EN_PAEN | RCU_APB2EN_USART0EN
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

    j reset

error:
    li a0, USART_BASE_ADDR_0

    # print " ?" and fall into reset
    li a1, ' '
    call putc
    li a1, '?'
    call putc
    li a1, '\n'
    call putc

reset:
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
    j interpreter_repl

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
