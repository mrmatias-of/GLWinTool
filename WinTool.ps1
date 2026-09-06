param(
    [switch]$NoProfile,
    [switch]$ValidateOnly,
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ConfigPath = Join-Path $script:Root "config\apps.json"
$script:VersionPath = Join-Path $script:Root "VERSION"
$script:TweaksPath = Join-Path $script:Root "config\tweaks.json"
$script:PresetsPath = Join-Path $script:Root "config\presets.json"
$script:AppxPath = Join-Path $script:Root "config\appx.json"
$script:IconRoot = Join-Path $script:Root "assets\icons"
$script:LogoPath = Join-Path $script:Root "assets\readme\glab-mark.png"
$script:BackupRoot = Join-Path $script:Root "backups"
$script:ActiveView = "Install"
$script:IsBusy = $false
$script:SelectedAppIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:SelectedTweakNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:SelectedAppxNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:TweakCheckboxes = [System.Collections.ArrayList]::new()
$script:DnsPresets = @(
    [pscustomobject]@{ Name = "Padrao do provedor"; Primary = ""; Secondary = ""; Description = "Volta para DNS automatico por DHCP." },
    [pscustomobject]@{ Name = "Cloudflare"; Primary = "1.1.1.1"; Secondary = "1.0.0.1"; Description = "DNS rapido com foco em privacidade." },
    [pscustomobject]@{ Name = "Google"; Primary = "8.8.8.8"; Secondary = "8.8.4.4"; Description = "DNS publico do Google." },
    [pscustomobject]@{ Name = "Quad9"; Primary = "9.9.9.9"; Secondary = "149.112.112.112"; Description = "DNS com bloqueio de dominios maliciosos." },
    [pscustomobject]@{ Name = "AdGuard"; Primary = "94.140.14.14"; Secondary = "94.140.15.15"; Description = "DNS com bloqueio de anuncios e rastreadores." }
)
$script:AppVersion = if (Test-Path -LiteralPath $script:VersionPath) { (Get-Content -LiteralPath $script:VersionPath -Raw).Trim() } else { "dev" }

if (-not $ValidateOnly -and [System.Threading.Thread]::CurrentThread.GetApartmentState() -ne "STA") {
    powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Path
    return
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Load-JsonFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Name nao encontrado: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Load-AppCatalog {
    return Load-JsonFile -Path $script:ConfigPath -Name "Catalogo de apps"
}

function Load-TweakCatalog {
    return Load-JsonFile -Path $script:TweaksPath -Name "Catalogo de tweaks"
}

function Load-PresetCatalog {
    return Load-JsonFile -Path $script:PresetsPath -Name "Catalogo de presets"
}

function Load-AppxCatalog {
    return Load-JsonFile -Path $script:AppxPath -Name "Catalogo AppX"
}

function Write-Log {
    param([string]$Message)
    if (-not $script:LogBox) { return }
    $stamp = Get-Date -Format "HH:mm:ss"
    $script:LogBox.Dispatcher.Invoke([Action]{
        $script:LogBox.AppendText("[$stamp] $Message`r`n")
        $script:LogBox.ScrollToEnd()
    })
}

function New-BackupSession {
    param([string]$Reason = "acao")
    $safeReason = ($Reason -replace '[^a-zA-Z0-9_-]', '-').Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeReason)) { $safeReason = "acao" }
    $session = Join-Path $script:BackupRoot ("{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $safeReason)
    New-Item -ItemType Directory -Path $session -Force | Out-Null
    Write-Log "Backup iniciado: $session"
    return $session
}

function Convert-RegistryPathForRegExe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    return ($Path -replace '^HKCU:', 'HKEY_CURRENT_USER' -replace '^HKLM:', 'HKEY_LOCAL_MACHINE' -replace '^HKCR:', 'HKEY_CLASSES_ROOT' -replace '^HKU:', 'HKEY_USERS' -replace '^HKCC:', 'HKEY_CURRENT_CONFIG') -replace '/', '\'
}

function Export-RegistryBackup {
    param(
        [Parameter(Mandatory=$true)][string]$RegistryPath,
        [Parameter(Mandatory=$true)][string]$BackupDir
    )

    $regPath = Convert-RegistryPathForRegExe -Path $RegistryPath
    if ([string]::IsNullOrWhiteSpace($regPath)) { return }
    $fileName = (($regPath -replace '[\\/:*?"<>| ]', '_').Trim("_")) + ".reg"
    $target = Join-Path $BackupDir $fileName
    try {
        Invoke-LoggedProcess -FilePath "reg.exe" -Arguments @("export", $regPath, $target, "/y") | Out-Null
        Write-Log "Registro salvo antes da alteracao: $regPath"
    } catch {
        Write-Log "Nao foi possivel salvar backup do registro: $regPath"
    }
}

function Export-AppxInventory {
    param([Parameter(Mandatory=$true)][string]$BackupDir)
    try {
        Get-AppxPackage -AllUsers |
            Select-Object Name, PackageFullName, PackageUserInformation |
            ConvertTo-Json -Depth 6 |
            Set-Content -LiteralPath (Join-Path $BackupDir "appx-instalados.json") -Encoding UTF8
        Get-AppxProvisionedPackage -Online |
            Select-Object DisplayName, PackageName |
            ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath (Join-Path $BackupDir "appx-provisionados.json") -Encoding UTF8
        Write-Log "Inventario AppX salvo antes da remocao."
    } catch {
        Write-Log "Nao foi possivel salvar inventario AppX."
    }
}

function New-SafeRestorePoint {
    param([string]$Description = "Assistente G-LAB")
    if (-not (Test-IsAdmin)) {
        Write-Log "Ponto de restauracao ignorado: execute como administrador para habilitar."
        return
    }
    try {
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"
        Write-Log "Ponto de restauracao solicitado."
    } catch {
        Write-Log "Ponto de restauracao nao criado: $($_.Exception.Message)"
    }
}

function Invoke-LoggedProcess {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string[]]$Arguments
    )

    Write-Log "> $FilePath $($Arguments -join ' ')"
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $escapedArguments = foreach ($argument in $Arguments) {
        if ($null -eq $argument) { continue }
        if ($argument -match '[\s"]') {
            '"' + ($argument -replace '"', '\"') + '"'
        } else {
            $argument
        }
    }
    $psi.Arguments = $escapedArguments -join " "
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($stdout -and $stdout.Trim()) { Write-Log $stdout.Trim() }
    if ($stderr -and $stderr.Trim()) { Write-Log $stderr.Trim() }
    Write-Log "Exit code: $($process.ExitCode)"
    return $process.ExitCode
}

function Get-WingetPackageArguments {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("install", "uninstall", "upgrade")]
        [string]$Action,

        [Parameter(Mandatory=$true)]
        [string]$PackageId
    )

    if ([string]::IsNullOrWhiteSpace($PackageId) -or $PackageId -eq "na") {
        return @()
    }

    $source = "winget"
    $id = $PackageId
    if ($id.StartsWith("msstore:", [System.StringComparison]::OrdinalIgnoreCase)) {
        $source = "msstore"
        $id = $id.Substring("msstore:".Length)
    }

    switch ($Action) {
        "install" {
            return @("install", "--id", $id, "--exact", "--source", $source, "--accept-package-agreements", "--accept-source-agreements", "--silent", "--disable-interactivity")
        }
        "upgrade" {
            return @("upgrade", "--id", $id, "--exact", "--source", $source, "--accept-package-agreements", "--accept-source-agreements", "--silent", "--disable-interactivity")
        }
        "uninstall" {
            return @("uninstall", "--id", $id, "--exact", "--source", $source, "--silent", "--disable-interactivity")
        }
    }
}

function Get-WingetUpgradeAllArguments {
    return @("upgrade", "--all", "--include-unknown", "--accept-package-agreements", "--accept-source-agreements", "--silent", "--disable-interactivity")
}

function Get-ActionLabel {
    param([ValidateSet("install", "uninstall", "upgrade")][string]$Action)
    switch ($Action) {
        "install" { return "Instalar" }
        "uninstall" { return "Desinstalar" }
        "upgrade" { return "Atualizar" }
    }
}

function Get-AppListPreview {
    param([object[]]$Apps, [int]$Limit = 12)
    $names = @($Apps | Select-Object -First $Limit | ForEach-Object { "- $($_.name)" })
    if ($Apps.Count -gt $Limit) {
        $names += "... e mais $($Apps.Count - $Limit) app(s)."
    }
    return ($names -join "`n")
}

function Confirm-GLabAction {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string]$Message
    )

    $result = [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Show-GLabInfo {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string]$Message
    )
    [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
}

function Update-WingetSources {
    param([Parameter(Mandatory=$true)][string]$WingetPath)
    Write-Log "Atualizando lista de aplicativos disponiveis..."
    Invoke-LoggedProcess -FilePath $WingetPath -Arguments @("source", "update", "--disable-interactivity") | Out-Null
}

function Test-AssistenteConfig {
    $ids = @{}
    foreach ($app in $script:Catalog) {
        if ([string]::IsNullOrWhiteSpace($app.name)) {
            throw "Existe app sem nome no catalogo."
        }
        if ([string]::IsNullOrWhiteSpace($app.id)) {
            throw "App sem id no catalogo: $($app.name)"
        }
        if ($ids.ContainsKey($app.id)) {
            throw "ID duplicado no catalogo: $($app.id)"
        }
        $ids[$app.id] = $true

        foreach ($actionName in @("install", "upgrade", "uninstall")) {
            $arguments = Get-WingetPackageArguments -Action $actionName -PackageId $app.id
            if ($arguments.Count -eq 0) {
                throw "Argumentos winget vazios para $($app.name) em $actionName."
            }
            if ($actionName -eq "uninstall" -and $arguments -contains "--accept-package-agreements") {
                throw "Argumento invalido no uninstall para $($app.name): --accept-package-agreements"
            }
            if (($app.id -like "msstore:*") -and -not ($arguments -contains "msstore")) {
                throw "App Microsoft Store sem source msstore: $($app.name)"
            }
        }
    }

    foreach ($preset in $script:Presets.PSObject.Properties) {
        foreach ($appId in @($preset.Value.apps)) {
            if (-not $ids.ContainsKey($appId)) {
                throw "Preset $($preset.Name) referencia app inexistente: $appId"
            }
        }
    }

    foreach ($tweak in (Get-AllTweaks)) {
        if ([string]::IsNullOrWhiteSpace($tweak.name)) {
            throw "Existe tweak sem nome no catalogo."
        }
        if ([string]::IsNullOrWhiteSpace($tweak.type)) {
            throw "Tweak sem tipo: $($tweak.name)"
        }
        if ($tweak.safe -and $tweak.type -eq "registry") {
            if ([string]::IsNullOrWhiteSpace($tweak.path) -or [string]::IsNullOrWhiteSpace($tweak.property)) {
                throw "Tweak de registro incompleto: $($tweak.name)"
            }
        }
        if ($tweak.safe -and $tweak.type -eq "command") {
            if ([string]::IsNullOrWhiteSpace($tweak.command)) {
                throw "Tweak de comando sem executavel: $($tweak.name)"
            }
        }
    }
}

function Test-AssistenteSelfTest {
    Test-AssistenteConfig

    $sampleWinget = Get-WingetPackageArguments -Action "install" -PackageId "Notepad++.Notepad++"
    if ($sampleWinget -notcontains "install" -or $sampleWinget -notcontains "--silent") {
        throw "Autoteste falhou: argumentos de instalacao invalidos."
    }

    $sampleUninstall = Get-WingetPackageArguments -Action "uninstall" -PackageId "Notepad++.Notepad++"
    if ($sampleUninstall -contains "--accept-package-agreements") {
        throw "Autoteste falhou: uninstall contem argumento invalido."
    }

    $sampleStore = Get-WingetPackageArguments -Action "install" -PackageId "msstore:9NKSQGP7F2NH"
    if ($sampleStore -notcontains "msstore") {
        throw "Autoteste falhou: app Microsoft Store sem source msstore."
    }

    foreach ($presetName in @("Minimo", "Padrao", "Avancado")) {
        Select-TweakPreset -Preset $presetName
        if ($script:SelectedTweakNames.Count -eq 0) {
            throw "Autoteste falhou: preset $presetName nao selecionou ajustes."
        }
    }
    Clear-TweakSelection

    $emptyUndo = Get-AllTweaks | Where-Object { $_.name -eq "Ocultar inicio das Configuracoes" } | Select-Object -First 1
    if ($emptyUndo -and "$($emptyUndo.undoValue)" -ne "") {
        throw "Autoteste falhou: reversao por remocao de propriedade nao configurada."
    }

    Select-SafeAppx
    if ($script:SelectedAppxNames.Count -eq 0) {
        throw "Autoteste falhou: selecao segura de AppX vazia."
    }
    $script:SelectedAppxNames.Clear()

    $requiredButtons = @(
        "InstallTab", "TweaksTab", "ConfigTab", "UpdatesTab", "AppxTab", "Win11Tab",
        "ApplyPresetButton", "ApplyDnsButton", "RestorePointButton", "BackupsButton",
        "HealthButton", "ReloadButton", "ClearButton"
    )
    foreach ($buttonName in $requiredButtons) {
        if (-not $window.FindName($buttonName)) {
            throw "Autoteste falhou: botao ausente $buttonName."
        }
    }

    return "SelfTest OK: argumentos, presets, AppX, botoes e catalogos validados sem executar acoes destrutivas."
}

