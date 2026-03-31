# E360Launcher

This repo contains a launcher script which make it easier to use an Equipment 360 RDP connection in combination with Cloudflare WARP. The launcher instructs the user on how to accept Cloudflare WARP permissions dialogs necessary to launch the included RDP files.

**InstallE360Launcher.ps1** is an installation script which creates the necessary directory structure, downloads the repo's contents, repairs the shortcut (.lnk) files, and copies the user-selected shortcuts to the user-selected destinations.

## Installation

1. Click the **Start Menu**, type `PowerShell`, and open it.

2. Copy and paste the code below and press **Enter.**  
    ```
    irm https://bit.ly/e360launcher | iex
    ```
    If the above does not work, try this:
    ```
    irm https://raw.githubusercontent.com/lahma0/E360Launcher/refs/heads/main/InstallE360Launcher.ps1 | iex
    ```
    Finally, if all of the above options fail, manually download **InstallE360Launcher.ps1** and run it like this:
    ```
    powershell.exe -NoProfile -NoLogo -ExecutionPolicy Bypass -File "C:\path\to\InstallE360Launcher.ps1"
    ```
