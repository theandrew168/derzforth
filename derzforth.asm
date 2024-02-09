# jump to "main" since programs execute top to bottom
# we do this to enable writing helper funcs at the top
tail main

# pull in the necessary defs / funcs for a given board
#  (based on the assembler's search path)
#
# this file should define:
#   RAM_BASE_ADDR
#   RAM_SIZE
#   ROM_BASE_ADDR
#   ROM_SIZE
#
# and implement:
#   serial_init(a0: baud_rate)
#   serial_getc() -> a0: char
#   serial_putc(a0: char)
include board.asm


#  16KB      Memory Map
# 0x0000 |----------------|
#        |                |
#        |                |
#        |                |
#        |   Interpreter  |
#        |       +        | 12KB
#        |   Dictionary   |
#        |                |
#        |                |
#        |                |
# 0x3000 |----------------|
#        |      TIB       | 1KB
# 0x3400 |----------------|
#        |  Return Stack  | 1KB (256 calls deep)
# 0x3800 |----------------|
#        |                |
#        |   Data Stack   | 2KB (512 elements)
#        |                |
# 0x4000 |----------------|

INTERPRETER_BASE_ADDR  = 0x0000
TIB_BASE_ADDR          = 0x3000
RETURN_STACK_BASE_ADDR = 0x3400
DATA_STACK_BASE_ADDR   = 0x3800

INTERPRETER_SIZE  = 0x3000  # 12KB
TIB_SIZE          = 0x0400  # 1KB
RETURN_STACK_SIZE = 0x0400  # 1KB
DATA_STACK_SIZE   = 0x0800  # 2KB

DERZFORTH_SIZE = 0x4000  # 16KB
HEAP_BASE_ADDR = RAM_BASE_ADDR + DERZFORTH_SIZE
HEAP_SIZE      = RAM_SIZE - DERZFORTH_SIZE

SERIAL_BAUD_RATE = 115200

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
# use one of these for heap size tracking?
SAVED0 = s8
SAVED1 = s9
SAVED2 = s10
SAVED3 = s11


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
# Ret: a2 = total bytes consumed (0 if not found)
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

    # skip if the word is hidden
    li t1, F_HIDDEN            # load hidden flag into t1
    and t1, t0, t1             # isolate hidden bit in word hash
    bnez t1, lookup_next       # if hidden, skip this word and try the next one

    li t1, ~FLAGS_MASK         # t1 = inverted FLAGS_MASK
    and t0, t0, t1             # ignore flags when comparing hashes
    beq t0, a1, lookup_found   # done if hash (dict) matches hash (lookup)
lookup_next:
    lw a0, 0(a0)               # follow link to next word in dict
    j lookup                   # repeat
lookup_found:
    # a0 is already pointing at the current dict entry
    ret
lookup_not_found:
    addi a0, zero, 0           # a0 = 0 (not found)
    ret


# Func: djb2_hash
# Arg: a0 = buffer addr
# Arg: a1 = buffer size
# Ret: a0 = hash value
djb2_hash:
    li t0, 5381         # t0 = hash value
djb2_hash_loop:
    beqz a1, djb2_hash_done
    lbu t2, 0(a0)       # c <- [addr]
    slli t1, t0, 5      # t1 = h * 32
    add t0, t1, t0      # h = t1 + h, so h = h * 33
    add t0, t0, t2      # h = h + c
    addi a0, a0, 1      # addr += 1
    addi a1, a1, -1     # size -= 1
    j djb2_hash_loop    # repeat
djb2_hash_done:
    li t1, ~FLAGS_MASK  # clear the top two bits (used for word flags)
    and a0, t0, t1      # a0 = final hash value
    ret


###
### interpreter
###

main:
    li a0, SERIAL_BAUD_RATE
    call serial_init

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
    # print " ?" and fall into reset
    li a0, ' '
    call serial_putc
    li a0, '?'
    call serial_putc
    li a0, '\n'
    call serial_putc

