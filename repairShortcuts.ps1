<#
.SYNOPSIS
    Repairs all Windows shortcut files (.lnk) in the script's directory.

.DESCRIPTION
    This script finds all .lnk files in the same directory as the script itself
    and repairs them by forcing Windows to re-resolve environment variables.
    This fixes shortcuts that were copied from other computers.

.NOTES
    Author: AI Assistant
    Date: 2024
#>

# Get the directory where this script is located
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Shortcut Repair Tool" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Script location: $ScriptDirectory`n" -ForegroundColor Yellow

# Find all .lnk files in the script's directory
$Shortcuts = Get-ChildItem -Path $ScriptDirectory -Filter "*.lnk" -File

if ($Shortcuts.Count -eq 0) {
    Write-Host "No shortcut files found in the script directory." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "Found $($Shortcuts.Count) shortcut(s) to repair:`n" -ForegroundColor Cyan

# Display list of shortcuts found
foreach ($shortcut in $Shortcuts) {
    Write-Host "  - $($shortcut.Name)" -ForegroundColor Gray
}

Write-Host ""

# Repair each shortcut
$SuccessCount = 0
$FailCount = 0

foreach ($shortcut in $Shortcuts) {
    try {
        # Create WScript.Shell COM object
        $WScriptShell = New-Object -ComObject WScript.Shell

        # Load the shortcut
        $ShortcutObj = $WScriptShell.CreateShortcut($shortcut.FullName)

        # Save it (this forces re-resolution of environment variables)
        $ShortcutObj.Save()

        # Clean up COM object
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WScriptShell) | Out-Null

        Write-Host "[OK] $($shortcut.Name)" -ForegroundColor Green
        $SuccessCount++
    }
    catch {
        Write-Host "[FAILED] $($shortcut.Name) - Error: $_" -ForegroundColor Red
        $FailCount++
    }
}

# Display summary
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Successfully repaired: $SuccessCount" -ForegroundColor Green
if ($FailCount -gt 0) {
    Write-Host "  Failed: $FailCount" -ForegroundColor Red
}
Write-Host "==================================================" -ForegroundColor Cyan

# Wait for user input before closing
# Write-Host "`nPress any key to exit..."
# $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
