\ define GPIO base address
: 0x40010800 1 256* 256* 256* 16* 2* 2* 1 256* 256* 1 256* 2* 2* 2* or or ;
: GPIO_BASE_ADDR 0x40010800 ;

\ define offsets for each GPIO port
: GPIO_A_OFFSET 0x00 256* ;
: GPIO_B_OFFSET 0x04 256* ;
: GPIO_C_OFFSET 0x08 256* ;
: GPIO_D_OFFSET 0x0c 256* ;
: GPIO_E_OFFSET 0x10 256* ;

\ define addresses for each GPIO port
: GPIO_A_ADDR GPIO_BASE_ADDR GPIO_A_OFFSET + ;
: GPIO_B_ADDR GPIO_BASE_ADDR GPIO_B_OFFSET + ;
: GPIO_C_ADDR GPIO_BASE_ADDR GPIO_C_OFFSET + ;
: GPIO_D_ADDR GPIO_BASE_ADDR GPIO_D_OFFSET + ;
: GPIO_E_ADDR GPIO_BASE_ADDR GPIO_E_OFFSET + ;

\ define GPIO register offsets
: GPIO_CTL0_OFFSET 0x00 ;
: GPIO_CTL1_OFFSET 0x04 ;
: GPIO_ISTAT_OFFSET 0x08 ;
: GPIO_OCTL_OFFSET 0x0c ;
: GPIO_BOP_OFFSET 0x10 ;
: GPIO_BC_OFFSET 0x14 ;
: GPIO_LOCK_OFFSET 0x18 ;

\ define GPIO mode constants
: GPIO_MODE_IN 0b00 ;
: GPIO_MODE_OUT_10MHZ 0b01 ;
: GPIO_MODE_OUT_2MHZ 0b10 ;
: GPIO_MODE_OUT_50MHZ 0b11 ;

\ define GPIO input control constants
: GPIO_CTL_IN_ANALOG 0b00 ;
: GPIO_CTL_IN_FLOATING 0b01 ;
: GPIO_CTL_IN_PULL 0b10 ;
: GPIO_CTL_IN_RESERVED 0b11 ;

\ define GPIO output control constants
: GPIO_CTL_OUT_PUSH_PULL 0b00 ;
: GPIO_CTL_OUT_OPEN_DRAIN 0b01 ;
: GPIO_CTL_OUT_ALT_PUSH_PULL 0b10 ;
: GPIO_CTL_OUT_ALT_OPEN_DRAIN 0b11 ;

: rled
    GPIO_C_ADDR GPIO_CTL1_OFFSET + @                     \ load current control
    0b1111                                               \ setup mask for config pins
    256* 256* 16* invert and                             \ shift over and clear existing config for pin 13
    GPIO_CTL_OUT_PUSH_PULL 2* 2* GPIO_MODE_OUT_50MHZ or  \ setup GPIO CTL and MODE
    256* 256* 16* or                                     \ shift over and set new config for pin 13
    GPIO_C_ADDR GPIO_CTL1_OFFSET + !                     \ store new control
;