reset:
    # set working reg to zero
    li W, 0

    # set interpreter state reg to 0 (execute)
    li STATE, 0

    # setup data stack ptr
    li DSP, RAM_BASE_ADDR + DATA_STACK_BASE_ADDR

    # setup return stack ptr
    li RSP, RAM_BASE_ADDR + RETURN_STACK_BASE_ADDR

    # setup text input buffer addr
    li TIB, RAM_BASE_ADDR + TIB_BASE_ADDR

    j interpreter

interpreter_ok:
    # print "ok" and fall into interpreter
    li a0, ' '
    call serial_putc
    li a0, 'o'
    call serial_putc
    li a0, 'k'
    call serial_putc
    li a0, '\n'
    call serial_putc

interpreter:

tib_clear:
    mv a0, TIB       # a0 = buffer addr
    li a1, TIB_SIZE  # a1 = buffer size
    call memclr      # clear out the text input buffer

tib_init:
    mv TBUF, TIB  # set TBUF to TIB
    li TLEN, 0    # set TLEN to 0
    li TPOS, 0    # set TPOS to 0

interpreter_repl:
    # read and echo a single char
    call serial_getc
    call serial_putc

    # check for single-line comment
    li t0, '\\'                           # comments start with \ char
    beq a0, t0, interpreter_skip_comment  # skip the comment if \ is found

    # check for bounded comments (parens)
    li t0, 0x28                           # bounded comments start with ( char
    beq a0, t0, interpreter_skip_parens   # skip the comment if ( is found

    # check for backspace
    li t0, '\b'
    bne a0, t0, interpreter_repl_char
    beqz TLEN, interpreter_repl  # ignore BS if TLEN is zero

    # if backspace, dec TLEN and send a space and another backspace
    #   this simulates clearing the char on the client side
    addi TLEN, TLEN, -1
    li a0, ' '
    call serial_putc
    li a0, '\b'
    call serial_putc

    j interpreter_repl

interpreter_skip_comment:
    # read and echo a single char
    call serial_getc
    call serial_putc

    # skip char until newline is found
    li t0, '\n'                           # newlines start with \n
    bne a0, t0, interpreter_skip_comment  # loop back to SKIP comment unless newline
    j interpreter_repl

interpreter_skip_parens:
    # read and echo a single char
    call serial_getc
    call serial_putc

    # skip char until closing parens is found
    li t0, 0x29                           # closing parens start with )
    bne a0, t0, interpreter_skip_parens   # loop back to SKIP parens unless closing parens
    j interpreter_repl

interpreter_repl_char:
    add t0, TBUF, TLEN   # t0 = dest addr for this char in TBUF
    li t1, TIB_SIZE      # t1 = buffer size
    bge TLEN, t1, error  # bounds check on TBUF
    sb a0, 0(t0)         # write char into TBUF
    addi TLEN, TLEN, 1   # TLEN += 1
    addi t0, zero, '\n'  # t0 = newline char
    beq a0, t0, interpreter_interpret  # interpret the input upon newline
    j interpreter_repl

# TODO: allow multiline word defs
interpreter_interpret:
    # grab the next token
    add a0, TBUF, TPOS       # a0 = buffer addr
    sub a1, TLEN, TPOS       # a1 = buffer size
    call strtok              # a0 = str addr, a1 = str size, a2 = bytes consumed
    beqz a0, interpreter_ok  # loop back to REPL if input is used up
    add TPOS, TPOS, a2       # update TPOS based on strtok bytes consumed

    # hash the current token
    call djb2_hash  # a0 = str hash

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
    addi t0, a0, 8      # t0 = addr of word's code field
    sw t0, 0(HERE)      # write addr of word's code field to current definition
    addi HERE, HERE, 4  # HERE += 4
    j interpreter_interpret

interpreter_execute:
    # setup double-indirect addr back to interpreter loop
    li IP, %position(interpreter_addr_addr, RAM_BASE_ADDR)
    addi W, a0, 8  # W = addr of word's code field
    lw t0, 0(W)    # t0 = addr of word's body
    jr t0          # execute the word


align 4
interpreter_addr:
    dw %position(interpreter_interpret, RAM_BASE_ADDR)