function Invoke-SafeUiAction {
    param(
        [Parameter(Mandatory=$true)][Alias("Action")][scriptblock]$ActionBlock,
        [string]$Name = "acao"
    )

    if ($script:IsBusy) {
        Write-Log "Aguarde: outra acao ainda esta em execucao."
        return
    }

    try {
        $script:IsBusy = $true
        Write-Log "----- Inicio: $Name -----"
        if ($script:ProgressBar) {
            $script:ProgressBar.Visibility = "Visible"
            $script:ProgressBar.IsIndeterminate = $true
        }
        if ($script:StatusText) {
            $script:StatusText.Text = "Executando: $Name"
        }
        & $ActionBlock
        Write-Log "----- Fim: $Name -----"
    } catch {
        Write-Log "Erro ao executar ${Name}: $($_.Exception.Message)"
        if ($_.ScriptStackTrace) {
            Write-Log $_.ScriptStackTrace
        }
        Write-Log "----- Falha: $Name -----"
    } finally {
        if ($script:ProgressBar) {
            $script:ProgressBar.IsIndeterminate = $false
            $script:ProgressBar.Visibility = "Collapsed"
        }
        $script:IsBusy = $false
    }
}

function New-IconBadge {
    param(
        [string]$Text,
        [string]$Accent = "#2563EB",
        [int]$Size = 38
    )

    $badge = [System.Windows.Controls.Border]::new()
    $badge.Width = $Size
    $badge.Height = $Size
    $badge.CornerRadius = "10"
    $badge.Background = $Accent
    $badge.Margin = "0,0,10,0"

    $label = [System.Windows.Controls.TextBlock]::new()
    $label.Text = $Text
    $label.Foreground = "#FFFFFF"
    $label.FontWeight = "Bold"
    $label.FontSize = 12
    $label.HorizontalAlignment = "Center"
    $label.VerticalAlignment = "Center"
    $label.TextAlignment = "Center"
    $badge.Child = $label
    return $badge
}

function Get-AppIconPath {
    param([object]$App)
    $safeName = ($App.id -replace '[^a-zA-Z0-9.-]', '_') + ".png"
    return Join-Path $script:IconRoot $safeName
}

function New-AppIcon {
    param([object]$App)

    $path = Get-AppIconPath -App $App
    if (Test-Path -LiteralPath $path) {
        try {
            $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit()
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.UriSource = [Uri]$path
            $bitmap.EndInit()
            $bitmap.Freeze()

            $border = [System.Windows.Controls.Border]::new()
            $border.Width = 40
            $border.Height = 40
            $border.CornerRadius = "7"
            $border.Margin = "0,0,10,0"
            $border.Background = "#E2E8F0"

            $image = [System.Windows.Controls.Image]::new()
            $image.Width = 40
            $image.Height = 40
            $image.Source = $bitmap
            $border.Child = $image
            return $border
        }
        catch {
            Write-Log "Icone invalido ignorado: $($App.name)"
        }
    }

    return New-IconBadge -Text $App.icon -Accent $App.accent
}

function Get-SelectedApps {
    $selected = New-Object System.Collections.Generic.List[object]
    foreach ($app in $script:Catalog) {
        if ($script:SelectedAppIds.Contains($app.id)) {
            [void]$selected.Add($app)
        }
    }
    return $selected
}

function Update-SelectedCount {
    if (-not $script:SelectedCountText) { return }
    if ($script:ActiveView -eq "Tweaks") {
        $script:SelectedCountText.Text = "Ajustes selecionados: $($script:SelectedTweakNames.Count)"
    } elseif ($script:ActiveView -eq "Appx") {
        $script:SelectedCountText.Text = "AppX selecionados: $($script:SelectedAppxNames.Count)"
    } else {
        $script:SelectedCountText.Text = "Apps selecionados: $($script:SelectedAppIds.Count)"
    }
}

function Set-AppSelection {
    param(
        [object]$App,
        [bool]$Selected
    )

    if (-not $App -or [string]::IsNullOrWhiteSpace($App.id)) { return }
    if ($Selected) {
        [void]$script:SelectedAppIds.Add($App.id)
    } else {
        [void]$script:SelectedAppIds.Remove($App.id)
    }
    Update-SelectedCount
}

function Clear-AppSelection {
    $script:SelectedAppIds.Clear()
    foreach ($child in $script:AppsPanel.Children) {
        $checkbox = $child.Tag
        if ($checkbox -and $checkbox -is [System.Windows.Controls.CheckBox]) {
            $checkbox.IsChecked = $false
        }
    }
    Update-SelectedCount
}

function Select-PresetApps {
    param([Parameter(Mandatory=$true)][string]$PresetName)

    $preset = $script:Presets.PSObject.Properties[$PresetName]
    if (-not $preset) {
        Write-Log "Preset nao encontrado: $PresetName"
        return
    }

    Clear-AppSelection
    foreach ($appId in @($preset.Value.apps)) {
        [void]$script:SelectedAppIds.Add($appId)
    }
    Refresh-AppGrid
    Write-Log "Preset aplicado: $PresetName ($($script:SelectedAppIds.Count) apps)."
}

function Select-InstalledApps {
    Invoke-SafeUiAction -Name "mostrar apps instalados" -Action {
        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetCommand) {
            Write-Log "Instalador padrao do Windows nao foi encontrado neste sistema."
            return
        }

        Write-Log "Lendo aplicativos instalados..."
        $originalEncoding = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
            $installedText = (& $wingetCommand.Source list --accept-source-agreements --disable-interactivity 2>&1) -join "`n"
        } finally {
            [Console]::OutputEncoding = $originalEncoding
        }

        Clear-AppSelection
        foreach ($app in $script:Catalog) {
            $packageId = ($app.id -replace "^msstore:", "")
            if ([string]::IsNullOrWhiteSpace($packageId)) { continue }
            $pattern = "(?im)[^\S\r\n]{2,}$([regex]::Escape($packageId))(?=[^\S\r\n]{2,}|$)"
            if ($installedText -match $pattern) {
                [void]$script:SelectedAppIds.Add($app.id)
            }
        }

        Refresh-AppGrid
        Write-Log "Apps instalados marcados: $($script:SelectedAppIds.Count)."
    }
}

function Set-TweakSelection {
    param(
        [object]$Tweak,
        [bool]$Selected
    )

    if (-not $Tweak -or [string]::IsNullOrWhiteSpace($Tweak.name)) { return }
    if ($Selected) {
        [void]$script:SelectedTweakNames.Add($Tweak.name)
    } else {
        [void]$script:SelectedTweakNames.Remove($Tweak.name)
    }
    Update-SelectedCount
}

function Clear-TweakSelection {
    $script:SelectedTweakNames.Clear()
    foreach ($checkbox in $script:TweakCheckboxes) {
        if ($checkbox) { $checkbox.IsChecked = $false }
    }
    Update-SelectedCount
}

function Refresh-TweakCheckboxStates {
    foreach ($checkbox in $script:TweakCheckboxes) {
        if (-not $checkbox) { continue }
        $tweak = $checkbox.Tag
        if ($tweak) {
            $checkbox.IsChecked = $script:SelectedTweakNames.Contains($tweak.name)
        }
    }
    Update-SelectedCount
}

function Select-SafeTweaks {
    Clear-TweakSelection
    foreach ($tweak in (Get-AllTweaks | Where-Object { $_.safe })) {
        [void]$script:SelectedTweakNames.Add($tweak.name)
    }
    Refresh-TweakCheckboxStates
    Write-Log "Ajustes seguros selecionados: $($script:SelectedTweakNames.Count)."
}

function Select-TweakPreset {
    param([ValidateSet("Minimo", "Padrao", "Avancado")][string]$Preset)

    $names = switch ($Preset) {
        "Minimo" {
            @(
                "Mostrar extensoes de arquivos",
                "Mostrar arquivos ocultos",
                "Abrir Explorer em Este Computador",
                "Desativar ID de publicidade",
                "Desativar teclas de aderencia",
                "Ocultar botao Visao de Tarefas"
            )
        }
        "Padrao" {
            @(
                "Mostrar extensoes de arquivos",
                "Mostrar arquivos ocultos",
                "Abrir Explorer em Este Computador",
                "Mostrar sempre barras de rolagem",
                "Desativar busca do Bing no iniciar",
                "Desativar recomendacoes do iniciar",
                "Desativar ID de publicidade",
                "Desativar historico de atividades",
                "Desativar consumidor Microsoft",
                "Ativar caminhos longos",
                "Desativar teclas de aderencia",
                "Ativar Num Lock na inicializacao",
                "Tema escuro para aplicativos",
                "Tema escuro do sistema",
                "Desativar transparencia",
                "Ocultar botao Visao de Tarefas",
                "Desativar Modo Jogo",
                "Desativar descoberta automatica do Explorer",
                "Desativar otimizacao de entrega"
            )
        }
        "Avancado" {
            @((Get-AllTweaks | Where-Object { $_.safe }) | Select-Object -ExpandProperty name)
        }
    }

    Clear-TweakSelection
    foreach ($name in $names) {
        $tweak = Get-AllTweaks | Where-Object { $_.safe -and $_.name -eq $name } | Select-Object -First 1
        if ($tweak) { [void]$script:SelectedTweakNames.Add($name) }
    }
    Refresh-TweakCheckboxStates
    Write-Log "Preset de ajustes aplicado: $Preset ($($script:SelectedTweakNames.Count) ajustes)."
}

function Get-AppxCategory {
    param([object]$Appx)
    $name = if ($Appx.name) { $Appx.name } else { $Appx.Name }
    $package = if ($Appx.package) { $Appx.package } else { $Appx.Package }
    $text = "$name $package".ToLowerInvariant()

    if ($text -match "xbox|gaming|solitaire") { return "Jogos e Xbox" }
    if ($text -match "bing|news|weather|start|copilot") { return "Conteudo e IA" }
    if ($text -match "teams|outlook|office|todo|sticky|phone|crossdevice") { return "Produtividade e conexao" }
    if ($text -match "clipchamp|zunemusic|photos|paint|camera|sound|screensketch") { return "Midia e criacao" }
    return "Sistema e utilitarios"
}

function Select-SafeAppx {
    $script:SelectedAppxNames.Clear()
    foreach ($appx in $script:AppxCatalog) {
        $package = if ($appx.package) { $appx.package } else { $appx.Package }
        $safe = if ($null -ne $appx.safe) { $appx.safe } else { $appx.Safe }
        if ($safe) { [void]$script:SelectedAppxNames.Add($package) }
    }
    Show-AppxView
    Write-Log "AppX seguros selecionados: $($script:SelectedAppxNames.Count)."
}

function Show-SelectedAppsPreview {
    $apps = Get-SelectedApps
    if ($apps.Count -eq 0) {
        Show-GLabInfo -Title "Apps marcados" -Message "Nenhum app marcado no momento."
        return
    }
    Show-GLabInfo -Title "Apps marcados" -Message (Get-AppListPreview -Apps $apps -Limit 40)
}

function Show-SelectedTweaksPreview {
    $selected = @((Get-AllTweaks) | Where-Object { $script:SelectedTweakNames.Contains($_.name) } | Sort-Object category, name)
    if ($selected.Count -eq 0) {
        Show-GLabInfo -Title "Ajustes marcados" -Message "Nenhum ajuste marcado no momento."
        return
    }
    $lines = @($selected | Select-Object -First 40 | ForEach-Object {
        $state = if ($_.safe) { "seguro" } else { "bloqueado" }
        "- $($_.name) ($state)"
    })
    if ($selected.Count -gt 40) { $lines += "... e mais $($selected.Count - 40) ajuste(s)." }
    Show-GLabInfo -Title "Ajustes marcados" -Message ($lines -join "`n")
}

