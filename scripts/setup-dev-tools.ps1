# =============================================================================
# setup-dev-tools.ps1
# Instala e configura: GitHub CLI + RTK (Rust Token Killer) + Hook Claude Code
# Repositorio: https://github.com/ClecioH/SOFTSKILL
#
# Como usar:
#   1. Abra o PowerShell como usuario normal (nao precisa de Admin)
#   2. Execute: .\scripts\setup-dev-tools.ps1
#   Ou direto do GitHub:
#   irm https://raw.githubusercontent.com/ClecioH/SOFTSKILL/master/scripts/setup-dev-tools.ps1 | iex
# =============================================================================

$ErrorActionPreference = "Stop"

function Write-Step  { param($msg) Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "   [OK] $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "   [--] $msg" -ForegroundColor DarkGray }
function Write-Warn  { param($msg) Write-Host "   [!] $msg" -ForegroundColor Yellow }

Write-Host @"

  ╔══════════════════════════════════════════╗
  ║        SOFTSKILL - Dev Tools Setup       ║
  ║  GitHub CLI  +  RTK  +  Claude Hook      ║
  ╚══════════════════════════════════════════╝

"@ -ForegroundColor Magenta

# ---------------------------------------------------------------------------
# 1. GitHub CLI
# ---------------------------------------------------------------------------
Write-Step "Verificando GitHub CLI (gh)..."

$ghPath = Get-Command gh -ErrorAction SilentlyContinue
if ($ghPath) {
    $ghVer = (gh --version 2>&1 | Select-Object -First 1)
    Write-Skip "gh ja instalado: $ghVer"
} else {
    Write-Host "   Instalando via winget..." -ForegroundColor Yellow
    winget install --id GitHub.cli --silent --accept-package-agreements --accept-source-agreements
    $env:PATH = "$env:PATH;C:\Program Files\GitHub CLI"
    Write-Ok "GitHub CLI instalado!"
}

# ---------------------------------------------------------------------------
# 2. RTK (Rust Token Killer)
# ---------------------------------------------------------------------------
Write-Step "Verificando RTK..."

$rtkInstallDir = "$env:LOCALAPPDATA\rtk"
$rtkExe        = "$rtkInstallDir\rtk.exe"

$rtkInPath = Get-Command rtk -ErrorAction SilentlyContinue
if ($rtkInPath) {
    $rtkVer = (rtk --version 2>&1)
    Write-Skip "rtk ja instalado: $rtkVer"
} elseif (Test-Path $rtkExe) {
    $env:PATH = "$env:PATH;$rtkInstallDir"
    $rtkVer = (& $rtkExe --version 2>&1)
    Write-Skip "rtk ja instalado (sem PATH): $rtkVer"
} else {
    Write-Host "   Buscando ultima versao no GitHub..." -ForegroundColor Yellow

    $release  = Invoke-RestMethod "https://api.github.com/repos/rtk-ai/rtk/releases/latest"
    $version  = $release.tag_name
    $asset    = $release.assets | Where-Object { $_.name -like "*windows*msvc*.zip" }

    if (-not $asset) {
        Write-Warn "Nao foi possivel encontrar binario Windows para RTK $version"
        exit 1
    }

    $zipPath = "$env:TEMP\rtk-windows.zip"
    $extract = "$env:TEMP\rtk-extracted"

    Write-Host "   Baixando RTK $version..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

    Expand-Archive -Path $zipPath -DestinationPath $extract -Force
    New-Item -ItemType Directory -Path $rtkInstallDir -Force | Out-Null
    Copy-Item "$extract\rtk.exe" -Destination $rtkExe -Force

    # Adicionar ao PATH do usuario permanentemente
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$rtkInstallDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$rtkInstallDir", "User")
    }
    $env:PATH = "$env:PATH;$rtkInstallDir"

    # Limpar temporarios
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue

    $rtkVer = (& $rtkExe --version 2>&1)
    Write-Ok "RTK instalado: $rtkVer"
}

# ---------------------------------------------------------------------------
# 3. Hook Claude Code
# ---------------------------------------------------------------------------
Write-Step "Configurando hook no Claude Code..."

$claudeDir      = "$env:USERPROFILE\.claude"
$settingsFile   = "$claudeDir\settings.json"

# Garantir que a pasta .claude existe
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# Ler settings existentes ou criar novo objeto
if (Test-Path $settingsFile) {
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
    Write-Host "   Settings existentes encontrados." -ForegroundColor DarkGray
} else {
    $settings = [PSCustomObject]@{}
    Write-Host "   Criando novo settings.json..." -ForegroundColor DarkGray
}

# Verificar se hook ja existe
$hookCmd   = "$rtkInstallDir\rtk.exe hook claude"
$hookExists = $false

if ($settings.PSObject.Properties["hooks"] -and
    $settings.hooks.PSObject.Properties["PreToolUse"]) {
    foreach ($entry in $settings.hooks.PreToolUse) {
        foreach ($h in $entry.hooks) {
            if ($h.command -like "*rtk*hook*claude*") {
                $hookExists = $true
            }
        }
    }
}

if ($hookExists) {
    Write-Skip "Hook RTK ja configurado no Claude Code."
} else {
    # Montar estrutura do hook
    $hookEntry = [PSCustomObject]@{
        matcher = "Bash"
        hooks   = @(
            [PSCustomObject]@{
                type    = "command"
                command = $hookCmd.Replace("\", "\\")
                shell   = "powershell"
            }
        )
    }

    if (-not ($settings.PSObject.Properties["hooks"])) {
        $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{})
    }
    if (-not ($settings.hooks.PSObject.Properties["PreToolUse"])) {
        $settings.hooks | Add-Member -NotePropertyName "PreToolUse" -NotePropertyValue @()
    }

    $settings.hooks.PreToolUse = @($settings.hooks.PreToolUse) + $hookEntry

    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    Write-Ok "Hook RTK adicionado ao Claude Code!"
}

# ---------------------------------------------------------------------------
# 4. Inicializar RTK para Claude Code
# ---------------------------------------------------------------------------
Write-Step "Inicializando RTK para Claude Code..."

$rtkMd = "$claudeDir\RTK.md"
if (Test-Path $rtkMd) {
    Write-Skip "RTK.md ja existe em $rtkMd"
} else {
    & $rtkExe init -g --agent claude --hook-only 2>&1 | Out-Null
    Write-Ok "RTK inicializado!"
}

# ---------------------------------------------------------------------------
# Conclusao
# ---------------------------------------------------------------------------
Write-Host @"

  ╔══════════════════════════════════════════╗
  ║           Setup Concluido!               ║
  ╚══════════════════════════════════════════╝

  O que foi instalado/configurado:
    [OK] GitHub CLI (gh)
    [OK] RTK $((& $rtkExe --version 2>&1))
    [OK] Hook PreToolUse no Claude Code

  Proximo passo:
    Reinicie o Claude Code para ativar o hook RTK.

  Verificar economia de tokens:
    rtk gain
    rtk gain --history

"@ -ForegroundColor Magenta
