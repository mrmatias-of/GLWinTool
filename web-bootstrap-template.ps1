$ErrorActionPreference = "Stop"

$repoZipUrl = "https://github.com/mrmatias-of/assistente-glab/archive/refs/heads/main.zip"
$tempRoot = Join-Path $env:TEMP "Assistente-GLAB"
$zipPath = Join-Path $tempRoot "assistente-glab-main.zip"
$extractRoot = Join-Path $tempRoot "repo"
$appRoot = Join-Path $extractRoot "assistente-glab-main"
$scriptPath = Join-Path $appRoot "WinTool.ps1"

function Write-GLabStep {
    param([string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message) -ForegroundColor Cyan
}

function Write-GLabError {
    param([string]$Message)
    Write-Host ""
    Write-Host "Assistente G-LAB nao conseguiu iniciar." -ForegroundColor Red
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Tente novamente em uma janela do Windows PowerShell executada como administrador:" -ForegroundColor Gray
    Write-Host "irm https://www.glabcursos.com.br/win | iex" -ForegroundColor White
}

Clear-Host
Write-Host ""
Write-Host "Assistente G-LAB" -ForegroundColor White
Write-Host "Central de instalacao, ajustes e manutencao Windows" -ForegroundColor DarkCyan
Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

try {
    Write-GLabStep "Preparando pasta temporaria..."
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }

    Write-GLabStep "Baixando versao mais recente do GitHub..."
    Invoke-RestMethod -Uri $repoZipUrl -OutFile $zipPath

    Write-GLabStep "Extraindo arquivos..."
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "WinTool.ps1 nao encontrado apos baixar o Assistente G-LAB."
    }

    Write-GLabStep "Abrindo interface grafica..."
    powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $scriptPath
}
catch {
    Write-GLabError -Message $_.Exception.Message
    throw
}
