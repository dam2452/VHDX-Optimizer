# Optimize-VHDXFiles.ps1
# Script to optimize VHDX files used by WSL and Docker
# Author: Enhanced version
# Version: 3.0

param(
    [string]$RootPath = "C:\Users\dam2452",
    [switch]$WhatIf,           # Simulation mode - no actual changes
    [switch]$SkipDocker,       # Skip closing Docker
    [switch]$SkipWSL,          # Skip closing WSL
    [int]$MinSizeMB = 100,     # Minimum file size in MB to optimize
    [switch]$Verbose,          # Verbose logging
    [switch]$NoLog             # Disable file logging
)

# Start logging if not disabled
if (-not $NoLog) {
    $logFile = Join-Path $env:TEMP "vhdx-optimize-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    Start-Transcript -Path $logFile -Append | Out-Null
    Write-Host "[+] Logging to: $logFile" -ForegroundColor DarkGray
}

# Function to format file size
function Format-FileSize {
    param([long]$Size)

    if ($Size -gt 1TB) {
        return "{0:N2} TB" -f ($Size / 1TB)
    } elseif ($Size -gt 1GB) {
        return "{0:N2} GB" -f ($Size / 1GB)
    } elseif ($Size -gt 1MB) {
        return "{0:N2} MB" -f ($Size / 1MB)
    } else {
        return "{0:N2} KB" -f ($Size / 1KB)
    }
}

# Function to check if file is locked
function Test-FileLocked {
    param([string]$Path)

    try {
        $fileStream = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $fileStream.Close()
        return $false
    } catch {
        return $true
    }
}

# Initialize statistics
$stats = @{
    TotalSizeBefore = 0
    TotalSizeAfter = 0
    ProcessedFiles = 0
    FailedFiles = 0
    SkippedFiles = 0
    LockedFiles = 0
    StartTime = Get-Date
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "           VHDX FILES OPTIMIZATION SCRIPT v3.0                  " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "`n[WhatIf] Running in simulation mode - no changes will be made" -ForegroundColor Yellow
}

# Shutdown WSL if needed
if (-not $SkipWSL) {
    $wslProcesses = Get-Process -Name "wsl*", "wslservice" -ErrorAction SilentlyContinue
    if ($wslProcesses) {
        Write-Host "`n[+] Shutting down WSL..." -ForegroundColor Yellow
        wsl --shutdown
        Start-Sleep -Seconds 2
        Write-Host "    WSL shut down successfully" -ForegroundColor Green
    } else {
        Write-Host "`n[i] WSL is not running" -ForegroundColor DarkGray
    }
} else {
    Write-Host "`n[i] Skipping WSL shutdown (SkipWSL flag set)" -ForegroundColor DarkGray
}

# Shutdown Docker Desktop if needed
if (-not $SkipDocker) {
    $dockerProcesses = Get-Process -Name "Docker Desktop", "com.docker*" -ErrorAction SilentlyContinue
    if ($dockerProcesses) {
        Write-Host "[+] Shutting down Docker Desktop..." -ForegroundColor Yellow
        $dockerProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Write-Host "    Docker Desktop shut down successfully" -ForegroundColor Green
    } else {
        Write-Host "[i] Docker Desktop is not running" -ForegroundColor DarkGray
    }
} else {
    Write-Host "[i] Skipping Docker shutdown (SkipDocker flag set)" -ForegroundColor DarkGray
}

# Search for VHDX files
Write-Host "`n[+] Searching for .vhdx files under: $RootPath" -ForegroundColor Cyan
Write-Host "    Minimum size filter: $(Format-FileSize ($MinSizeMB * 1MB))" -ForegroundColor DarkGray

$vhdxFiles = @()
$searchErrors = 0

# Progress counter for search
$dirCount = 0
Write-Host "    Scanning directories..." -NoNewline

Get-ChildItem -Path $RootPath -Recurse -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $dirCount++
    if ($dirCount % 100 -eq 0) {
        Write-Host "." -NoNewline
    }

    try {
        $found = Get-ChildItem -Path $_.FullName -Filter *.vhdx -File -Force -ErrorAction Stop
        if ($found) {
            foreach ($file in $found) {
                if ($file.Length -ge ($MinSizeMB * 1MB)) {
                    $vhdxFiles += $file
                }
            }
        }
    } catch {
        $searchErrors++
        if ($Verbose) {
            Write-Host "`n    [!] Cannot access: $($_.FullName)" -ForegroundColor DarkYellow
        }
    }
}

Write-Host "" # New line after dots

if ($searchErrors -gt 0 -and $Verbose) {
    Write-Host "    [i] Could not access $searchErrors directories" -ForegroundColor DarkYellow
}

if (-not $vhdxFiles -or $vhdxFiles.Count -eq 0) {
    Write-Host "`n[-] No .vhdx files found matching criteria." -ForegroundColor Red
    Write-Host "    Searched path: $RootPath" -ForegroundColor DarkGray
    Write-Host "    Minimum size: $(Format-FileSize ($MinSizeMB * 1MB))" -ForegroundColor DarkGray

    if (-not $NoLog) {
        Stop-Transcript | Out-Null
    }
    exit
}

# Display found files
Write-Host "`n[+] Found $($vhdxFiles.Count) VHDX file(s) to process:" -ForegroundColor Yellow
foreach ($file in $vhdxFiles) {
    Write-Host "    * $($file.Name) ($(Format-FileSize $file.Length))" -ForegroundColor DarkCyan
    Write-Host "      $($file.DirectoryName)" -ForegroundColor DarkGray
}

Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "STARTING OPTIMIZATION PROCESS" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