function Show-SelectedAppxPreview {
    $selected = @($script:AppxCatalog | Where-Object {
        $package = if ($_.package) { $_.package } else { $_.Package }
        $script:SelectedAppxNames.Contains($package)
    } | Sort-Object name)
    if ($selected.Count -eq 0) {
        Show-GLabInfo -Title "AppX marcados" -Message "Nenhum AppX marcado no momento."
        return
    }
    $lines = @($selected | Select-Object -First 40 | ForEach-Object {
        $name = if ($_.name) { $_.name } else { $_.Name }
        $safe = if ($null -ne $_.safe) { $_.safe } else { $_.Safe }
        $state = if ($safe) { "seguro" } else { "bloqueado" }
        "- $name ($state)"
    })
    if ($selected.Count -gt 40) { $lines += "... e mais $($selected.Count - 40) item(ns)." }
    Show-GLabInfo -Title "AppX marcados" -Message ($lines -join "`n")
}

function New-AppCard {
    param([object]$App)

    $border = [System.Windows.Controls.Border]::new()
    $border.Margin = "4"
    $border.Padding = "8"
    $border.Width = 255
    $border.MinHeight = 68
    $border.BorderBrush = "#CBD5E1"
    $border.BorderThickness = "1"
    $border.CornerRadius = "12"
    $border.Background = "#FFFFFF"

    $grid = [System.Windows.Controls.Grid]::new()
    $grid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
    $checkColumn = [System.Windows.Controls.ColumnDefinition]::new()
    $checkColumn.Width = "Auto"
    $grid.ColumnDefinitions.Add($checkColumn)

    $row = [System.Windows.Controls.StackPanel]::new()
    $row.Orientation = "Horizontal"
    $row.Children.Add((New-AppIcon -App $App)) | Out-Null

    $stack = [System.Windows.Controls.StackPanel]::new()
    $name = [System.Windows.Controls.TextBlock]::new()
    $name.Text = $App.name
    $name.FontWeight = "SemiBold"
    $name.Foreground = "#0F172A"
    $name.TextWrapping = "Wrap"

    $desc = [System.Windows.Controls.TextBlock]::new()
    $desc.Text = $App.category
    $desc.Foreground = "#475569"
    $desc.Margin = "0,3,0,0"
    $desc.FontSize = 11
    $desc.TextWrapping = "Wrap"

    $id = [System.Windows.Controls.TextBlock]::new()
    $id.Text = $App.id
    $id.Foreground = "#64748B"
    $id.Margin = "0,3,0,0"
    $id.FontSize = 10
    $id.FontFamily = "Consolas"

    $stack.Children.Add($name) | Out-Null
    $stack.Children.Add($desc) | Out-Null
    $stack.Children.Add($id) | Out-Null
    $row.Children.Add($stack) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($row, 0)
    $grid.Children.Add($row) | Out-Null

    $checkbox = [System.Windows.Controls.CheckBox]::new()
    $checkbox.VerticalAlignment = "Center"
    $checkbox.Margin = "6,0,0,0"
    $checkbox.ToolTip = "Selecionar $($App.name)"
    $checkbox.Tag = $App
    $checkbox.IsChecked = $script:SelectedAppIds.Contains($App.id)
    $checkbox.Add_Checked({ Set-AppSelection -App $this.Tag -Selected $true })
    $checkbox.Add_Unchecked({ Set-AppSelection -App $this.Tag -Selected $false })
    [System.Windows.Controls.Grid]::SetColumn($checkbox, 1)
    $grid.Children.Add($checkbox) | Out-Null

    $border.Child = $grid
    $border.Tag = $checkbox
    return $border
}

function New-InfoCard {
    param(
        [string]$Title,
        [string]$Body,
        [string]$Icon,
        [string]$Accent = "#2563EB"
    )

    $card = [System.Windows.Controls.Border]::new()
    $card.Margin = "4"
    $card.Padding = "9"
    $card.Width = 255
    $card.MinHeight = 84
    $card.BorderBrush = "#CBD5E1"
    $card.BorderThickness = "1"
    $card.CornerRadius = "12"
    $card.Background = "#FFFFFF"

    $row = [System.Windows.Controls.StackPanel]::new()
    $row.Orientation = "Horizontal"
    $row.Children.Add((New-IconBadge -Text $Icon -Accent $Accent -Size 34)) | Out-Null

    $stack = [System.Windows.Controls.StackPanel]::new()
    $titleBlock = [System.Windows.Controls.TextBlock]::new()
    $titleBlock.Text = $Title
    $titleBlock.FontWeight = "SemiBold"
    $titleBlock.FontSize = 14
    $titleBlock.Foreground = "#0F172A"

    $bodyBlock = [System.Windows.Controls.TextBlock]::new()
    $bodyBlock.Text = $Body
    $bodyBlock.Foreground = "#475569"
    $bodyBlock.Margin = "0,4,0,0"
    $bodyBlock.TextWrapping = "Wrap"
    $bodyBlock.FontSize = 11
    $bodyBlock.MaxWidth = 182

    $stack.Children.Add($titleBlock) | Out-Null
    $stack.Children.Add($bodyBlock) | Out-Null
    $row.Children.Add($stack) | Out-Null
    $card.Child = $row
    return $card
}

function New-ActionCard {
    param(
        [string]$Title,
        [string]$Body,
        [string]$ButtonText,
        [scriptblock]$ClickAction,
        [string]$Icon = "OK",
        [string]$Accent = "#2563EB"
    )

    $card = New-InfoCard -Title $Title -Body $Body -Icon $Icon -Accent $Accent
    $row = [System.Windows.Controls.StackPanel]$card.Child
    $stack = [System.Windows.Controls.StackPanel]$row.Children[1]

    $button = [System.Windows.Controls.Button]::new()
    $button.Content = $ButtonText
    $button.Height = 28
    $button.Margin = "0,8,0,0"
    $button.FontSize = 11
    $button.Tag = $ClickAction
    $button.Add_Click({
        if ($this.Tag) {
            & ([scriptblock]$this.Tag)
        }
    })
    $stack.Children.Add($button) | Out-Null
    return $card
}

function New-ActionBar {
    param([object[]]$Actions)

    $bar = [System.Windows.Controls.WrapPanel]::new()
    $bar.Margin = "4,0,4,8"
    foreach ($action in $Actions) {
        $button = [System.Windows.Controls.Button]::new()
        $button.Content = $action.Label
        $button.Height = 31
        $button.MinWidth = 128
        $button.Margin = "0,0,7,6"
        $button.Tag = $action.Action
        if ($action.Primary) {
            $button.Background = "#0F172A"
            $button.Foreground = "#FFFFFF"
            $button.BorderBrush = "#22D3EE"
        }
        $button.Add_Click({
            if ($this.Tag) {
                & ([scriptblock]$this.Tag)
            }
        })
        $bar.Children.Add($button) | Out-Null
    }
    return $bar
}

function New-TweakCard {
    param([object]$Tweak)

    $checkbox = [System.Windows.Controls.CheckBox]::new()
    $checkbox.Margin = "0,2,0,2"
    $checkbox.FontSize = 12
    $checkbox.Foreground = "#0F172A"
    $checkbox.Content = if ($Tweak.safe) { "$($Tweak.name)" } else { "$($Tweak.name) - planejado" }
    $checkbox.Tag = $Tweak
    $checkbox.IsEnabled = [bool]$Tweak.safe
    $checkbox.IsChecked = $script:SelectedTweakNames.Contains($Tweak.name)
    $checkbox.ToolTip = "$($Tweak.description)`nEscopo: $($Tweak.scope)"
    $checkbox.Add_Checked({ Set-TweakSelection -Tweak $this.Tag -Selected $true })
    $checkbox.Add_Unchecked({ Set-TweakSelection -Tweak $this.Tag -Selected $false })
    $script:TweakCheckboxes.Add($checkbox) | Out-Null
    return $checkbox
}

function New-AppxRow {
    param([object]$Appx)

    $name = if ($Appx.name) { $Appx.name } else { $Appx.Name }
    $package = if ($Appx.package) { $Appx.package } else { $Appx.Package }
    $description = if ($Appx.description) { $Appx.description } else { $Appx.Description }
    $safe = if ($null -ne $Appx.safe) { $Appx.safe } else { $Appx.Safe }

    $checkbox = [System.Windows.Controls.CheckBox]::new()
    $checkbox.Margin = "0,3,0,3"
    $checkbox.FontSize = 12
    $checkbox.Foreground = "#0F172A"
    $checkbox.Content = if ($safe) { "$name" } else { "$name - bloqueado" }
    $checkbox.Tag = $Appx
    $checkbox.IsEnabled = [bool]$safe
    $checkbox.IsChecked = $script:SelectedAppxNames.Contains($package)
    $checkbox.ToolTip = "$description`nPacote: $package"
    $checkbox.Add_Checked({ Set-AppxSelection -Appx $this.Tag -Selected $true })
    $checkbox.Add_Unchecked({ Set-AppxSelection -Appx $this.Tag -Selected $false })
    return $checkbox
}

function New-SectionHeader {
    param(
        [string]$Title,
        [string]$Subtitle = ""
    )

    $outer = [System.Windows.Controls.Border]::new()
    $outer.Width = 900
    $outer.Margin = "4,8,4,5"
    $outer.Padding = "10,6"
    $outer.CornerRadius = "10"
    $outer.Background = "#E0E7FF"
    $outer.BorderBrush = "#C7D2FE"
    $outer.BorderThickness = "1"

    $panel = [System.Windows.Controls.StackPanel]::new()

    $titleBlock = [System.Windows.Controls.TextBlock]::new()
    $titleBlock.Text = $Title
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "SemiBold"
    $titleBlock.Foreground = "#0F172A"
    $panel.Children.Add($titleBlock) | Out-Null

    if ($Subtitle) {
        $subtitleBlock = [System.Windows.Controls.TextBlock]::new()
        $subtitleBlock.Text = $Subtitle
        $subtitleBlock.FontSize = 12
        $subtitleBlock.Foreground = "#64748B"
        $subtitleBlock.Margin = "0,3,0,0"
        $panel.Children.Add($subtitleBlock) | Out-Null
    }

    $outer.Child = $panel
    return $outer
}

function Get-AllTweaks {
    $items = @()
    foreach ($category in $script:Tweaks.PSObject.Properties) {
        foreach ($tweak in @($category.Value)) {
            $items += [pscustomobject]@{
                category = $category.Name
                name = $tweak.name
                description = $tweak.description
                scope = $tweak.scope
                safe = [bool]$tweak.safe
                type = $tweak.type
                path = $tweak.path
                property = $tweak.property
                value = $tweak.value
                undoValue = $tweak.undoValue
                valueKind = $tweak.valueKind
                command = $tweak.command
                arguments = @($tweak.arguments)
            }
        }
    }
    return $items
}

function Set-RegistryTweak {
    param(
        [Parameter(Mandatory=$true)][psobject]$Tweak,
        [string]$BackupDir = ""
    )

    if ([string]::IsNullOrWhiteSpace($Tweak.path) -or [string]::IsNullOrWhiteSpace($Tweak.property)) {
        throw "Tweak de registro incompleto: $($Tweak.name)"
    }

    if ($BackupDir) {
        Export-RegistryBackup -RegistryPath $Tweak.path -BackupDir $BackupDir
    }

    if (-not (Test-Path -LiteralPath $Tweak.path)) {
        New-Item -Path $Tweak.path -Force | Out-Null
    }

    $propertyType = if ([string]::IsNullOrWhiteSpace($Tweak.valueKind)) { "DWord" } else { $Tweak.valueKind }
    New-ItemProperty -Path $Tweak.path -Name $Tweak.property -Value $Tweak.value -PropertyType $propertyType -Force | Out-Null
}

function Invoke-TweakItem {
    param(
        [Parameter(Mandatory=$true)][psobject]$Tweak,
        [string]$BackupDir = ""
    )

    if (-not $Tweak.safe) {
        Write-Log "Tweak ignorado por nao estar marcado como seguro: $($Tweak.name)"
        return
    }

    switch ($Tweak.type) {
        "registry" {
            Set-RegistryTweak -Tweak $Tweak -BackupDir $BackupDir
            Write-Log "Tweak aplicado: $($Tweak.name)"
        }
        "command" {
            Invoke-LoggedProcess -FilePath $Tweak.command -Arguments @($Tweak.arguments) | Out-Null
            Write-Log "Ajuste aplicado: $($Tweak.name)"
        }
        default {
            Write-Log "Tweak ainda nao implementado: $($Tweak.name)"
        }
    }
}

