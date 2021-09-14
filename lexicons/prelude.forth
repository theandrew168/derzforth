\ duplicate the item on top of the stack
: dup sp@ @ ;

\ basic decimal numbers (0-32)
: -1 dup dup nand dup dup nand nand ;
: 0 -1 dup nand ;
: 1 -1 dup + dup nand ;
: 2 1 1 + ;
: 3 2 1 + ;
: 4 2 2 + ;
: 5 4 1 + ;
: 6 4 2 + ;
: 7 4 3 + ;
: 8 4 4 + ;
: 9 8 1 + ;
: 10 8 2 + ;
: 11 8 3 + ;
: 12 8 4 + ;
: 13 12 1 + ;
: 14 12 2 + ;
: 15 12 3 + ;
: 16 12 4 + ;
: 17 16 1 + ;
: 18 16 2 + ;
: 19 16 3 + ;
: 20 16 4 + ;
: 21 20 1 + ;
: 22 20 2 + ;
: 23 20 3 + ;
: 24 20 4 + ;
: 25 24 1 + ;
: 26 24 2 + ;
: 27 24 3 + ;
: 28 24 4 + ;
: 29 28 1 + ;
: 30 28 2 + ;
: 31 28 3 + ;
: 32 28 4 + ;

\ inversion and negation
: invert dup nand ;
: negate invert 1 + ;
: - negate + ;

\ stack manipulation words
: drop dup - + ;
: over sp@ 4 - @ ;
: swap over over sp@ 12 - ! sp@ 4 - ! ;
: nip swap drop ;
: 2dup over over ;
: 2drop drop drop ;

\ logic operators
: and nand invert ;
: or invert swap invert and invert ;

\ equality checks
: = - 0= ;
: <> = invert ;

\ left shift operators (1, 4, and 8 bits)
: 2* dup + ;
: 16* 2* 2* 2* 2* ;
: 256* 16* 16* ;

\ basic binary numbers
: 0b00 0 ;
: 0b01 1 ;
: 0b10 2 ;
: 0b11 3 ;
: 0b1111 15 ;

\ basic hex numbers
: 0x00 0 ;
: 0x04 1 2* 2* ;
: 0x08 1 2* 2* 2* ;
: 0x0c 0x08 0x04 or ;
: 0x10 1 16* ;
: 0x14 0x10 0x04 or ;
: 0x18 0x10 0x08 or ;
: 0x1c 0x10 0x0c or ;
: 0x20 1 16* 2* ;
: 0x24 0x20 0x04 or ;
: 0x28 0x20 0x08 or ;
: 0x2c 0x20 0x0c or ;
: 0x30 0x20 0x10 or ;
: 0x34 0x30 0x04 or ;
: 0x38 0x30 0x08 or ;
: 0x3c 0x30 0x0c or ;
: 0x40 1 16* 2* 2* ;
: 0x80 1 16* 2* 2* 2* ;

\ individual bits
: 0x00000000 0 ;
: 0x00000001 1 ;
: 0x00000002 2 ;
: 0x00000004 4 ;
: 0x00000008 8 ;
: 0x00000010 1 16* ;
: 0x00000020 2 16* ;
: 0x00000040 4 16* ;
: 0x00000080 8 16* ;
: 0x00000100 1 256* ;
: 0x00000200 2 256* ;
: 0x00000400 4 256* ;
: 0x00000800 8 256* ;
: 0x00001000 1 256* 16* ;
: 0x00002000 2 256* 16* ;
: 0x00004000 4 256* 16* ;
: 0x00008000 8 256* 16* ;
: 0x00010000 1 256* 256* ;
: 0x00020000 2 256* 256* ;
: 0x00040000 4 256* 256* ;
: 0x00080000 8 256* 256* ;
: 0x00100000 1 256* 256* 16* ;
: 0x00200000 2 256* 256* 16* ;
: 0x00400000 4 256* 256* 16* ;
: 0x00800000 8 256* 256* 16* ;
: 0x01000000 1 256* 256* 256* ;
: 0x02000000 2 256* 256* 256* ;
: 0x04000000 4 256* 256* 256* ;
: 0x08000000 8 256* 256* 256* ;
: 0x10000000 1 256* 256* 256* 16* ;
: 0x20000000 2 256* 256* 256* 16* ;
: 0x40000000 4 256* 256* 256* 16* ;
: 0x80000000 8 256* 256* 256* 16* ;

\ getting fancy
\ TODO: these wont work until I fix variables :(
\: , here @ ! here @ 4 + here ! ;
\: immediate latest @ 4 + dup @ 0x80000000 or swap ! ;
\: [ 0 state ! ; immediate
\: ] 1 state ! ;
\: branch rp@ @ dup @ + rp@ ! ;