interpreter_addr_addr:
    dw %position(interpreter_addr, RAM_BASE_ADDR)

# standard forth routine: next
next:
    lw W, 0(IP)     # W <- [IP]
    addi IP, IP, 4  # IP += 4
    lw t0, 0(W)     # t0 <- [W]
    jr t0

# standard forth routine: enter
enter:
    sw IP, 0(RSP)     # IP -> [RSP]
    addi RSP, RSP, 4  # RSP += 4
    addi IP, W, 4     # IP = W + 4 (skip code field)
    j next


###
### dictionary
###

align 4
word_exit:
    dw 0
    dw 0x3c967e3f  # djb2_hash('exit')
code_exit:
    dw %position(body_exit, RAM_BASE_ADDR)
body_exit:
    addi RSP, RSP, -4  # dec return stack ptr
    lw IP, 0(RSP)      # load next addr into IP
    j next

align 4
word_colon:
    dw %position(word_exit, RAM_BASE_ADDR)
    dw 0x0002b5df  # djb2_hash(':')
code_colon:
    dw %position(body_colon, RAM_BASE_ADDR)
body_colon:
    # grab the next token
    add a0, TBUF, TPOS   # a0 = buffer addr
    sub a1, TLEN, TPOS   # a1 = buffer size
    call strtok          # a0 = str addr, a1 = str size
    beqz a0, error       # error and reset if strtok fails
    add TPOS, TPOS, a2   # update TPOS based on strtok bytes consumed

    # hash the current token
    call djb2_hash       # a0 = str hash

    # set the hidden flag
    li t0, F_HIDDEN      # load hidden flag into t0
    or a0, a0, t0        # hide the word

    # write the word's link and hash
    sw LATEST, 0(HERE)   # write link to prev word (LATEST -> [HERE])
    sw a0, 4(HERE)       # write word name hash (hash -> [HERE + 4])
    mv LATEST, HERE      # set LATEST = HERE (before HERE gets modified)
    addi HERE, HERE, 8   # move HERE past link and hash (to start of code)

    # set word's code field to "enter"
    li t0, %position(enter, RAM_BASE_ADDR)
    sw t0, 0(HERE)       # write addr of "enter" to word definition
    addi HERE, HERE, 4   # HERE += 4
    addi STATE, zero, 1  # STATE = 1 (compile)
    j next

align 4
word_semi:
    dw %position(word_colon, RAM_BASE_ADDR)
    dw 0x0002b5e0 | F_IMMEDIATE  # djb2_hash(';') or'd w/ F_IMMEDIATE flag
code_semi:
    dw %position(body_semi, RAM_BASE_ADDR)
body_semi:
    # clear the hidden flag
    lw t0, 4(LATEST)     # load word name hash (t0 <- [LATEST+4])
    li t1, ~F_HIDDEN     # load hidden flag mask into t1
    and t0, t0, t1       # reveal the word
    sw t0, 4(LATEST)     # write word name hash (t0 -> [LATEST+4])

    li t0, %position(code_exit, RAM_BASE_ADDR)
    sw t0, 0(HERE)       # write addr of "code_exit" to word definition
    addi HERE, HERE, 4   # HERE += 4
    addi STATE, zero, 0  # STATE = 0 (execute)
    j next

align 4
word_at:
    dw %position(word_semi, RAM_BASE_ADDR)
    dw 0x0002b5e5  # djb2_hash('@')
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
    dw 0x0002b5c6  # djb2_hash('!')
code_ex:
    dw %position(body_ex, RAM_BASE_ADDR)
body_ex:
    addi DSP, DSP, -8  # dec data stack ptr
    lw t0, 4(DSP)      # pop addr into t0
    lw t1, 0(DSP)      # pop value into t1
    sw t1, 0(t0)       # store value at addr
    j next

align 4
word_spat:
    dw %position(word_ex, RAM_BASE_ADDR)
    dw 0x0b88aac8  # djb2_hash('sp@')
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
    dw 0x0b88a687  # djb2_hash('rp@')
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
    dw 0x005970b2  # djb2_hash('0=')
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
    dw 0x0002b5d0  # djb2_hash('+')
