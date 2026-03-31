param(
    [string]$rdpPath = "$($env:ONEDRIVE)\Documents\Equipment360\RDP\E360 Manager zt.rdp",
    [string]$softwareName = "Equipment 360",
    [string]$ip = "10.147.18.204",
    [int]$port = 3389,
    [int]$connectTimeoutMs = 2000,
    [int]$autoCloseTimeout = 10,
    [int]$rdpWaitIntervalSec = 2,
    [int]$rdpWaitTimeoutSec = 40,
    [bool]$killAllRdpProcs = $true
)

function Kill-RdpProcesses {
    Write-Host "Killing all existing RDP processes..." -ForegroundColor Yellow
    Stop-Process -Name "mstsc", "wksprt" -Force -ErrorAction SilentlyContinue
}

function Show-AuthInstructions {
    Write-Host "Re-authentication is required to access '${softwareName}'. Please follow these steps:" -ForegroundColor Red
    Write-Host "- Look in the bottom right corner of your screen for a notification titled '" -ForegroundColor Blue -NoNewline
    Write-Host "Cloudflare WARP" -ForegroundColor Cyan -NoNewline
    Write-Host "'" -ForegroundColor Blue
    Write-Host "- Click the button labeled '" -ForegroundColor Blue -NoNewline
    Write-Host "Open Browser and Re-Authenticate" -ForegroundColor Cyan -NoNewline
    Write-Host "'" -ForegroundColor Blue
    Write-Host "- A new web browser tab/window should now open. If you do not see it, hover your mouse over" -ForegroundColor Blue
    Write-Host "  the web browser icon in your taskbar. Click the browser tab/window with the title including" -ForegroundColor Blue
    Write-Host "  the text '" -ForegroundColor Blue -NoNewline
    Write-Host "Cloudflare Access" -ForegroundColor Cyan -NoNewline
    Write-Host "'" -ForegroundColor Blue
    Write-Host "- If you see a success message on the webpage, continue to the next step. If you instead" -ForegroundColor Blue
    Write-Host "  see a login/sign-in webpage, do one of the following:" -ForegroundColor Blue
    Write-Host "    - If you have a work email address:" -ForegroundColor Blue
    Write-Host "        Click the '" -ForegroundColor Blue -NoNewline
    Write-Host "Azure AD - Azure AD - Tex-Mix Concrete" -ForegroundColor Cyan -NoNewline
    Write-Host "' button and enter your work email" -ForegroundColor Blue
    Write-Host "        credentials if prompted (if you see a success msg, you don't need to enter anything)" -ForegroundColor Blue
    Write-Host "    - If you do not have a work email address:" -ForegroundColor Blue
    Write-Host "        Enter your personal email address in the '" -ForegroundColor Blue -NoNewline
    Write-Host "Email" -ForegroundColor Cyan -NoNewline
    Write-Host "' textbox, click '" -ForegroundColor Blue -NoNewline
    Write-Host "Send me a code" -ForegroundColor Cyan -NoNewline
    Write-Host "'," -ForegroundColor Blue
    Write-Host "        and follow the instructions" -ForegroundColor Blue
    Write-Host "- Once you see a message indicating you have successfully authenticated, close the browser" -ForegroundColor Blue
    Write-Host "  tab/window, click inside this window, and " -ForegroundColor Blue -NoNewline
    Write-Host "press any key on your keyboard to continue..." -ForegroundColor Yellow -NoNewLine
    [System.Console]::ReadKey($true) | Out-Null
    Write-Host ""  # New line after key press
}

