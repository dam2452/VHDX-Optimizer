# VHDX Optimizer

<img width="632" height="227" alt="image" src="https://github.com/user-attachments/assets/0a060fa9-f174-4a87-a0df-c66a26645186" />


## The Problem

Docker Desktop and WSL2 on Windows have a known issue regarding disk space management: their virtual disk images (`.vhdx` files) grow endlessly but do not shrink automatically when data is deleted.

**Typical Scenarios:**

- You created a Docker container, causing the `.vhdx` file to grow to 50 GB.
- You deleted all images and containers, but the file remains at 50 GB.
- WSL2 has consumed a significant portion of your system drive (e.g., 300 GB).
- Storage space is critically low, impacting project requirements.

This is expected behavior (by design). Virtual disks expand dynamically to accommodate new data, but the operating system does not automatically compact them when space is freed within the virtual machine.

**Real World Examples:**

```
Docker Desktop:  ext4.vhdx     → 487 GB (350 GB is unallocated space)
WSL2 Ubuntu:     ext4.vhdx     → 256 GB (180 GB is deleted data)
WSL2 Arch:       ext4.vhdx     → 128 GB (90 GB recoverable)
                                  ───────
Potential Reclaimable Space:     620 GB
```

## The Solution

This script safely compresses `.vhdx` files to reclaim physical disk space.

**How it works:**

1. Scans the system for all `.vhdx` files (Docker, WSL2, Hyper-V).
2. Safely shuts down Docker Desktop and WSL2 services.
3. Optimizes each file using the native Windows `Optimize-VHD` command.
4. Reports detailed statistics on reclaimed space.
5. Logs the entire process to a file.

**Key Features:**

- **Safe:** Uses the official Microsoft `Optimize-VHD` toolset.
- **Non-Destructive:** Only removes zeroed-out blocks; no data is modified.
- **Auto-Discovery:** Automatically locates relevant `.vhdx` files.
- **Simulation Mode:** Includes a `-WhatIf` flag to preview operations without changes.
- **Detailed Logging:** Comprehensive logs for auditing.
- **Colorized Output:** Easy-to-read progress indicators.

## Installation

**Requirements:**

- Windows 10/11
- PowerShell 5.1+ (Built-in)
- Administrator Privileges
- Hyper-V enabled (Standard for WSL2/Docker users)

**Download:**

```powershell
# Clone the repository
git clone https://github.com/your-username/vhdx-optimizer.git
cd vhdx-optimizer

# OR download the script directly
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/your-username/vhdx-optimizer/main/optimize-all-vhdx-v3.ps1" -OutFile "optimize-all-vhdx-v3.ps1"
```

## Usage

**Basic Usage:**

Open PowerShell as Administrator and run:

```powershell
.\optimize-all-vhdx-v3.ps1
```

**Advanced Options:**

```powershell
# Simulation Mode - Preview changes without executing
.\optimize-all-vhdx-v3.ps1 -WhatIf

# Scan a specific directory
.\optimize-all-vhdx-v3.ps1 -RootPath "C:\Users\dam2452"

# Skip stopping Docker services (if not running)
.\optimize-all-vhdx-v3.ps1 -SkipDocker

# Skip stopping WSL (if not running)
.\optimize-all-vhdx-v3.ps1 -SkipWSL

# Filter by size (e.g., only files larger than 500 MB)
.\optimize-all-vhdx-v3.ps1 -MinSizeMB 500

# Enable verbose logging
.\optimize-all-vhdx-v3.ps1 -Verbose

# Combine multiple parameters
.\optimize-all-vhdx-v3.ps1 -RootPath "D:\VirtualMachines" -MinSizeMB 1024 -Verbose
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-RootPath` | String | `C:\Users\{User}` | Directory to search for `.vhdx` files. |
| `-WhatIf` | Switch | `false` | Simulation mode. |
| `-SkipDocker` | Switch | `false` | Bypasses Docker Desktop shutdown. |
| `-SkipWSL` | Switch | `false` | Bypasses WSL2 shutdown. |
| `-MinSizeMB` | Int | `100` | Minimum file size threshold (MB). |
| `-Verbose` | Switch | `false` | Enables detailed output. |
| `-NoLog` | Switch | `false` | Disables file logging. |

