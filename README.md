# computer-specs-script

A simple PowerShell script that collects your computer's specs — CPU, RAM, storage, motherboard, OS, and GPU — and saves them to a text file on your Desktop. Made for anyone selling, upgrading, or just curious about their machine, no tech skills needed.

No installs needed: it uses only built-in PowerShell cmdlets.

## What it collects

- **Model**: system manufacturer and model
- **CPU**: exact model, cores / threads, base clock
- **RAM**: total size, type (DDR3 / DDR4 / DDR5), speed, module sizes and slots used
- **Storage**: every physical disk with model and size, labelled **NVMe**, **SATA SSD** or **HDD**
- **Motherboard**: manufacturer and exact model, with BIOS version (tries `Win32_BaseBoard`, `Win32_ComputerSystemProduct` and the registry, in that order)
- **OS**: Windows edition, version, build, architecture and activation status
- **GPU**: every graphics adapter, with VRAM when available

## How to run

1. Download `Get-ComputerSpecs.ps1`.
2. Right-click the file and choose **Run with PowerShell**,
   or open PowerShell in the file's folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File Get-ComputerSpecs.ps1
```

Running as administrator makes some fields more complete.

## Output

The script saves **`Computer-specs-en.txt`** to your Desktop (overwriting any older copy), shows the same text on screen, copies it to the clipboard and prints the exact file path at the end. If your Desktop is synced with OneDrive, the file goes to the OneDrive Desktop folder.

Example:

```
==== COMPUTER SPECS ====
Model          : Dell Inc. OptiPlex 7080
CPU            : Intel(R) Core(TM) i5-10500 CPU @ 3.10GHz (6 cores / 12 threads, 3.10 GHz)
RAM            : 16 GB DDR4 2666 MHz (8 GB + 8 GB) - 2 of 4 slots used
Storage        :
  - SSD NVMe   KINGSTON SNV2S500G 466 GB
  - HDD SATA   ST1000DM010-2EP102 932 GB
Motherboard    : Dell Inc. 0J37VM (BIOS 1.21.0)
OS             : Microsoft Windows 11 Pro 23H2 (build 22631) 64-bit - Activated
GPU            :
  - Intel(R) UHD Graphics 630 1 GB
Generated on   : 24/11/2026 22:40
========================
```

*(Example values only.)*

## Notes

- Physical USB ports and free video outputs are not reported, because Windows does not expose them reliably.
- Windows only. A Linux version could use `lscpu`, `lsblk`, `dmidecode` and `/sys/class/dmi/id`.