function Undo-TweakItem {
    param(
        [Parameter(Mandatory=$true)][psobject]$Tweak,
        [string]$BackupDir = ""
    )

    if ($Tweak.type -ne "registry" -or $null -eq $Tweak.undoValue) {
        Write-Log "Sem reversao automatica para: $($Tweak.name)"
        return
    }

    if ("$($Tweak.undoValue)" -eq "") {
        if ($BackupDir) {
            Export-RegistryBackup -RegistryPath $Tweak.path -BackupDir $BackupDir
        }
        Remove-ItemProperty -LiteralPath $Tweak.path -Name $Tweak.property -ErrorAction SilentlyContinue
    } else {
        $undoTweak = [pscustomobject]@{
            name = $Tweak.name
            path = $Tweak.path
            property = $Tweak.property
            value = $Tweak.undoValue
            valueKind = $Tweak.valueKind
        }
        Set-RegistryTweak -Tweak $undoTweak -BackupDir $BackupDir
    }
    Write-Log "Ajuste desfeito: $($Tweak.name)"
}

function Clear-MainPanel {
    $script:AppsPanel.Children.Clear()
}

function Write-Status {
    param([string]$Section, [string]$Detail)
    if ($script:StatusText) {
        $script:StatusText.Text = "$Section - $Detail"
    }
}

function Set-ActiveTab {
    param([string]$TabName)
    foreach ($name in @("InstallTab", "TweaksTab", "ConfigTab", "UpdatesTab", "AppxTab", "Win11Tab")) {
        $button = $window.FindName($name)
        if (-not $button) { continue }
        if ($name -eq $TabName) {
            $button.Background = "#0F172A"
            $button.Foreground = "#FFFFFF"
            $button.BorderBrush = "#22D3EE"
        } else {
            $button.Background = "#FFFFFF"
            $button.Foreground = "#0F172A"
            $button.BorderBrush = "#B8C4D6"
        }
    }
}

function Update-SidebarForView {
    if (-not $window) { return }
    Update-SelectedCount
}

function Refresh-AppGrid {
    $script:ActiveView = "Install"
    Set-ActiveTab -TabName "InstallTab"
    Update-SidebarForView
    $query = $script:SearchBox.Text.Trim().ToLowerInvariant()
    $category = $script:CategoryBox.SelectedItem.Tag

    Clear-MainPanel
    $apps = $script:Catalog | Where-Object {
        $category -eq "All" -or $_.category -eq $category
    } | Where-Object {
        if (-not $query) { return $true }
        $haystack = "$($_.name) $($_.id) $($_.category) $($_.description) $($_.tags -join ' ')".ToLowerInvariant()
        return $haystack.Contains($query)
    } | Sort-Object category, name

    $script:AppsPanel.Children.Add((New-ActionBar -Actions @(
        [pscustomobject]@{ Label = "Instalar"; Primary = $true; Action = { Invoke-WingetForSelection -Action "install" } },
        [pscustomobject]@{ Label = "Atualizar"; Primary = $false; Action = { Invoke-WingetForSelection -Action "upgrade" } },
        [pscustomobject]@{ Label = "Desinstalar"; Primary = $false; Action = { Invoke-WingetForSelection -Action "uninstall" } },
        [pscustomobject]@{ Label = "Marcar instalados"; Primary = $false; Action = { Select-InstalledApps } },
        [pscustomobject]@{ Label = "Ver marcados"; Primary = $false; Action = { Show-SelectedAppsPreview } },
        [pscustomobject]@{ Label = "Limpar selecao"; Primary = $false; Action = { Clear-AppSelection } }
    ))) | Out-Null

    $lastCategory = $null
    if (@($apps).Count -eq 0) {
        $script:AppsPanel.Children.Add((New-InfoCard -Title "Nada encontrado" -Body "Tente buscar por outro nome, categoria ou ID do aplicativo." -Icon "?" -Accent "#64748B")) | Out-Null
    }
    foreach ($app in $apps) {
        if ($app.category -ne $lastCategory) {
            $script:AppsPanel.Children.Add((New-SectionHeader -Title $app.category -Subtitle "Marque os apps e escolha uma acao acima.")) | Out-Null
            $lastCategory = $app.category
        }
        $script:AppsPanel.Children.Add((New-AppCard -App $app)) | Out-Null
    }

    Update-SelectedCount
    Write-Status "Instalar" "$($apps.Count) apps visiveis"
}

function Show-TweaksView {
    $script:ActiveView = "Tweaks"
    Set-ActiveTab -TabName "TweaksTab"
    Update-SidebarForView
    Clear-MainPanel
    $script:TweakCheckboxes.Clear()

    $script:AppsPanel.Children.Add((New-ActionBar -Actions @(
        [pscustomobject]@{ Label = "Minimo"; Primary = $false; Action = { Select-TweakPreset -Preset "Minimo" } },
        [pscustomobject]@{ Label = "Padrao"; Primary = $false; Action = { Select-TweakPreset -Preset "Padrao" } },
        [pscustomobject]@{ Label = "Avancado"; Primary = $false; Action = { Select-TweakPreset -Preset "Avancado" } },
        [pscustomobject]@{ Label = "Verificar"; Primary = $false; Action = { Show-TweakStatusReport } },
        [pscustomobject]@{ Label = "Aplicar"; Primary = $true; Action = { Invoke-SafeTweaks } },
        [pscustomobject]@{ Label = "Desfazer"; Primary = $false; Action = { Invoke-UndoSelectedTweaks } },
        [pscustomobject]@{ Label = "Ver marcados"; Primary = $false; Action = { Show-SelectedTweaksPreview } },
        [pscustomobject]@{ Label = "Limpar selecao"; Primary = $false; Action = { Clear-TweakSelection } }
    ))) | Out-Null

    $grid = [System.Windows.Controls.Grid]::new()
    $grid.Width = 930
    $grid.Margin = "4"
    $left = [System.Windows.Controls.ColumnDefinition]::new()
    $left.Width = "*"
    $right = [System.Windows.Controls.ColumnDefinition]::new()
    $right.Width = "*"
    $grid.ColumnDefinitions.Add($left)
    $grid.ColumnDefinitions.Add($right)

    $leftPanel = [System.Windows.Controls.StackPanel]::new()
    $rightPanel = [System.Windows.Controls.StackPanel]::new()

    $leftBorder = [System.Windows.Controls.Border]::new()
    $leftBorder.Padding = "10"
    $leftBorder.Margin = "0,0,5,0"
    $leftBorder.Background = "#FFFFFF"
    $leftBorder.BorderBrush = "#CBD5E1"
    $leftBorder.BorderThickness = "1"
    $leftBorder.CornerRadius = "8"
    $leftBorder.Child = $leftPanel

    $rightBorder = [System.Windows.Controls.Border]::new()
    $rightBorder.Padding = "10"
    $rightBorder.Margin = "5,0,0,0"
    $rightBorder.Background = "#FFFFFF"
    $rightBorder.BorderBrush = "#CBD5E1"
    $rightBorder.BorderThickness = "1"
    $rightBorder.CornerRadius = "8"
    $rightBorder.Child = $rightPanel

    [System.Windows.Controls.Grid]::SetColumn($leftBorder, 0)
    [System.Windows.Controls.Grid]::SetColumn($rightBorder, 1)
    $grid.Children.Add($leftBorder) | Out-Null
    $grid.Children.Add($rightBorder) | Out-Null

    $titleLeft = [System.Windows.Controls.TextBlock]::new()
    $titleLeft.Text = "Ajustes essenciais e avancados"
    $titleLeft.FontFamily = "Consolas"
    $titleLeft.FontSize = 13
    $titleLeft.Foreground = "#0F172A"
    $titleLeft.Margin = "0,0,0,6"
    $leftPanel.Children.Add($titleLeft) | Out-Null

    $titleRight = [System.Windows.Controls.TextBlock]::new()
    $titleRight.Text = "Preferencias rapidas"
    $titleRight.FontFamily = "Consolas"
    $titleRight.FontSize = 13
    $titleRight.Foreground = "#0F172A"
    $titleRight.Margin = "0,0,0,8"
    $rightPanel.Children.Add($titleRight) | Out-Null

    foreach ($tweak in (Get-AllTweaks | Sort-Object category, name)) {
        $headerText = $null
        if ($script:lastTweakCategory -ne $tweak.category) {
            $headerText = $tweak.category
            $script:lastTweakCategory = $tweak.category
        }

        $targetPanel = if ($tweak.category -in @("Aparencia", "Barra de tarefas e menu iniciar")) { $rightPanel } else { $leftPanel }
        if ($headerText) {
            $header = [System.Windows.Controls.TextBlock]::new()
            $header.Text = $headerText
            $header.FontFamily = "Consolas"
            $header.FontSize = 12
            $header.Margin = "0,8,0,3"
            $header.Foreground = "#334155"
            $targetPanel.Children.Add($header) | Out-Null
        }
        $targetPanel.Children.Add((New-TweakCard -Tweak $tweak)) | Out-Null
    }
    $script:lastTweakCategory = $null
    $script:AppsPanel.Children.Add($grid) | Out-Null
    $safeCount = @((Get-AllTweaks) | Where-Object { $_.safe }).Count
    Update-SelectedCount
    Write-Status "Ajustes" "$safeCount ajustes seguros disponiveis"
}

