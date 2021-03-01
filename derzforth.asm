CLOCK_FREQ = 8000000
USART_BAUD = 115200
ROM_BASE_ADDR = 0x08000000
RAM_BASE_ADDR = 0x20000000
RCU_BASE_ADDR = 0x40021000
RCU_APB2EN_OFFSET = 0x18
GPIO_BASE_ADDR_A = 0x40010800
GPIO_BASE_ADDR_C = 0x40011000
GPIO_CTL1_OFFSET = 0x04
GPIO_MODE_IN = 0b00
GPIO_MODE_OUT_50MHZ = 0b11
GPIO_CTL_IN_FLOATING = 0b01
GPIO_CTL_OUT_PUSH_PULL = 0b00
GPIO_CTL_OUT_ALT_PUSH_PULL = 0b10
USART_BASE_ADDR_0 = 0x40013800
USART_STAT_OFFSET = 0x00
USART_DATA_OFFSET = 0x04
USART_BAUD_OFFSET = 0x08
USART_CTL0_OFFSET = 0x0c

#       Register Assignment
# |------------------------------|
# | reg | name |   description   |
# |------------------------------|
# |  x0 | zero | always 0        |
# |  x1 |  ra  | return address  |
# |  x2 |  sp  | DSP             |
# |  x3 |  gp  | IP              |
# |  x4 |  tp  | RSP             |
# |  x5 |  t0  | scratch         |
# |  x6 |  t1  | scratch         |
# |  x7 |  t2  | scratch         |
# |  x8 |  s0  | W               |
# |  x9 |  s1  | STATE           |
# | x10 |  a0  | token address   |
# | x11 |  a1  | token length    |
# | x12 |  a2  | lookup address  |
# | x13 |  a3  | align arg / ret |
# | x14 |  a4  | pad arg / ret   |
# | x15 |  a5  | getc / putc     |
# | x16 |  a6  | <unused>        |
# | x17 |  a7  | <unused>        |
# | x18 |  s2  | TIB             |
# | x19 |  s3  | TBUF            |
# | x20 |  s4  | TLEN            |
# | x21 |  s5  | TPOS            |
# | x22 |  s6  | HERE            |
# | x23 |  s7  | LATEST          |
# | x24 |  s8  | <unused>        |
# | x25 |  s9  | <unused>        |
# | x26 |  s10 | <unused>        |
# | x27 |  s11 | <unused>        |
# | x28 |  t3  | scratch         |
# | x29 |  t4  | scratch         |
# | x30 |  t5  | scratch         |
# | x31 |  t6  | scratch         |
# |------------------------------|

# "The Classical Forth Registers"
W = 's0'  # working register
IP = 'gp'  # interpreter pointer
DSP = 'sp'  # data stack pointer
RSP = 'tp'  # return stack pointer

#                Variables
# |----------------------------------------|
# |  name  |          description          |
# |----------------------------------------|
# | STATE  | 0 = execute, 1 = compile      |
# | TIB    | text input buffer addr        |
# | TBUF   | text buffer addr              |
# | TLEN   | text buffer length            |
# | TPOS   | text buffer current position  |
# | HERE   | next dict entry addr          |
# | LATEST | latest dict entry addr        |
# |----------------------------------------|

# Variable registers
STATE = 's1'
TIB = 's2'
TBUF = 's3'
TLEN = 's4'
TPOS = 's5'
HERE = 's6'
LATEST = 's7'

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

INTERPRETER_BASE = 0x0000
TIB_BASE = 0x1c00
DATA_STACK_BASE = 0x2000
RETURN_STACK_BASE = 0x3000

INTERPRETER_SIZE = 0x1c00  # 7K
TIB_SIZE = 0x0400  # 1K
DATA_STACK_SIZE = 0x1000  # 4K
RETURN_STACK_SIZE = 0x1000  # 4K

F_IMMEDIATE = 0b10000000
F_HIDDEN    = 0b01000000
F_LENGTH    = 0b00111111

# t0 = src, t1 = dest, t2 = count
copy:
    # setup copy src
    lui t0 %hi(ROM_BASE_ADDR)
    addi t0 t0 %lo(ROM_BASE_ADDR)
    # setup copy dest
    lui t1 %hi(RAM_BASE_ADDR)
    addi t1 t1 %lo(RAM_BASE_ADDR)
    # setup copy count
    addi t2 zero %position(here, 0)
