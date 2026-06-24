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
    $lines = [System.Collections.Generic.List[string]]::new()
    $a = { param($s) $lines.Add($s) }
    & $a '# Generated by Aurora-Shell Installer'
    & $a '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8'
    & $a '. "$HOME\.aurora-shell_files\aurora-shell_settings.ps1"'
    & $a ''
    & $a 'function Get-StoredPin {'
    & $a '    $enc = "$HOME\.aurora-shell_files\aurora-pin.enc"'
    & $a '    if (Test-Path $enc) { (Get-Content $enc | ConvertTo-SecureString) |'
    & $a '        ForEach-Object { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) } }'
    & $a '}'
    & $a ''
    & $a 'function Invoke-Auth {'
    & $a '    $target = Get-StoredPin'
    & $a '    if (-not $target) { return }'
    & $a '    Clear-Host'
    & $a '    Write-Host "           .---." -ForegroundColor Cyan'
    & $a '    Write-Host "          /     \"  -ForegroundColor Cyan'
    & $a '    Write-Host "         | (00)  |  SYSTEM ENCRYPTED" -ForegroundColor Cyan'
    & $a '    Write-Host "          \  ^  /" -ForegroundColor Cyan'
    & $a '    Write-Host "           (---)" -ForegroundColor Cyan'
    & $a '    Write-Host "     ╔════════════════════════════════════════╗" -ForegroundColor Cyan'
    & $a '    Write-Host "     ║     AURORA-SHELL SECURITY TERMINAL     ║" -ForegroundColor Cyan'
    & $a '    Write-Host "     ╚════════════════════════════════════════╝" -ForegroundColor Cyan'
    & $a '    while ($true) {'
    & $a '        $in = Read-Host "[AUTH] Key" -AsSecureString'
    & $a '        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($in))'
    & $a '        if ($plain -eq $target) { Clear-Host; break }'
    & $a '        Write-Host "DENIED" -ForegroundColor Red'
    & $a '    }'
    & $a '    $label = "Logged in as $global:AURORA_HDR_VAL"'
    & $a '    $w = 100; $inner = $w - 2; $pad = [math]::Floor(($inner - $label.Length) / 2)'
    & $a '    Write-Host ("╭" + "─"*$inner + "╮")'
    & $a '    Write-Host ("│" + " "*$inner + "│")'
    & $a '    Write-Host ("│" + " "*$pad + $label + " "*($inner - $pad - $label.Length) + "│")'
    & $a '    Write-Host ("│" + " "*$inner + "│")'
    & $a '    Write-Host ("╰" + "─"*$inner + "╯")'
    & $a '}'
    & $a ''
    & $a 'function Show-Aurora {'
    & $a '    . "$HOME\.aurora-shell_files\aurora-shell_settings.ps1"'
    & $a '    $cols = $Host.UI.RawUI.WindowSize.Width'
    & $a '    if ($global:AURORA_HDR_MODE -eq "BLOCK") {'
    & $a '        $content = " █████╗ ██╗   ██╗██████╗  ██████╗ ██████╗  █████╗`n██╔══██╗██║   ██║██╔══██╗██╔═══██╗██╔══██╗██╔══██╗`n███████║██║   ██║██████╔╝██║   ██║██████╔╝███████║`n██╔══██║██║   ██║██╔══██╗██║   ██║██╔══██╗██╔══██║`n██║  ██║╚██████╔╝██║  ██║╚██████╔╝██║  ██║██║  ██║`n╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝`n      ███████╗██╗  ██╗███████╗██╗     ██╗`n      ██╔════╝██║  ██║██╔════╝██║     ██║`n      ███████╗███████║█████╗  ██║     ██║`n      ╚════██║██╔══██║██╔══╝  ██║     ██║`n      ███████║██║  ██║███████╗███████╗███████╗`n      ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝"'
    & $a '    } else {'
    & $a '        $content = & figlet -f slant $global:AURORA_HDR_VAL 2>$null'
    & $a '    }'
    & $a '    $maxW = ($content -split "`n" | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum'
    & $a '    $pad  = [math]::Max(0, [math]::Floor(($cols - $maxW) / 2))'
    & $a '    $content -split "`n" | ForEach-Object { Write-Host (" " * $pad + $_) -ForegroundColor Cyan }'
    & $a '    $cpu  = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average'
    & $a '    $disk = [math]::Round((Get-PSDrive C).Free / 1GB, 1)'
    & $a '    $batt = (Get-CimInstance Win32_Battery | Select-Object -First 1).EstimatedChargeRemaining'
    & $a '    $battStr = if ($batt) { "${batt}%" } else { "N/A" }'
    & $a '    $stats = "⚡ AURORA v$global:AURORA_VER | 🧠 CPU: ${cpu}% | 💾 FREE: ${disk}GB | 🔋 $battStr | 📅 $(Get-Date -Format MM/dd/yy)"'
    & $a '    $sPad = [math]::Max(0, [math]::Floor(($cols - $stats.Length) / 2))'
    & $a '    Write-Host (" " * $sPad + $stats) -ForegroundColor Blue'
    & $a '    Write-Host ("-" * $cols) -ForegroundColor Cyan'
    & $a '}'
    & $a ''
    & $a '$PACKAGES_FILE = "$HOME\.aurora-shell_files\packages.json"'
    & $a '$INSTALLED_DIR = "$HOME\.aurora-shell_files\bin"'
    & $a 'New-Item -ItemType Directory -Path $INSTALLED_DIR -Force | Out-Null'
    & $a '$env:PATH = "$INSTALLED_DIR;$env:PATH"'
    & $a 'if (-not (Test-Path $PACKAGES_FILE)) {'
    & $a '    "{`"packages`":{`"Aurora.App`":{`"aliases`":[`"aurora-app`"],`"url`":`"https://github.com/Seaus-tech/Aurora-Shell/releases/latest/download/aurora-shell.mac.dmg`",`"type`":`"dmg`",`"description`":`"Aurora Shell Terminal App`"},`"Aurora.CLI`":{`"aliases`":[`"CLI`"],`"url`":`"install-cli`",`"type`":`"cli-installer`",`"description`":`"Aurora-Shell CLI`"}}}" | Set-Content $PACKAGES_FILE'
    & $a '}'
    & $a ''
    & $a 'function shell {'
    & $a '    param([string]$cmd, [string]$pkg)'
    & $a '    switch ($cmd) {'
    & $a '        "install" {'
    & $a '            $data = Get-Content $PACKAGES_FILE | ConvertFrom-Json'
    & $a '            $resolved = $data.packages.PSObject.Properties | Where-Object { $_.Value.aliases -contains $pkg } | Select-Object -First 1 -ExpandProperty Name'
    & $a '            if ($resolved) { $pkg = $resolved }'
    & $a '            $entry = $data.packages.$pkg'
    & $a '            if (-not $entry) { Write-Host "Not in Aurora registry. Try: winget install $pkg" -ForegroundColor Yellow; return }'
    & $a '            Write-Host "Installing $pkg..." -ForegroundColor Cyan'
    & $a '            switch ($entry.type) {'
    & $a '                "binary" { Invoke-WebRequest $entry.url -OutFile "$INSTALLED_DIR\$pkg.exe"; Write-Host "Installed" -ForegroundColor Green }'
    & $a '                "cli-installer" { Write-Host "Use: CLI install <package>" -ForegroundColor Yellow }'
    & $a '                default { Write-Host "Type not supported on Windows" -ForegroundColor Red }'
    & $a '            }'
    & $a '        }'
    & $a '        "list"      { Get-ChildItem $INSTALLED_DIR -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name }'
    & $a '        "search"    { $d = Get-Content $PACKAGES_FILE | ConvertFrom-Json; $d.packages.PSObject.Properties | ForEach-Object { "$($_.Name) - $($_.Value.description)" } }'
    & $a '        "uninstall" { Remove-Item "$INSTALLED_DIR\$pkg*" -Force -ErrorAction SilentlyContinue; Write-Host "Uninstalled $pkg" -ForegroundColor Green }'
    & $a '        default     { Write-Host "Usage: shell install|list|search|uninstall" }'
    & $a '    }'
    & $a '}'
    & $a ''
    & $a '$AURORA_WORKER_URL   = "https://aurora-accounts.yash-behera.workers.dev"'
    & $a '$AURORA_ACCOUNT_FILE = "$HOME\.aurora-shell_files\active_account.json"'
    & $a ''
    & $a 'function _aurora_hash([string]$s) { (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($s))) -Algorithm SHA256).Hash.ToLower() }'
    & $a 'function _read_pw([string]$p) { $ss = Read-Host $p -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)) }'
    & $a ''
    & $a 'function _aurora_take_snapshot {'
    & $a '    $snap = "$HOME\.aurora-shell_files\session_snapshot"'
    & $a '    Remove-Item $snap -Recurse -Force -ErrorAction SilentlyContinue'
    & $a '    New-Item -ItemType Directory -Path $snap -Force | Out-Null'
    & $a '    if (Test-Path $PROFILE) { Copy-Item $PROFILE "$snap\profile.bak" }'
    & $a '    winget list 2>$null | Out-File "$snap\winget.txt"'
    & $a '    npm list -g --depth=0 2>$null | Out-File "$snap\npm-global.txt"'
    & $a '}'
    & $a ''
    & $a 'function _aurora_apply_profile($profile, [string]$fast="") {'
    & $a '    _aurora_take_snapshot'
    & $a '    $uid = $profile.username'
    & $a '    if ($profile.linked.openai_key)    { $env:OPENAI_API_KEY    = $profile.linked.openai_key }'
    & $a '    if ($profile.linked.anthropic_key) { $env:ANTHROPIC_API_KEY = $profile.linked.anthropic_key }'
    & $a '    if ($profile.linked.gh_token)      { $env:GITHUB_TOKEN      = $profile.linked.gh_token }'
    & $a '    if ($profile.linked.aws_key)       { $env:AWS_ACCESS_KEY_ID = $profile.linked.aws_key; $env:AWS_SECRET_ACCESS_KEY = $profile.linked.aws_secret }'
    & $a '    if ($profile.linked.ollama_host)   { $env:OLLAMA_HOST       = $profile.linked.ollama_host }'
    & $a '    $profile | ConvertTo-Json -Compress | Set-Content $AURORA_ACCOUNT_FILE'
    & $a '    Write-Host "Logged in as $uid$(if($fast){" (fast mode)"})" -ForegroundColor Green'
    & $a '}'
    & $a ''
    & $a 'function _aurora_logout_cleanup([string]$fast="") {'
    & $a '    $snap = "$HOME\.aurora-shell_files\session_snapshot"'
    & $a '    if (-not (Test-Path $snap)) { return }'
    & $a '    if ($fast -ne "--fast" -and (Test-Path "$snap\profile.bak")) { Copy-Item "$snap\profile.bak" $PROFILE -Force }'
    & $a '    Remove-Item $snap,$AURORA_ACCOUNT_FILE -Recurse -Force -ErrorAction SilentlyContinue'
    & $a '    "OPENAI_API_KEY","ANTHROPIC_API_KEY","GITHUB_TOKEN","AWS_ACCESS_KEY_ID","AWS_SECRET_ACCESS_KEY","OLLAMA_HOST" | ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }'
    & $a '    Write-Host "Logged out. System restored." -ForegroundColor Green'
    & $a '}'
    & $a ''
    & $a 'function aurora_account([string]$opt, [string]$flag="") {'
    & $a '    switch ($opt) {'
    & $a '        "--create" {'
    & $a '            $uname = Read-Host "Username"; $pw1 = _read_pw "Password"; $pw2 = _read_pw "Confirm"'
    & $a '            if ($pw1 -ne $pw2) { Write-Host "Passwords do not match" -ForegroundColor Red; return }'
    & $a '            $payload = @{username=$uname;password_hash=(_aurora_hash $pw1);installed="";plugins=@();linked=@{};header="Aurora-Shell";header_mode="BLOCK"} | ConvertTo-Json -Compress'
    & $a '            try { Invoke-RestMethod -Method Post -Uri "$AURORA_WORKER_URL/accounts" -ContentType "application/json" -Body $payload | Out-Null; Write-Host "Account created!" -ForegroundColor Green }'
    & $a '            catch { Write-Host "Error: $_" -ForegroundColor Red }'
    & $a '        }'
    & $a '        "--login" {'
    & $a '            $uname = Read-Host "Username"; $hash = _aurora_hash (_read_pw "Password")'
    & $a '            try {'
    & $a '                $resp = Invoke-RestMethod -Method Post -Uri "$AURORA_WORKER_URL/accounts/login" -ContentType "application/json" -Body "{`"username`":`"$uname`",`"password_hash`":`"$hash`"}"'
    & $a '                $resp | Add-Member -NotePropertyName password_hash -NotePropertyValue $hash -Force'
    & $a '                _aurora_apply_profile $resp $flag'
    & $a '            } catch { Write-Host "Error: $_" -ForegroundColor Red }'
    & $a '        }'
    & $a '        "--logout" { _aurora_logout_cleanup $flag }'
    & $a '        "--whoami" {'
    & $a '            if (-not (Test-Path $AURORA_ACCOUNT_FILE)) { Write-Host "Not logged in"; return }'
    & $a '            $p = Get-Content $AURORA_ACCOUNT_FILE | ConvertFrom-Json'
    & $a '            Write-Host "User: $($p.username) | linked: $($p.linked.PSObject.Properties.Name -join ", ")"'
    & $a '        }'
    & $a '        "--link" {'
    & $a '            if (-not (Test-Path $AURORA_ACCOUNT_FILE)) { Write-Host "Not logged in" -ForegroundColor Red; return }'
    & $a '            $p = Get-Content $AURORA_ACCOUNT_FILE | ConvertFrom-Json'
    & $a '            $uname = $p.username; $hash = _aurora_hash (_read_pw "Password")'
    & $a '            Write-Host "Link: 1)AWS 2)GitHub 3)OpenAI 4)Anthropic 5)Ollama"'
    & $a '            $linked = switch (Read-Host "Choice") {'
    & $a '                "1" { @{aws_key=(Read-Host "AWS Key ID");aws_secret=(_read_pw "AWS Secret")} }'
    & $a '                "2" { @{gh_token=(_read_pw "GitHub Token")} }'
    & $a '                "3" { @{openai_key=(_read_pw "OpenAI Key")} }'
    & $a '                "4" { @{anthropic_key=(_read_pw "Anthropic Key")} }'
    & $a '                "5" { $h=Read-Host "Ollama Host"; @{ollama_host=if($h){$h}else{"localhost:11434"}} }'
    & $a '            }'
    & $a '            try { Invoke-RestMethod -Method Patch -Uri "$AURORA_WORKER_URL/accounts/$uname" -ContentType "application/json" -Body (@{password_hash=$hash;linked=$linked}|ConvertTo-Json -Compress) | Out-Null; Write-Host "Service linked" -ForegroundColor Green }'
    & $a '            catch { Write-Host "Error: $_" -ForegroundColor Red }'
    & $a '        }'
    & $a '        "--users" {'
    & $a '            if (-not (Test-Path $AURORA_ACCOUNT_FILE)) { Write-Host "Not logged in" -ForegroundColor Red; return }'
    & $a '            $p = Get-Content $AURORA_ACCOUNT_FILE | ConvertFrom-Json'
    & $a '            try { (Invoke-RestMethod -Uri "$AURORA_WORKER_URL/accounts" -Headers @{"X-Username"=$p.username;"X-Password-Hash"=$p.password_hash}) | ForEach-Object { "$($_.username)$(if($_.is_owner){" OWNER"})" } }'
    & $a '            catch { Write-Host "Error: $_ (owner only)" -ForegroundColor Red }'
    & $a '        }'
    & $a '        default { Write-Host "Usage: aurora_account --create|--login|--logout|--link|--whoami|--users" }'
    & $a '    }'
    & $a '}'
    & $a ''
    & $a 'function shell.aurora([string]$flag, [string]$arg2="") {'
    & $a '    switch ($flag) {'
    & $a '        "--display"   { Show-Aurora }'
    & $a '        "--sys"       { (Get-CimInstance Win32_Processor).Name; Get-ComputerInfo | Select-Object OsName }'
    & $a '        "--update"    { $b=if($arg2){$arg2}else{"main"}; $t=[IO.Path]::GetTempFileName()+".ps1"; irm "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/$b/install.ps1" -OutFile $t; & $t; Remove-Item $t }'
    & $a '        "--config"    { notepad "$HOME\.aurora-shell_files\aurora-shell_settings.ps1" }'
    & $a '        "--lock"      { Invoke-Auth; Show-Aurora }'
    & $a '        "--uninstall" { Remove-Item "$HOME\.aurora-shell_files" -Recurse -Force -ErrorAction SilentlyContinue; if(Test-Path $PROFILE){(Get-Content $PROFILE)|Where-Object{$_ -notmatch "aurora-shell_files"}|Set-Content $PROFILE} }'
    & $a '        "--account"   { aurora_account $arg2 }'
    & $a '        default       { Write-Host "Flags: --display --sys --update [branch] --config --lock --uninstall --account" }'
    & $a '    }'
    & $a '}'
    & $a ''
    & $a '$REMOTE_VER = try { $raw = irm "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/install.sh"; if($raw -match "VER=`"([^`"]+)`""){$Matches[1]}else{$null} } catch { $null }'
    & $a 'if ($REMOTE_VER -and $REMOTE_VER -ne $global:AURORA_VER) {'
    & $a '    $upd = Read-Host "Aurora-Shell update available ($global:AURORA_VER -> $REMOTE_VER) install? [y/N]"'
    & $a '    if ($upd -in "y","Y") { shell.aurora --update dev }'
    & $a '}'
    & $a ''
    & $a 'Invoke-Auth'
    & $a 'Show-Aurora'

    $lines | Set-Content $THEME_FILE -Encoding UTF8
}

# ── execute ───────────────────────────────────────────────────────────────────
Sync-Env
Install-DevTools
Run-Wizard
Generate-Theme

if (Test-Path $PROFILE) {
    (Get-Content $PROFILE) | Where-Object { $_ -notmatch 'aurora-shell_theme' } | Set-Content $PROFILE
}
Add-Content $PROFILE ". `"$THEME_FILE`""

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
