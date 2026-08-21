#DEPRECATED
# Aurora Shell 2.0 - Windows Build Installer
$ErrorActionPreference = "Stop"

Write-Host "`n🌌 Initializing Aurora Shell 2.0 Build Installer..." -ForegroundColor Cyan

# Define local storage path
$configPath = Join-Path $HOME ".aurora-shell"
if (!(Test-Path $configPath)) { 
    New-Item -ItemType Directory -Path $configPath | Out-Null 
    Write-Host "✅ Created local config directory." -ForegroundColor Gray
}

# The URL to the actual theme/logic file (Update this to your repo link)
$themeUrl = "https://raw.githubusercontent.com/YashB-byte/aurora-shell-2/main/aurora_theme.ps1"
$themePath = Join-Path $configPath "aurora_theme.ps1"

Write-Host "📥 Fetching latest build components..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $themeUrl -OutFile $themePath
} catch {
    Write-Host "❌ Failed to download theme components. Check your internet connection." -ForegroundColor Red
    return
}

# Profile Integration
$profilePath = $PROFILE
if (!(Test-Path $profilePath)) { 
    New-Item -ItemType File -Path $profilePath -Force | Out-Null 
}

$sourceLine = "if (Test-Path '$themePath') { . '$themePath' }"
$currentProfile = Get-Content $profilePath

if ($currentProfile -notcontains $sourceLine) {
    Add-Content -Path $profilePath -Value "`n# Aurora Shell 2.0 Build Logic`n$sourceLine"
    Write-Host "🚀 Build-installer has linked Aurora to your Profile!" -ForegroundColor Green
} else {
    Write-Host "✨ Build is already active in your Profile." -ForegroundColor Yellow
}

Write-Host "`n🎉 Installation Complete. Restart PowerShell to launch Aurora.`n" -ForegroundColor Cyan
