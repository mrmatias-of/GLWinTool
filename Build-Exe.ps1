param(
    [string]$Version = "0.4.0"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $projectRoot "dist"
$compiledScript = Join-Path $dist "AssistenteGLAB.ps1"
$exePath = Join-Path $dist "Assistente-G-LAB.exe"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot "Compile.ps1")

$ps2exe = Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue
if (-not $ps2exe) {
    throw "Invoke-ps2exe nao encontrado. Instale com: Install-Module ps2exe -Scope CurrentUser"
}

Invoke-ps2exe $compiledScript $exePath `
    -title "Assistente G-LAB" `
    -description "Central de instalacao, ajustes e manutencao Windows" `
    -company "G-LAB Cursos" `
    -product "Assistente G-LAB" `
    -version $Version

Write-Host "EXE gerado: $exePath"
