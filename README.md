# Gun.Smoke - for MEGA65

**Gun.Smoke** is Capcom's 1985 vertically scrolling arcade shoot-'em-up. Players take the role of bounty hunter Billy Bob, fighting through the Wild West against armed enemies and bosses. Its distinctive three-button firing system lets the player shoot left, straight ahead, or right while moving independently.

This project ports the **Gun.Smoke** FPGA core from **Jotego's JTCORES project** to the MEGA65.

The upstream core used as the basis of this port is:

[Jotego JTCORES - Gun.Smoke](https://github.com/jotego/jtcores/tree/master/cores/gunsmk)

The original FPGA implementation, JTFRAME infrastructure and associated supporting cores are the work of **Jotego and the JTCORES contributors**.

The MEGA65 port uses the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework and [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for MEGA65 integration, including FAT32 ROM loading and the on-screen menu.

## Credits

*Gun.Smoke* was originally developed and released by **Capcom** in 1985.

This MEGA65 core would not exist without the work of **Jotego and the JTCORES contributors**. The MEGA65 version is based on the JTCORES Gun.Smoke implementation linked above.

Additional credit goes to **sy2002, MJoergen and the MiSTer2MEGA65 contributors** for the MiSTer2MEGA65 framework and QNICE-FPGA integration used by this port.

## How to install the core

### 1. Obtain the Gun.Smoke ROM archives

The current conversion scripts require two ZIP archives:

```text
gunsmoke.zip
gunsmoke_meg65_roms.zip
```

`gunsmoke.zip` contains the original MAME arcade ROM chips used to reconstruct the sprite/object graphics. `gunsmoke_meg65_roms.zip` supplies the prepared MEGA65 ROM images used as the basis for the remaining regions.

**Do not extract the ZIP archives.** The scripts read their contents directly. The original MAME archive alone is **not sufficient** for the current scripts; the prepared MEGA65 archive is also required.

### 2. Generate the MEGA65 ROM images

Three independent ROM conversion scripts are provided:

- `gunsmoke.py` — Python 3 (standard library only)
- `gunsmoke.sh` — Linux Bash, using `unzip`, Perl and `Compress::Zlib`
- `gunsmoke.ps1` — Windows PowerShell, using .NET ZIP support

**Each script performs the ROM conversion itself.** The Bash and PowerShell scripts do not call Python or another ROM-building script.

Place both ZIP archives alongside the scripts in the project directory.

#### Windows / PowerShell

```powershell
.\gunsmoke.ps1
```

If Windows blocks the downloaded script, unblock it first:

```powershell
Unblock-File .\gunsmoke.ps1
```

By default, the PowerShell script locates the ZIP archives relative to its own directory, not PowerShell's working directory. To use different archive locations:

```powershell
.\gunsmoke.ps1 -MameZip 'D:\ROMs\gunsmoke.zip' -MegaZip 'D:\ROMs\gunsmoke_meg65_roms.zip'
```

To specify an output directory, add `-OutputDir 'D:\ROMs\gunsmoke'`.

#### Linux

Make the Bash script executable if necessary, then run:

```bash
chmod +x gunsmoke.sh
./gunsmoke.sh
```

To supply different archive paths, pass the MAME ZIP, prepared ZIP and optional output directory as positional arguments:

```bash
./gunsmoke.sh /path/to/gunsmoke.zip /path/to/gunsmoke_meg65_roms.zip /path/to/output
```

The Bash script requires `bash`, `unzip`, `perl` and the Perl module `Compress::Zlib`.

#### Python

```bash
python3 gunsmoke.py gunsmoke.zip gunsmoke_meg65_roms.zip
```

To override the destination:

```bash
python3 gunsmoke.py gunsmoke.zip gunsmoke_meg65_roms.zip --output /path/to/output
```

Python 3 is required; no third-party Python packages are needed.

#### Output directory

By default, all three scripts write seven individual ROM files to:

```text
arcade/gunsmoke
```

The conversion applies the JTCORES graphics transformations required by this MEGA65 port:

| ROM region | Graphics layout |
|---|---|
| Object/sprite (`obj`) | `hvvvvxx` sorted |
| Scroll map (`map`) | `hvvvx` sorted |
| Scroll graphics (`scr`) | Unsorted |
| Character graphics (`char`) | Retained from prepared ROM |

**Important:** The object ROM is reconstructed from eight original arcade chips, then sorted. The map ROM is sorted from the prepared image. Both transformations are performed automatically. There is no unsorted option and **no additional FPGA object-address remapping is required** for this Gun.Smoke port.

### 3. Generated ROM files

The scripts generate these seven files:

| File | Size (bytes) | CRC32 |
|---|---:|---|
| `gunsmoke_main.rom` | 98304 | `E9558550` |
| `gunsmoke_sound.rom` | 32768 | `CD7A2C38` |
| `gunsmoke_char.rom` | 16384 | `887C649F` |
| `gunsmoke_map.rom` | 32768 | `0C65E533` |
| `gunsmoke_scr.rom` | 262144 | `A8FC2FB9` |
| `gunsmoke_obj.rom` | 262144 | `D9C6C64F` |
| `gunsmoke_prom.rom` | 2560 | `C1196F40` |

These checksums correspond to the ROM archives used during development. Each script prints the generated sizes and CRC32 values for comparison. Missing ZIP entries or incorrect ROM sizes should be investigated before copying files to the SD card.

### 4. Copy the ROMs to the MEGA65 SD card

Copy the seven generated ROM files to:

```text
/arcade/gunsmoke
```

Also copy the supplied Gun.Smoke configuration file to this directory. The configured settings file is:

```text
/arcade/gunsmoke/gscfg
```

Both the bottom and rear SD card slots can be used. As with other MEGA65 cores, the rear SD card takes precedence when both are present.

Install the Gun.Smoke `.cor` file using the normal MEGA65 core installation procedure.

## Game setup

Press the **HELP** key while the core is running to open the MiSTer2MEGA65 on-screen menu.

The menu provides display, joystick-button mapping, POT polarity and DIP-switch settings.

### Video output

Gun.Smoke is a vertically oriented arcade game. The MEGA65 port uses the MiSTer2MEGA65 rotation/frame-buffer support to display the game in the correct orientation.

The display menu includes **Rotate screen 90**, HDMI display settings, CRT emulation and VGA options. VGA modes include standard output, retro 15 kHz with separate HS/VS and retro 15 kHz with CSYNC.

### Controls

Gun.Smoke uses an eight-way joystick and **three directional firing buttons**:

- **Fire Left** — shoots to the left of the player's forward direction.
- **Fire Centre** — shoots straight ahead.
- **Fire Right** — shoots to the right of the player's forward direction.

The MEGA65 implementation supports the normal joystick fire button plus **POTX** and **POTY** as three independent firing inputs. Under **Button Controls**, Player 1 and Player 2 can select their button layouts independently from six permutations:

| Layout | Fire Left | Fire Centre | Fire Right |
|---|---|---|---|
| Default | POTX | Fire | POTY |
| 2 | POTY | Fire | POTX |
| 3 | Fire | POTX | POTY |
| 4 | Fire | POTY | POTX |
| 5 | POTX | POTY | Fire |
| 6 | POTY | POTX | Fire |

The menu also includes separate **P1 POT polarity** and **P2 POT polarity** settings to accommodate different joystick/button hardware.

For Player 1, the keyboard supports cursor keys for movement and **Z** (Fire Left), **X** (Fire Centre), **C** (Fire Right). Press **1** or **2** to start and **5** or **6** to insert credits. The on-screen menu also provides **Flip joystick ports**.

### DIP switches

The on-screen **Game Setup → DSW A & B** menu exposes these arcade DIP-switch functions:

| Switch | Setting |
|---|---|
| SW1-1 | Bonus Player |
| SW1-2 | Bonus Player |
| SW1-3 | Demo |
| SW1-4 | Game Type |
| SW1-5 | Difficulty |
| SW1-6 | Difficulty |
| SW1-7 | Freeze Mode |
| SW1-8 | Test Mode |
| SW2-1 to SW2-3 | Coin 1 |
| SW2-4 to SW2-6 | Coin 2 |
| SW2-7 | Continue |
| SW2-8 | Attract Sound |

If saved menu settings are enabled, an existing `/arcade/gunsmoke/gscfg` can override newly compiled defaults. **Regenerate the configuration file when `OPTM_SIZE` changes**; the current button-control menu configuration uses 81 entries.

## Upstream projects

This port builds upon several open-source FPGA projects:

- [Jotego JTCORES](https://github.com/jotego/jtcores)
- [Gun.Smoke core in JTCORES](https://github.com/jotego/jtcores/tree/master/cores/gunsmk)
- [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
- [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA)

Please support the upstream projects and developers whose work made this MEGA65 port possible.

## Status

This is an initial MEGA65 port of the Gun.Smoke core. Video, ROM loading, sprite sorting and three-button input integration have been brought up during development.

Please report MEGA65-specific problems through the Gun.Smoke MEGA65 project rather than to the upstream JTCORES project, unless the problem has also been reproduced on the original upstream implementation.

## Known issues

No confirmed Gunsmoke-specific issues are documented here yet.
