\ define RCU base address
: 0x40021000 1 256* 256* 256* 16* 2* 2* 1 256* 256* 2* 1 256* 16* or or ;
: RCU_BASE_ADDR 0x40021000 ;

\ define RCU register offsets
: RCU_CTL_OFFSET 0x00 ;
: RCU_CFG0_OFFSET 0x04 ;
: RCU_INT_OFFSET 0x08 ;
: RCU_APB2RST_OFFSET 0x0c ;
: RCU_APB1RST_OFFSET 0x10 ;
: RCU_AHBEN_OFFSET 0x14 ;
: RCU_APB2EN_OFFSET 0x18 ;
: RCU_APB1EN_OFFSET 0x1c ;
: RCU_BDCTL_OFFSET 0x20 ;
: RCU_RSTSCK_OFFSET 0x24 ;
: RCU_AHBRST_OFFSET 0x28 ;
: RCU_CFG1_OFFSET 0x2c ;
: RCU_DSV_OFFSET 0x34 ;

\ define RCU enable bits for GPIO ports
: RCU_GPIO_A_BIT 1 2* 2* ;
: RCU_GPIO_B_BIT 1 2* 2* 2* ;
: RCU_GPIO_C_BIT 1 2* 2* 2* 2* ;
: RCU_GPIO_D_BIT 1 2* 2* 2* 2* 2* ;
: RCU_GPIO_E_BIT 1 2* 2* 2* 2* 2* 2* ;

\ enable RCU for the bit pattern on top of the stack
: rcu_enable RCU_BASE_ADDR RCU_APB2EN_OFFSET + ! ;

\ enable RCU for GPIO ports A and C
RCU_GPIO_A_BIT RCU_GPIO_C_BIT or rcu_enable