copy_loop:
    beq t2 zero %offset copy_done
    lw t3 t0 0  # [src] -> t3
    sw t1 t3 0  # [dest] <- t3
    addi t0 t0 4  # src += 4
    addi t1 t1 4  # dest += 4
    addi t2 t2 -4  # count -= 4
    jal zero %offset copy_loop
copy_done:
    # t0 = addr of start
    # TODO: allow %position / %offset in %hi / %lo
    # lui t0 %hi(%position(start, RAM_BASE_ADDR))
    # addi t0 t0 %lo(%position(start, RAM_BASE_ADDR))
    lui t0 %hi(RAM_BASE_ADDR)
    addi t0 t0 %lo(RAM_BASE_ADDR)
    addi t0 t0 start
    # jump to start
    jalr zero t0 0

# Procedure: token
# Usage: jal ra token
# Ret: a0 = addr of word name (0 if not found)
# Ret: a1 = length of word name (0 if not found)
token:
    addi t0 zero 33  # put whitespace threshold value into t0
token_skip_whitespace:
    add t1 TBUF TPOS  # point t1 at current char
    lbu t2 t1 0  # load current char into t2
    bge t2 t0 token_scan  # check if non-whitespace char is found
    addi TPOS TPOS 1  # inc TPOS
    bge TPOS TLEN token_not_found  # no token if TPOS >= TLEN
    jal zero token_skip_whitespace  # else check again
token_scan:
    addi t1 TPOS 0  # put current TPOS value into t1
token_scan_loop:
    add t2 TBUF t1  # point t2 at next char
    lbu t3 t2 0  # load next char into t3
    blt t3 t0 token_found  # check for whitespace
    addi t1 t1 1  # increment offset
    bge t1 TLEN token_not_found  # no token if t1 >= TLEN
    jal zero token_scan_loop  # scan the next char
token_found:
    add a0 TBUF TPOS  # a0 = addr of word
    sub a1 t1 TPOS  # a1 = len of word
    addi TPOS t1 0  # update TPOS
    jalr zero ra 0  # return
token_not_found:
    addi a0 zero 0  # a0 = 0
    addi a1 zero 0  # a1 = 0
    addi TPOS t1 0  # update TPOS
    jalr zero ra 0  # return

# Procedure: lookup
# Usage: jal ra lookup
# Arg: a0 = addr of word name
# Arg: a1 = length of word name
# Ret: a2 = addr of found word (0 if not found)
lookup:
    addi t0 LATEST 0  # copy addr of latest word into t0
lookup_body:
    lw t1 t0 0  # load link of current word into t1
    lbu t2 t0 4  # load flags | len of current word into t2
    andi t2 t2 F_LENGTH  # isolate word length
    beq a1 t2 lookup_strncmp  # start strncmp if len matches
lookup_next:
    beq t1 zero lookup_not_found  # if link is zero then the word isn't found (end of dict)
    addi t0 t1 0  # point t0 at the next word (move link addr into t0)
    jal zero lookup_body
lookup_not_found:
    addi a2 zero 0  # a2 = 0
    jalr zero ra 0  # return
lookup_strncmp:
    addi t3 a0 0  # t3 points at name in TIB string
    addi t4 t0 5  # t4 points at name in word dict
lookup_strncmp_body:
    lbu t5 t3 0  # load TIB char into t5
    lbu t6 t4 0  # load dict char into t6
    bne t5 t6 lookup_next  # try next word if current chars don't match
lookup_strncmp_next:
    addi t2 t2 -1  # dec word name len
    beq t2 zero lookup_found  # if all chars have been checked, its a match!
    addi t3 t3 1  # inc TIB name ptr
    addi t4 t4 1  # inc dict name ptr
    jal zero lookup_strncmp_body
lookup_found:
    addi a2 t0 0  # a2 = addr of found word in dict
    jalr zero ra 0  # return

# Procedure: align
# Usage: jal ra align
# Arg: a3 = value to be aligned
# Ret: a3 = value after alignment
align:
    andi t0 a3 0b11  # t0 = bottom 2 bits of a3
    beq t0 zero align_done  # if they are zero, then a3 is a multiple of 4
    addi a3 a3 1  # else inc a3 by 1
    jal zero align  # and loop again
align_done:
    jalr zero ra 0  # return

# Procedure: pad
# Usage: jal ra pad
# Arg: a4 = addr to be padded
# Ret: a4 = addr after padding
pad:
    andi t0 a4 0b11  # t0 = bottom 2 bits of a4
    beq t0 zero pad_done  # if they are zero, then a4 is a multiple of 4
    sb a4 zero 0  # write a 0 to addr at a4
    addi a4 a4 1  # inc a4 by 1
    jal zero pad  # loop again