function Show-ConfigView {
    $script:ActiveView = "Config"
    Set-ActiveTab -TabName "ConfigTab"
    Update-SidebarForView
    Clear-MainPanel
    $adminStatus = if (Test-IsAdmin) { "Executando elevado." } else { "Nao elevado; algumas acoes podem pedir permissao." }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    $wingetStatus = if ($winget) { "Disponivel: $($winget.Source)" } else { "Nao encontrado no PATH desta sessao." }
    $presetCount = @($script:Presets.PSObject.Properties).Count
    $tweakCount = @((Get-AllTweaks)).Count
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osText = if ($os) { "$($os.Caption) build $($os.BuildNumber)" } else { "Nao foi possivel ler a versao do Windows." }
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
    $diskText = if ($disk -and $disk.Size) { "Livre em C: {0:N1} GB de {1:N1} GB" -f ($disk.FreeSpace / 1GB), ($disk.Size / 1GB) } else { "Disco principal nao identificado." }

    $script:AppsPanel.Children.Add((New-SectionHeader -Title "O que voce quer resolver?" -Subtitle "Atalhos pensados para pessoas: escolha o sintoma e o Assistente executa o fluxo seguro correspondente.")) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Meu PC esta lento" -Body "Limpa temporarios, reinicia a interface e prepara uma base segura para manutencao." -ButtonText "Melhorar agora" -Icon "PC" -Accent "#16A34A" -ClickAction { Invoke-SlowPcRescue })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Apps nao instalam" -Body "Repara a lista do instalador, atualiza fontes e mostra atualizacoes disponiveis." -ButtonText "Corrigir apps" -Icon "AP" -Accent "#2563EB" -ClickAction { Invoke-AppInstallRescue })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Internet com problema" -Body "Limpa DNS, renova IP e redefine componentes basicos de rede." -ButtonText "Corrigir internet" -Icon "NET" -Accent "#0284C7" -ClickAction { Invoke-NetworkRepair })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Windows Update travou" -Body "Refaz caches de atualizacao com backup e reinicia servicos essenciais." -ButtonText "Reparar updates" -Icon "WU" -Accent "#7C3AED" -ClickAction { Invoke-WindowsUpdateRepair })) | Out-Null

    $script:AppsPanel.Children.Add((New-SectionHeader -Title "Antes de mexer" -Subtitle "Use estas acoes para criar uma trilha de recuperacao antes de ajustes maiores.")) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Criar ponto de restauracao" -Body "Recomendado antes de ajustes maiores no Windows." -ButtonText "Criar agora" -Icon "PR" -Accent "#16A34A" -ClickAction { New-GLabRestorePoint })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Abrir backups" -Body "Mostra os backups e inventarios salvos pelo Assistente." -ButtonText "Abrir pasta" -Icon "BK" -Accent "#2563EB" -ClickAction { Open-BackupFolder })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Pasta do assistente" -Body "Abre a copia local em execucao para conferencia tecnica." -ButtonText "Abrir pasta" -Icon "PA" -Accent "#64748B" -ClickAction { Open-AppFolder })) | Out-Null

    $script:AppsPanel.Children.Add((New-SectionHeader -Title "Corrigir problemas" -Subtitle "Rotinas de manutencao para quando o Windows esta lento, instavel ou com falhas.")) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Limpar arquivos temporarios" -Body "Remove sobras em pastas temporarias do usuario e do sistema." -ButtonText "Limpar" -Icon "LT" -Accent "#F59E0B" -ClickAction { Invoke-TempCleanup })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Reparar imagem do Windows" -Body "Executa DISM e SFC. Pode demorar alguns minutos." -ButtonText "Reparar" -Icon "SF" -Accent "#7C3AED" -ClickAction { Invoke-SystemRepair })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Reiniciar Explorer" -Body "Aplica ajustes visuais sem reiniciar o computador." -ButtonText "Reiniciar" -Icon "EX" -Accent "#0EA5E9" -ClickAction { Restart-ExplorerShell })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Relatorio de saude" -Body "Mostra versao do Windows, memoria, discos, servicos e instalador." -ButtonText "Gerar relatorio" -Icon "RS" -Accent "#0F766E" -ClickAction { Show-SystemHealthReport })) | Out-Null

    $script:AppsPanel.Children.Add((New-SectionHeader -Title "Internet e horario" -Subtitle "Acoes comuns para problemas de rede, DNS e relogio fora de sincronia.")) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Reparar rede" -Body "Limpa DNS, renova IP e redefine Winsock/IP com backup previo." -ButtonText "Reparar rede" -Icon "RD" -Accent "#0284C7" -ClickAction { Invoke-NetworkRepair })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Corrigir horario" -Body "Ativa o servico de tempo do Windows e solicita sincronizacao NTP." -ButtonText "Sincronizar" -Icon "HR" -Accent "#4F46E5" -ClickAction { Invoke-TimeRepair })) | Out-Null

    $script:AppsPanel.Children.Add((New-SectionHeader -Title "Windows Update" -Subtitle "Controle o comportamento das atualizacoes ou repare componentes quando o Windows Update travar.")) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Padrao do Windows" -Body "Remove politicas locais criadas pelo assistente." -ButtonText "Restaurar padrao" -Icon "UP" -Accent "#2563EB" -ClickAction { Set-WindowsUpdateMode -Mode "Padrao" })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Baixar e avisar" -Body "Baixa atualizacoes e avisa antes da instalacao." -ButtonText "Aplicar modo aviso" -Icon "AV" -Accent "#0891B2" -ClickAction { Set-WindowsUpdateMode -Mode "Seguranca" })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Desativar automaticas" -Body "Opcao avancada. Exige confirmacao antes de aplicar." -ButtonText "Desativar" -Icon "!" -Accent "#DC2626" -ClickAction { Set-WindowsUpdateMode -Mode "Desativar" })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Reparar Windows Update" -Body "Refaz caches de atualizacao com backup e reinicia servicos essenciais." -ButtonText "Reparar update" -Icon "WU" -Accent "#7C3AED" -ClickAction { Invoke-WindowsUpdateRepair })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Abrir configuracoes" -Body "Abre a tela oficial do Windows Update." -ButtonText "Abrir Windows" -Icon "WU" -Accent "#0EA5E9" -ClickAction { Open-WindowsUpdateSettings })) | Out-Null

    $script:AppsPanel.Children.Add((New-SectionHeader -Title "Diagnostico do ambiente" -Subtitle "Leitura local do estado usado pelo Assistente G-LAB.")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Windows" -Body $osText -Icon "OS" -Accent "#0EA5E9")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Armazenamento" -Body $diskText -Icon "HD" -Accent "#16A34A")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Catalogo JSON" -Body $script:ConfigPath -Icon "JS" -Accent "#2563EB")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Administrador" -Body $adminStatus -Icon "AD" -Accent "#64748B")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Instalador do Windows" -Body $wingetStatus -Icon "IN" -Accent "#7C3AED")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Predefinicoes" -Body "$presetCount predefinicoes carregadas de $script:PresetsPath" -Icon "PR" -Accent "#0EA5E9")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Ajustes" -Body "$tweakCount ajustes carregados de $script:TweaksPath" -Icon "AJ" -Accent "#16A34A")) | Out-Null
    Write-Status "Configurar" "Ambiente e configuracoes inspecionados"
}

function Show-UpdatesView {
    $script:ActiveView = "Updates"
    Set-ActiveTab -TabName "UpdatesTab"
    Update-SidebarForView
    Clear-MainPanel
    $script:AppsPanel.Children.Add((New-SectionHeader -Title "Atualizar aplicativos" -Subtitle "Verifique, atualize selecionados ou rode uma atualizacao geral com confirmacao.")) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Verificar atualizacoes" -Body "Lista no log quais aplicativos possuem atualizacao disponivel." -ButtonText "Verificar" -Icon "VR" -Accent "#2563EB" -ClickAction { Invoke-CheckAppUpdates })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Atualizar selecionados" -Body "Atualiza apenas os aplicativos marcados na aba Instalar." -ButtonText "Atualizar marcados" -Icon "AT" -Accent "#16A34A" -ClickAction { Invoke-WingetForSelection -Action "upgrade" })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Atualizar todos" -Body "Atualiza todos os aplicativos detectados. Pede confirmacao antes de iniciar." -ButtonText "Atualizar tudo" -Icon "TD" -Accent "#DC2626" -ClickAction { Invoke-UpgradeAll })) | Out-Null

    $script:AppsPanel.Children.Add((New-SectionHeader -Title "Manutencao do instalador" -Subtitle "Use quando a lista de apps falhar, ficar lenta ou nao encontrar pacotes conhecidos.")) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Atualizar lista de apps" -Body "Sincroniza as fontes do instalador padrao do Windows." -ButtonText "Atualizar lista" -Icon "LI" -Accent "#0EA5E9" -ClickAction {
        Invoke-SafeUiAction -Name "Atualizar lista de apps" -Action {
            $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
            if (-not $wingetCommand) {
                Write-Log "Instalador padrao do Windows nao foi encontrado neste sistema."
                return
            }
            Update-WingetSources -WingetPath $wingetCommand.Source
        }
    })) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionCard -Title "Reparar fontes" -Body "Restaura e sincroniza as fontes usadas para encontrar aplicativos." -ButtonText "Reparar fontes" -Icon "RF" -Accent "#7C3AED" -ClickAction { Invoke-RepairPackageManager })) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Registro" -Body "Todos os resultados aparecem no console inferior do Assistente G-LAB." -Icon "LOG" -Accent "#111827")) | Out-Null
    Write-Status "Atualizar" "Verificacao e manutencao disponiveis"
}

function Show-AppxView {
    $script:ActiveView = "Appx"
    Set-ActiveTab -TabName "AppxTab"
    Update-SidebarForView
    Clear-MainPanel
    $panel = [System.Windows.Controls.StackPanel]::new()
    $panel.Width = 930
    $panel.Margin = "6"
    $query = $script:SearchBox.Text.Trim().ToLowerInvariant()
    $script:AppsPanel.Children.Add((New-ActionBar -Actions @(
        [pscustomobject]@{ Label = "Marcar seguros"; Primary = $false; Action = { Select-SafeAppx } },
        [pscustomobject]@{ Label = "Remover"; Primary = $true; Action = { Invoke-AppxRemoval } },
        [pscustomobject]@{ Label = "Reinstalar"; Primary = $false; Action = { Invoke-AppxInstall } },
        [pscustomobject]@{ Label = "Ver marcados"; Primary = $false; Action = { Show-SelectedAppxPreview } },
        [pscustomobject]@{ Label = "Limpar selecao"; Primary = $false; Action = { $script:SelectedAppxNames.Clear(); Show-AppxView } }
    ))) | Out-Null
    $panel.Children.Add((New-SectionHeader -Title "Aplicativos do Windows" -Subtitle "Marque o que deseja remover ou reinstalar. O Assistente pede confirmacao antes de executar.")) | Out-Null

    $items = @($script:AppxCatalog | Where-Object {
        if (-not $query) { return $true }
        $name = if ($_.name) { $_.name } else { $_.Name }
        $package = if ($_.package) { $_.package } else { $_.Package }
        $description = if ($_.description) { $_.description } else { $_.Description }
        return ("$name $package $description".ToLowerInvariant()).Contains($query)
    })

    foreach ($group in ($items | Group-Object { Get-AppxCategory -Appx $_ } | Sort-Object Name)) {
        if ($group.Count -eq 0) { continue }
        $panel.Children.Add((New-SectionHeader -Title $group.Name -Subtitle "$($group.Count) itens nesta categoria.")) | Out-Null
        foreach ($appx in ($group.Group | Sort-Object name)) {
            $panel.Children.Add((New-AppxRow -Appx $appx)) | Out-Null
        }
    }
    if ($items.Count -eq 0) {
        $panel.Children.Add((New-InfoCard -Title "Nada encontrado" -Body "Tente buscar por outro nome ou pacote do Windows." -Icon "?" -Accent "#64748B")) | Out-Null
    }
    $script:AppsPanel.Children.Add($panel) | Out-Null
    Update-SelectedCount
    $safeCount = @($script:AppxCatalog | Where-Object { if ($null -ne $_.safe) { $_.safe } else { $_.Safe } }).Count
    Write-Status "AppX" "$safeCount remocoes seguras disponiveis"
}

function Show-Win11View {
    $script:ActiveView = "Win11"
    Set-ActiveTab -TabName "Win11Tab"
    Update-SidebarForView
    Clear-MainPanel
    $script:AppsPanel.Children.Add((New-SectionHeader -Title "Preparar Windows 11" -Subtitle "Comece pelas fontes oficiais. A criacao de pendrive sera adicionada com selecao segura de disco.")) | Out-Null
    $script:AppsPanel.Children.Add((New-ActionBar -Actions @(
        [pscustomobject]@{ Label = "Download oficial"; Primary = $true; Action = { Open-Windows11Creator } },
        [pscustomobject]@{ Label = "Gerar AutoUnattend"; Primary = $false; Action = { New-AutoUnattendFile } },
        [pscustomobject]@{ Label = "Gerenciamento de disco"; Primary = $false; Action = { Open-DiskManagement } },
        [pscustomobject]@{ Label = "Pasta Downloads"; Primary = $false; Action = { Open-DownloadsFolder } }
    ))) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "ISO oficial" -Body "Baixe a imagem ou a ferramenta da Microsoft antes de preparar a midia." -Icon "ISO" -Accent "#2563EB")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Pendrive" -Body "Use um dispositivo dedicado. A gravacao apaga dados e tera confirmacao propria." -Icon "USB" -Accent "#F59E0B")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "Drivers" -Body "Separe drivers de rede, chipset e armazenamento antes da instalacao." -Icon "DR" -Accent "#0F766E")) | Out-Null
    $script:AppsPanel.Children.Add((New-InfoCard -Title "AutoUnattend" -Body "Gera um modelo inicial em pt-BR para instalacoes assistidas, sem chave e sem formatacao automatica." -Icon "AU" -Accent "#7C3AED")) | Out-Null
    Write-Status "Windows 11" "Preparacao inicial disponivel"
}

function Invoke-WingetForSelection {
    param([ValidateSet("install", "uninstall", "upgrade")][string]$Action)

    Invoke-SafeUiAction -Name "winget $Action" -Action {
        $apps = Get-SelectedApps
        if ($apps.Count -eq 0) {
            Write-Log "Nenhum app selecionado."
            return
        }

        $actionLabel = Get-ActionLabel -Action $Action
        if ($Action -eq "uninstall" -or $apps.Count -ge 5) {
            $preview = Get-AppListPreview -Apps $apps
            if (-not (Confirm-GLabAction -Title "Confirmar $($actionLabel.ToLower())" -Message "$actionLabel os apps selecionados?`n`n$preview")) {
                Write-Log "$actionLabel cancelado pelo usuario."
                return
            }
        }

        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetCommand) {
            Write-Log "Instalador padrao do Windows nao foi encontrado neste sistema."
            return
        }

        Update-WingetSources -WingetPath $wingetCommand.Source
        $backupDir = New-BackupSession -Reason "apps-$Action"
        $apps | Select-Object name, id, category, description |
            ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath (Join-Path $backupDir "fila-apps.json") -Encoding UTF8
        Write-Log "Aplicativos na fila: $($apps.Count)."
        Write-Log "Fila salva em: $backupDir"

        foreach ($app in $apps) {
            Write-Log "${actionLabel}: $($app.name)"
            $args = Get-WingetPackageArguments -Action $Action -PackageId $app.id
            if ($args.Count -eq 0) {
                Write-Log "Pacote ignorado: id vazio ou nao suportado para $($app.name)."
                continue
            }
            $exitCode = Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments $args
            if ($exitCode -ne 0) {
                Write-Log "Atencao: $($app.name) terminou com codigo $exitCode."
            }
        }
    }
}

function Invoke-UpgradeAll {
    Invoke-SafeUiAction -Name "winget upgrade --all" -Action {
        if (-not (Confirm-GLabAction -Title "Confirmar atualizacao geral" -Message "Atualizar todos os aplicativos detectados pelo instalador do Windows?`n`nIsso pode demorar e alguns programas podem reiniciar componentes em segundo plano.")) {
            Write-Log "Atualizacao geral cancelada pelo usuario."
            return
        }
        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetCommand) {
            Write-Log "Instalador padrao do Windows nao foi encontrado neste sistema."
            return
        }
        Update-WingetSources -WingetPath $wingetCommand.Source
        Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments (Get-WingetUpgradeAllArguments) | Out-Null
    }
}

