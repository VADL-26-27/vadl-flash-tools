# boards/f411.mk
# Make-syntax board config (used by Makefile.common; separate from
# boards/f411.conf used by flash.sh and boards/f411.ps1 used by flash.ps1)
MCU_CPU       = cortex-m4
MCU_FPU       = fpv4-sp-d16
MCU_FLOAT_ABI = hard
MCU_DEFINE    = STM32F411xE
STARTUP_FILE  = startup/startup_stm32f411xe.s