pad_done:
    jalr zero ra 0  # return

# Procedure: getc
# Usage: jal ra getc
# Ret: a5 = character received from serial
getc:
    # t1 = stat, t2 = data
    lui t0 %hi(USART_BASE_ADDR_0)
    addi t0 t0 %lo(USART_BASE_ADDR_0)
    addi t1 t0 USART_STAT_OFFSET
    addi t2 t0 USART_DATA_OFFSET
getc_wait:
    lw t3 t1 0  # load stat into t3
    andi t3 t3 (1 << 5)  # isolate RBNE bit
    beq t3 zero getc_wait  # keep looping until ready to recv
    lw a5 t2 0  # load char into a5
    jalr zero ra 0  # return

# Procedure: putc
# Usage: jal ra putc
# Arg: a5 = character to send over serial
putc:
    # t1 = stat, t2 = data
    lui t0 %hi(USART_BASE_ADDR_0)
    addi t0 t0 %lo(USART_BASE_ADDR_0)
    addi t1 t0 USART_STAT_OFFSET
    addi t2 t0 USART_DATA_OFFSET
putc_wait:
    lw t3 t1 0  # load stat into t3
    andi t3 t3 (1 << 7)  # isolate TBE bit
    beq t3 zero putc_wait  # keep looping until ready to send
    sw t2 a5 0  # write char from a5
    jalr zero ra 0  # return

###
### main program starts here
###

# Init serial comm via USART0:
# 1. RCU APB2 enable GPIOA (1 << 2)
# 2. RCU APB2 enable USART0 (1 << 14)
# 3. GPIOA config pin 9 (ctl = OUT_ALT_PUSH_PULL, mode = OUT_50MHZ)
#   Pin 9 offset = ((PIN - 8) * 4) = 4
# 4. GPIOA config pin 10 (ctl = IN_FLOATING, mode = IN)
#   Pin 10 offset = ((PIN - 8) * 4) = 8
# 5. USART0 config baud (CLOCK // BAUD = 69)
# 6. USART0 enable RX (1 << 2)
# 7. USART0 enable TX (1 << 3)
# 7. USART0 enable USART (1 << 13)
start:
    # setup addr and load current APB2EN config into t1
    lui t0 %hi(RCU_BASE_ADDR)
    addi t0 t0 %lo(RCU_BASE_ADDR)
    addi t0 t0 RCU_APB2EN_OFFSET
    lw t1 t0 0

    # setup enable bit for AFIO
    addi t2 zero 1
    or t1 t1 t2

    # setup enable bit for GPIO A
    addi t2 zero 1
    slli t2 t2 2
    or t1 t1 t2

    # setup enable bit for GPIO C
    addi t2 zero 1
    slli t2 t2 4
    or t1 t1 t2

    # setup enable bit for USART 0
    addi t2 zero 1
    slli t2 t2 14
    or t1 t1 t2

    # store APB2EN config
    sw t0 t1 0

    # setup addr and load current GPIO A config into t1
    lui t0 %hi(GPIO_BASE_ADDR_A)
    addi t0 t0 %lo(GPIO_BASE_ADDR_A)
    addi t0 t0 GPIO_CTL1_OFFSET
    lw t1 t0 0

    # clear existing config (pin 9)
    addi t2 zero 0b1111
    slli t2 t2 4
    xori t2 t2 -1
    and t1 t1 t2

    # setup config bits (pin 9)
    addi t2 zero (GPIO_CTL_OUT_ALT_PUSH_PULL << 2 | GPIO_MODE_OUT_50MHZ)
    slli t2 t2 4
    or t1 t1 t2

    # clear existing config (pin 10)
    addi t2 zero 0b1111
    slli t2 t2 8
    xori t2 t2 -1
    and t1 t1 t2

    # setup config bits (pin 10)
    addi t2 zero (GPIO_CTL_IN_FLOATING << 2 | GPIO_MODE_IN)
    slli t2 t2 8
    or t1 t1 t2

    # store GPIO A config
    sw t0 t1 0

    # setup addr for USART 0
    lui t0 %hi(USART_BASE_ADDR_0)
    addi t0 t0 %lo(USART_BASE_ADDR_0)

    # set baud rate clkdiv
    addi t1 t0 USART_BAUD_OFFSET
    addi t2 zero CLOCK_FREQ // USART_BAUD
    sw t1 t2 0

    # load current USART 0 config into t1
    addi t0 t0 USART_CTL0_OFFSET
    lw t1 t0 0

    # setup enable bit for RX
    addi t2 zero 1
    slli t2 t2 2
    or t1 t1 t2

    # setup enable bit for TX
    addi t2 zero 1
    slli t2 t2 3
    or t1 t1 t2

    # setup enable bit for USART
    addi t2 zero 1
    slli t2 t2 13
    or t1 t1 t2

    # store USART 0 config
    sw t0 t1 0

    # set HERE var to "here" location
    lui HERE %hi(RAM_BASE_ADDR)
    addi HERE HERE %lo(RAM_BASE_ADDR)
    addi HERE HERE here

    # set LATEST var to "latest" location
    lui LATEST %hi(RAM_BASE_ADDR)
    addi LATEST LATEST %lo(RAM_BASE_ADDR)
    addi LATEST LATEST latest

    jal zero init