function Invoke-CheckAppUpdates {
    Invoke-SafeUiAction -Name "Verificar atualizacoes" -Action {
        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetCommand) {
            Write-Log "Instalador padrao do Windows nao foi encontrado neste sistema."
            return
        }
        Update-WingetSources -WingetPath $wingetCommand.Source
        Write-Log "Verificando atualizacoes disponiveis..."
        Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments @("upgrade", "--accept-source-agreements", "--disable-interactivity") | Out-Null
    }
}

function Invoke-RepairPackageManager {
    Invoke-SafeUiAction -Name "Reparar instalador" -Action {
        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetCommand) {
            Write-Log "Instalador padrao do Windows nao foi encontrado nesta sessao."
            Write-Log "Abra a Microsoft Store e atualize o 'Instalador de Aplicativo'."
            return
        }
        Write-Log "Reparando fontes do instalador padrao do Windows..."
        Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments @("source", "reset", "--force", "--disable-interactivity") | Out-Null
        Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments @("source", "update", "--disable-interactivity") | Out-Null
        Write-Log "Reparo das fontes concluido."
    }
}

function Invoke-AppInstallRescue {
    Invoke-SafeUiAction -Name "Corrigir instalacao de apps" -Action {
        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetCommand) {
            Write-Log "Instalador de apps nao encontrado nesta sessao."
            Write-Log "Abra a Microsoft Store e atualize o 'Instalador de Aplicativo'."
            return
        }

        if (-not (Confirm-GLabAction -Title "Corrigir instalacao de apps" -Message "Reparar a lista do instalador e verificar atualizacoes disponiveis?`n`nUse quando apps nao aparecem, falham ao baixar ou o Assistente nao encontra pacotes conhecidos.")) {
            Write-Log "Correcao do instalador cancelada pelo usuario."
            return
        }

        Write-Log "Corrigindo instalador de apps..."
        Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments @("source", "reset", "--force", "--disable-interactivity") | Out-Null
        Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments @("source", "update", "--disable-interactivity") | Out-Null
        Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments @("upgrade", "--accept-source-agreements", "--disable-interactivity") | Out-Null
        Write-Log "Instalador de apps corrigido e lista de atualizacoes verificada."
    }
}

function Invoke-SlowPcRescue {
    Invoke-SafeUiAction -Name "Melhorar PC lento" -Action {
        if (-not (Confirm-GLabAction -Title "Melhorar PC lento" -Message "Executar uma manutencao segura para PC lento?`n`nO Assistente vai criar um ponto de restauracao quando possivel, limpar temporarios, reiniciar o Explorer e gerar um relatorio rapido no log.")) {
            Write-Log "Manutencao para PC lento cancelada pelo usuario."
            return
        }

        if (Test-IsAdmin) {
            New-SafeRestorePoint -Description "Assistente G-LAB - manutencao"
        } else {
            Write-Log "Ponto de restauracao ignorado: execute como administrador para habilitar."
        }

        $targets = @($env:TEMP, (Join-Path $env:SystemRoot "Temp"))
        foreach ($target in $targets) {
            if (-not (Test-Path -LiteralPath $target)) { continue }
            Write-Log "Limpando temporarios em $target"
            Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                } catch {
                    Write-Log "Ignorado: $($_.FullName)"
                }
            }
        }

        Write-Log "Reiniciando Explorer para renovar a interface."
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Process explorer.exe
        Write-Log "Manutencao para PC lento finalizada. Veja o relatorio de saude para proximos passos."
    }
}

function Invoke-SafeTweaks {
    Invoke-SafeUiAction -Name "tweaks seguros" -Action {
        $selectedTweaks = @((Get-AllTweaks) | Where-Object { $_.safe -and $script:SelectedTweakNames.Contains($_.name) })
        if ($selectedTweaks.Count -eq 0) {
            Write-Log "Nenhum ajuste marcado. Escolha Minimo, Padrao, Avancado ou marque ajustes manualmente."
            return
        }

        Write-Log "Aplicando $($selectedTweaks.Count) ajustes selecionados."
        $backupDir = New-BackupSession -Reason "ajustes"
        New-SafeRestorePoint -Description "Assistente G-LAB - ajustes"
        foreach ($tweak in $selectedTweaks) {
            Invoke-TweakItem -Tweak $tweak -BackupDir $backupDir
        }
        Write-Log "Ajustes selecionados finalizados."
        Restart-ExplorerShell
    }
}

function Invoke-UndoSelectedTweaks {
    Invoke-SafeUiAction -Name "Desfazer ajustes" -Action {
        $selectedTweaks = @((Get-AllTweaks) | Where-Object { $_.safe -and $script:SelectedTweakNames.Contains($_.name) })
        if ($selectedTweaks.Count -eq 0) {
            Write-Log "Nenhum ajuste selecionado para desfazer."
            return
        }
        $reversible = @($selectedTweaks | Where-Object { $_.type -eq "registry" -and $null -ne $_.undoValue })
        if ($reversible.Count -eq 0) {
            Write-Log "Nenhum dos ajustes marcados possui reversao automatica."
            return
        }
        $names = ($reversible | ForEach-Object { "- " + $_.name }) -join "`n"
        if (-not (Confirm-GLabAction -Title "Desfazer ajustes" -Message "Desfazer $($reversible.Count) ajustes selecionados?`n`n$names`n`nUm backup sera salvo antes da reversao.")) {
            Write-Log "Reversao de ajustes cancelada."
            return
        }
        $backupDir = New-BackupSession -Reason "desfazer-ajustes"
        foreach ($tweak in $reversible) {
            Undo-TweakItem -Tweak $tweak -BackupDir $backupDir
        }
        Write-Log "Reversao finalizada."
        Restart-ExplorerShell
    }
}

function Test-TweakState {
    param([Parameter(Mandatory=$true)][psobject]$Tweak)
    if ($Tweak.type -ne "registry") { return "Nao verificavel automaticamente" }
    try {
        if (-not (Test-Path -LiteralPath $Tweak.path)) { return "Nao aplicado" }
        $current = (Get-ItemProperty -LiteralPath $Tweak.path -Name $Tweak.property -ErrorAction Stop).$($Tweak.property)
        if ("$current" -eq "$($Tweak.value)") { return "Aplicado" }
        return "Diferente do esperado"
    } catch {
        return "Nao aplicado"
    }
}

function Show-TweakStatusReport {
    Invoke-SafeUiAction -Name "Verificar ajustes" -Action {
        $safeTweaks = @((Get-AllTweaks) | Where-Object { $_.safe })
        Write-Log "Verificando estado de $($safeTweaks.Count) ajustes seguros..."
        foreach ($tweak in $safeTweaks) {
            Write-Log "$($tweak.name): $(Test-TweakState -Tweak $tweak)"
        }
        Write-Log "Verificacao de ajustes finalizada."
    }
}

function Set-GLabDns {
    param([Parameter(Mandatory=$true)][psobject]$Preset)
    Invoke-SafeUiAction -Name "Configurar DNS" -Action {
        $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq "Up" })
        if ($adapters.Count -eq 0) { Write-Log "Nenhum adaptador de rede ativo encontrado."; return }
        $backupDir = New-BackupSession -Reason "dns"
        Get-DnsClientServerAddress |
            Select-Object InterfaceAlias, InterfaceIndex, AddressFamily, ServerAddresses |
            ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $backupDir "dns-atual.json") -Encoding UTF8
        Write-Log "Configuracao DNS atual salva antes da alteracao."
        foreach ($adapter in $adapters) {
            if ([string]::IsNullOrWhiteSpace($Preset.Primary)) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses
                Write-Log "DNS automatico restaurado em $($adapter.Name)."
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @($Preset.Primary, $Preset.Secondary)
                Write-Log "DNS $($Preset.Name) aplicado em $($adapter.Name): $($Preset.Primary), $($Preset.Secondary)."
            }
        }
    }
}

function Invoke-SystemRepair {
    Invoke-SafeUiAction -Name "Reparo do sistema" -Action {
        Write-Log "Iniciando DISM /RestoreHealth."
        Invoke-LoggedProcess -FilePath "dism.exe" -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") | Out-Null
        Write-Log "Iniciando SFC /scannow."
        Invoke-LoggedProcess -FilePath "sfc.exe" -Arguments @("/scannow") | Out-Null
    }
}

function Show-SystemHealthReport {
    Invoke-SafeUiAction -Name "Relatorio de saude" -Action {
        Write-Log "Gerando relatorio rapido de saude do sistema..."
        $backupDir = New-BackupSession -Reason "relatorio-saude"
        $reportPath = Join-Path $backupDir "relatorio-saude.txt"
        $report = [System.Collections.Generic.List[string]]::new()
        $report.Add("Assistente G-LAB - Relatorio de saude")
        $report.Add("Gerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $report.Add("")

        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $report.Add("Windows: $($os.Caption) build $($os.BuildNumber)")
            $report.Add("Ultima inicializacao: $($os.LastBootUpTime)")
            $report.Add(("Memoria livre: {0:N1} GB" -f ($os.FreePhysicalMemory / 1MB)))
        }

        $report.Add("")
        $report.Add("Discos:")
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | ForEach-Object {
            $free = if ($_.Size) { ($_.FreeSpace / $_.Size) * 100 } else { 0 }
            $report.Add(("- {0}: {1:N1} GB livres de {2:N1} GB ({3:N0}%)" -f $_.DeviceID, ($_.FreeSpace / 1GB), ($_.Size / 1GB), $free))
        }

        $report.Add("")
        $report.Add("Servicos:")
        $services = "wuauserv", "bits", "cryptsvc"
        foreach ($serviceName in $services) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $report.Add("- ${serviceName}: $($service.Status)")
            }
        }

        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCommand) {
            $report.Add("")
            $report.Add("Instalador de apps: disponivel em $($wingetCommand.Source)")
        } else {
            $report.Add("")
            $report.Add("Instalador de apps: nao encontrado")
        }
        $report | Set-Content -LiteralPath $reportPath -Encoding UTF8
        foreach ($line in $report) {
            if (-not [string]::IsNullOrWhiteSpace($line)) { Write-Log $line }
        }
        Start-Process explorer.exe $backupDir
        Write-Log "Relatorio rapido finalizado."
    }
}

function Invoke-NetworkRepair {
    Invoke-SafeUiAction -Name "Reparar rede" -Action {
        if (-not (Confirm-GLabAction -Title "Confirmar reparo de rede" -Message "Executar reparo basico de rede?`n`nSerao aplicados flushdns, renovacao de IP e reset de Winsock/IP. Pode ser necessario reiniciar o computador depois.")) {
            Write-Log "Reparo de rede cancelado pelo usuario."
            return
        }
        $backupDir = New-BackupSession -Reason "rede"
        Get-NetIPConfiguration |
            ConvertTo-Json -Depth 6 |
            Set-Content -LiteralPath (Join-Path $backupDir "rede-atual.json") -Encoding UTF8
        Write-Log "Configuracao de rede atual salva."
        Invoke-LoggedProcess -FilePath "ipconfig.exe" -Arguments @("/flushdns") | Out-Null
        Invoke-LoggedProcess -FilePath "ipconfig.exe" -Arguments @("/release") | Out-Null
        Invoke-LoggedProcess -FilePath "ipconfig.exe" -Arguments @("/renew") | Out-Null
        Invoke-LoggedProcess -FilePath "netsh.exe" -Arguments @("winsock", "reset") | Out-Null
        Invoke-LoggedProcess -FilePath "netsh.exe" -Arguments @("int", "ip", "reset") | Out-Null
        Write-Log "Reparo de rede finalizado. Reinicie o computador se a conexao continuar instavel."
    }
}

function Invoke-TimeRepair {
    Invoke-SafeUiAction -Name "Corrigir horario" -Action {
        if (-not (Confirm-GLabAction -Title "Confirmar correcao de horario" -Message "Sincronizar horario do Windows e ajustar o servico de tempo para automatico?")) {
            Write-Log "Correcao de horario cancelada pelo usuario."
            return
        }
        $backupDir = New-BackupSession -Reason "horario"
        Get-Service -Name "w32time" -ErrorAction SilentlyContinue |
            Select-Object Name, Status, StartType |
            ConvertTo-Json -Depth 3 |
            Set-Content -LiteralPath (Join-Path $backupDir "servico-horario.json") -Encoding UTF8
        Set-Service -Name "w32time" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "w32time" -ErrorAction SilentlyContinue
        Invoke-LoggedProcess -FilePath "w32tm.exe" -Arguments @("/resync", "/force") | Out-Null
        Write-Log "Sincronizacao de horario solicitada."
    }
}

