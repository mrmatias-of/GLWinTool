param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $projectRoot "dist"
$compiledScript = Join-Path $dist "GLWinTool.ps1"
$exePath = Join-Path $dist "GL-WinTool.exe"
$iconPath = Join-Path $projectRoot "assets\app-icon.ico"
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath (Join-Path $projectRoot "VERSION") -Raw).Trim() -replace '-.*$', ''
}

powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot "Compile.ps1")

$ps2exe = Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue
if (-not $ps2exe) {
    throw "Invoke-ps2exe nao encontrado. Instale com: Install-Module ps2exe -Scope CurrentUser"
}

if (Test-Path -LiteralPath $iconPath) {
    Invoke-ps2exe $compiledScript $exePath `
        -title "GL WinTool" `
        -description "Central de instalacao, ajustes e manutencao Windows" `
        -company "G-LAB Cursos" `
        -product "GL WinTool" `
        -version $Version `
        -iconFile $iconPath `
        -noConsole
} else {
    Invoke-ps2exe $compiledScript $exePath `
        -title "GL WinTool" `
        -description "Central de instalacao, ajustes e manutencao Windows" `
        -company "G-LAB Cursos" `
        -product "GL WinTool" `
        -version $Version `
        -noConsole
}

Write-Host "EXE gerado: $exePath"