code_plus:
    dw %position(body_plus, RAM_BASE_ADDR)
body_plus:
    addi DSP, DSP, -8  # dec data stack ptr
    lw t0, 4(DSP)      # pop first value into t0
    lw t1, 0(DSP)      # pop second value into t1
    add t0, t0, t1     # ADD the values together into t0
    sw t0, 0(DSP)      # push value onto stack
    addi DSP, DSP, 4   # inc data stack ptr
    j next

align 4
word_nand:
    dw %position(word_plus, RAM_BASE_ADDR)
    dw 0x3c9b0c66  # djb2_hash('nand')
code_nand:
    dw %position(body_nand, RAM_BASE_ADDR)
body_nand:
    addi DSP, DSP, -8  # dec data stack ptr
    lw t0, 4(DSP)      # pop first value into t0
    lw t1, 0(DSP)      # pop second value into t1
    and t0, t0, t1     # AND the values together into t0
    not t0, t0         # NOT t0 (invert the bits)
    sw t0, 0(DSP)      # push value onto stack
    addi DSP, DSP, 4   # inc data stack ptr
    j next

#STATE  = s1  # 0 = execute, 1 = compile
#TIB    = s2  # text input buffer addr
#TBUF   = s3  # text buffer addr
#TLEN   = s4  # text buffer length
#TPOS   = s5  # text buffer current position
#HERE   = s6  # next dict entry addr
#LATEST = s7  # latest dict entry addr

align 4
word_state:
    dw %position(word_nand, RAM_BASE_ADDR)
    dw 0x10614a06  # djb2_hash('state')
code_state:
    dw %position(body_state, RAM_BASE_ADDR)
body_state:
    sw STATE, 0(DSP)
    addi DSP, DSP, 4
    j next

align 4
word_tib:
    dw %position(word_state, RAM_BASE_ADDR)
    dw 0x0b88ae44  # djb2_hash('tib')
code_tib:
    dw %position(body_tib, RAM_BASE_ADDR)
body_tib:
    sw TIB, 0(DSP)
    addi DSP, DSP, 4
    j next

align 4
word_toin:
    dw %position(word_tib, RAM_BASE_ADDR)
    dw 0x0b87c89a  # djb2_hash('>in')
code_toin:
    dw %position(body_toin, RAM_BASE_ADDR)
body_toin:
    sw TPOS, 0(DSP)
    addi DSP, DSP, 4
    j next

align 4
word_here:
    dw %position(word_toin, RAM_BASE_ADDR)
    dw 0x3c97d3a9  # djb2_hash('here')
code_here:
    dw %position(body_here, RAM_BASE_ADDR)
body_here:
    sw HERE, 0(DSP)
    addi DSP, DSP, 4
    j next

align 4
word_latest:
    dw %position(word_here, RAM_BASE_ADDR)
    dw 0x0ae8ca72  # djb2_hash('latest')
code_latest:
    dw %position(body_latest, RAM_BASE_ADDR)
body_latest:
    sw LATEST, 0(DSP)
    addi DSP, DSP, 4
    j next

align 4
word_key:
    dw %position(word_latest, RAM_BASE_ADDR)
    dw 0x0b88878e  # djb2_hash('key')
code_key:
    dw %position(body_key, RAM_BASE_ADDR)
body_key:
    call serial_getc  # read char into a0 via serial_getc
    sw a0, 0(DSP)     # push char onto stack
    addi DSP, DSP, 4  # inc data stack ptr
    j next

align 4
latest:  # mark the latest builtin word
word_emit:
    dw %position(word_key, RAM_BASE_ADDR)
    dw 0x3c964f74  # djb2_hash('emit')
code_emit:
    dw %position(body_emit, RAM_BASE_ADDR)
body_emit:
    addi DSP, DSP, -4  # dec data stack ptr
    lw a0, 0(DSP)      # pop char into a1
    call serial_putc   # emit the char via serial_putc
    j next

align 4
here:  # next new word will go here
