$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$catalogPath = Join-Path $root "config\apps.json"
$iconRoot = Join-Path $root "assets\icons"

New-Item -ItemType Directory -Path $iconRoot -Force | Out-Null
$apps = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json

function Get-SafeIconName {
    param([string]$Id)
    return ($Id -replace '[^a-zA-Z0-9.-]', '_') + ".png"
}

function New-FallbackIcon {
    param([object]$App, [string]$Path)

    $bitmap = [System.Drawing.Bitmap]::new(64, 64)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $color = [System.Drawing.ColorTranslator]::FromHtml($App.accent)
    $brush = [System.Drawing.SolidBrush]::new($color)
    $graphics.FillRectangle($brush, 0, 0, 64, 64)

    $fontSize = if ($App.icon.Length -gt 2) { 16 } else { 21 }
    $font = [System.Drawing.Font]::new("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $graphics.DrawString($App.icon, $font, $white, [System.Drawing.RectangleF]::new(0, 0, 64, 64), $format)

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

function Save-IconFromUrl {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Path
    )

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing -TimeoutSec 20
        if (-not (Test-Path -LiteralPath $tempFile) -or ((Get-Item -LiteralPath $tempFile).Length -le 100)) {
            return $false
        }

        try {
            $image = [System.Drawing.Image]::FromFile($tempFile)
            $bitmap = [System.Drawing.Bitmap]::new($image, 64, 64)
            $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
            $bitmap.Dispose()
            $image.Dispose()
            return (Test-Path -LiteralPath $Path) -and ((Get-Item -LiteralPath $Path).Length -gt 100)
        } catch {
            Copy-Item -LiteralPath $tempFile -Destination $Path -Force
            return (Test-Path -LiteralPath $Path) -and ((Get-Item -LiteralPath $Path).Length -gt 100)
        }
    } catch {
        return $false
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
}

$downloaded = 0
$fallback = 0

foreach ($app in $apps) {
    $path = Join-Path $iconRoot (Get-SafeIconName -Id $app.id)
    $ok = $false

    if ($app.domain) {
        $domainText = ([string]$app.domain) -replace '^https?://', ''
        $domainText = ($domainText -split '/')[0]
        $encodedDomain = [Uri]::EscapeDataString($domainText)
        $urls = @(
            "https://icons.duckduckgo.com/ip3/$domainText.ico",
            "https://www.google.com/s2/favicons?domain=$encodedDomain&sz=64",
            "https://$domainText/favicon.ico"
        )

        foreach ($url in $urls) {
            if (Save-IconFromUrl -Url $url -Path $path) {
                $ok = $true
                $downloaded++
                break
            }
        }
    }

    if (-not $ok) {
        New-FallbackIcon -App $app -Path $path
        $fallback++
    }
}

"Icones reais baixados: $downloaded"
"Fallbacks gerados: $fallback"