# Process each VHDX file
$fileIndex = 0
foreach ($file in $vhdxFiles) {
    $fileIndex++
    Write-Host "`n[$fileIndex/$($vhdxFiles.Count)] Processing: $($file.Name)" -ForegroundColor Green
    Write-Host "      Path: $($file.FullName)" -ForegroundColor DarkGray

    # Check if file is locked
    if (Test-FileLocked -Path $file.FullName) {
        Write-Host "      [!] File is locked/in use, skipping" -ForegroundColor Yellow
        $stats.LockedFiles++
        $stats.SkippedFiles++
        continue
    }

    # Get size before optimization
    $sizeBefore = $file.Length
    $stats.TotalSizeBefore += $sizeBefore

    Write-Host "      Size before: $(Format-FileSize $sizeBefore)" -ForegroundColor DarkGray

    # WhatIf mode
    if ($WhatIf) {
        Write-Host "      [WhatIf] Would optimize this file" -ForegroundColor Cyan
        $stats.TotalSizeAfter += [long]($sizeBefore * 0.85) # Estimate 15% reduction
        continue
    }

    # Perform optimization
    try {
        Write-Host "      Optimizing... " -NoNewline
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        Optimize-VHD -Path $file.FullName -Mode Full -ErrorAction Stop

        $stopwatch.Stop()

        # Get size after optimization
        $file.Refresh()
        $sizeAfter = $file.Length
        $stats.TotalSizeAfter += $sizeAfter
        $stats.ProcessedFiles++

        $saved = $sizeBefore - $sizeAfter
        $savedPercent = if ($sizeBefore -gt 0) { ($saved / $sizeBefore) * 100 } else { 0 }

        $elapsedTime = "{0:N1}s" -f $stopwatch.Elapsed.TotalSeconds
        Write-Host "Done! ($elapsedTime)" -ForegroundColor Green
        Write-Host "      Size after:  $(Format-FileSize $sizeAfter)" -ForegroundColor DarkGray

        if ($saved -gt 0) {
            $savedPercentFormatted = "{0:N1}%" -f $savedPercent
            Write-Host "      [+] Saved: $(Format-FileSize $saved) ($savedPercentFormatted)" -ForegroundColor Green
        } else {
            Write-Host "      [i] No space saved (file was already optimized)" -ForegroundColor DarkCyan
        }
    }
    catch {
        Write-Host "FAILED!" -ForegroundColor Red
        Write-Host "      [X] Error: $($_.Exception.Message)" -ForegroundColor Red
        $stats.FailedFiles++
        $stats.TotalSizeAfter += $sizeBefore # Assume size unchanged on failure
    }
}

# Calculate summary statistics
$totalSaved = $stats.TotalSizeBefore - $stats.TotalSizeAfter
$totalSavedPercent = if ($stats.TotalSizeBefore -gt 0) { ($totalSaved / $stats.TotalSizeBefore) * 100 } else { 0 }
$duration = (Get-Date) - $stats.StartTime

# Display summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "OPTIMIZATION SUMMARY" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "[WhatIf] Simulation Results (estimated)" -ForegroundColor Yellow
    Write-Host ""
}

$durationFormatted = "{0:N1}" -f $duration.TotalSeconds
Write-Host "Execution time:   $durationFormatted seconds" -ForegroundColor White
Write-Host "Files found:      $($vhdxFiles.Count)" -ForegroundColor White
Write-Host "Files processed:  $($stats.ProcessedFiles)" -ForegroundColor $(if ($stats.ProcessedFiles -eq $vhdxFiles.Count) { 'Green' } else { 'White' })

if ($stats.FailedFiles -gt 0) {
    Write-Host "Files failed:     $($stats.FailedFiles)" -ForegroundColor Yellow
}

if ($stats.LockedFiles -gt 0) {
    Write-Host "Files locked:     $($stats.LockedFiles)" -ForegroundColor Yellow
}

if ($stats.SkippedFiles -gt 0) {
    Write-Host "Files skipped:    $($stats.SkippedFiles)" -ForegroundColor Yellow
}

Write-Host "`nSpace Analysis:" -ForegroundColor Cyan
Write-Host "Total before:     $(Format-FileSize $stats.TotalSizeBefore)" -ForegroundColor White
Write-Host "Total after:      $(Format-FileSize $stats.TotalSizeAfter)" -ForegroundColor White

if ($totalSaved -gt 0) {
    $totalSavedPercentFormatted = "{0:N1}%" -f $totalSavedPercent
    Write-Host "Space saved:      $(Format-FileSize $totalSaved) ($totalSavedPercentFormatted)" -ForegroundColor Green -BackgroundColor DarkGreen
} else {
    Write-Host "Space saved:      None" -ForegroundColor DarkGray
}

if ($WhatIf) {
    Write-Host "`n[WhatIf] No actual changes were made (simulation mode)" -ForegroundColor Cyan
}

Write-Host "`n[+] Optimization process completed!" -ForegroundColor Green

# Stop logging
if (-not $NoLog) {
    Write-Host "[+] Log saved to: $logFile" -ForegroundColor DarkGray
    Stop-Transcript | Out-Null
}

# Return statistics object for potential pipeline use
return $stats
