param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath (Join-Path $projectRoot "VERSION") -Raw).Trim() -replace '-.*$', ''
}

& (Join-Path $projectRoot 'Build-NativeSingle.ps1')
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'dist') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'dist-native-single\GL-WinTool.exe') -Destination (Join-Path $projectRoot 'dist\GL-WinTool.exe') -Force
$exePath = Join-Path $projectRoot 'dist\GL-WinTool.exe'
$actualVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath).ProductVersion

Write-Host "EXE nativo gerado: $exePath"
Write-Host "Versao solicitada: $Version"
Write-Host "Versao do arquivo: $actualVersion"

