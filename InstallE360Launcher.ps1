<#
.SYNOPSIS
    Installs E360 Launcher shortcuts for Equipment360 RDP connections.

.DESCRIPTION
    Downloads the latest E360Launcher from GitHub, extracts it, repairs shortcuts,
    and installs them to Desktop and/or Start Menu based on user preferences.

.EXAMPLE
    irm https://raw.githubusercontent.com/lahma0/E360Launcher/refs/heads/main/InstallE360Launcher.ps1 | iex

.NOTES
    Repository: https://github.com/lahma0/E360Launcher
#>

$ErrorActionPreference = "Stop"

Write-Host "`n=== E360 Launcher Installation ===" -ForegroundColor Cyan
Write-Host ""

# Define paths
$baseDir = Join-Path $env:ONEDRIVE "Documents\Equipment360\RDP"
$zipUrl = "https://github.com/lahma0/E360Launcher/archive/refs/heads/main.zip"
$zipPath = Join-Path $baseDir "E360Launcher-main.zip"
$extractTempPath = Join-Path $baseDir "temp_extract"

try {
    # Create directory structure
    Write-Host "Creating directory: $baseDir" -ForegroundColor Yellow
    New-Item -Path $baseDir -ItemType Directory -Force | Out-Null

    # Download repository ZIP
    Write-Host "Downloading E360Launcher from GitHub..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

    # Extract ZIP to temporary location
    Write-Host "Extracting files..." -ForegroundColor Yellow
    Expand-Archive -Path $zipPath -DestinationPath $extractTempPath -Force

    # Move files from E360Launcher-main subdirectory to RDP directory
    $extractedFolder = Join-Path $extractTempPath "E360Launcher-main"
    Get-ChildItem -Path $extractedFolder | Move-Item -Destination $baseDir -Force

    # Clean up temporary files
    Remove-Item -Path $extractTempPath -Recurse -Force
    Remove-Item -Path $zipPath -Force

    # Run repairShortcuts.ps1
    $repairScript = Join-Path $baseDir "repairShortcuts.ps1"
    if (Test-Path $repairScript) {
        Write-Host "Running repairShortcuts.ps1..." -ForegroundColor Yellow
        & $repairScript
    } else {
        Write-Warning "repairShortcuts.ps1 not found at: $repairScript"
    }

    Write-Host ""

    # Ask which shortcuts to install
    Write-Host "Which shortcuts would you like to install?" -ForegroundColor Cyan
    Write-Host "  1) E360 Manager"
    Write-Host "  2) E360 Mechanic"
    Write-Host "  3) Both"
    $shortcutChoice = Read-Host "Enter your choice (1-3)"

    Write-Host ""

    # Ask where to install shortcuts
    Write-Host "Where would you like to install the shortcuts?" -ForegroundColor Cyan
    Write-Host "  1) Desktop"
    Write-Host "  2) Start Menu"
    Write-Host "  3) Both"
    $locationChoice = Read-Host "Enter your choice (1-3)"

    Write-Host ""

    # Determine which shortcut files to copy
    $shortcutsToCopy = @()
    switch ($shortcutChoice) {
        "1" { 
            $shortcutsToCopy += Join-Path $baseDir "E360 Manager Launcher.lnk"
        }
        "2" { 
            $shortcutsToCopy += Join-Path $baseDir "E360 Mechanic Launcher.lnk"
        }
        "3" { 
            $shortcutsToCopy += Join-Path $baseDir "E360 Manager Launcher.lnk"
            $shortcutsToCopy += Join-Path $baseDir "E360 Mechanic Launcher.lnk"
        }
        default {
            Write-Warning "Invalid choice. Defaulting to 'Both'."
            $shortcutsToCopy += Join-Path $baseDir "E360 Manager Launcher.lnk"
            $shortcutsToCopy += Join-Path $baseDir "E360 Mechanic Launcher.lnk"
        }
    }

    # Determine destination paths
    $destinations = @()
    $installedToStartMenu = $false
    switch ($locationChoice) {
        "1" { 
            $destinations += [Environment]::GetFolderPath("Desktop")
        }
        "2" {
            $destinations += Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
            $installedToStartMenu = $true
        }
        "3" {
            $destinations += [Environment]::GetFolderPath("Desktop")
            $destinations += Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
            $installedToStartMenu = $true
        }
        default {
            Write-Warning "Invalid choice. Defaulting to 'Both'."
            $destinations += [Environment]::GetFolderPath("Desktop")
            $destinations += Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
            $installedToStartMenu = $true
        }
    }

    # Copy shortcuts to destinations
    Write-Host "Installing shortcuts..." -ForegroundColor Yellow
    Write-Host ""
    foreach ($shortcut in $shortcutsToCopy) {
        if (Test-Path $shortcut) {
            $shortcutName = Split-Path $shortcut -Leaf
            foreach ($destination in $destinations) {
                $destPath = Join-Path $destination $shortcutName
                Copy-Item -Path $shortcut -Destination $destPath -Force
                Write-Host "  ✓ Copied '$shortcutName' to: $destination" -ForegroundColor Green
            }
        } else {
            Write-Warning "Shortcut not found: $shortcut"
        }
    }

    Write-Host ""
    Write-Host "=== Installation Complete ===" -ForegroundColor Green
    Write-Host ""

    # Remind about Start Menu pinning if applicable
    if ($installedToStartMenu) {
        Write-Host "REMINDER: " -ForegroundColor Yellow -NoNewline
        Write-Host "Don't forget to Pin the shortcuts to your Start Menu!"
        Write-Host ""
    }

    # Important reminders
    Write-Host "IMPORTANT: Before using the shortcuts, you must:" -ForegroundColor Yellow
    Write-Host "  1. Install/configure " -NoNewline
    Write-Host "Cloudflare WARP" -ForegroundColor Blue
    Write-Host "  2. Set up credentials in the " -NoNewline
    Write-Host "Windows Credentials Manager" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Please test the shortcuts and:" -ForegroundColor Yellow
    Write-Host "  - Check the `"Don't ask me again for connections to this computer`" checkbox"
    Write-Host "  - Permanently approve any other permissions requests and 'Remember' any credentials"
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host ""
}

Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