function New-GLabRestorePoint {
    Invoke-SafeUiAction -Name "Criar ponto de restauracao" -Action {
        if (-not (Test-IsAdmin)) {
            Write-Log "Criar ponto de restauracao exige execucao como administrador."
            return
        }
        Write-Log "Criando ponto de restauracao do sistema..."
        New-SafeRestorePoint -Description "Assistente G-LAB"
    }
}

function Invoke-TempCleanup {
    Invoke-SafeUiAction -Name "Limpar temporarios" -Action {
        $targets = @($env:TEMP, (Join-Path $env:SystemRoot "Temp"))
        foreach ($target in $targets) {
            if (-not (Test-Path -LiteralPath $target)) { continue }
            Write-Log "Limpando temporarios em $target"
            Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                } catch {
                    Write-Log "Ignorado: $($_.FullName)"
                }
            }
        }
        Write-Log "Limpeza de temporarios finalizada."
    }
}

function Restart-ExplorerShell {
    Invoke-SafeUiAction -Name "Reiniciar Explorer" -Action {
        Write-Log "Reiniciando Explorer para aplicar ajustes visuais."
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Process explorer.exe
        Write-Log "Explorer reiniciado."
    }
}

function Set-WindowsUpdateMode {
    param([ValidateSet("Padrao", "Seguranca", "Desativar")][string]$Mode)
    Invoke-SafeUiAction -Name "Configurar Windows Update" -Action {
        if ($Mode -ne "Padrao") {
            if (-not (Confirm-GLabAction -Title "Confirmar Windows Update" -Message "Aplicar modo '$Mode' ao Windows Update? Essa acao altera politica local do sistema.")) {
                Write-Log "Alteracao do Windows Update cancelada pelo usuario."
                return
            }
        }
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        $backupDir = New-BackupSession -Reason "windows-update"
        Export-RegistryBackup -RegistryPath $path -BackupDir $backupDir
        if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
        switch ($Mode) {
            "Padrao" {
                Remove-ItemProperty -Path $path -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $path -Name "AUOptions" -ErrorAction SilentlyContinue
                Write-Log "Windows Update restaurado para o comportamento padrao."
            }
            "Seguranca" {
                New-ItemProperty -Path $path -Name "AUOptions" -Value 3 -PropertyType DWord -Force | Out-Null
                Write-Log "Windows Update configurado para baixar e avisar antes de instalar."
            }
            "Desativar" {
                New-ItemProperty -Path $path -Name "NoAutoUpdate" -Value 1 -PropertyType DWord -Force | Out-Null
                Write-Log "Atualizacoes automaticas desativadas por politica local."
            }
        }
    }
}

function Rename-WindowsUpdateCache {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Log "Cache nao encontrado: $Path"
        return
    }

    $parent = Split-Path -Parent $Path
    $leaf = Split-Path -Leaf $Path
    $backupName = "{0}.glab-bak-{1}" -f $leaf, (Get-Date -Format "yyyyMMdd-HHmmss")
    $target = Join-Path $parent $backupName
    try {
        Rename-Item -LiteralPath $Path -NewName $backupName -ErrorAction Stop
        Write-Log "Cache preservado como backup: $target"
    } catch {
        Write-Log "Nao foi possivel renomear ${Path}: $($_.Exception.Message)"
    }
}

function Invoke-WindowsUpdateRepair {
    Invoke-SafeUiAction -Name "Reparar Windows Update" -Action {
        if (-not (Test-IsAdmin)) {
            Write-Log "Reparar Windows Update exige execucao como administrador."
            return
        }
        if (-not (Confirm-GLabAction -Title "Confirmar reparo do Windows Update" -Message "Reparar componentes do Windows Update agora?`n`nO Assistente vai salvar informacoes atuais, parar servicos, renomear caches antigos e reiniciar os servicos. Pode ser necessario reiniciar o computador depois.")) {
            Write-Log "Reparo do Windows Update cancelado pelo usuario."
            return
        }

        $backupDir = New-BackupSession -Reason "windows-update-reparo"
        Export-RegistryBackup -RegistryPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -BackupDir $backupDir
        Get-Service -Name "wuauserv","bits","cryptsvc","appidsvc" -ErrorAction SilentlyContinue |
            Select-Object Name, Status, StartType |
            ConvertTo-Json -Depth 3 |
            Set-Content -LiteralPath (Join-Path $backupDir "servicos-windows-update.json") -Encoding UTF8

        Write-Log "Parando servicos de atualizacao..."
        foreach ($serviceName in @("wuauserv", "bits", "cryptsvc", "appidsvc")) {
            try {
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Log "Servico parado: $serviceName"
            } catch {
                Write-Log "Servico nao parado ou indisponivel: $serviceName"
            }
        }

        Rename-WindowsUpdateCache -Path (Join-Path $env:SystemRoot "SoftwareDistribution")
        Rename-WindowsUpdateCache -Path (Join-Path $env:SystemRoot "System32\catroot2")

        Write-Log "Reiniciando servicos de atualizacao..."
        foreach ($serviceName in @("appidsvc", "cryptsvc", "bits", "wuauserv")) {
            try {
                Start-Service -Name $serviceName -ErrorAction Stop
                Write-Log "Servico iniciado: $serviceName"
            } catch {
                Write-Log "Servico nao iniciado automaticamente: $serviceName"
            }
        }

        if (Get-Command "UsoClient.exe" -ErrorAction SilentlyContinue) {
            Invoke-LoggedProcess -FilePath "UsoClient.exe" -Arguments @("StartScan") | Out-Null
        } elseif (Get-Command "wuauclt.exe" -ErrorAction SilentlyContinue) {
            Invoke-LoggedProcess -FilePath "wuauclt.exe" -Arguments @("/resetauthorization", "/detectnow") | Out-Null
        }

        Write-Log "Reparo do Windows Update finalizado. Se ainda houver erro, reinicie o computador e tente novamente."
    }
}

function Open-BackupFolder {
    Invoke-SafeUiAction -Name "Abrir backups" -Action {
        New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
        Start-Process explorer.exe $script:BackupRoot
        Write-Log "Pasta de backups aberta."
    }
}

function Open-AppFolder {
    Invoke-SafeUiAction -Name "Abrir pasta do app" -Action {
        Start-Process explorer.exe $script:Root
        Write-Log "Pasta local do Assistente G-LAB aberta."
    }
}

function Open-WindowsUpdateSettings {
    Invoke-SafeUiAction -Name "Abrir Windows Update" -Action {
        Start-Process "ms-settings:windowsupdate"
        Write-Log "Configuracoes do Windows Update abertas."
    }
}

function Set-AppxSelection {
    param([object]$Appx, [bool]$Selected)
    if (-not $Appx) { return }
    $package = if ($Appx.package) { $Appx.package } else { $Appx.Package }
    if ($Selected) { [void]$script:SelectedAppxNames.Add($package) } else { [void]$script:SelectedAppxNames.Remove($package) }
    Update-SelectedCount
}

function Invoke-AppxRemoval {
    Invoke-SafeUiAction -Name "Remover AppX" -Action {
        $selected = @($script:AppxCatalog | Where-Object {
            $package = if ($_.package) { $_.package } else { $_.Package }
            $safe = if ($null -ne $_.safe) { $_.safe } else { $_.Safe }
            $script:SelectedAppxNames.Contains($package) -and $safe
        })
        if ($selected.Count -eq 0) { Write-Log "Nenhum AppX seguro selecionado para remocao."; return }
        $names = ($selected | ForEach-Object { "- " + $(if ($_.name) { $_.name } else { $_.Name }) }) -join "`n"
        $message = "Remover $($selected.Count) aplicativos AppX selecionados?`n`n$names`n`nAntes da remocao sera salvo um inventario local dos pacotes."
        if (-not (Confirm-GLabAction -Title "Confirmar remocao AppX" -Message $message)) {
            Write-Log "Remocao AppX cancelada pelo usuario."
            return
        }
        $backupDir = New-BackupSession -Reason "appx"
        Export-AppxInventory -BackupDir $backupDir
        New-SafeRestorePoint -Description "Assistente G-LAB - AppX"
        foreach ($appx in $selected) {
            $name = if ($appx.name) { $appx.name } else { $appx.Name }
            $package = if ($appx.package) { $appx.package } else { $appx.Package }
            Write-Log "Removendo AppX: $name"
            Get-AppxPackage -Name $package -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $package } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Log "Remocao AppX finalizada."
    }
}

function Invoke-AppxInstall {
    Invoke-SafeUiAction -Name "Reinstalar AppX" -Action {
        $selected = @($script:AppxCatalog | Where-Object {
            $package = if ($_.package) { $_.package } else { $_.Package }
            $script:SelectedAppxNames.Contains($package)
        })
        if ($selected.Count -eq 0) { Write-Log "Nenhum AppX selecionado para reinstalar."; return }

        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetCommand) {
            Write-Log "Instalador de apps nao encontrado. Abra a Microsoft Store para reinstalar manualmente."
            return
        }

        $names = ($selected | ForEach-Object { "- " + $(if ($_.name) { $_.name } else { $_.Name }) }) -join "`n"
        if (-not (Confirm-GLabAction -Title "Confirmar reinstalacao AppX" -Message "Reinstalar $($selected.Count) apps do Windows selecionados?`n`n$names`n`nO Assistente tentara usar o instalador de apps do Windows.")) {
            Write-Log "Reinstalacao AppX cancelada pelo usuario."
            return
        }

        Update-WingetSources -WingetPath $wingetCommand.Source
        foreach ($appx in $selected) {
            $name = if ($appx.name) { $appx.name } else { $appx.Name }
            $package = if ($appx.package) { $appx.package } else { $appx.Package }
            Write-Log "Reinstalando AppX: $name"
            $exitCode = Invoke-LoggedProcess -FilePath $wingetCommand.Source -Arguments @("install", "--id", $package, "--exact", "--accept-package-agreements", "--accept-source-agreements", "--silent", "--disable-interactivity")
            if ($exitCode -ne 0) {
                Write-Log "Atencao: $name pode exigir reinstalacao pela Microsoft Store."
            }
        }
        Write-Log "Reinstalacao AppX finalizada."
    }
}

function Open-Windows11Creator {
    Invoke-SafeUiAction -Name "Windows 11 Creator" -Action {
        Write-Log "Abrindo download oficial do Windows 11. A gravacao de USB permanece bloqueada ate existir selecao segura de disco."
        Start-Process "https://www.microsoft.com/software-download/windows11"
    }
}

function Open-DiskManagement {
    Invoke-SafeUiAction -Name "Abrir gerenciamento de disco" -Action {
        Start-Process "diskmgmt.msc"
        Write-Log "Gerenciamento de Disco aberto."
    }
}

function Open-DownloadsFolder {
    Invoke-SafeUiAction -Name "Abrir Downloads" -Action {
        $downloads = Join-Path $env:USERPROFILE "Downloads"
        if (Test-Path -LiteralPath $downloads) {
            Start-Process explorer.exe $downloads
            Write-Log "Pasta Downloads aberta."
        } else {
            Write-Log "Pasta Downloads nao encontrada."
        }
    }
}

function New-AutoUnattendFile {
    Invoke-SafeUiAction -Name "Gerar AutoUnattend" -Action {
        if (-not (Confirm-GLabAction -Title "Gerar AutoUnattend" -Message "Gerar um modelo inicial de AutoUnattend.xml?`n`nEle sera salvo em uma pasta de backup do Assistente. Nada sera aplicado no computador e nenhum disco sera alterado.")) {
            Write-Log "Geracao de AutoUnattend cancelada pelo usuario."
            return
        }

        $outputDir = New-BackupSession -Reason "win11-autounattend"
        $target = Join-Path $outputDir "AutoUnattend.xml"
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>pt-BR</UILanguage>
      </SetupUILanguage>
      <InputLocale>pt-BR</InputLocale>
      <SystemLocale>pt-BR</SystemLocale>
      <UILanguage>pt-BR</UILanguage>
      <UserLocale>pt-BR</UserLocale>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>pt-BR</InputLocale>
      <SystemLocale>pt-BR</SystemLocale>
      <UILanguage>pt-BR</UILanguage>
      <UserLocale>pt-BR</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <TimeZone>E. South America Standard Time</TimeZone>
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>false</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>false</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
    </component>
  </settings>
</unattend>
'@
        Set-Content -LiteralPath $target -Value $xml -Encoding UTF8
        Write-Log "AutoUnattend gerado: $target"
        Start-Process explorer.exe $outputDir
    }
}