# print error indicator and fall through into reset
error:
    addi a5 zero 32  # space
    jal ra putc
    addi a5 zero 63  # ?
    jal ra putc
    addi a5 zero 10  # newline
    jal ra putc

init:
    # set working register to zero
    addi W zero 0

    # setup data stack pointer
    lui DSP %hi(RAM_BASE_ADDR + DATA_STACK_BASE)
    addi DSP DSP %lo(RAM_BASE_ADDR + DATA_STACK_BASE)

    # setup return stack pointer
    lui RSP %hi(RAM_BASE_ADDR + RETURN_STACK_BASE)
    addi RSP RSP %lo(RAM_BASE_ADDR + RETURN_STACK_BASE)

    # set STATE var to zero
    addi STATE zero 0

    # set TIB var to TIB_BASE
    lui TIB %hi(RAM_BASE_ADDR + TIB_BASE)
    addi TIB TIB %lo(RAM_BASE_ADDR + TIB_BASE)

jal zero interpreter

# print "ok" and fall through into interpreter
interpreter_ok:
    addi a5 zero 32  # space
    jal ra putc
    addi a5 zero 111  # o
    jal ra putc
    addi a5 zero 107  # k
    jal ra putc
    addi a5 zero 10  # newline
    jal ra putc

# main interpreter loop
interpreter:

# fill TIB with zeroes
tib_clear:
    addi t0 TIB 0  # t0 = addr of TIB
    addi t1 zero TIB_SIZE  # t1 = size of TIB (1024)
tib_clear_body:
    sb t0 zero 0  # [t0] <- 0
tib_clear_next:
    addi t0 t0 1  # t0 += 1
    addi t1 t1 -1  # t1 -= 1
    bne t1 zero tib_clear_body  # keep looping til t1 == 0
tib_clear_done:
    addi TBUF TIB 0  # set TBUF to TIB
    addi TLEN zero 0  # set TLEN to zero
    addi TPOS zero 0  # set TPOS to zero

interpreter_repl:
    jal ra getc  # read char into a5
    jal ra putc  # echo back
    addi t0 zero 8  # load backspace char into t0
    bne a5 t0 interpreter_repl_char  # proceed normally if not a BS
    beq TLEN zero interpreter_repl  # ignore BS if TLEN is zero
    addi TLEN TLEN -1  # dec TLEN, effectively erasing a character
    jal zero interpreter_repl  # loop back to top of REPL
interpreter_repl_char:
    add t0 TBUF TLEN  # t0 = dest addr for this char in TBUF
    sw t0 a5 0  # write char into TBUF
    addi TLEN TLEN 1  # TLEN += 1
    addi t0 zero 10  # t0 = newline char
    beq a5 t0 interpreter_interpret  # interpreter the input upon newline
    jal zero interpreter_repl  # else wait for more input

interpreter_interpret:
    jal ra token  # call token procedure (a0 = addr, a1 = len)
    beq a0 zero interpreter_ok  # loop back to REPL if input is used up

    jal ra lookup  # call lookup procedure (a2 = addr of word to lookup)
    beq a2 zero error  # error and reset if word isn't found

    # decide whether to compile or execute the word
    lb t0 a2 4  # load word flags | len into t0
    andi t0 t0 F_IMMEDIATE  # isolate immediate flag
    bne t0 zero interpreter_execute  # execute if word is immediate
    beq STATE zero interpreter_execute  # execute if STATE is zero
