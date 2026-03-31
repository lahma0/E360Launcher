<#
.SYNOPSIS
    Repairs all Windows shortcut files (.lnk) in the script's directory.

.DESCRIPTION
    Extracts string data from broken shortcuts and recreates them as new shortcuts
    with properly resolved paths for the current computer.

.NOTES
    Author: AI Assistant
    Date: 2024
#>

function Extract-ShortcutStrings {
    param([byte[]]$Bytes)

    $strings = @{
        TargetPath = ""
        WorkingDirectory = ""
        IconLocation = ""
        IconIndex = 0
        Arguments = ""
    }

    try {
        Write-Host "  File size: $($Bytes.Length) bytes (0x$($Bytes.Length.ToString('X')))" -ForegroundColor Gray

        # Read LinkFlags at offset 0x14
        $linkFlags = [System.BitConverter]::ToUInt32($Bytes, 0x14)
        Write-Host "  LinkFlags: 0x$($linkFlags.ToString('X8'))" -ForegroundColor Gray

        # Check which optional structures are present
        $hasLinkTargetIDList = ($linkFlags -band 0x01) -ne 0
        $hasLinkInfo = ($linkFlags -band 0x02) -ne 0
        $hasName = ($linkFlags -band 0x04) -ne 0
        $hasRelativePath = ($linkFlags -band 0x08) -ne 0
        $hasWorkingDir = ($linkFlags -band 0x10) -ne 0
        $hasArguments = ($linkFlags -band 0x20) -ne 0
        $hasIconLocation = ($linkFlags -band 0x40) -ne 0

        Write-Host "  Has: IDList=$hasLinkTargetIDList, LinkInfo=$hasLinkInfo, Name=$hasName, RelPath=$hasRelativePath, WorkDir=$hasWorkingDir, Args=$hasArguments, Icon=$hasIconLocation" -ForegroundColor Gray

        # Start after the shell link header (0x4C bytes)
        $offset = 0x4C

        # Skip LinkTargetIDList if present
        if ($hasLinkTargetIDList) {
            if ($offset + 2 -gt $Bytes.Length) {
                throw "File too short for IDList size"
            }
            $idListSize = [System.BitConverter]::ToUInt16($Bytes, $offset)
            Write-Host "  IDList size: $idListSize bytes (at offset 0x$($offset.ToString('X')))" -ForegroundColor Gray
            $offset += 2 + $idListSize  # Size field (2 bytes) + actual data
            Write-Host "  After IDList, offset: 0x$($offset.ToString('X'))" -ForegroundColor Gray
        }

        # Skip LinkInfo if present
        if ($hasLinkInfo) {
            if ($offset + 4 -gt $Bytes.Length) {
                Write-Host "  WARNING: File too short for LinkInfo, skipping" -ForegroundColor Yellow
            } else {
                $linkInfoSize = [System.BitConverter]::ToUInt32($Bytes, $offset)
                Write-Host "  LinkInfo size (raw): $linkInfoSize bytes (0x$($linkInfoSize.ToString('X'))) at offset 0x$($offset.ToString('X'))" -ForegroundColor Gray

                # Sanity check
                if ($linkInfoSize -gt $Bytes.Length -or $linkInfoSize -lt 0x1C) {
                    Write-Host "  WARNING: LinkInfo size seems invalid, trying to find next section..." -ForegroundColor Yellow

                    $found = $false
                    for ($searchOffset = $offset + 4; $searchOffset -lt [Math]::Min($offset + 500, $Bytes.Length - 2); $searchOffset++) {
                        $testCount = [System.BitConverter]::ToUInt16($Bytes, $searchOffset)
                        if ($testCount -gt 0 -and $testCount -lt 300) {
                            $testStringEnd = $searchOffset + 2 + ($testCount * 2)
                            if ($testStringEnd -lt $Bytes.Length) {
                                Write-Host "  Found potential STRING_DATA at offset 0x$($searchOffset.ToString('X'))" -ForegroundColor Yellow
                                $offset = $searchOffset
                                $found = $true
                                break
                            }
                        }
                    }

                    if (-not $found) {
                        Write-Host "  Could not find STRING_DATA section" -ForegroundColor Red
                        $offset = $Bytes.Length
                    }
                } else {
                    $offset += $linkInfoSize
                    Write-Host "  After LinkInfo, offset: 0x$($offset.ToString('X'))" -ForegroundColor Gray
                }
            }
        }

        # Read STRING_DATA structures

        # NAME_STRING (if present)
        if ($hasName -and ($offset + 2 -le $Bytes.Length)) {
            $charCount = [System.BitConverter]::ToUInt16($Bytes, $offset)
            Write-Host "  Name string: $charCount chars at offset 0x$($offset.ToString('X'))" -ForegroundColor Gray
            $offset += 2
            if ($charCount -gt 0 -and $charCount -lt 1000 -and ($offset + $charCount * 2 -le $Bytes.Length)) {
                $name = [System.Text.Encoding]::Unicode.GetString($Bytes, $offset, $charCount * 2)
                Write-Host "    Name: '$name'" -ForegroundColor Gray
                $offset += $charCount * 2
            }
        }

        # RELATIVE_PATH (if present)
        $relativePath = ""
        if ($hasRelativePath -and ($offset + 2 -le $Bytes.Length)) {
            $charCount = [System.BitConverter]::ToUInt16($Bytes, $offset)
            Write-Host "  RelativePath: $charCount chars at offset 0x$($offset.ToString('X'))" -ForegroundColor Gray
            $offset += 2
            if ($charCount -gt 0 -and $charCount -lt 1000 -and ($offset + $charCount * 2 -le $Bytes.Length)) {
                $relativePath = [System.Text.Encoding]::Unicode.GetString($Bytes, $offset, $charCount * 2)
                Write-Host "    RelPath: '$relativePath'" -ForegroundColor Gray
                $offset += $charCount * 2
            }
        }

        # WORKING_DIR (if present)
        if ($hasWorkingDir -and ($offset + 2 -le $Bytes.Length)) {
            $charCount = [System.BitConverter]::ToUInt16($Bytes, $offset)
            Write-Host "  WorkingDir: $charCount chars at offset 0x$($offset.ToString('X'))" -ForegroundColor Gray
            $offset += 2
            if ($charCount -gt 0 -and $charCount -lt 1000 -and ($offset + $charCount * 2 -le $Bytes.Length)) {
                $strings.WorkingDirectory = [System.Text.Encoding]::Unicode.GetString($Bytes, $offset, $charCount * 2)
                Write-Host "    WorkDir: '$($strings.WorkingDirectory)'" -ForegroundColor Gray
                $offset += $charCount * 2
            }
        }

        # COMMAND_LINE_ARGUMENTS (if present)
        if ($hasArguments -and ($offset + 2 -le $Bytes.Length)) {
            $charCount = [System.BitConverter]::ToUInt16($Bytes, $offset)
            Write-Host "  Arguments: $charCount chars at offset 0x$($offset.ToString('X'))" -ForegroundColor Gray
            $offset += 2
            if ($charCount -gt 0 -and $charCount -lt 1000 -and ($offset + $charCount * 2 -le $Bytes.Length)) {
                $strings.Arguments = [System.Text.Encoding]::Unicode.GetString($Bytes, $offset, $charCount * 2)
                Write-Host "    Args: '$($strings.Arguments)'" -ForegroundColor Gray
                $offset += $charCount * 2
            }
        }

        # ICON_LOCATION (if present)
        if ($hasIconLocation -and ($offset + 2 -le $Bytes.Length)) {
            $charCount = [System.BitConverter]::ToUInt16($Bytes, $offset)
            Write-Host "  IconLocation: $charCount chars at offset 0x$($offset.ToString('X'))" -ForegroundColor Gray
            $offset += 2
            if ($charCount -gt 0 -and $charCount -lt 1000 -and ($offset + $charCount * 2 -le $Bytes.Length)) {
                $iconString = [System.Text.Encoding]::Unicode.GetString($Bytes, $offset, $charCount * 2)
                Write-Host "    Icon: '$iconString'" -ForegroundColor Gray
                if ($iconString -match '^(.+),(\d+)$') {
                    $strings.IconLocation = $matches[1]
                    $strings.IconIndex = [int]$matches[2]
                } else {
                    $strings.IconLocation = $iconString
                    $strings.IconIndex = 0
                }
                $offset += $charCount * 2
            }
        }

        Write-Host "  After string data, offset: 0x$($offset.ToString('X'))" -ForegroundColor Gray

        # Convert relative path to absolute path
        if (-not [string]::IsNullOrWhiteSpace($relativePath)) {
            # If it starts with .\ or .\. then it's relative to working directory
            if ($relativePath -match '^\.\\(.+)$') {
                $filename = $matches[1]
                if (-not [string]::IsNullOrWhiteSpace($strings.WorkingDirectory)) {
                    # Combine working directory with relative path
                    if ($strings.WorkingDirectory.EndsWith('\')) {
                        $strings.TargetPath = $strings.WorkingDirectory + $filename
                    } else {
                        $strings.TargetPath = $strings.WorkingDirectory + '\' + $filename
                    }
                    Write-Host "  Converted relative path to: '$($strings.TargetPath)'" -ForegroundColor Gray
                } else {
                    $strings.TargetPath = $relativePath
                }
            } else {
                $strings.TargetPath = $relativePath
            }
        }

        return $strings
    }
    catch {
        Write-Host "  Error parsing shortcut: $_" -ForegroundColor Red
        Write-Host "  Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $strings
    }
}

function New-ShortcutFromData {
    param(
        [string]$ShortcutPath,
        [hashtable]$Data
    )

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

    # Set target path - DO NOT expand environment variables
    $Shortcut.TargetPath = $Data.TargetPath

    if ($Data.WorkingDirectory) {
        $Shortcut.WorkingDirectory = $Data.WorkingDirectory
    }

    if ($Data.Arguments) {
        $Shortcut.Arguments = $Data.Arguments
    }

    if ($Data.IconLocation) {
        $iconPath = $Data.IconLocation
        if ($Data.IconIndex -ne 0) {
            $iconPath = "$iconPath,$($Data.IconIndex)"
        }
        $Shortcut.IconLocation = $iconPath
    }

    $Shortcut.Save()

    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
}

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
        Write-Host "Processing: $($shortcut.Name)" -ForegroundColor Cyan

        # Read the broken shortcut
        $bytes = [System.IO.File]::ReadAllBytes($shortcut.FullName)

        # Extract string data
        $data = Extract-ShortcutStrings -Bytes $bytes

        Write-Host "  Final extracted data:" -ForegroundColor Yellow
        Write-Host "    Target: '$($data.TargetPath)'" -ForegroundColor Cyan
        Write-Host "    WorkDir: '$($data.WorkingDirectory)'" -ForegroundColor Cyan
        Write-Host "    Arguments: '$($data.Arguments)'" -ForegroundColor Cyan
        Write-Host "    Icon: '$($data.IconLocation)',$($data.IconIndex)" -ForegroundColor Cyan

        if ([string]::IsNullOrWhiteSpace($data.TargetPath)) {
            throw "Could not extract target path from shortcut"
        }

        # Validate that the target will exist when environment variables are expanded
        $expandedTarget = [System.Environment]::ExpandEnvironmentVariables($data.TargetPath)
        if (-not (Test-Path $expandedTarget)) {
            throw "Target file does not exist: $expandedTarget (from: $($data.TargetPath))"
        }

        # Create backup
        $backupPath = "$($shortcut.FullName).bak"
        Copy-Item $shortcut.FullName $backupPath -Force

        # Delete old shortcut
        Remove-Item $shortcut.FullName -Force

        # Create new shortcut with extracted data
        New-ShortcutFromData -ShortcutPath $shortcut.FullName -Data $data

        # Delete backup if successful
        Remove-Item $backupPath -Force

        Write-Host "[OK] $($shortcut.Name)" -ForegroundColor Green
        Write-Host ""
        $SuccessCount++
    }
    catch {
        Write-Host "[FAILED] $($shortcut.Name) - Error: $_" -ForegroundColor Red
        Write-Host ""
        $FailCount++

        # Restore from backup if it exists
        $backupPath = "$($shortcut.FullName).bak"
        if (Test-Path $backupPath) {
            Copy-Item $backupPath $shortcut.FullName -Force
            Remove-Item $backupPath -Force
            Write-Host "  Restored from backup" -ForegroundColor Yellow
        }
    }
}

# Display summary
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Successfully repaired: $SuccessCount" -ForegroundColor Green
if ($FailCount -gt 0) {
    Write-Host "  Failed: $FailCount" -ForegroundColor Red
}
Write-Host "==================================================" -ForegroundColor Cyan