function Build-Ui {
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Assistente G-LAB" Height="780" Width="1240" MinHeight="720" MinWidth="1120" WindowStartupLocation="CenterScreen"
        Background="#E8EEF6" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#F8FAFC"/>
            <Setter Property="BorderBrush" Value="#B8C4D6"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Foreground" Value="#0F172A"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="78"/>
            <RowDefinition Height="42"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="118"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#060A17" Padding="18,11">
            <DockPanel LastChildFill="True">
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
                    <Border Width="48" Height="48" CornerRadius="14" Background="#111827" Margin="0,0,12,0" BorderBrush="#22D3EE" BorderThickness="1" ClipToBounds="True">
                        <Image x:Name="LogoImage" Stretch="UniformToFill"/>
                    </Border>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="Assistente G-LAB" FontSize="24" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                        <TextBlock Text="Instalacao, ajustes e manutencao Windows" FontSize="12" Foreground="#93C5FD" TextWrapping="NoWrap"/>
                        <TextBlock x:Name="VersionText" Text="" FontSize="11" Foreground="#64748B" TextWrapping="NoWrap"/>
                    </StackPanel>
                </StackPanel>
                <Border DockPanel.Dock="Right" HorizontalAlignment="Right" VerticalAlignment="Center" Background="#0F172A" BorderBrush="#1E40AF" BorderThickness="1" CornerRadius="18" Padding="14,7">
                    <StackPanel Width="230">
                        <TextBlock x:Name="StatusText" Foreground="#BFDBFE" TextTrimming="CharacterEllipsis"/>
                        <ProgressBar x:Name="ProgressBar" Height="4" Margin="0,6,0,0" Visibility="Collapsed" Foreground="#22D3EE" Background="#1E293B"/>
                    </StackPanel>
                </Border>
            </DockPanel>
        </Border>

        <Grid Grid.Row="1" Margin="14,7,14,5">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="704"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Orientation="Horizontal">
                <Button x:Name="InstallTab" Content="Instalar" Width="110" Margin="0,0,7,0" FontSize="12" Background="#FFFFFF"/>
                <Button x:Name="TweaksTab" Content="Ajustes" Width="110" Margin="0,0,7,0" FontSize="12" Background="#FFFFFF"/>
                <Button x:Name="ConfigTab" Content="Configurar" Width="110" Margin="0,0,7,0" FontSize="12" Background="#FFFFFF"/>
                <Button x:Name="UpdatesTab" Content="Atualizar" Width="110" Margin="0,0,7,0" FontSize="12" Background="#FFFFFF"/>
                <Button x:Name="AppxTab" Content="AppX" Width="82" Margin="0,0,7,0" FontSize="12" Background="#FFFFFF"/>
                <Button x:Name="Win11Tab" Content="Win11" Width="82" Margin="0,0,7,0" FontSize="12" Background="#FFFFFF"/>
            </StackPanel>
            <TextBox Grid.Column="1" x:Name="SearchBox" Height="29" Margin="8,0,0,0" Padding="10,0" VerticalContentAlignment="Center"
                     BorderBrush="#CBD5E1" Background="#FFFFFF" Foreground="#0F172A" ToolTip="Digite para buscar por nome, categoria, id ou tag"/>
        </Grid>

        <Grid Grid.Row="2" Margin="14,0,14,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="230"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Padding="10" Background="#F8FAFC" BorderBrush="#CBD5E1" BorderThickness="1" CornerRadius="14">
                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                <StackPanel>
                    <TextBlock Text="Atalhos" FontSize="16" FontWeight="SemiBold" Foreground="#0F172A" Margin="0,0,0,8"/>
                    <TextBlock Text="Predefinicoes" FontSize="13" FontWeight="SemiBold" Foreground="#334155" Margin="0,0,0,5"/>
                    <ComboBox x:Name="PresetBox" Height="29" Margin="0,0,0,5"/>
                    <Button x:Name="ApplyPresetButton" Content="Usar predefinicao" Margin="0,0,0,10" Height="29"/>
                    <TextBlock Text="DNS" FontSize="13" FontWeight="SemiBold" Foreground="#334155" Margin="0,0,0,5"/>
                    <ComboBox x:Name="DnsBox" Height="29" Margin="0,0,0,5"/>
                    <Button x:Name="ApplyDnsButton" Content="Trocar DNS" Margin="0,0,0,10" Height="29"/>
                    <TextBlock Text="Uso rapido" FontSize="13" FontWeight="SemiBold" Foreground="#334155" Margin="0,0,0,5"/>
                    <Button x:Name="ClearButton" Content="Limpar selecao" Margin="0,0,0,5" Height="29"/>
                    <Button x:Name="RestorePointButton" Content="Criar ponto seguro" Margin="0,0,0,5" Height="29"/>
                    <Button x:Name="BackupsButton" Content="Abrir backups" Margin="0,0,0,5" Height="29"/>
                    <Button x:Name="HealthButton" Content="Relatorio de saude" Margin="0,0,0,5" Height="29"/>
                    <Button x:Name="ReloadButton" Content="Recarregar catalogos" Margin="0,0,0,10" Height="29"/>
                    <Border Background="#F1F5F9" CornerRadius="10" Padding="10" Margin="0,4,0,0">
                        <StackPanel>
                            <TextBlock x:Name="SelectedCountText" Text="Selecionados: 0" FontWeight="SemiBold" Foreground="#0F172A"/>
                            <TextBlock x:Name="AdminText" Text="" Margin="0,8,0,0" TextWrapping="Wrap" Foreground="#047857"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
                </ScrollViewer>
            </Border>

            <DockPanel Grid.Column="1" Margin="10,0,0,0">
                <ComboBox x:Name="CategoryBox" DockPanel.Dock="Top" Height="30" Margin="0,0,0,6" Padding="8,0"/>
                <ScrollViewer VerticalScrollBarVisibility="Auto" Background="Transparent">
                    <WrapPanel x:Name="AppsPanel"/>
                </ScrollViewer>
            </DockPanel>
        </Grid>

        <Border Grid.Row="3" Margin="14,8,14,12" Padding="8" Background="#0B1020" CornerRadius="14">
            <TextBox x:Name="LogBox" Background="#0F172A" Foreground="#E5E7EB" BorderThickness="0"
                     FontFamily="Consolas" FontSize="12" IsReadOnly="True" TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto"/>
        </Border>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
    return [Windows.Markup.XamlReader]::Load($reader)
}

$script:Catalog = Load-AppCatalog
$script:Tweaks = Load-TweakCatalog
$script:Presets = Load-PresetCatalog
$script:AppxCatalog = Load-AppxCatalog
$script:ValidationRan = $false
$window = Build-Ui
if (-not $window) {
    throw "Nao foi possivel carregar a janela WPF do Assistente G-LAB."
}

$script:SearchBox = $window.FindName("SearchBox")
$script:CategoryBox = $window.FindName("CategoryBox")
$script:PresetBox = $window.FindName("PresetBox")
$script:DnsBox = $window.FindName("DnsBox")
$script:AppsPanel = $window.FindName("AppsPanel")
$script:LogBox = $window.FindName("LogBox")
$script:SelectedCountText = $window.FindName("SelectedCountText")
$script:StatusText = $window.FindName("StatusText")
$script:ProgressBar = $window.FindName("ProgressBar")
$script:LogoImage = $window.FindName("LogoImage")
$script:VersionText = $window.FindName("VersionText")
$adminText = $window.FindName("AdminText")

if ($script:LogoImage -and (Test-Path -LiteralPath $script:LogoPath)) {
    $logo = [System.Windows.Media.Imaging.BitmapImage]::new()
    $logo.BeginInit()
    $logo.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $logo.UriSource = [Uri]$script:LogoPath
    $logo.EndInit()
    $logo.Freeze()
    $script:LogoImage.Source = $logo
}
if ($script:VersionText) {
    $script:VersionText.Text = "Versao $script:AppVersion"
}

$categories = @([pscustomobject]@{ Label = "Todos"; Value = "All" }) + (($script:Catalog | Select-Object -ExpandProperty category -Unique | Sort-Object) | ForEach-Object {
    [pscustomobject]@{ Label = $_; Value = $_ }
})
foreach ($category in $categories) {
    $item = [System.Windows.Controls.ComboBoxItem]::new()
    $item.Content = $category.Label
    $item.Tag = $category.Value
    $script:CategoryBox.Items.Add($item) | Out-Null
}
$script:CategoryBox.SelectedIndex = 0

foreach ($preset in $script:Presets.PSObject.Properties) {
    $item = [System.Windows.Controls.ComboBoxItem]::new()
    $item.Content = "$($preset.Name) - $($preset.Value.description)"
    $item.Tag = $preset.Name
    $script:PresetBox.Items.Add($item) | Out-Null
}
if ($script:PresetBox.Items.Count -gt 0) {
    $script:PresetBox.SelectedIndex = 0
}

foreach ($dns in $script:DnsPresets) {
    $item = [System.Windows.Controls.ComboBoxItem]::new()
    $item.Content = $dns.Name
    $item.Tag = $dns
    $script:DnsBox.Items.Add($item) | Out-Null
}
if ($script:DnsBox.Items.Count -gt 0) {
    $script:DnsBox.SelectedIndex = 0
}

$window.FindName("ApplyPresetButton").Add_Click({
    if ($script:PresetBox.SelectedItem) {
        Select-PresetApps -PresetName $script:PresetBox.SelectedItem.Tag
    }
})
$window.FindName("ApplyDnsButton").Add_Click({
    if ($script:DnsBox.SelectedItem) {
        Set-GLabDns -Preset $script:DnsBox.SelectedItem.Tag
    }
})
$window.FindName("RestorePointButton").Add_Click({ New-GLabRestorePoint })
$window.FindName("BackupsButton").Add_Click({ Open-BackupFolder })
$window.FindName("HealthButton").Add_Click({ Show-SystemHealthReport })
$window.FindName("ReloadButton").Add_Click({
    $script:Catalog = Load-AppCatalog
    $script:Tweaks = Load-TweakCatalog
    $script:Presets = Load-PresetCatalog
    $script:AppxCatalog = Load-AppxCatalog
    Test-AssistenteConfig
    Write-Log "Configuracoes recarregadas: $($script:Catalog.Count) apps, $(@((Get-AllTweaks)).Count) tweaks, $(@($script:Presets.PSObject.Properties).Count) presets."
    if ($script:ActiveView -eq "Tweaks") {
        Show-TweaksView
    } elseif ($script:ActiveView -eq "Config") {
        Show-ConfigView
    } elseif ($script:ActiveView -eq "Updates") {
        Show-UpdatesView
    } elseif ($script:ActiveView -eq "Appx") {
        Show-AppxView
    } elseif ($script:ActiveView -eq "Win11") {
        Show-Win11View
    } else {
        Refresh-AppGrid
    }
})
$window.FindName("ClearButton").Add_Click({
    if ($script:ActiveView -eq "Tweaks") {
        Clear-TweakSelection
    } elseif ($script:ActiveView -eq "Appx") {
        $script:SelectedAppxNames.Clear()
        Show-AppxView
    } else {
        Clear-AppSelection
    }
})

$window.FindName("InstallTab").Add_Click({ Refresh-AppGrid })
$window.FindName("TweaksTab").Add_Click({ Show-TweaksView })
$window.FindName("ConfigTab").Add_Click({ Show-ConfigView })
$window.FindName("UpdatesTab").Add_Click({ Show-UpdatesView })
$window.FindName("AppxTab").Add_Click({ Show-AppxView })
$window.FindName("Win11Tab").Add_Click({ Show-Win11View })
$script:SearchBox.Add_TextChanged({
    if ($script:ActiveView -eq "Install") {
        Refresh-AppGrid
    } elseif ($script:ActiveView -eq "Appx") {
        Show-AppxView
    }
})
$script:CategoryBox.Add_SelectionChanged({
    if ($script:ActiveView -eq "Install") { Refresh-AppGrid }
})

if (Test-IsAdmin) {
    $adminText.Text = "Executando como administrador."
} else {
    $adminText.Text = "Sem administrador. Instalar apps pode pedir elevacao."
    $adminText.Foreground = "#B45309"
}

Write-Log "Assistente G-LAB iniciado. Catalogo carregado: $($script:Catalog.Count) apps."
Refresh-AppGrid
if ($ValidateOnly) {
    Test-AssistenteConfig
    $script:ValidationRan = $true
    "ValidateOnly OK: versao $script:AppVersion, $($script:Catalog.Count) apps, $(@((Get-AllTweaks)).Count) tweaks e $(@($script:Presets.PSObject.Properties).Count) presets carregados."
    return
}
if ($SelfTest) {
    Test-AssistenteSelfTest
    return
}
if (-not $window) {
    throw "A janela WPF nao foi inicializada. Execute novamente com powershell.exe -STA."
}

[void]$window.ShowDialog()
