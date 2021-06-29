# GD32VF103 Manual: Section 5.3
RCU_BASE_ADDR = 0x40021000

# GD32VF103 Manual: Section 5.3.7
RCU_APB2EN_OFFSET   = 0x18
RCU_APB2EN_AFEN_BIT = 0
RCU_APB2EN_PAEN_BIT = 2
RCU_APB2EN_PBEN_BIT = 3
RCU_APB2EN_PCEN_BIT = 4
RCU_APB2EN_PDEN_BIT = 5
RCU_APB2EN_PEEN_BIT = 6
RCU_APB2EN_USART0EN_BIT = 14

# GD32VF103 Manual: Section 7.5
AFIO_BASE_ADDR   = 0x40010000
GPIO_BASE_ADDR_A = 0x40010800
GPIO_BASE_ADDR_B = 0x40010c00
GPIO_BASE_ADDR_C = 0x40011000
GPIO_BASE_ADDR_D = 0x40011400
GPIO_BASE_ADDR_E = 0x40011800
GPIO_CTL0_OFFSET = 0x00  # GD32VF103 Manual: Section 7.5.1 (pins 0-7)
GPIO_CTL1_OFFSET = 0x04  # GD32VF103 Manual: Section 7.5.2 (pins 8-15)
GPIO_BOP_OFFSET  = 0x10  # GD32VF103 Manual: Section 7.5.5

# GD32VF103 Manual: Section 7.3
GPIO_MODE_IN        = 0b00
GPIO_MODE_OUT_10MHZ = 0b01
GPIO_MODE_OUT_2MHZ  = 0b10
GPIO_MODE_OUT_50MHZ = 0b11

# GD32VF103 Manual: Section 7.3
GPIO_CTL_IN_ANALOG    = 0b00
GPIO_CTL_IN_FLOATING  = 0b01
GPIO_CTL_IN_PULL_DOWN = 0b10
GPIO_CTL_IN_PULL_UP   = 0b11

# GD32VF103 Manual: Section 7.3
GPIO_CTL_OUT_PUSH_PULL      = 0b00
GPIO_CTL_OUT_OPEN_DRAIN     = 0b01
GPIO_CTL_OUT_ALT_PUSH_PULL  = 0b10
GPIO_CTL_OUT_ALT_OPEN_DRAIN = 0b11

# GD32VF103 Manual: Section 16.4
USART_BASE_ADDR_0 = 0x40013800

# GD32VF103 Manual: Section 16.4.1
USART_STAT_OFFSET   = 0x00
USART_STAT_RBNE_BIT = 5
USART_STAT_TBE_BIT  = 7

# GD32VF103 Manual: Section 16.4.2
USART_DATA_OFFSET = 0x04

# GD32VF103 Manual: Section 16.4.3
USART_BAUD_OFFSET = 0x08

# GD32VF103 Manual: Section 16.4.4
USART_CTL0_OFFSET = 0x0c
USART_CTL0_REN_BIT = 2
USART_CTL0_TEN_BIT = 3
USART_CTL0_UEN_BIT = 13