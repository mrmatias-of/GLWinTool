param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = Join-Path $root "src\native\GLWinTool\GLWinTool.csproj"
$publish = Join-Path $root "dist-native"
$env:DOTNET_CLI_HOME = Join-Path $root ".dotnet-home"
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
New-Item -ItemType Directory -Path $env:DOTNET_CLI_HOME -Force | Out-Null

$sdk = (& dotnet --list-sdks) 2>$null
if (-not $sdk) {
    throw "SDK .NET nao encontrado. Instale o .NET 8 SDK para gerar o aplicativo nativo."
}

dotnet publish $project `
    -c $Configuration `
    -r win-x64 `
    --self-contained false `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=true `
    --ignore-failed-sources `
    -o $publish
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao gerar o aplicativo nativo."
}

Write-Host "App nativo gerado em: $publish"
