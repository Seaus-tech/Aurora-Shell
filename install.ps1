# Aurora-Shell v5.6.2 installer — PowerShell port
# FIX: Sentinel Auth Visuals + Separator + CPU/Disk Telemetry
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$VER      = "5.6.2"
$DATA_DIR = "$HOME\.aurora-shell_files"
$THEME_FILE  = "$DATA_DIR\aurora-shell_theme.ps1"
$CONFIG_FILE = "$DATA_DIR\aurora-shell_settings.ps1"
$GIT_CLONE   = "https://github.com/Seaus-tech/Aurora-Shell.git"

Write-Host "running as ${env:USERNAME}: rm -rf $DATA_DIR" -ForegroundColor Yellow
if (Test-Path $DATA_DIR) { Remove-Item -Recurse -Force $DATA_DIR }
if (Test-Path $PROFILE) {
    (Get-Content $PROFILE) | Where-Object { $_ -notmatch 'aurora-shell_files' } | Set-Content $PROFILE
}
Write-Host "running as ${env:USERNAME}: mkdir $DATA_DIR" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $DATA_DIR -Force | Out-Null
Write-Host "--- Aurora-Shell v$VER installer---" -ForegroundColor Cyan

# ── helpers ─────────────────────────────────────────────────────────────────
function Get-SHA256([string]$s) {
    (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($s))) -Algorithm SHA256).Hash.ToLower()
}
function Read-PlainPassword([string]$prompt) {
    $ss = Read-Host $prompt -AsSecureString
    [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
}

# ── sync env ─────────────────────────────────────────────────────────────────
function Sync-Env {
    Write-Host "Syncing Environment..." -ForegroundColor Yellow -NoNewline
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "`nwinget not found — install App Installer from the Microsoft Store." -ForegroundColor Red; return
    }
    Write-Host " downloading extensions..." -ForegroundColor Yellow -NoNewline
    winget install --id Figlet.Figlet -e --silent 2>$null
    Write-Host " READY" -ForegroundColor Green
}

