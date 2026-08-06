# boards/h753.mk
MCU_CPU       = cortex-m7
MCU_FPU       = fpv5-d16
MCU_FLOAT_ABI = hard
MCU_DEFINE    = STM32H753xx
STARTUP_FILE  = startup/startup_stm32h753xx.s