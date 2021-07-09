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

# word flags (top 2 bits of hash)
FLAGS_MASK  = 0xc0000000
F_IMMEDIATE = 0x80000000
F_HIDDEN    = 0x40000000

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

# extra saved regs (use for whatever)
SAVED0 = s8
SAVED1 = s9
SAVED2 = s10
SAVED3 = s11


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
rcu_init_done:
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
gpio_init_done:
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
usart_init_done:
    ret


# Func: getc
# Arg: a0 = USART base addr
# Ret: a1 = character received (a1 here for simpler getc + putc loops)
getc:
    lw t0, USART_STAT_OFFSET(a0)  # load status into t0
    andi t0, t0, USART_STAT_RBNE  # isolate read buffer not empty (RBNE) bit
    beqz t0, getc                 # keep looping until ready to recv
    lw a1, USART_DATA_OFFSET(a0)  # load char into a1
    andi a1, a1, 0xff             # isolate bottom 8 bits
getc_done:
    ret


# Func: putc
# Arg: a0 = USART base addr
# Arg: a1 = character to send
# Ret: none
putc:
    lw t0, USART_STAT_OFFSET(a0)  # load status into t0
    andi t0, t0, USART_STAT_TBE   # isolate transmit buffer empty (TBE) bit
    beqz t0, putc                 # keep looping until ready to send
    andi a1, a1, 0xff             # isolate bottom 8 bits
    sw a1, USART_DATA_OFFSET(a0)  # write char from a1
putc_done:
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


# Func: strtok
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: a0 = token addr (0 if not found)
# Ret: a1 = token size (0 if not found)
# Reg: a2 = total bytes consumed (0 if not found)
strtok:
    addi t0, zero, ' '         # t0 = whitespace threshold
    mv t2, a0                  # save buffer's start addr for later
strtok_skip_whitespace:
    beqz a1, strtok_not_found  # not found if we run out of chars
    lbu t1, 0(a0)              # pull the next char
    bgtu t1, t0, strtok_scan   # if not whitespace, start the scan
    addi a0, a0, 1             # else advance ptr by one char
    addi a1, a1, -1            # and reduce size by 1
    j strtok_skip_whitespace   # repeat
strtok_scan:
    mv t3, a0                  # save the token's start addr for later
strtok_scan_loop:
    beqz a1, strtok_not_found  # early exit if reached EOB
    lbu t1, 0(a0)              # grab the next char
    bleu t1, t0, strtok_found  # if found whitespace, we are done
    addi a0, a0, 1             # else advance ptr by one char
    addi a1, a1, -1            # and reduce size by 1
    j strtok_scan_loop         # repeat
strtok_found:
    sub a2, a0, t2             # a2 = (end - buffer) = bytes consumed
    addi a2, a2, 1             # add one to include the delimiter
    sub a1, a0, t3             # a1 = (end - start) = token size
    mv a0, t3                  # a0 = start = token addr
    ret
strtok_not_found:
    addi a0, zero, 0           # a0 = 0 (not found)
    addi a1, zero, 0           # a1 = 0 (not found)
    addi a2, zero, 0           # a2 = 0 (not found)
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
    ret  # a0 is already pointing at the current dict entry
lookup_not_found:
    addi a0, zero, 0           # a0 = 0 (not found)
    ret


# Func: tpop_hash
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: a0 = hash value
tpop_hash:
    li t0, 0            # t0 = hash value
    li t1, 37           # t1 = prime multiplier
tpop_hash_loop:
    beqz a1, tpop_hash_done
    lbu t2, 0(a0)       # c <- [addr]
    mul t0, t0, t1      # h = h * 37
    add t0, t0, t2      # h = h + c
    addi a0, a0, 1      # addr += 1
    addi a1, a1, -1     # size -= 1
    j tpop_hash_loop    # repeat
tpop_hash_done:
    li t1, ~FLAGS_MASK  # clear the top two bits (used for word flags)
    and a0, t0, t1      # a0 = final hash value
    ret


# Func: perl_hash
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: a0 = hash value
perl_hash:
    li t0, 0            # t0 = hash value
    li t1, 33           # t1 = prime multiplier
perl_hash_loop:
    beqz a1, perl_hash_done
    lbu t2, 0(a0)       # c <- [addr]
    mul t0, t0, t1      # h = h * 33
    add t0, t0, t2      # h = h + c
    srai t3, t0, 5      # tmp = h >> 5
    add t0, t0, t3      # h = h + tmp
    addi a0, a0, 1      # addr += 1
    addi a1, a1, -1     # size -= 1
    j perl_hash_loop    # repeat
perl_hash_done:
    li t1, ~FLAGS_MASK  # clear the top two bits (used for word flags)
    and a0, t0, t1      # a0 = final hash value
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

    # copy program from ROM to RAM
    li a0, ROM_BASE_ADDR
    li a1, RAM_BASE_ADDR
    li a2, %position(here, 0)
    call memcpy

    # jump to reset (in RAM now)
    li t0, %position(reset, RAM_BASE_ADDR)
    jr t0

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
    # set working reg to zero
    li W, 0

    # set interpreter state reg to 0 (execute)
    li STATE, 0

    # setup data stack ptr
    li DSP, RAM_BASE_ADDR + DATA_STACK_BASE

    # setup return stack ptr
    li RSP, RAM_BASE_ADDR + RETURN_STACK_BASE

    # setup text input buffer addr
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
    mv a0, TIB       # a0 = buffer addr
    li a1, TIB_SIZE  # a1 = buffer size
    call memclr      # clear out the text input buffer

