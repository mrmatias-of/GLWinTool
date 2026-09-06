$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Join-Path $root "WinTool.ps1"

Clear-Host
Write-Host ""
Write-Host "Assistente G-LAB" -ForegroundColor White
Write-Host "Inicializacao local" -ForegroundColor DarkCyan
Write-Host "-------------------" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path -LiteralPath $app)) {
    throw "WinTool.ps1 nao encontrado em $root"
}

Write-Host "Abrindo interface grafica..." -ForegroundColor Cyan
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $app
