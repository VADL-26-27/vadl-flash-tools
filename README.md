# vadl-flash-tools

Shared build and flashing tooling for VADL STM32 firmware projects.

This repo provides:
- `flash.sh` / `flash.ps1` — board-aware flashing scripts (Linux/Mac and Windows) built on `st-flash`
- `common.mk` — a shared Makefile fragment that handles compiling, linking, and wiring up `flash.sh`
- `boards/` — per-MCU configuration, one subfolder per board

It's meant to be added as a **git submodule** inside each firmware project repo (HIL rig, nose cone, avionics, recovery, etc.), so every subsystem gets the same build/flash commands without duplicating scripts per project.

---

## Repo layout

```
vadl-flash-tools/
  flash.sh          # Linux/Mac flashing script
  flash.ps1         # Windows flashing script
  common.mk         # shared Makefile logic, included by each project's own Makefile
  boards/
    f411/
      flash.conf     # bash config, used by flash.sh
      flash.ps1      # PowerShell config, used by flash.ps1
      build.mk       # Make config, used by common.mk
    h753/
      flash.conf
      flash.ps1
      build.mk
```

Adding support for a new MCU means adding one new `boards/<name>/` folder with those three files — nothing else in the repo needs to change.

---

## Prerequisites

Install on any machine that will build or flash firmware:

- `arm-none-eabi-gcc` (GNU Arm Embedded Toolchain)
- `make`
- `stlink-tools` (provides `st-flash` and `st-info`) — Linux/Mac
  - Windows: install the [stlink Windows build](https://github.com/stlink-org/stlink) and ensure `st-flash.exe`/`st-info.exe` are on `PATH`

Verify with:
```bash
arm-none-eabi-gcc --version
st-flash --version
```

---

## Adding this to a project

From the root of a firmware project repo:

```bash
git submodule add https://github.com/VADL-26-27/vadl-flash-tools.git vadl-flash-tools
git submodule update --init
```

Anyone cloning the project fresh needs:
```bash
git clone --recurse-submodules <project-url>
# or, if already cloned without that flag:
git submodule update --init
```

Then create a `Makefile` in the project root:

```makefile
BOARD    = f411
SRC_DIRS = src rtos
LDSCRIPT = ld/STM32F411RETx_FLASH.ld
INCLUDES = -Irtos/include

include vadl-flash-tools/common.mk
```

- `BOARD` must match a folder name under `vadl-flash-tools/boards/`
- `SRC_DIRS` — directories `common.mk` will glob `.c` files from
- `LDSCRIPT` — path to your project's linker script (lives in the project repo, not the tools repo)
- `INCLUDES` — any extra `-I` flags beyond `inc/`

Also add a `.gitignore` entry for `build/` in the project so compiled artifacts don't get committed.

---

## Commands

Run from the project root (not from inside `vadl-flash-tools/`):

| Command | What it does |
|---|---|
| `make` | Compile and link, produce `build/firmware.bin` |
| `make flash` | Flash the already-built binary to the board |
| `make flash-build` | Build, then flash, in one step |
| `make flash-erase` | Mass-erase the chip, then reset |
| `make size` | Print firmware size (`arm-none-eabi-size`) |
| `make clean` | Remove `build/` |

On Windows, `flash.ps1` can also be called directly if you're not using `make`:
```powershell
./vadl-flash-tools/flash.ps1 -Board f411
./vadl-flash-tools/flash.ps1 -Board f411 -Build
./vadl-flash-tools/flash.ps1 -Board h753 -Erase -Reset
```

And `flash.sh` directly on Linux/Mac:
```bash
./vadl-flash-tools/flash.sh --board f411
./vadl-flash-tools/flash.sh --board f411 --build
./vadl-flash-tools/flash.sh --board h753 --erase --reset
```

---

## Adding a new board

1. Create `boards/<name>/` (e.g. `boards/f446/`)
2. Add `flash.conf`:
   ```bash
   MCU_NAME="STM32F446RET6"
   MCU_FAMILY="F446"
   FLASH_ADDR="0x08000000"
   FLASH_SIZE="0x80000"
   BIN="./build/firmware.bin"
   ```
3. Add `flash.ps1`:
   ```powershell
   $MCUName = "STM32F446RET6"
   $MCUFamily = "F446"
   $MCUFlashAddr = "0x08000000"
   $MCUBin = ".\build\firmware.bin"
   ```
4. Add `build.mk`:
   ```makefile
   MCU_CPU       = cortex-m4
   MCU_FPU       = fpv4-sp-d16
   MCU_FLOAT_ABI = hard
   MCU_DEFINE    = STM32F446xx
   STARTUP_FILE  = startup/startup_stm32f446xetx.s
   ```
5. Any project can now use it by setting `BOARD = f446` in its Makefile.

`FLASH_ADDR` is `0x08000000` for essentially all STM32 parts, so the main things that actually change per board are the CPU/FPU flags, the chip define, and the startup file name — grab these from your CubeMX project or the datasheet's part number.

---

## What lives here vs. what lives in the project repo

| Belongs in `vadl-flash-tools` | Belongs in the project repo |
|---|---|
| Flashing logic (`flash.sh`/`flash.ps1`) | Application source (`src/`, `rtos/`) |
| Shared build logic (`common.mk`) | Linker script (`ld/*.ld`) |
| Per-MCU flags (`boards/*/build.mk`) | Startup file (`startup/*.s`) |
| Per-MCU flash config (`boards/*/flash.conf`, `flash.ps1`) | Project's own `Makefile` (4 lines, sets `BOARD`/`SRC_DIRS`/`LDSCRIPT`) |
|  | GPIO/peripheral/clock config (baked into your source, e.g. via CubeMX) |

GPIO pin assignments, clock trees, and peripheral setup are **not** handled here — those live entirely in each project's own source/CubeMX config, since they're application-specific, not chip-family-specific.

---

## Troubleshooting

- **`st-flash not found`** — install stlink-tools and confirm it's on `PATH`.
- **`No ST-Link probe detected`** — check the USB connection; run `st-info --probe` directly to debug.
- **`Unknown board: <name>`** — check that `boards/<name>/` exists in this repo and that `BOARD` in your project's Makefile matches the folder name exactly.
- **Device busy (Linux/Mac)** — `flash.sh` will attempt to kill processes holding the serial port open (e.g. a leftover `hexdump`/`screen` session); on Windows, `flash.ps1` only warns, since there's no reliable `lsof` equivalent — close the offending program (PuTTY, Tera Term, Arduino Serial Monitor) manually.
- **Submodule folder empty after clone** — run `git submodule update --init`.
