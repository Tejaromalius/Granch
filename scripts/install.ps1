<#
.SYNOPSIS
    Installs a binary from GitHub releases and adds it to the user's PATH.

.PARAMETER Repo
    The GitHub repository in 'user/repo' format. Defaults to 'Tejaromalius/granch'.

.PARAMETER BinaryName
    The name of the binary to install. Defaults to 'granch'.

.EXAMPLE
    .\install.ps1 -Repo "Tejaromalius/granch" -BinaryName "granch"
#>

param (
    [string]$Repo = "Tejaromalius/granch",
    [string]$BinaryName = "granch"
)

$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $HOME ".local\bin"
if (!(Test-Path $InstallDir)) {
    Write-Host "Creating install directory: $InstallDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

Write-Host "Fetching latest release for $Repo..." -ForegroundColor Cyan
$ReleaseUrl = "https://api.github.com/repos/$Repo/releases/latest"

try {
    $ReleaseData = Invoke-RestMethod -Uri $ReleaseUrl -Method Get
} catch {
    Write-Error "No release found for $Repo. Ensure the repository has a public release."
    return
}

# Determine Architecture
$Arch = "amd64"
if ([Environment]::Is64BitProcess) {
    if ($PSVersionTable.OS -eq "Darwin") { $Arch = "arm64" } # Simplistic
} else {
    $Arch = "386"
}

# Find suitable asset
# We look for assets that match Windows and the detected architecture
$Asset = $ReleaseData.assets | Where-Object { 
    $MatchesOS = ($_.name -like "*windows*" -or $_.name -like "*.exe" -or $_.name -like "*.zip")
    $MatchesArch = ($_.name -like "*$Arch*" -or $_.name -like "*x64*" -or $_.name -like "*86_64*")
    $MatchesOS -and $MatchesArch
} | Select-Object -First 1

if ($null -eq $Asset) {
    Write-Host "Could not find a suitable Windows asset for $Arch." -ForegroundColor Red
    Write-Host "Available assets:"
    $ReleaseData.assets.name
    return
}

$DownloadUrl = $Asset.browser_download_url
$TempFile = Join-Path $env:TEMP $Asset.name

Write-Host "Downloading $($Asset.name)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile

# Extraction / Installation
if ($Asset.name -like "*.zip") {
    $ExtractPath = Join-Path $env:TEMP "granch_install"
    if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }
    Expand-Archive -Path $TempFile -DestinationPath $ExtractPath -Force
    
    $Binary = Get-ChildItem -Path $ExtractPath -Filter "$BinaryName.exe" -Recurse | Select-Object -First 1
    if ($Binary) {
        Move-Item $Binary.FullName -Destination (Join-Path $InstallDir "$BinaryName.exe") -Force
    } else {
        Write-Error "Could not find $BinaryName.exe in the zip archive."
    }
    Remove-Item $ExtractPath -Recurse -Force
} else {
    $DestPath = Join-Path $InstallDir "$BinaryName.exe"
    Move-Item $TempFile -Destination $DestPath -Force
}

if (Test-Path $TempFile) { Remove-Item $TempFile -Force }

Write-Host "Successfully installed $BinaryName to $InstallDir" -ForegroundColor Green

# Update PATH
$Target = [EnvironmentVariableTarget]::User
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", $Target)

if ($CurrentPath -notlike "*$InstallDir*") {
    Write-Host "Adding $InstallDir to User PATH..." -ForegroundColor Cyan
    $NewPath = "$CurrentPath;$InstallDir"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, $Target)
    Write-Host "PATH updated. Please restart your terminal." -ForegroundColor Green
} else {
    Write-Host "$InstallDir is already in your PATH." -ForegroundColor Gray
}

Write-Host "Installation complete!" -ForegroundColor Green
