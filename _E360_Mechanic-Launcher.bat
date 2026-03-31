@echo off

set ps1Path=%~dp0CFWarpRdpLauncher.ps1
set rdpPath=%~dp0E360 Mechanic zt.rdp
set softwareName=Equipment 360
set ip=10.147.18.204
set port=3389
set connectTimeoutMs=2000
set autoCloseTimeout=10
set rdpWaitIntervalSec=2
set rdpWaitTimeoutSec=40
set killAllRdpProcs=$true

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { . '%ps1Path%' -rdpPath '%rdpPath%' -softwareName '%softwareName%' -ip %ip% -port %port% -connectTimeoutMs %connectTimeoutMs% -autoCloseTimeout %autoCloseTimeout% -rdpWaitIntervalSec %rdpWaitIntervalSec% -rdpWaitTimeoutSec %rdpWaitTimeoutSec% -killAllRdpProcs %killAllRdpProcs% }"
