$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$csc = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $csc) {
    throw "Compilador C# nativo do Windows nao encontrado."
}

$outDir = Join-Path $root "dist-native-single"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$outExe = Join-Path $outDir "GL-WinTool.exe"

& $csc `
    /nologo `
    /target:winexe `
    /platform:x64 `
    /optimize+ `
    /win32icon:"$(Join-Path $root 'assets\app-icon.ico')" `
    /reference:System.dll `
    /reference:System.Core.dll `
    /reference:System.Drawing.dll `
    /reference:System.Windows.Forms.dll `
    /reference:System.Web.Extensions.dll `
    /resource:"$(Join-Path $root 'config\apps.json'),config.apps.json" `
    /out:"$outExe" `
    "$(Join-Path $root 'src\native-single\GLWinToolNative.cs')"

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao compilar o GL WinTool nativo single-exe."
}

Write-Host "EXE nativo single-file gerado: $outExe"
