#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap a Windows machine: install apps via winget and set up WSL2 + Ubuntu.

.DESCRIPTION
    Philosophy: Windows hosts the GUI apps; WSL2 + Ubuntu hosts the dev tooling.
    Heavy lifting (zsh, tmux, nvim, mise, Starship) is done by bootstrap-linux.sh
    inside WSL — we just need to get WSL up and the apps installed here.

.PARAMETER SkipApps
    Skip the winget import step (useful if you've already run it).

.PARAMETER SkipWsl
    Skip WSL2 + Ubuntu install (useful on machines where WSL isn't wanted).

.EXAMPLE
    PS> .\bootstrap-windows.ps1

.EXAMPLE
    PS> .\bootstrap-windows.ps1 -SkipWsl

.NOTES
    Run from an elevated PowerShell (Run as Administrator). The script will
    reboot prompts for WSL feature enablement — re-run after reboot to finish.
#>
param(
    [switch]$SkipApps,
    [switch]$SkipWsl
)

$ErrorActionPreference = 'Stop'
$DotfilesDir = $PSScriptRoot

function Log-Info    { param($m) Write-Host "[INFO] $m"    -ForegroundColor Cyan }
function Log-Success { param($m) Write-Host "[OK]   $m"    -ForegroundColor Green }
function Log-Warning { param($m) Write-Host "[WARN] $m"    -ForegroundColor Yellow }
function Log-Error   { param($m) Write-Host "[ERR]  $m"    -ForegroundColor Red }

###############################################################################
# 0. Elevation check
###############################################################################
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log-Error "This script must be run as Administrator. Right-click PowerShell -> Run as Administrator."
    exit 1
}

Log-Info "Dotfiles directory: $DotfilesDir"

###############################################################################
# 1. Install apps via winget
###############################################################################
if (-not $SkipApps) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Log-Error "winget not found. Install 'App Installer' from the Microsoft Store and re-run."
        exit 1
    }

    $manifest = Join-Path $DotfilesDir 'winget.json'
    if (-not (Test-Path $manifest)) {
        Log-Error "winget.json not found at $manifest"
        exit 1
    }

    Log-Info "Importing apps from winget.json (this takes a while)..."
    # --ignore-unavailable: don't fail the whole import if one package ID is off
    # --ignore-versions:    accept whatever latest is on the machine
    winget import --import-file $manifest --accept-package-agreements --accept-source-agreements --ignore-unavailable --ignore-versions
    Log-Success "winget import finished"
} else {
    Log-Info "Skipping winget import (-SkipApps)"
}

###############################################################################
# 2. Install WSL2 + Ubuntu
###############################################################################
if (-not $SkipWsl) {
    Log-Info "Setting up WSL2 + Ubuntu..."

    # On Windows 10 2004+ / Windows 11, `wsl --install` handles feature enablement,
    # kernel install, and distro install in one go. On older builds this will
    # fall back to a manual flow that requires a reboot.
    $wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wslInstalled) {
        $distros = (wsl --list --quiet 2>$null) -replace "`0", ""
        if ($distros -match "Ubuntu") {
            Log-Success "Ubuntu WSL distro already present"
        } else {
            Log-Info "Installing Ubuntu via 'wsl --install -d Ubuntu'..."
            wsl --install -d Ubuntu
            Log-Warning "A reboot may be required to finish WSL setup. If Ubuntu didn't launch,"
            Log-Warning "reboot and re-run this script with -SkipApps to finish WSL setup."
        }
    } else {
        Log-Info "wsl command not found — enabling features and installing..."
        wsl --install -d Ubuntu
        Log-Warning "Reboot required. Re-run this script with -SkipApps after reboot."
    }

    Log-Info "Setting WSL default version to 2..."
    wsl --set-default-version 2 2>$null | Out-Null
} else {
    Log-Info "Skipping WSL setup (-SkipWsl)"
}

###############################################################################
# Summary
###############################################################################
Write-Host ""
Log-Success "Windows bootstrap finished."
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Launch Ubuntu from the Start Menu. On first run it asks for a username + password."
Write-Host "  2. Inside Ubuntu, clone this repo and run bootstrap-linux.sh:"
Write-Host ""
Write-Host "       sudo apt-get update && sudo apt-get install -y git"
Write-Host "       git clone https://github.com/calebtutty/dotfiles.git ~/dotfiles"
Write-Host "       cd ~/dotfiles && ./bootstrap-linux.sh"
Write-Host ""
Write-Host "  3. Launch Tailscale from the Start Menu and sign in to join the tailnet."
Write-Host "     (WSL's Ubuntu side will need its own 'sudo tailscale up' — WSL doesn't share"
Write-Host "      the Windows host's tailnet identity.)"
Write-Host "  4. Open Windows Terminal — it should auto-detect Ubuntu and PowerShell 7 profiles."
Write-Host ""