# ── dev tools ────────────────────────────────────────────────────────────────
function Install-DevTools {
    Write-Host "`n--- DEV TOOLS SETUP ---" -ForegroundColor Cyan
    $tools = @(
        @{Name="Git";        Id="Git.Git"},
        @{Name="GitHub_CLI"; Id="GitHub.cli"},
        @{Name="NodeJS";     Id="OpenJS.NodeJS"},
        @{Name="Python3";    Id="Python.Python.3"},
        @{Name="Java";       Id="Microsoft.OpenJDK.21"},
        @{Name="Go";         Id="GoLang.Go"},
        @{Name="Rust";       Id="Rustlang.Rustup"},
        @{Name="Docker";     Id="Docker.DockerDesktop"},
        @{Name="AWS_CLI";    Id="Amazon.AWSCLI"},
        @{Name="Azure_CLI";  Id="Microsoft.AzureCLI"}
    )
    foreach ($t in $tools) {
        if ((Read-Host "Install $($t.Name)? (y/n)") -eq 'y') {
            if ($t.Name -eq 'Git' -and (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Host "✔ Git already installed: $(git --version)" -ForegroundColor Green
            } else { winget install --id $t.Id -e --silent }
        }
    }
}


# ── config wizard ─────────────────────────────────────────────────────────────
function Run-Wizard {
    Write-Host "`n--- AURORA CONFIGURATION WIZARD ---" -ForegroundColor Green
    if (Test-Path $CONFIG_FILE) { . $CONFIG_FILE }

    $plain = Read-PlainPassword "Set Terminal PIN (Enter for none)"
    if ($plain) {
        $plain | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Set-Content "$DATA_DIR\aurora-pin.enc"
        Write-Host "PIN stored securely." -ForegroundColor Green
    }

    Write-Host "1) Mega-Block  2) Custom Slant"
    if ((Read-Host "Selection") -eq '2') { $HDR_MODE = "CUSTOM"; $HDR_VAL = Read-Host "Header Name" }
    else                                  { $HDR_MODE = "BLOCK";  $HDR_VAL = "Aurora-Shell" }

    $BDAY = Read-Host "Birthday (MMDD)"
    $P_ID = Read-Host "Prompt ID"

    @"
`$global:AURORA_VER="$VER"
`$global:AURORA_HDR_MODE="$HDR_MODE"
`$global:AURORA_HDR_VAL="$HDR_VAL"
`$global:AURORA_USER_BDAY="$BDAY"
`$global:AURORA_ID="$P_ID"
"@ | Set-Content $CONFIG_FILE

    # account sign-in
    Write-Host "`nAurora Account (optional — syncs your profile across machines)" -ForegroundColor Cyan
    switch (Read-Host "Sign in? (y/n/create)") {
        { $_ -in 'y','yes' } {
            $uname = Read-Host "Username"
            $hash  = Get-SHA256 (Read-PlainPassword "Password")
            try {
                $resp = Invoke-RestMethod -Method Post -Uri "https://aurora-accounts.yash-behera.workers.dev/accounts/login" `
                    -ContentType "application/json" -Body "{`"username`":`"$uname`",`"password_hash`":`"$hash`"}"
                $resp | ConvertTo-Json -Compress | Set-Content "$DATA_DIR\active_account.json"
                (Get-Content $CONFIG_FILE) -replace '(?m)^.*AURORA_ID.*$', "`$global:AURORA_ID=`"$($resp.username)`"" | Set-Content $CONFIG_FILE
                Write-Host "Signed in as $($resp.username)" -ForegroundColor Green
            } catch { Write-Host "Sign-in failed: $_" -ForegroundColor Red }
        }
        'create' {
            $uname = Read-Host "New username"
            $pw1   = Read-PlainPassword "Password"
            $pw2   = Read-PlainPassword "Confirm"
            if ($pw1 -ne $pw2) { Write-Host "Passwords don't match — skipping" -ForegroundColor Red; return }
            $payload = @{username=$uname;password_hash=(Get-SHA256 $pw1);installed="";plugins=@();linked=@{};header="Aurora-Shell";header_mode="BLOCK"} | ConvertTo-Json -Compress
            try {
                Invoke-RestMethod -Method Post -Uri "https://aurora-accounts.yash-behera.workers.dev/accounts" `
                    -ContentType "application/json" -Body $payload | Out-Null
                Write-Host "Account created! Login with: shell.aurora --account --login" -ForegroundColor Green
            } catch { Write-Host "Create failed: $_" -ForegroundColor Red }
        }
    }
}


# ── theme generator ───────────────────────────────────────────────────────────
function Generate-Theme {
$themeContent = @'
# Generated by Aurora-Shell Installer
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. "$HOME\.aurora-shell_files\aurora-shell_settings.ps1"

function Get-StoredPin {
    $enc = "$HOME\.aurora-shell_files\aurora-pin.enc"
    if (Test-Path $enc) { (Get-Content $enc | ConvertTo-SecureString) |
        ForEach-Object { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) } }
}

function Invoke-Auth {
    $target = Get-StoredPin
    if (-not $target) { return }
    Clear-Host
    Write-Host @"
           .---.
          /     \
         | (00)  |  SYSTEM ENCRYPTED
          \  ^  /
           '---'
     ╔════════════════════════════════════════╗
     ║     AURORA-SHELL SECURITY TERMINAL     ║
     ╚════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    while ($true) {
        $in = Read-Host "[AUTH] Key" -AsSecureString
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($in))
        if ($plain -eq $target) { Clear-Host; break }
        Write-Host "DENIED" -ForegroundColor Red
    }
    $label = "Logged in as $global:AURORA_HDR_VAL"
    $w = 100; $inner = $w - 2; $pad = [math]::Floor(($inner - $label.Length) / 2)
    Write-Host ("╭" + "─"*$inner + "╮")
    Write-Host ("│" + " "*$inner + "│")
    Write-Host ("│" + " "*$pad + $label + " "*($inner - $pad - $label.Length) + "│")
    Write-Host ("│" + " "*$inner + "│")
    Write-Host ("╰" + "─"*$inner + "╯")
}

function Show-Aurora {
    . "$HOME\.aurora-shell_files\aurora-shell_settings.ps1"
    $cols = $Host.UI.RawUI.WindowSize.Width
    if ($global:AURORA_HDR_MODE -eq "BLOCK") {
        $content = @"
 █████╗ ██╗   ██╗██████╗  ██████╗ ██████╗  █████╗  
██╔══██╗██║   ██║██╔══██╗██╔═══██╗██╔══██╗██╔══██╗ 
███████║██║   ██║██████╔╝██║   ██║██████╔╝███████║ 
██╔══██║██║   ██║██╔══██╗██║   ██║██╔══██╗██╔══██║ 
██║  ██║╚██████╔╝██║  ██║╚██████╔╝██║  ██║██║  ██║ 
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ 
      ███████╗██╗  ██╗███████╗██╗     ██╗           
      ██╔════╝██║  ██║██╔════╝██║     ██║           
      ███████╗███████║█████╗  ██║     ██║           
      ╚════██║██╔══██║██╔══╝  ██║     ██║           
      ███████║██║  ██║███████╗███████╗███████╗      
      ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝      
"@
    } else {
        $content = & figlet -f slant $global:AURORA_HDR_VAL 2>$null
    }
    $maxW = ($content -split "`n" | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $pad  = [math]::Max(0, [math]::Floor(($cols - $maxW) / 2))
    $content -split "`n" | ForEach-Object { Write-Host (" " * $pad + $_) -ForegroundColor Cyan }

    # telemetry
    $cpu  = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    $disk = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
    $batt = (Get-CimInstance Win32_Battery | Select-Object -First 1).EstimatedChargeRemaining
    $battStr = if ($batt) { "${batt}%" } else { "N/A" }
    $stats = "⚡ AURORA v$global:AURORA_VER | 🧠 CPU: ${cpu}% | 💾 FREE: ${disk}GB | 🔋 $battStr | 📅 $(Get-Date -Format 'MM/dd/yy')"
    $sPad  = [math]::Max(0, [math]::Floor(($cols - $stats.Length) / 2))
    Write-Host (" " * $sPad + $stats) -ForegroundColor Blue

    Write-Host ("-" * $cols) -ForegroundColor Cyan
}

# ── package manager ───────────────────────────────────────────────────────────
$PACKAGES_FILE = "$HOME\.aurora-shell_files\packages.json"
$INSTALLED_DIR = "$HOME\.aurora-shell_files\bin"
New-Item -ItemType Directory -Path $INSTALLED_DIR -Force | Out-Null
$env:PATH = "$INSTALLED_DIR;$env:PATH"

if (-not (Test-Path $PACKAGES_FILE)) {
    @'
{"packages":{"Aurora.App":{"aliases":["aurora-app"],"url":"https://github.com/Seaus-tech/Aurora-Shell/releases/latest/download/aurora-shell.mac.dmg","type":"dmg","description":"Aurora Shell Terminal App"},"Aurora.CLI":{"aliases":["CLI"],"url":"install-cli","type":"cli-installer","description":"Aurora-Shell CLI"}}}
'@ | Set-Content $PACKAGES_FILE
}

function shell {
    param([string]$cmd, [string]$pkg, [string]$url, [string]$type, [string]$desc)
    switch ($cmd) {
        'install' {
            $data = Get-Content $PACKAGES_FILE | ConvertFrom-Json
            $resolved = $data.packages.PSObject.Properties | Where-Object { $_.Value.aliases -contains $pkg } | Select-Object -First 1 -ExpandProperty Name
            if ($resolved) { $pkg = $resolved }
            $entry = $data.packages.$pkg
            if (-not $entry) {
                Write-Host "Not in Aurora registry. Try: winget install $pkg" -ForegroundColor Yellow; return
            }
            Write-Host "Installing $pkg..." -ForegroundColor Cyan
            switch ($entry.type) {
                'binary' { Invoke-WebRequest $entry.url -OutFile "$INSTALLED_DIR\$pkg.exe"; Write-Host "✅ Installed" -ForegroundColor Green }
                'cli-installer' { Write-Host "Use: CLI install <package>" -ForegroundColor Yellow }
                default { Write-Host "Type '$($entry.type)' not supported on Windows" -ForegroundColor Red }
            }
        }
        'list'      { Write-Host "Installed:"; Get-ChildItem $INSTALLED_DIR -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name }
        'search'    { $d = Get-Content $PACKAGES_FILE | ConvertFrom-Json; $d.packages.PSObject.Properties | ForEach-Object { "$($_.Name) — $($_.Value.description)" } }
        'uninstall' { Remove-Item "$INSTALLED_DIR\$pkg*" -Force -ErrorAction SilentlyContinue; Write-Host "✅ Uninstalled $pkg" -ForegroundColor Green }
        default     { Write-Host "Usage: shell install|list|search|uninstall" }
    }
}

# ── accounts ──────────────────────────────────────────────────────────────────
$AURORA_WORKER_URL   = "https://aurora-accounts.yash-behera.workers.dev"
$AURORA_ACCOUNT_FILE = "$HOME\.aurora-shell_files\active_account.json"

function _aurora_hash([string]$s) {
    (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($s))) -Algorithm SHA256).Hash.ToLower()
}
function _read_pw([string]$p) {
    $ss = Read-Host $p -AsSecureString
    [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
}

function _aurora_take_snapshot {
    $snap = "$HOME\.aurora-shell_files\session_snapshot"
    Remove-Item $snap -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $snap -Force | Out-Null
    if (Test-Path $PROFILE) { Copy-Item $PROFILE "$snap\profile.bak" }
    winget list 2>$null | Out-File "$snap\winget.txt"
    npm list -g --depth=0 2>$null | Out-File "$snap\npm-global.txt"
}

function _aurora_apply_profile($profile, [string]$fast="") {
    _aurora_take_snapshot
    $uid     = $profile.username
    $hdr     = if ($profile.header)      { $profile.header }      else { "Aurora-Shell" }
    $hdrMode = if ($profile.header_mode) { $profile.header_mode } else { "BLOCK" }
    (Get-Content $global:CONFIG_FILE) -replace '"[^"]*"$', "`"$uid`"" | Set-Content $global:CONFIG_FILE -ErrorAction SilentlyContinue
    if ($fast -ne '--fast') {
        $profile.plugins | ForEach-Object { Write-Host "Plugin: $_" }
    }
    if ($profile.linked.openai_key)    { $env:OPENAI_API_KEY    = $profile.linked.openai_key }
    if ($profile.linked.anthropic_key) { $env:ANTHROPIC_API_KEY = $profile.linked.anthropic_key }
    if ($profile.linked.gh_token)      { $env:GITHUB_TOKEN      = $profile.linked.gh_token }
    if ($profile.linked.aws_key)       { $env:AWS_ACCESS_KEY_ID = $profile.linked.aws_key; $env:AWS_SECRET_ACCESS_KEY = $profile.linked.aws_secret }
    if ($profile.linked.ollama_host)   { $env:OLLAMA_HOST       = $profile.linked.ollama_host }
    $profile | ConvertTo-Json -Compress | Set-Content $AURORA_ACCOUNT_FILE
    Write-Host "✅ Logged in as $uid$(if($fast){'  (fast mode)'})" -ForegroundColor Green
}

function _aurora_logout_cleanup([string]$fast="") {
    $snap = "$HOME\.aurora-shell_files\session_snapshot"
    if (-not (Test-Path $snap)) { return }
    Write-Host "Restoring system state..." -ForegroundColor Yellow
    if ($fast -ne '--fast') {
        if (Test-Path "$snap\profile.bak") { Copy-Item "$snap\profile.bak" $PROFILE -Force }
    }
    Remove-Item $snap,$AURORA_ACCOUNT_FILE -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:OPENAI_API_KEY,Env:ANTHROPIC_API_KEY,Env:GITHUB_TOKEN,Env:AWS_ACCESS_KEY_ID,Env:AWS_SECRET_ACCESS_KEY,Env:OLLAMA_HOST -ErrorAction SilentlyContinue
    Write-Host "Logged out. System restored." -ForegroundColor Green
}

function aurora_account([string]$opt, [string]$flag="") {
    switch ($opt) {
        '--create' {
            $uname = Read-Host "Username"
            $pw1   = _read_pw "Password"; $pw2 = _read_pw "Confirm"
            if ($pw1 -ne $pw2) { Write-Host "Passwords don't match" -ForegroundColor Red; return }
            $payload = @{username=$uname;password_hash=(_aurora_hash $pw1);installed="";plugins=@();linked=@{};header="Aurora-Shell";header_mode="BLOCK"} | ConvertTo-Json -Compress
            try { Invoke-RestMethod -Method Post -Uri "$AURORA_WORKER_URL/accounts" -ContentType "application/json" -Body $payload | Out-Null
                  Write-Host "Account created!" -ForegroundColor Green }
            catch { Write-Host "❌ $_" -ForegroundColor Red }
        }
        '--login' {
            $uname = Read-Host "Username"; $hash = _aurora_hash (_read_pw "Password")
            try {
                $resp = Invoke-RestMethod -Method Post -Uri "$AURORA_WORKER_URL/accounts/login" `
                    -ContentType "application/json" -Body "{`"username`":`"$uname`",`"password_hash`":`"$hash`"}"
                $resp | Add-Member -NotePropertyName password_hash -NotePropertyValue $hash -Force
                _aurora_apply_profile $resp $flag
            } catch { Write-Host "❌ $_" -ForegroundColor Red }
        }
        '--logout' { _aurora_logout_cleanup $flag }
        '--whoami' {
            if (-not (Test-Path $AURORA_ACCOUNT_FILE)) { Write-Host "Not logged in"; return }
            $p = Get-Content $AURORA_ACCOUNT_FILE | ConvertFrom-Json
            Write-Host "👤 $($p.username) | plugins: $($p.plugins -join ', ') | linked: $($p.linked.PSObject.Properties.Name -join ', ')"
        }
        '--link' {
            if (-not (Test-Path $AURORA_ACCOUNT_FILE)) { Write-Host "❌ Not logged in" -ForegroundColor Red; return }
            $p = Get-Content $AURORA_ACCOUNT_FILE | ConvertFrom-Json
            $uname = $p.username; $hash = _aurora_hash (_read_pw "Password")
            Write-Host "Link: 1) AWS  2) GitHub  3) OpenAI  4) Anthropic  5) Ollama"
            $linked = switch (Read-Host "Choice") {
                '1' { @{aws_key=(Read-Host "AWS Key ID");aws_secret=(_read_pw "AWS Secret")} }
                '2' { @{gh_token=(_read_pw "GitHub Token")} }
                '3' { @{openai_key=(_read_pw "OpenAI API Key")} }
                '4' { @{anthropic_key=(_read_pw "Anthropic API Key")} }
                '5' { $h=Read-Host "Ollama Host (default localhost:11434)"; @{ollama_host=if($h){$h}else{"localhost:11434"}} }
                default { Write-Host "Invalid" -ForegroundColor Red; return }
            }
            $body = (@{password_hash=$hash;linked=$linked} | ConvertTo-Json -Compress)
            try { Invoke-RestMethod -Method Patch -Uri "$AURORA_WORKER_URL/accounts/$uname" -ContentType "application/json" -Body $body | Out-Null
                  Write-Host "✅ Service linked" -ForegroundColor Green }
            catch { Write-Host "❌ $_" -ForegroundColor Red }
        }
        '--users' {
            if (-not (Test-Path $AURORA_ACCOUNT_FILE)) { Write-Host "❌ Not logged in" -ForegroundColor Red; return }
            $p = Get-Content $AURORA_ACCOUNT_FILE | ConvertFrom-Json
            $hash = $p.password_hash
            try { (Invoke-RestMethod -Uri "$AURORA_WORKER_URL/accounts" -Headers @{"X-Username"=$p.username;"X-Password-Hash"=$hash}) |
                  ForEach-Object { "👤 $($_.username)$(if($_.is_owner){' 👑'}) | plugins: $($_.plugins -join ', ')" } }
            catch { Write-Host "❌ $_ (owner only)" -ForegroundColor Red }
        }
        default {
            @"
Usage: aurora_account <option>
  --create   Create a new Aurora account
  --login    Sign in  (--login --fast to skip installations)
  --logout   Sign out (--logout --fast to skip uninstalls)
  --link     Link a service
  --whoami   Show current account
  --users    List all accounts (owner only)
"@
        }
    }
}

function shell.aurora([string]$flag, [string]$arg2="") {
    switch ($flag) {
        '--display' { Show-Aurora }
        '--sys'     { Get-ComputerInfo | Select-Object CsName,OsName,CsProcessors; (Get-CimInstance Win32_Processor).Name }
        '--update'  { $b = if($arg2){$arg2}else{"main"}; irm "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/$b/install.ps1" | iex }
        '--config'  { notepad $global:CONFIG_FILE }
        '--lock'    { Invoke-Auth; Show-Aurora }
        '--uninstall' {
            Remove-Item "$HOME\.aurora-shell_files" -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $PROFILE) { (Get-Content $PROFILE) | Where-Object { $_ -notmatch 'aurora-shell_files' } | Set-Content $PROFILE }
        }
        '--account' { aurora_account $arg2 }
        default     { Write-Host "Flags: --display --sys --update [branch] --config --lock --uninstall --account" }
    }
}

# ── version check ─────────────────────────────────────────────────────────────
$REMOTE_VER = try { (irm "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/install.sh") -match 'VER="([^"]+)"' | Out-Null; $Matches[1] } catch { $null }
if ($REMOTE_VER -and $REMOTE_VER -ne $global:AURORA_VER) {
    $upd = Read-Host "🔔 Aurora-Shell wants to update (v$global:AURORA_VER → v$REMOTE_VER) [y/N]"
    if ($upd -in 'y','Y') { shell.aurora --update dev }
}

Invoke-Auth
Show-Aurora
'@

    $themeContent | Set-Content $THEME_FILE
}


# ── execute ───────────────────────────────────────────────────────────────────
Sync-Env
Install-DevTools
Run-Wizard
Generate-Theme

# Wire theme into PowerShell profile
if (Test-Path $PROFILE) {
    (Get-Content $PROFILE) | Where-Object { $_ -notmatch 'aurora-shell_theme' } | Set-Content $PROFILE
}
Add-Content $PROFILE ". `"$THEME_FILE`""

# Clone / update repo
Write-Host "`n🌀 Checking Aurora-shell..." -ForegroundColor Cyan
$FOUND_REPO = Get-ChildItem $HOME -Recurse -Depth 10 -Directory -Filter "Aurora-Shell" -ErrorAction SilentlyContinue |
    Where-Object { (git -C $_.FullName remote get-url origin 2>$null) -eq $GIT_CLONE } |
    Select-Object -First 1 -ExpandProperty FullName

if ($FOUND_REPO) {
    Write-Host "Found existing repo at: $FOUND_REPO" -ForegroundColor Green
    git -C $FOUND_REPO pull
    Copy-Item "$FOUND_REPO\brew-progress.py" $DATA_DIR -ErrorAction SilentlyContinue
    Copy-Item "$FOUND_REPO\spinner.js"       $DATA_DIR -ErrorAction SilentlyContinue
} else {
    Write-Host "Cloning fresh copy..." -ForegroundColor Yellow
    git clone $GIT_CLONE "$DATA_DIR\aurora-shell"
    Copy-Item "$DATA_DIR\aurora-shell\brew-progress.py" $DATA_DIR -ErrorAction SilentlyContinue
    Copy-Item "$DATA_DIR\aurora-shell\spinner.js"       $DATA_DIR -ErrorAction SilentlyContinue
}

Write-Host "`n✅ v$VER Deployed." -ForegroundColor Green
Write-Host "welcome to Aurora-Shell" -ForegroundColor Cyan