## Example Output

```
================================================================
           VHDX FILES OPTIMIZATION SCRIPT v3.0
================================================================

[+] Shutting down WSL...
    WSL shut down successfully
[+] Shutting down Docker Desktop...
    Docker Desktop shut down successfully

[+] Found 3 VHDX file(s) to process:
    * ext4.vhdx (487.23 GB)
      C:\Users\dam2452\AppData\Local\Docker\wsl\data
    * ext4.vhdx (256.47 GB)
      C:\Users\dam2452\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState
    * ext4.vhdx (128.91 GB)
      C:\Users\dam2452\AppData\Local\Packages\ArchWSL_abcd1234\LocalState

============================================================
STARTING OPTIMIZATION PROCESS
============================================================

[1/3] Processing: ext4.vhdx
      Path: C:\Users\dam2452\AppData\Local\Docker\wsl\data\ext4.vhdx
      Size before: 487.23 GB
      Optimizing... Done! (127.3s)
      Size after:  142.18 GB
      [+] Saved: 345.05 GB (70.8%)

[2/3] Processing: ext4.vhdx
      Path: C:\Users\dam2452\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx
      Size before: 256.47 GB
      Optimizing... Done! (89.7s)
      Size after:  78.32 GB
      [+] Saved: 178.15 GB (69.5%)

[3/3] Processing: ext4.vhdx
      Path: C:\Users\dam2452\AppData\Local\Packages\ArchWSL_abcd1234\LocalState\ext4.vhdx
      Size before: 128.91 GB
      Optimizing... Done! (43.2s)
      Size after:  35.67 GB
      [+] Saved: 93.24 GB (72.3%)

============================================================
OPTIMIZATION SUMMARY
============================================================
Execution time:   260.2 seconds
Files found:      3
Files processed:  3

Space Analysis:
Total before:     872.61 GB
Total after:      256.17 GB
Space saved:      616.44 GB (70.6%)

[+] Optimization process completed!
[+] Log saved to: C:\Users\dam2452\AppData\Local\Temp\vhdx-optimize-20241214-153042.log
```

## FAQ

**When should I run this?**

Run this script after deleting large amounts of data (e.g., old Docker images, large datasets in WSL) or as part of routine monthly maintenance.

**Is it safe?**

Yes. The script utilizes the standard `Optimize-VHD` cmdlet provided by Microsoft Hyper-V. It essentially performs a "trim" operation on the virtual disk file.

**How long does it take?**

Performance depends on disk speed and file size. A 100 GB file typically takes 30–60 seconds.

**What if something goes wrong?**

1. Check the log file in `%TEMP%\vhdx-optimize-*.log`
2. If a file is locked, ensure all programs are closed and try again
3. In the worst case, WSL/Docker will automatically rebuild the file

**Do I need to back up first?**

The script is safe, but if you have critical data, you can test first:

```powershell
# Preview what will happen WITHOUT making changes
.\optimize-all-vhdx-v3.ps1 -WhatIf
```

## Troubleshooting

**File Locked:**

If the script cannot access a file, ensure Docker and WSL are completely stopped:

```powershell
wsl --shutdown
Stop-Process -Name "Docker Desktop" -Force
```

**Access Denied:**

Ensure you are running PowerShell as Administrator (Right-click → "Run as administrator").

**Optimize-VHD: command not found:**

This feature requires Hyper-V. Enable it via PowerShell:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

**No files found:**

Verify the search path using:

```powershell
Get-ChildItem -Path C:\ -Filter *.vhdx -Recurse -ErrorAction SilentlyContinue
```
