param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = Join-Path $root "src\native\GLWinTool\GLWinTool.csproj"
$publish = Join-Path $root "dist-native"

$sdk = (& dotnet --list-sdks) 2>$null
if (-not $sdk) {
    throw "SDK .NET nao encontrado. Instale o .NET 8 SDK para gerar o aplicativo nativo."
}

dotnet publish $project `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -o $publish

Write-Host "App nativo gerado em: $publish"