tib_init:
    mv TBUF, TIB  # set TBUF to TIB
    li TLEN, 0    # set TLEN to 0
    li TPOS, 0    # set TPOS to 0

# TODO: bounds check on TBUF (error or overwrite last char?)
interpreter_repl:
    # read and echo a single char
    li a0, USART_BASE_ADDR_0
    call getc
    call putc
    # check for backspace
    li t0, '\b'
    bne a1, t0, interpreter_repl_char
    beqz TLEN, interpreter_repl  # ignore BS if TLEN is zero
    # if backspace, dec TLEN and send a space and another backspace
    #   this simulates clearing the char on the client side
    addi TLEN, TLEN, -1
    li a1, ' '
    call putc
    li a1, '\b'
    call putc
    j interpreter_repl

interpreter_repl_char:
    add t0, TBUF, TLEN   # t0 = dest addr for this char in TBUF
    sb a1, 0(t0)         # write char into TBUF
    addi TLEN, TLEN, 1   # TLEN += 1
    addi t0, zero, '\n'  # t0 = newline char
    beq a1, t0, interpreter_interpret  # interpret the input upon newline
    j interpreter_repl

interpreter_interpret:
    # grab the next token
    add a0, TBUF, TPOS       # a0 = buffer addr
    sub a1, TLEN, TPOS       # a1 = buffer size
    call strtok              # a0 = str addr, a1 = str size, a2 = bytes consumed
    beqz a0, interpreter_ok  # loop back to REPL if input is used up
    add TPOS, TPOS, a2       # update TPOS based on strtok bytes consumed

    mv SAVED0, a0
    mv SAVED1, a1
    mv SAVED2, a2

    li a0, USART_BASE_ADDR_0
    addi t0, a1, '0'
    addi t1, a2, '0'
    addi t2, zero, ' '

    mv a1, t0
    call putc
    mv a1, t2
    call putc
    mv a1, t1
    call putc
    mv a1, t2
    call putc

    mv a0, SAVED0
    mv a1, SAVED1
    mv a2, SAVED2

    # hash the current token
    call tpop_hash  # a0 = str hash

    # lookup the hash in the word dict
    mv a1, a0       # a1 = hash of word name
    mv a0, LATEST   # a0 = addr of latest word
    call lookup     # a0 = addr of found word (0 if not found)
    beqz a0, error  # check for error from lookup

    # load and isolate the immediate flag
    lw t0, 4(a0)        # load word hash into t0
    li t1, F_IMMEDIATE  # load immediate flag into t1
    and t0, t0, t1      # isolate immediate bit in word hash

    # decide whether to compile or execute the word
    bnez t0, interpreter_execute     # execute if word is immediate...
    beqz STATE, interpreter_execute  # or if STATE is 0 (execute)

interpreter_compile:
    sw a0 0(HERE)       # write addr of found word to current definition
    addi HERE, HERE, 4  # HERE += 4
    j interpreter_ok

interpreter_execute:
    # setup double-indirect addr back to interpreter loop
    li IP, %position(interpreter_addr_addr, RAM_BASE_ADDR)
    lw W, 8(a0)  # W = addr of word's code field
    lw t0, 0(W)  # t0 = addr of word's body
    jr t0        # execute the word


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
    addi RSP, RSP, -4  # dec return stack ptr
    lw IP, 0(RSP)      # load next addr into IP
    j next

align 4
word_colon:
    dw %position(word_exit, RAM_BASE_ADDR)
    dw 0x0000003a 
code_colon:
    dw %position(body_colon, RAM_BASE_ADDR)
body_colon:
    add a0, TBUF, TPOS   # a0 = buffer addr
    mv a1, TLEN          # a1 = buffer size
    call strtok          # a0 = str addr, a1 = str size
    # TODO: handle error from strtok
    add TPOS, TPOS, a2   # update TPOS based on strtok bytes consumed
    call tpop_hash       # a0 = str hash
    sw LATEST, 0(HERE)   # write link to prev word (LATEST -> [HERE])
    sw a0, 4(HERE)       # write word name hash (hash -> [HERE + 4])
    mv LATEST, HERE      # set LATEST = HERE (before HERE gets modified)
    addi HERE, HERE, 8   # move HERE past link and hash (to start of code)
    li t0, %position(enter, RAM_BASE_ADDR)
    sw t0, 0(HERE)       # write addr of "enter" to word definition
    addi HERE, HERE, 4   # HERE += 4
    addi STATE, zero, 1  # STATE = 1 (compile)
    j next

align 4
word_semi:
    dw %position(word_colon, RAM_BASE_ADDR)
    dw 0x0000003b | F_IMMEDIATE
code_semi:
    dw %position(body_semi, RAM_BASE_ADDR)