function Test-Connect {
    param(
        [string]$ipAddress,
        [int]$port,
        [int]$connectTimeoutMs
    )

    function Compare-ByteArrays($array1, $array2, $count) {
        if ($array1.Length -lt $count -or $array2.Length -lt $count) {
            return $false
        }
        for ($i = 0; $i -lt $count; $i++) {
            if ($array1[$i] -ne $array2[$i]) {
                return $false
            }
        }
        return $true
    }

    $rdpNegotiationByteArray = [byte[]] -split ('0300002c27e00000000000436f6f6b69653a206d737473686173683d656c746f6e730d0a0100080000000000' -replace '..', '0x$& ')
    $validResponseByteArray = [byte[]] -split ('030000130ED000001234' -replace '..', '0x$& ')

    $tcpClient = New-Object System.Net.Sockets.TcpClient

    try {
        $connectTask = $tcpClient.ConnectAsync($ipAddress, $port)
        if ($connectTask.Wait($connectTimeoutMs)) {
            $networkStream = $tcpClient.GetStream()
            $networkStream.Write($rdpNegotiationByteArray, 0, $rdpNegotiationByteArray.Length)
            $responseBuffer = [byte[]]::new(32)
            $responseLength = $networkStream.Read($responseBuffer, 0, $responseBuffer.Length)
            $networkStream.Close()
            
            if ($responseLength -ge $validResponseByteArray.Length) {
                return Compare-ByteArrays $validResponseByteArray $responseBuffer $validResponseByteArray.Length
            }
        }
        return $false
    }
    catch {
        return $false
    }
    finally {
        $tcpClient.Close()
    }
}

function Open-RdpFile {
    param([string]$rdpPath)
    
    Write-Host "Launching '${softwareName}'. Please wait..." -ForegroundColor Green
    Start-Process "mstsc.exe" -ArgumentList "`"${rdpPath}`""
}

function Show-ExitMessage {
    param(
        [bool]$success,
        [bool]$waitForKey = $false
    )
    
    if ($success) {
        Write-Host "'${softwareName}' should now be starting up. If it is not, try running this script " -ForegroundColor Green
        Write-Host "again. If it still fails, please contact IT for help. This window will automatically " -ForegroundColor Green
        Write-Host "close in ${autoCloseTimeout} seconds. To exit immediately, click inside this window, and" -ForegroundColor Green
        Write-Host "press " -ForegroundColor Yellow -NoNewLine
        Write-Host "any key on your keyboard to exit..." -ForegroundColor Yellow
        
        # Wait for key or timeout, whichever comes first
        $timeout = [datetime]::Now.AddSeconds($autoCloseTimeout)
        while ([datetime]::Now -lt $timeout) {
            if ([Console]::KeyAvailable) {
                [System.Console]::ReadKey($true) | Out-Null
                break
            }
            Start-Sleep -Milliseconds 100
        }
    }
    else {
        Write-Host "Communication with the '${softwareName}' server could not be established." -ForegroundColor Red
        Write-Host "Try running this script again, and if it still fails, please contact"
        Write-Host "IT for help. To close this window, click inside this window, and"
        Write-Host "press any key on your keyboard to exit..." -ForegroundColor Yellow
        
        if ($waitForKey) {
            [System.Console]::ReadKey($true) | Out-Null
        }
    }
}

function Wait-ForConnection {
    param([bool]$showInitialDelay = $false)
    
    Write-Host "'${softwareName}' will open automatically as soon as a connection to the server is established. Please wait..." -ForegroundColor Yellow
    
    if ($showInitialDelay) {
        Start-Sleep -Seconds 20
    }
    
    $startTime = [datetime]::Now
    
    while ($true) {
        $elapsedTime = ([datetime]::Now - $startTime).TotalSeconds
        
        if ($elapsedTime -ge $rdpWaitTimeoutSec) {
            Write-Host "Timeout reached. Aborting..." -ForegroundColor Red
            Show-ExitMessage -success $false -waitForKey $true
            exit 1
        }

        if (Test-Connect -ipAddress $ip -port $port -connectTimeoutMs $connectTimeoutMs) {
            Write-Host "Connection successful!" -ForegroundColor Green
            Open-RdpFile -rdpPath $rdpPath
            Show-ExitMessage -success $true
            exit 0
        }

        Start-Sleep -Seconds $rdpWaitIntervalSec
    }
}

# Main script execution
if ($killAllRdpProcs) {
    Kill-RdpProcesses
}

Write-Host "Checking the connection to '${softwareName}'. Please wait..." -ForegroundColor Yellow

if (Test-Connect -ipAddress $ip -port $port -connectTimeoutMs $connectTimeoutMs) {
    Write-Host "Connection successful!" -ForegroundColor Green
    Open-RdpFile -rdpPath $rdpPath
    Show-ExitMessage -success $true
    exit 0
}
else {
    Show-AuthInstructions
    Wait-ForConnection -showInitialDelay $true
}