interpreter_compile:
    # otherwise compile
    addi t0 a2 5  # t0 = start of word name
    add t0 t0 a1  # skip to end of word name
    addi a3 t0 0  # setup arg for align
    jal ra align  # align to start of code word (a3 = addr of code word)
    sw HERE a3 0  # write addr of code word to definition
    addi HERE HERE 4  # HERE += 4
    jal zero interpreter_interpret
interpreter_execute:
    # set IP to double-indirect addr back to interpreter loop
    lui IP %hi RAM_BASE_ADDR
    addi IP IP %lo RAM_BASE_ADDR
    addi IP IP interpreter_addr_addr
    # word is found and located at a2
    addi W a2 5  # skip to end of word name (skip link and len)
    add W W a1  # point W to end of word name (might need padding)
    addi a3 W 0  # setup arg for align (a3 = W)
    jal ra align  # call align procedure
    addi W a3 0  # handle ret from align (W = a3)
    # at this point, W holds the addr of the target word's code field
    lw t0 W 0  # load code addr into t0 (t0 now holds the addr of the word's body)
    jalr zero t0 0  # execute the word

interpreter_addr:
    pack <I %position interpreter_interpret RAM_BASE_ADDR
interpreter_addr_addr:
    pack <I %position interpreter_addr RAM_BASE_ADDR

# not technically required by should be here since the prev item wasn't an inst
align 4

# standard forth routine: next
next:
    lw W IP 0
    addi IP IP 4
    lw t0 W 0
    jalr zero t0 0

# standard forth routine: enter
enter:
    sw RSP IP 0
    addi RSP RSP 4
    addi IP W 4  # skip code field
    jal zero next

###
### dictionary starts here
###

word_exit:
    pack <I 0
    pack <B 4
    string "exit"
    align 4
code_exit:
    pack <I %position body_exit RAM_BASE_ADDR
body_exit:
    addi RSP RSP -4
    lw IP RSP 0
    jal zero next

# TODO: error if word name is loo long (> 63) (len & F_LENGTH != 0)
word_colon:
    pack <I %position word_exit RAM_BASE_ADDR
    pack <B 1
    string ":"
    align 4
code_colon:
    pack <I %position body_colon RAM_BASE_ADDR
body_colon:
    jal ra token  # a0 = addr, a1 = len
    sw HERE LATEST 0  # write link to prev word (write LATEST to HERE)
    sb HERE a1 4  # write word len
    addi LATEST HERE 0  # set LATEST = HERE (before HERE gets modified)
    addi HERE HERE 5  # move HERE past link and len (to start of name)
strncpy:
    addi t0 a0 0  # t0 = strncpy src
    addi t1 HERE 0  # t1 = strncpy dest
    addi t2 a1 0  # t2 = strncpy len
strncpy_body:
    lbu t3 t0 0  # t3 <- [src]
    sb t1 t3 0  # [dest] <- t3
strncpy_next:
    addi t2 t2 -1  # len--
    beq t2 zero strncpy_done  # done if len == 0
    addi t0 t0 1  # src++
    addi t1 t1 1  # dest++
    jal zero strncpy_body  # copy next char
strncpy_done:
    addi HERE t1 1  # HERE = end of word, need +1 cuz still on last char of name
    addi a4 HERE 0  # setup arg for pad (a4 = HERE)
    jal ra pad  # call pad procedure
    addi HERE a4 0  # handle ret from pad (HERE = a4)
    # load addr of "enter" into t0
    lui t0 %hi(RAM_BASE_ADDR)
    addi t0 t0 %lo(RAM_BASE_ADDR)
    addi t0 t0 enter
    sw HERE t0 0  # write addr of "enter" to word definition
    addi HERE HERE 4  # HERE += 4
    addi STATE zero 1  # STATE = 1 (compile)
    jal zero next  # next

word_semi:
    pack(<I, %position(word_colon, RAM_BASE_ADDR))
    pack(<B, F_IMMEDIATE | 1)
    string ";"
    align 4
code_semi:
    pack <I %position(body_semi, RAM_BASE_ADDR)
body_semi:
    # load addr of "code_exit" into t0
    lui t0 %hi(RAM_BASE_ADDR)
    addi t0 t0 %lo(RAM_BASE_ADDR)
    addi t0 t0 code_exit
    sw HERE t0 0  # write addr of "code_exit" to word definition
    addi HERE HERE 4  # HERE += 4
    addi STATE zero 0  # STATE = 0 (execute)
    jal zero next  # next

word_key:
    pack <I %position word_semi RAM_BASE_ADDR
    pack <B 3
    string "key"
    align 4
