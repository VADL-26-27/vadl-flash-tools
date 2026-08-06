# boards/f446/build.mk
MCU_CPU       = cortex-m4
MCU_FPU       = fpv4-sp-d16
MCU_FLOAT_ABI = hard
MCU_DEFINE    = STM32F446xx
STARTUP_FILE  = startup/startup_stm32f446xx.s