body_semi:
    li t0, %position(code_exit, RAM_BASE_ADDR)
    sw t0, 0(HERE)       # write addr of "code_exit" to word definition
    addi HERE, HERE, 4   # HERE += 4
    addi STATE, zero, 0  # STATE = 0 (execute)
    j next

align 4
word_at:
    dw %position(word_semi, RAM_BASE_ADDR)
    dw 0x00000040
code_at:
    dw %position(body_at, RAM_BASE_ADDR)
body_at:
    addi DSP, DSP, -4  # dec data stack ptr
    lw t0, 0(DSP)      # pop addr into t0
    lw t0, 0(t0)       # load value from addr
    sw t0, 0(DSP)      # push value onto stack
    addi DSP, DSP, 4   # inc data stack ptr
    j next

align 4
word_ex:
    dw %position(word_at, RAM_BASE_ADDR)
    dw 0x00000021
code_ex:
    dw %position(body_ex, RAM_BASE_ADDR)
body_ex:
    addi DSP, DSP, -4  # dec data stack ptr
    lw t0, 0(DSP)      # pop addr into t0
    addi DSP, DSP, -4  # dec data stack ptr
    lw t1, 0(DSP)      # pop value into t1
    sw t1, 0(t0)       # store value at addr
    j next

align 4
word_spat:
    dw %position(word_ex, RAM_BASE_ADDR)
    dw 0x0002776b
code_spat:
    dw %position(body_spat, RAM_BASE_ADDR)
body_spat:
    mv t0, DSP        # copy next DSP addr
    addi t0, t0, -4   # dec to reach current DSP addr
    sw t0 0(DSP)      # push addr onto data stack
    addi DSP, DSP, 4  # inc data stack ptr
    j next

align 4
word_rpat:
    dw %position(word_spat, RAM_BASE_ADDR)
    dw 0x00027212
code_rpat:
    dw %position(body_rpat, RAM_BASE_ADDR)
body_rpat:
    mv t0, RSP        # copy next RSP addr
    addi t0, t0, -4   # dec to reach current RSP addr
    sw t0 0(DSP)      # push addr onto data stack
    addi DSP, DSP, 4  # inc data stack ptr
    j next

align 4
word_zeroeq:
    dw %position(word_rpat, RAM_BASE_ADDR)
    dw 0x0000072d
code_zeroeq:
    dw %position(body_zeroeq, RAM_BASE_ADDR)
body_zeroeq:
    addi DSP, DSP, -4  # dec data stack ptr
    lw t0, 0(DSP)      # pop value into t0
    addi t1, zero, 0   # setup initial result as 0
    bnez t0, notzero   #  0 if not zero
    addi t1, t1, -1    # -1 if zero 
notzero:
    sw t1, 0(DSP)      # push value onto stack
    addi DSP, DSP, 4   # inc data stack ptr
    j next

align 4
word_plus:
    dw %position(word_zeroeq, RAM_BASE_ADDR)
    dw 0x0000002b
code_plus:
    dw %position(body_plus, RAM_BASE_ADDR)
body_plus:
    addi DSP, DSP, -4  # dec data stack ptr
    lw t0, 0(DSP)      # pop first value into t0
    addi DSP, DSP, -4  # dec data stack ptr
    lw t1, 0(DSP)      # pop second value into t1
    add t0, t0, t1     # ADD the values together into t0
    sw t0, 0(DSP)      # push value onto stack
    addi DSP, DSP, 4   # inc data stack ptr
    j next

align 4
word_nand:
    dw %position(word_plus, RAM_BASE_ADDR)
    dw 0x00571bf9
code_nand:
    dw %position(body_nand, RAM_BASE_ADDR)
body_nand:
    addi DSP, DSP, -4  # dec data stack ptr
    lw t0, 0(DSP)      # pop first value into t0
    addi DSP, DSP, -4  # dec data stack ptr
    lw t1, 0(DSP)      # pop second value into t1
    and t0, t0, t1     # AND the values together into t0
    not t0, t0         # NOT t0 (invert the bits)
    sw t0, 0(DSP)      # push value onto stack
    addi DSP, DSP, 4   # inc data stack ptr
    j next

align 4
word_key:
    dw %position(word_nand, RAM_BASE_ADDR)
    dw 0x00024b45
code_key:
    dw %position(body_key, RAM_BASE_ADDR)
body_key:
    li a0, USART_BASE_ADDR_0  # load USART addr into a0
    call getc                 # read char into a1
    sw a1, 0(DSP)             # push char onto stack
    addi DSP, DSP, 4          # inc data stack ptr
    j next

align 4
latest:  # mark the latest builtin word
word_emit:
    dw %position(word_key, RAM_BASE_ADDR)
    dw 0x005066b7
code_emit:
    dw %position(body_emit, RAM_BASE_ADDR)
body_emit:
    li a0, USART_BASE_ADDR_0  # load USART addr into a0
    addi DSP, DSP, -4         # dec data stack ptr
    lw a1, 0(DSP)             # pop char into a1
    call putc                 # emit the char via putc
    j next

align 4
here:  # next new word will go here