code_key:
    pack <I %position body_key RAM_BASE_ADDR
body_key:
    # call getc (a5 = char)
    jal ra getc

    # isolate bottom 8 bits (ascii)
    andi a5 a5 0xff

    # push char onto stack
    sw DSP a5 0
    addi DSP DSP 4

    # next
    jal zero next

word_emit:
    pack <I %position word_key RAM_BASE_ADDR
    pack <B 4
    string "emit"
    align 4
code_emit:
    pack <I %position body_emit RAM_BASE_ADDR
body_emit:
    # pop char into a5
    addi DSP DSP -4
    lw a5 DSP 0

    # isolate bottom 8 bits (ascii)
    andi a5 a5 0xff

    # call putc (char = a5)
    jal ra putc

    # next
    jal zero next

word_at:
    pack <I %position word_emit RAM_BASE_ADDR
    pack <B 1
    string "@"
    align 4
code_at:
    pack <I %position body_at RAM_BASE_ADDR
body_at:
    # pop addr into t0
    addi DSP DSP -4
    lw t0 DSP 0

    # load value from addr
    lw t0 t0 0

    # push value onto stack
    sw DSP t0 0
    addi DSP DSP 4

    # next
    jal zero next

word_ex:
    pack <I %position word_at RAM_BASE_ADDR
    pack <B 1
    string "!"
    align 4
code_ex:
    pack <I %position body_ex RAM_BASE_ADDR
body_ex:
    # pop addr into t0
    addi DSP DSP -4
    lw t0 DSP 0

    # pop value into t1
    addi DSP DSP -4
    lw t1 DSP 0

    # store value to addr
    sw t0 t1 0

    # next
    jal zero next

word_spat:
    pack <I %position word_ex RAM_BASE_ADDR
    pack <B 3
    string "sp@"
    align 4
code_spat:
    pack <I %position body_spat RAM_BASE_ADDR
body_spat:
    # copy DSP into t0 and decrement to current top value
    addi t0 DSP 0
    addi t0 t0 -4

    # push t0 onto stack
    sw DSP t0 0
    addi DSP DSP 4

    # next
    jal zero next

word_rpat:
    pack <I %position word_spat RAM_BASE_ADDR
    pack <B 3
    string "rp@"
    align 4
code_rpat:
    pack <I %position body_rpat RAM_BASE_ADDR
body_rpat:
    # copy RSP into t0 and decrement to current top value
    addi t0 RSP 0
    addi t0 t0 -4

    # push t0 onto stack
    sw DSP t0 0
    addi DSP DSP 4

    # next
    jal zero next

word_zeroeq:
    pack <I %position word_rpat RAM_BASE_ADDR
    pack <B 2
    string "0="
    align 4
code_zeroeq:
    pack <I %position body_zeroeq RAM_BASE_ADDR
body_zeroeq:
    # pop value into t0
    addi DSP DSP -4
    lw t0 DSP 0
    # check equality between t0 and 0
    addi t1 zero 0  # setup result (0 if nonzero)
    bne t0 zero notzero
    addi t1 zero -1  # -1 if zero
notzero:
    # push result of comparison onto stack
    sw DSP t1 0
    addi DSP DSP 4
    # next
    jal zero next

word_plus:
    pack <I %position word_zeroeq RAM_BASE_ADDR
    pack <B 1
    string "+"
    align 4
code_plus:
    pack <I %position body_plus RAM_BASE_ADDR
body_plus:
    # pop first value into t0
    addi DSP DSP -4
    lw t0 DSP 0
    # pop second value into t1
    addi DSP DSP -4
    lw t1 DSP 0
    # add the two together into t0
    add t0 t0 t1
    # push resulting sum onto stack
    sw DSP t0 0
    addi DSP DSP 4
    # next
    jal zero next

# mark the latest builtin word (nand)
latest:
word_nand:
    pack <I %position word_plus RAM_BASE_ADDR
    pack <B 4
    string "nand"
    align 4
code_nand:
    pack <I %position body_nand RAM_BASE_ADDR
body_nand:
    # pop first value into t0
    addi DSP DSP -4
    lw t0 DSP 0
    # pop second value into t1
    addi DSP DSP -4
    lw t1 DSP 0
    # AND the two together into t0
    and t0 t0 t1
    # NOT the value into t0 (via a XOR with -1)
    xori t0 t0 -1
    # push resulting value onto stack
    sw DSP t0 0
    addi DSP DSP 4
    # next
    jal zero %offset next

# mark the location of the next new word
here:
