# Makefile.common
# Shared build/flash logic for VADL STM32 firmware projects.
# Include this from a project's own Makefile after setting:
#   BOARD      - board name, must match boards/<BOARD>.mk (e.g. f411, h753)
#   SRC_DIRS   - directories to glob .c files from (e.g. src rtos)
#   LDSCRIPT   - path to the linker script
#   INCLUDES   - extra -I flags beyond inc/ (optional)
#   EXTRA_DEFS - extra -D flags (optional)
#
# Example project Makefile:
#   BOARD = f411
#   SRC_DIRS = src rtos
#   LDSCRIPT = ld/STM32F411RETx_FLASH.ld
#   include vadl-flash-tools/Makefile.common

ifndef BOARD
$(error BOARD is not set. Add "BOARD = <name>" to your Makefile before including Makefile.common)
endif

THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
TOOLS_DIR := $(dir $(THIS_MAKEFILE))

# Makefile.common
BOARD_MK := $(TOOLS_DIR)boards/$(BOARD)/build.mk

ifeq (,$(wildcard $(BOARD_MK)))
$(error No board file found: $(BOARD_MK))
endif
include $(BOARD_MK)
# Expected to define: MCU_CPU, MCU_FPU, MCU_FLOAT_ABI, MCU_DEFINE, STARTUP_FILE

# --- toolchain ---
CC      = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy
SIZE    = arm-none-eabi-size

BUILD_DIR ?= build
TARGET    ?= firmware

# --- sources ---
SRC_DIRS  ?= src
INCLUDES  ?=
EXTRA_DEFS ?=

C_SRCS = $(foreach d,$(SRC_DIRS),$(wildcard $(d)/*.c))
OBJS   = $(patsubst %.c,$(BUILD_DIR)/%.o,$(notdir $(C_SRCS)))
DEPS   = $(OBJS:.o=.d)

STARTUP_OBJ = $(BUILD_DIR)/startup.o

vpath %.c $(SRC_DIRS)

# --- flags ---
CFLAGS = -mcpu=$(MCU_CPU) -mthumb -mfpu=$(MCU_FPU) -mfloat-abi=$(MCU_FLOAT_ABI) \
         -O0 -g -Wall -ffunction-sections -fdata-sections \
         -D$(MCU_DEFINE) $(EXTRA_DEFS) -MMD -MP

ALL_INCLUDES = -Iinc $(INCLUDES)

LDFLAGS = -T$(LDSCRIPT) -Wl,--gc-sections -Wl,-Map=$(BUILD_DIR)/$(TARGET).map \
          -nostartfiles --specs=nano.specs --specs=nosys.specs

# --- rules ---
.PHONY: all clean flash flash-erase flash-build size

all: $(BUILD_DIR)/$(TARGET).bin size

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(ALL_INCLUDES) -c $< -o $@

$(STARTUP_OBJ): $(STARTUP_FILE) | $(BUILD_DIR)
	$(CC) -mcpu=$(MCU_CPU) -mthumb -c $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJS) $(STARTUP_OBJ)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

$(BUILD_DIR)/$(TARGET).bin: $(BUILD_DIR)/$(TARGET).elf
	$(OBJCOPY) -O binary $< $@

size: $(BUILD_DIR)/$(TARGET).elf
	$(SIZE) $<

clean:
	rm -rf $(BUILD_DIR)

# --- flashing (delegates to the shared flash.sh) ---
flash:
	$(TOOLS_DIR)flash.sh --board $(BOARD)

flash-build:
	$(TOOLS_DIR)flash.sh --board $(BOARD) --build

flash-erase:
	$(TOOLS_DIR)flash.sh --board $(BOARD) --erase --reset

-include $(DEPS)