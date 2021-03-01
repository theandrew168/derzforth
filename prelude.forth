\ duplicate the item on top of the stack
: dup sp@ @ ;

\ basic decimal numbers
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
: 16 8 8 + ;

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
