# Aurora-Shell v7.1.7 installer — PowerShell port
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$VER         = "7.1.7"
$DATA_DIR    = "$HOME\.aurora-shell_files"
$THEME_FILE  = "$DATA_DIR\aurora-shell_theme.ps1"
$CONFIG_FILE = "$DATA_DIR\aurora-shell_settings.ps1"
$GIT_CLONE   = "https://github.com/Seaus-tech/Aurora-Shell.git"
$REPO_BASE   = "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell"

Write-Host "Running as ${env:USERNAME}..." -ForegroundColor Yellow

# Clean old aurora entries from profile
if (Test-Path $PROFILE) {
    (Get-Content $PROFILE -ErrorAction SilentlyContinue) |
        Where-Object { $_ -notmatch 'aurora-shell_files' } |
        Set-Content $PROFILE
}
New-Item -ItemType Directory -Path $DATA_DIR -Force | Out-Null
Write-Host "--- Aurora-Shell v$VER ---" -ForegroundColor Cyan

# ── Credential helpers (Windows equivalent of macOS Keychain) ────────────────

function Set-AuroraCred([string]$svc, [string]$val) {
    $enc = $val | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString
    $d = "$DATA_DIR\.creds"; New-Item -ItemType Directory -Path $d -Force | Out-Null
    $enc | Set-Content "$d\$svc.enc" -Encoding UTF8
}

function Get-AuroraCred([string]$svc) {
    $f = "$DATA_DIR\.creds\$svc.enc"
    if (-not (Test-Path $f)) { return $null }
    try {
        $ss = Get-Content $f | ConvertTo-SecureString
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
    } catch { return $null }
}

function Remove-AuroraCred([string]$svc) {
    $f = "$DATA_DIR\.creds\$svc.enc"
    if (Test-Path $f) { Remove-Item $f -Force }
}

function Test-AuroraCred([string]$svc) {
    return (Test-Path "$DATA_DIR\.creds\$svc.enc")
}

# ── General helpers ───────────────────────────────────────────────────────────

function Get-SHA256([string]$s) {
    (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($s))) -Algorithm SHA256).Hash.ToLower()
}

function Read-PlainPassword([string]$prompt) {
    $ss = Read-Host $prompt -AsSecureString
    [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
}

function Write-Lolcat([string]$text) {
    if (Get-Command lolcat -ErrorAction SilentlyContinue) { $text | lolcat }
    else { Write-Host $text -ForegroundColor Cyan }
}

# ── Sync environment ──────────────────────────────────────────────────────────

function Sync-Env {
    Write-Host "Syncing Environment..." -ForegroundColor Yellow -NoNewline
    if (-not (Get-Command figlet -ErrorAction SilentlyContinue)) {
        if (Get-Command npm -ErrorAction SilentlyContinue) { npm install -g figlet-cli --silent 2>$null }
        else { Write-Host "`n  figlet skipped (npm not found)" -ForegroundColor DarkGray }
    }
    if (-not (Get-Command lolcat -ErrorAction SilentlyContinue)) {
        if (Get-Command gem -ErrorAction SilentlyContinue) { gem install lolcat 2>$null }
        elseif (Get-Command npm -ErrorAction SilentlyContinue) { npm install -g lolcat --silent 2>$null }
        else { Write-Host "`n  lolcat skipped (gem/npm not found)" -ForegroundColor DarkGray }
    }
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) { winget install --id jqlang.jq -e --silent 2>$null }
        else { Write-Host "`n  jq skipped (winget not found)" -ForegroundColor DarkGray }
    }
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) { winget install --id junegunn.fzf -e --silent 2>$null }
    }
    Write-Host " DONE" -ForegroundColor Green
}

# ── Dev tools ─────────────────────────────────────────────────────────────────

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
        $ans = Read-Host "Install $($t.Name)? (y/n)"
        if ($ans -eq 'y') {
            if ($t.Name -eq 'Git' -and (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Host "✔ Git already installed: $(git --version)" -ForegroundColor Green
            } else {
                winget install --id $t.Id -e --silent
            }
        }
    }
}

# ── Config wizard ─────────────────────────────────────────────────────────────

function Run-Wizard {
    Write-Host "`n--- AURORA CONFIGURATION WIZARD ---" -ForegroundColor Green
    if (Test-Path $CONFIG_FILE) { . $CONFIG_FILE }

    # Update mode — auto-restore from backup, no prompts
    if ($env:AURORA_UPDATE_MODE -eq "1" -and
        (Test-Path "$env:TEMP\aurora-shell-preferences\aurora-shell_settings.ps1")) {
        . "$env:TEMP\aurora-shell-preferences\aurora-shell_settings.ps1"
        $HDR_MODE    = if ($global:AURORA_HDR_MODE)    { $global:AURORA_HDR_MODE }    else { "BLOCK" }
        $HDR_VAL     = if ($global:AURORA_HDR_VAL)     { $global:AURORA_HDR_VAL }     else { "Aurora-Shell" }
        $FIGLET_FONT = if ($global:AURORA_FIGLET_FONT) { $global:AURORA_FIGLET_FONT } else { "slant" }
        $BDAY        = $global:AURORA_USER_BDAY
        $P_ID        = $global:AURORA_ID
        Write-Lolcat "Auto-restoring wizard settings from backup..."
        @"
`$global:AURORA_VER="$VER"
`$global:AURORA_HDR_MODE="$HDR_MODE"
`$global:AURORA_HDR_VAL="$HDR_VAL"
`$global:AURORA_FIGLET_FONT="$FIGLET_FONT"
`$global:AURORA_USER_BDAY="$BDAY"
`$global:AURORA_ID="$P_ID"
"@ | Set-Content $CONFIG_FILE -Encoding UTF8
        $acctSrc = "$env:TEMP\aurora-shell-preferences\active_account.json"
        if (Test-Path $acctSrc) {
            Copy-Item $acctSrc "$DATA_DIR\active_account.json" -Force
            try {
                $uid = (Get-Content "$DATA_DIR\active_account.json" | ConvertFrom-Json).username
                if ($uid) {
                    (Get-Content $CONFIG_FILE) -replace '(?m)^\$global:AURORA_ID=.*', "`$global:AURORA_ID=`"$uid`"" |
                        Set-Content $CONFIG_FILE -Encoding UTF8
                    Write-Lolcat "  Account restored: $uid"
                }
            } catch {}
        }
        return
    }

    # PIN
    $plain = Read-PlainPassword "Set Terminal PIN (Enter for none)"
    if ($env:AURORA_UPDATE_MODE -eq "1") {
        Write-Host "PIN kept from previous install." -ForegroundColor Green
    } elseif ($plain) {
        Set-AuroraCred "aurora-shell-pin" $plain
        Write-Host "PIN stored securely." -ForegroundColor Green
    }

    # Security methods
    Write-Host ""
    Write-Host "Security method(s) — PIN is always kept. Add extras:" -ForegroundColor Cyan
    Write-Host "   1) Windows Hello / Fingerprint"
    Write-Host "   2) YubiKey"
    Write-Host "   3) Security Key File (USB)"
    Write-Host "   4) All of the above"
    Write-Host "   5) PIN only (default)"
    $secChoice = Read-Host "   Selection (e.g. 1 2 or 4)"

    if ($secChoice -match "1" -or $secChoice -match "4") {
        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
            Set-AuroraCred "aurora-shell-windowshello" "enabled"
            Write-Host "   ✅ Windows Hello enabled" -ForegroundColor Green
        } catch {
            Write-Host "   ⚠️  Windows Hello not available on this machine" -ForegroundColor Yellow
        }
    }

    if ($secChoice -match "2" -or $secChoice -match "4") {
        if (Get-Command ykman -ErrorAction SilentlyContinue) {
            $ykSerial = (ykman list 2>$null) -replace '\D','' | Select-Object -First 1
            if ($ykSerial) {
                Set-AuroraCred "aurora-shell-yubikey" $ykSerial
                Write-Host "   ✅ YubiKey registered (serial: $ykSerial)" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  No YubiKey detected — insert it and re-run: shell.aurora --security --add-yubikey" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ⚠️  ykman not found — install: winget install Yubico.YubiKeyManager" -ForegroundColor Yellow
            Write-Host "       Then run: shell.aurora --security --add-yubikey" -ForegroundColor Yellow
        }
    }

    if ($secChoice -match "3" -or $secChoice -match "4") {
        $kfPath = Read-Host "   Path to key file (e.g. E:\aurora.key)"
        if (Test-Path $kfPath) {
            $kfHash = (Get-FileHash $kfPath -Algorithm SHA256).Hash.ToLower()
            Set-AuroraCred "aurora-shell-keyfile-path" $kfPath
            Set-AuroraCred "aurora-shell-keyfile-hash" $kfHash
            Write-Host "   ✅ Key file registered" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  File not found — run: shell.aurora --security --add-keyfile" -ForegroundColor Yellow
        }
    }

    # Header style — all 6 fonts matching install.sh
    Write-Host ""
    Write-Host "Header style:" -ForegroundColor Cyan
    Write-Host "   1) Mega-Block  2) Slant  3) Doom  4) Banner  5) Big  6) Digital  7) Custom text"
    $choice = Read-Host "Selection"
    switch ($choice) {
        "2" { $HDR_MODE = "CUSTOM"; $HDR_VAL = Read-Host "Header Name"; $FIGLET_FONT = "slant"   }
        "3" { $HDR_MODE = "CUSTOM"; $HDR_VAL = Read-Host "Header Name"; $FIGLET_FONT = "doom"    }
        "4" { $HDR_MODE = "CUSTOM"; $HDR_VAL = Read-Host "Header Name"; $FIGLET_FONT = "banner"  }
        "5" { $HDR_MODE = "CUSTOM"; $HDR_VAL = Read-Host "Header Name"; $FIGLET_FONT = "big"     }
        "6" { $HDR_MODE = "CUSTOM"; $HDR_VAL = Read-Host "Header Name"; $FIGLET_FONT = "digital" }
        "7" { $HDR_MODE = "CUSTOM"; $HDR_VAL = Read-Host "Header Name"; $FIGLET_FONT = "slant"   }
        default { $HDR_MODE = "BLOCK"; $HDR_VAL = "Aurora-Shell"; $FIGLET_FONT = "" }
    }

    $BDAY = Read-Host "Birthday (MMDD)"
    $P_ID = Read-Host "Prompt ID"

    @"
`$global:AURORA_VER="$VER"
`$global:AURORA_HDR_MODE="$HDR_MODE"
`$global:AURORA_HDR_VAL="$HDR_VAL"
`$global:AURORA_FIGLET_FONT="$(if ($FIGLET_FONT) { $FIGLET_FONT } else { 'slant' })"
`$global:AURORA_USER_BDAY="$BDAY"
`$global:AURORA_ID="$P_ID"
"@ | Set-Content $CONFIG_FILE -Encoding UTF8

    # Account sign-in
    Write-Host ""
    Write-Host "Aurora Account (optional — syncs your profile across machines)" -ForegroundColor Cyan
    $acctChoice = Read-Host "Sign in? (y/n/create)"
    switch ($acctChoice) {
        { $_ -in 'y','yes' } {
            $uname = Read-Host "Username"
            $hash  = Get-SHA256 (Read-PlainPassword "Password")
            try {
                $resp = Invoke-RestMethod -Method Post `
                    -Uri "https://aurora-accounts.yash-behera.workers.dev/accounts/login" `
                    -ContentType "application/json" `
                    -Body "{`"username`":`"$uname`",`"password_hash`":`"$hash`"}"
                $resp | ConvertTo-Json -Compress | Set-Content "$DATA_DIR\active_account.json" -Encoding UTF8
                (Get-Content $CONFIG_FILE) -replace '(?m)^\$global:AURORA_ID=.*', "`$global:AURORA_ID=`"$($resp.username)`"" |
                    Set-Content $CONFIG_FILE -Encoding UTF8
                Write-Host "   ✅ Signed in as $($resp.username)" -ForegroundColor Green
            } catch { Write-Host "   ❌ Sign-in failed: $_" -ForegroundColor Red }
        }
        'create' {
            $uname = Read-Host "New username"
            $pw1   = Read-PlainPassword "Password"
            $pw2   = Read-PlainPassword "Confirm"
            if ($pw1 -ne $pw2) { Write-Host "   ❌ Passwords don't match — skipping" -ForegroundColor Red; return }
            $payload = @{
                username=$uname; password_hash=(Get-SHA256 $pw1)
                installed=""; plugins=@(); linked=@{}
                header="Aurora-Shell"; header_mode="BLOCK"
            } | ConvertTo-Json -Compress
            try {
                Invoke-RestMethod -Method Post `
                    -Uri "https://aurora-accounts.yash-behera.workers.dev/accounts" `
                    -ContentType "application/json" -Body $payload | Out-Null
                Write-Host "   ✅ Account created! Login with: shell.aurora --account --login" -ForegroundColor Green
            } catch { Write-Host "   ❌ Create failed: $_" -ForegroundColor Red }
        }
    }
}

# ── Theme generator ───────────────────────────────────────────────────────────

function Generate-Theme {
    $sb = [System.Text.StringBuilder]::new()
    $a  = { param($s) [void]$sb.AppendLine($s) }

    & $a '# Generated by Aurora-Shell Installer v7.1.2'
    & $a '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8'
    & $a '. "$HOME\.aurora-shell_files\aurora-shell_settings.ps1"'
    & $a ''

    # ── Credential helpers (embedded in theme) ────────────────────────────
    & $a 'function _aurora_set_cred([string]$svc,[string]$val){'
    & $a '    $enc=$val|ConvertTo-SecureString -AsPlainText -Force|ConvertFrom-SecureString'
    & $a '    $d="$HOME\.aurora-shell_files\.creds";New-Item -ItemType Directory -Path $d -Force|Out-Null'
    & $a '    $enc|Set-Content "$d\$svc.enc" -Encoding UTF8'
    & $a '}'
    & $a 'function _aurora_get_cred([string]$svc){'
    & $a '    $f="$HOME\.aurora-shell_files\.creds\$svc.enc"'
    & $a '    if(-not(Test-Path $f)){return $null}'
    & $a '    try{$ss=Get-Content $f|ConvertTo-SecureString;return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))}catch{return $null}'
    & $a '}'
    & $a 'function _aurora_del_cred([string]$svc){$f="$HOME\.aurora-shell_files\.creds\$svc.enc";if(Test-Path $f){Remove-Item $f -Force}}'
    & $a 'function _aurora_has_cred([string]$svc){return(Test-Path "$HOME\.aurora-shell_files\.creds\$svc.enc")}'
    & $a ''

    # ── General helpers ───────────────────────────────────────────────────
    & $a 'function _aurora_hash([string]$s){(Get-FileHash -InputStream([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($s))) -Algorithm SHA256).Hash.ToLower()}'
    & $a 'function _read_pw([string]$p){$ss=Read-Host $p -AsSecureString;[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))}'
    & $a 'function Write-Lolcat([string]$t){if(Get-Command lolcat -ea SilentlyContinue){$t|lolcat}else{Write-Host $t -ForegroundColor Cyan}}'
    & $a ''

    # ── Notify (Windows Toast via BurntToast, fallback to WScript popup) ──
    & $a 'function notify([string]$title="Aurora-Shell",[string]$msg="",[string]$sound=""){'
    & $a '    try{'
    & $a '        if(Get-Command New-BurntToastNotification -ea SilentlyContinue){'
    & $a '            New-BurntToastNotification -Text $title,$msg -ea SilentlyContinue'
    & $a '        } else {'
    & $a '            $wsh=New-Object -ComObject WScript.Shell'
    & $a '            $wsh.Popup($msg,3,$title,0x40)|Out-Null'
    & $a '        }'
    & $a '    }catch{}'
    & $a '}'
    & $a ''

    # ── Multi-method auth helpers ─────────────────────────────────────────
    & $a 'function _aurora_try_windows_hello{'
    & $a '    if(-not(_aurora_has_cred "aurora-shell-windowshello")){return $false}'
    & $a '    try{'
    & $a '        $result=Start-Process powershell -ArgumentList @("-NonInteractive","-Command","[void][Windows.Security.Credentials.UI.UserConsentVerifier,Windows.Security.Credentials.UI,ContentType=WindowsRuntime];`$t=[Windows.Security.Credentials.UI.UserConsentVerifier]::RequestVerificationAsync(''Aurora-Shell login'');`$t.AsTask().Wait();exit ([int](`$t.AsTask().Result -eq ''Verified''))") -Wait -PassThru -WindowStyle Hidden -ea Stop'
    & $a '        return $result.ExitCode -eq 1'
    & $a '    }catch{return $false}'
    & $a '}'
    & $a ''
    & $a 'function _aurora_try_yubikey{'
    & $a '    $stored=_aurora_get_cred "aurora-shell-yubikey"'
    & $a '    if(-not $stored){return $false}'
    & $a '    $usb=Get-WmiObject Win32_USBHub -ea SilentlyContinue|Where-Object{$_.DeviceID -match "VID_1050|VID_24DC|VID_096E|VID_2CCF"}|Select-Object -First 1'
    & $a '    if($usb){return $true}'
    & $a '    if(Get-Command ykman -ea SilentlyContinue){'
    & $a '        $serial=(ykman list 2>$null) -replace "\D",""|Select-Object -First 1'
    & $a '        return $serial -eq $stored'
    & $a '    }'
    & $a '    return $false'
    & $a '}'
    & $a ''
    & $a 'function _aurora_try_keyfile{'
    & $a '    $path=_aurora_get_cred "aurora-shell-keyfile-path"'
    & $a '    $storedHash=_aurora_get_cred "aurora-shell-keyfile-hash"'
    & $a '    if(-not $path -or -not $storedHash){return $false}'
    & $a '    if(-not(Test-Path $path)){return $false}'
    & $a '    $cur=(Get-FileHash $path -Algorithm SHA256).Hash.ToLower()'
    & $a '    return $cur -eq $storedHash'
    & $a '}'
    & $a ''
    & $a 'function _aurora_auth{'
    & $a '    $hasHello=_aurora_has_cred "aurora-shell-windowshello"'
    & $a '    $hasYK=_aurora_has_cred "aurora-shell-yubikey"'
    & $a '    $hasKF=_aurora_has_cred "aurora-shell-keyfile-path"'
    & $a '    if($hasHello){'
    & $a '        Write-Lolcat "Windows Hello required..."'
    & $a '        if(_aurora_try_windows_hello){'
    & $a '            [int](Get-Date -UFormat %s)|Set-Content "$HOME\.aurora-shell_files\.last_auth"'
    & $a '            "$(Get-Date -Format ''yyyy-MM-dd HH:mm:ss'') — login OK (Windows Hello)"|Add-Content "$HOME\.aurora-shell_files\login_history.log"'
    & $a '            notify "Aurora-Shell" "Logged in via Windows Hello"'
    & $a '            return $true'
    & $a '        }'
    & $a '        Write-Lolcat "Windows Hello failed — trying next method..."'
    & $a '    }'
    & $a '    if($hasYK){'
    & $a '        Write-Lolcat "Insert your YubiKey..."'
    & $a '        $att=0'
    & $a '        while($att -lt 3){'
    & $a '            if(_aurora_try_yubikey){'
    & $a '                [int](Get-Date -UFormat %s)|Set-Content "$HOME\.aurora-shell_files\.last_auth"'
    & $a '                "$(Get-Date -Format ''yyyy-MM-dd HH:mm:ss'') — login OK (YubiKey)"|Add-Content "$HOME\.aurora-shell_files\login_history.log"'
    & $a '                notify "Aurora-Shell" "Logged in via YubiKey"'
    & $a '                return $true'
    & $a '            }'
    & $a '            $att++;Start-Sleep -Seconds 1'
    & $a '        }'
    & $a '        Write-Lolcat "YubiKey not detected — trying next method..."'
    & $a '    }'
    & $a '    if($hasKF){'
    & $a '        Write-Lolcat "Checking security key file..."'
    & $a '        if(_aurora_try_keyfile){'
    & $a '            [int](Get-Date -UFormat %s)|Set-Content "$HOME\.aurora-shell_files\.last_auth"'
    & $a '            "$(Get-Date -Format ''yyyy-MM-dd HH:mm:ss'') — login OK (Key File)"|Add-Content "$HOME\.aurora-shell_files\login_history.log"'
    & $a '            notify "Aurora-Shell" "Logged in via Key File"'
    & $a '            return $true'
    & $a '        }'
    & $a '        Write-Lolcat "Key file not found — falling back to PIN..."'
    & $a '    }'
    & $a '    return $false'
    & $a '}'
    & $a ''

    # ── aurora_security ───────────────────────────────────────────────────
    & $a 'function aurora_security([string]$opt,[string]$sub=""){'
    & $a '    switch($opt){'
    & $a '        "--add-windowshello"{'
    & $a '            try{Add-Type -AssemblyName System.Runtime.WindowsRuntime -ea Stop;_aurora_set_cred "aurora-shell-windowshello" "enabled";Write-Host "Windows Hello enabled" -ForegroundColor Green}'
    & $a '            catch{Write-Host "Windows Hello not available on this machine" -ForegroundColor Red}'
    & $a '        }'
    & $a '        "--add-yubikey"{'
    & $a '            $usb=Get-WmiObject Win32_USBHub -ea SilentlyContinue|Where-Object{$_.DeviceID -match "VID_1050|VID_24DC|VID_096E|VID_2CCF"}|Select-Object -First 1'
    & $a '            if($usb){_aurora_set_cred "aurora-shell-yubikey" ($usb.DeviceID -replace "\D","");Write-Host "YubiKey registered" -ForegroundColor Green}'
    & $a '            elseif(Get-Command ykman -ea SilentlyContinue){$s=(ykman list 2>$null) -replace "\D",""|Select-Object -First 1;if($s){_aurora_set_cred "aurora-shell-yubikey" $s;Write-Host "YubiKey registered (serial: $s)" -ForegroundColor Green}else{Write-Host "No YubiKey detected" -ForegroundColor Red}}'
    & $a '            else{Write-Host "No FIDO2/security key detected — insert it first" -ForegroundColor Red}'
    & $a '        }'
    & $a '        "--add-keyfile"{'
    & $a '            $kp=Read-Host "Path to key file"'
    & $a '            if(-not(Test-Path $kp)){Write-Host "File not found" -ForegroundColor Red;return}'
    & $a '            $kh=(Get-FileHash $kp -Algorithm SHA256).Hash.ToLower()'
    & $a '            _aurora_set_cred "aurora-shell-keyfile-path" $kp'
    & $a '            _aurora_set_cred "aurora-shell-keyfile-hash" $kh'
    & $a '            Write-Host "Key file registered: $kp" -ForegroundColor Green'
    & $a '        }'
    & $a '        "--remove"{'
    & $a '            switch($sub){'
    & $a '                "windowshello"{_aurora_del_cred "aurora-shell-windowshello";Write-Host "Windows Hello removed"}'
    & $a '                "yubikey"     {_aurora_del_cred "aurora-shell-yubikey";     Write-Host "YubiKey removed"}'
    & $a '                "keyfile"     {_aurora_del_cred "aurora-shell-keyfile-path";_aurora_del_cred "aurora-shell-keyfile-hash";Write-Host "Key file removed"}'
    & $a '                "pin"         {_aurora_del_cred "aurora-shell-pin";         Write-Host "PIN removed"}'
    & $a '                default       {Write-Host "Usage: shell.aurora --security --remove <windowshello|yubikey|keyfile|pin>"}'
    & $a '            }'
    & $a '        }'
    & $a '        "--status"{'
    & $a '            Write-Host "Security Methods:"'
    & $a '            if(_aurora_has_cred "aurora-shell-pin")          {Write-Host "   PIN           enabled" -ForegroundColor Green}else{Write-Host "   PIN           not set" -ForegroundColor Red}'
    & $a '            if(_aurora_has_cred "aurora-shell-windowshello") {Write-Host "   Windows Hello  enabled" -ForegroundColor Green}else{Write-Host "   Windows Hello  not set" -ForegroundColor DarkGray}'
    & $a '            if(_aurora_has_cred "aurora-shell-yubikey")      {Write-Host "   YubiKey        $(_aurora_get_cred ''aurora-shell-yubikey'')" -ForegroundColor Green}else{Write-Host "   YubiKey        not set" -ForegroundColor DarkGray}'
    & $a '            if(_aurora_has_cred "aurora-shell-keyfile-path") {Write-Host "   Key File       $(_aurora_get_cred ''aurora-shell-keyfile-path'')" -ForegroundColor Green}else{Write-Host "   Key File       not set" -ForegroundColor DarkGray}'
    & $a '        }'
    & $a '        default{'
    & $a '            Write-Host "Usage: shell.aurora --security <option>"'
    & $a '            Write-Host "  --add-windowshello   Enable Windows Hello / Fingerprint"'
    & $a '            Write-Host "  --add-yubikey        Register YubiKey or FIDO2 key"'
    & $a '            Write-Host "  --add-keyfile        Register a security key file"'
    & $a '            Write-Host "  --remove <type>      Remove a method (windowshello|yubikey|keyfile|pin)"'
    & $a '            Write-Host "  --status             Show configured methods"'
    & $a '        }'
    & $a '    }'
    & $a '}'
    & $a ''

    # ── Invoke-Auth ───────────────────────────────────────────────────────
    & $a 'function Invoke-Auth{'
    & $a '    param([switch]$ForceAuth,[string]$PinOverride="")'
    & $a '    $target=if($PinOverride){$PinOverride}else{_aurora_get_cred "aurora-shell-pin"}'
    & $a '    $lockFile="$HOME\.aurora-shell_files\.last_auth"'
    & $a '    $hasExtra=(_aurora_has_cred "aurora-shell-windowshello")-or(_aurora_has_cred "aurora-shell-yubikey")-or(_aurora_has_cred "aurora-shell-keyfile-path")'
    & $a '    if(-not $target -and -not $hasExtra){return}'
    & $a '    if(-not $ForceAuth -and (Test-Path $lockFile)){'
    & $a '        $last=[int](Get-Content $lockFile -ea SilentlyContinue)'
    & $a '        $now=[int](Get-Date -UFormat %s)'
    & $a '        if(($now-$last) -lt 600){return}'
    & $a '    }'
    & $a '    if($hasExtra -and (_aurora_auth)){'
    & $a '        . "$HOME\.aurora-shell_files\aurora-shell_settings.ps1" -ea SilentlyContinue'
    & $a '        $label="Logged in as $(if($global:AURORA_ID){$global:AURORA_ID}else{$env:USERNAME})"'
    & $a '        $w=100;$inner=$w-2;$pad=[math]::Floor(($inner-$label.Length)/2);$padr=$inner-$pad-$label.Length'
    & $a '        $box="╭"+"─"*$inner+"╮`n│"+" "*$inner+"│`n│"+" "*$pad+$label+" "*$padr+"│`n│"+" "*$inner+"│`n╰"+"─"*$inner+"╯"'
    & $a '        Write-Lolcat $box;return'
    & $a '    }'
    & $a '    if(-not $target){return}'
    & $a '    Clear-Host'
    & $a '    $banner=@"'
    & $a '           .---.'
    & $a '          /     \'
    & $a '         | (00)  |  SYSTEM ENCRYPTED'
    & $a '          \  ^  /'
    & $a '           (---)'
    & $a '     ╔════════════════════════════════════════╗'
    & $a '     ║     AURORA-SHELL SECURITY TERMINAL     ║'
    & $a '     ╚════════════════════════════════════════╝'
    & $a '"@'
    & $a '    Write-Lolcat $banner'
    & $a '    $attempts=0'
    & $a '    while($true){'
    & $a '        $in=Read-Host "[AUTH] Key" -AsSecureString'
    & $a '        $plain=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($in))'
    & $a '        if($plain -eq $target){'
    & $a '            [int](Get-Date -UFormat %s)|Set-Content $lockFile'
    & $a '            "$(Get-Date -Format ''yyyy-MM-dd HH:mm:ss'') — login OK"|Add-Content "$HOME\.aurora-shell_files\login_history.log"'
    & $a '            notify "Aurora-Shell" "Logged in as $(if($global:AURORA_ID){$global:AURORA_ID}else{$env:USERNAME})" "default"'
    & $a '            Clear-Host;break'
    & $a '        }'
    & $a '        $attempts++'
    & $a '        Write-Host "DENIED ($attempts failed attempt$(if($attempts -gt 1){''s''}))" -ForegroundColor Red'
    & $a '        "$(Get-Date -Format ''yyyy-MM-dd HH:mm:ss'') — FAILED attempt $attempts"|Add-Content "$HOME\.aurora-shell_files\login_history.log"'
    & $a '        notify "Aurora-Shell" "Failed PIN attempt #$attempts" "Basso"'
    & $a '        if($attempts -ge 5){Write-Lolcat "Too many failed attempts. Locking session.";notify "Aurora-Shell" "Locked out after 5 failed attempts" "Sosumi";exit 1}'
    & $a '    }'
    & $a '    . "$HOME\.aurora-shell_files\aurora-shell_settings.ps1" -ea SilentlyContinue'
    & $a '    $label="Logged in as $(if($global:AURORA_ID){$global:AURORA_ID}else{$env:USERNAME})"'
    & $a '    $w=100;$inner=$w-2;$pad=[math]::Floor(($inner-$label.Length)/2);$padr=$inner-$pad-$label.Length'
    & $a '    $box="╭"+"─"*$inner+"╮`n│"+" "*$inner+"│`n│"+" "*$pad+$label+" "*$padr+"│`n│"+" "*$inner+"│`n╰"+"─"*$inner+"╯"'
    & $a '    Write-Lolcat $box'
    & $a '}'
    & $a ''

    # ── Show-Aurora ───────────────────────────────────────────────────────
    & $a 'function Show-Aurora{'
    & $a '    . "$HOME\.aurora-shell_files\aurora-shell_settings.ps1"'
    & $a '    $cols=$Host.UI.RawUI.WindowSize.Width'
    & $a '    $lolcat=Get-Command lolcat -ErrorAction SilentlyContinue'
    & $a '    if($global:AURORA_HDR_MODE -eq "BLOCK"){'
    & $a '        $content=" █████╗ ██╗   ██╗██████╗  ██████╗ ██████╗  █████╗  `n██╔══██╗██║   ██║██╔══██╗██╔═══██╗██╔══██╗██╔══██╗ `n███████║██║   ██║██████╔╝██║   ██║██████╔╝███████║ `n██╔══██║██║   ██║██╔══██╗██║   ██║██╔══██╗██╔══██║ `n██║  ██║╚██████╔╝██║  ██║╚██████╔╝██║  ██║██║  ██║ `n╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ `n`n      ███████╗██╗  ██╗███████╗██╗     ██╗           `n      ██╔════╝██║  ██║██╔════╝██║     ██║           `n      ███████╗███████║█████╗  ██║     ██║           `n      ╚════██║██╔══██║██╔══╝  ██║     ██║           `n      ███████║██║  ██║███████╗███████╗███████╗      `n      ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝"'
    & $a '    } else {'
    & $a '        $font=if($global:AURORA_FIGLET_FONT){$global:AURORA_FIGLET_FONT}else{"slant"}'
    & $a '        if($font -eq "banner" -and (Get-Command figlet -ea SilentlyContinue)){'
    & $a '            $parts=$global:AURORA_HDR_VAL -split "-"'
    & $a '            $content=($parts|ForEach-Object{& figlet -f banner $_ 2>$null})-join "`n"'
    & $a '        } elseif(Get-Command figlet -ea SilentlyContinue){'
    & $a '            $content=& figlet -f $font $global:AURORA_HDR_VAL 2>$null'
    & $a '        } else { $content=$global:AURORA_HDR_VAL }'
    & $a '    }'
    & $a '    $maxW=($content -split "`n"|ForEach-Object{$_.Length}|Measure-Object -Maximum).Maximum'
    & $a '    $pad=[math]::Max(0,[math]::Floor(($cols-$maxW)/2))'
    & $a '    $padded=($content -split "`n"|ForEach-Object{" "*$pad+$_})-join "`n"'
    & $a '    if($lolcat){$padded|lolcat}else{Write-Host $padded -ForegroundColor Cyan}'
    & $a '    # Telemetry'
    & $a '    $cpu=(Get-CimInstance Win32_Processor|Measure-Object -Property LoadPercentage -Average).Average'
    & $a '    $diskFree=[math]::Round((Get-PSDrive C -ea SilentlyContinue).Free/1GB,1)'
    & $a '    $batt=(Get-CimInstance Win32_Battery -ea SilentlyContinue|Select-Object -First 1).EstimatedChargeRemaining'
    & $a '    $battStr=if($batt){"${batt}%"}else{"N/A"}'
    & $a '    $stats="⚡ AURORA v$global:AURORA_VER | CPU: ${cpu}% | FREE: ${diskFree}GB | BATT: $battStr | $(Get-Date -Format MM/dd/yy)"'
    & $a '    $sPad=[math]::Max(0,[math]::Floor(($cols-$stats.Length)/2))'
    & $a '    Write-Host (" "*$sPad+$stats) -ForegroundColor Blue'
    & $a '    $sep="-"*$cols'
    & $a '    if($lolcat){$sep|lolcat}else{Write-Host $sep -ForegroundColor Cyan}'
    & $a '}'
    & $a ''

    # ── Account system ────────────────────────────────────────────────────
    & $a '$AURORA_WORKER_URL="https://aurora-accounts.yash-behera.workers.dev"'
    & $a '$AURORA_ACCOUNT_FILE="$HOME\.aurora-shell_files\active_account.json"'
    & $a '$AURORA_SESSION_INSTALLED="$HOME\.aurora-shell_files\session_installed.txt"'
    & $a ''
    & $a 'function _aurora_scan_installed{'
    & $a '    $pkgs=@()'
    & $a '    foreach($cmd in @("git","gh","node","python","java","go","rustc","docker","aws","az")){'
    & $a '        if(Get-Command $cmd -ea SilentlyContinue){$pkgs+=$cmd}'
    & $a '    }'
    & $a '    return $pkgs -join " "'
    & $a '}'
    & $a ''
    & $a 'function _aurora_take_snapshot{'
    & $a '    $snap="$HOME\.aurora-shell_files\session_snapshot"'
    & $a '    Remove-Item $snap -Recurse -Force -ea SilentlyContinue'
    & $a '    New-Item -ItemType Directory -Path $snap -Force|Out-Null'
    & $a '    if(Test-Path $PROFILE){Copy-Item $PROFILE "$snap\profile.bak"}'
    & $a '    winget list 2>$null|Out-File "$snap\winget.txt"'
    & $a '    npm list -g --depth=0 2>$null|Out-File "$snap\npm-global.txt"'
    & $a '    pip list 2>$null|Out-File "$snap\pip.txt"'
    & $a '    if(Get-Command cargo -ea SilentlyContinue){cargo install --list 2>$null|Out-File "$snap\cargo.txt"}'
    & $a '    if(Get-Command gem -ea SilentlyContinue){gem list 2>$null|Out-File "$snap\gem.txt"}'
    & $a '}'
    & $a ''
    & $a 'function _aurora_apply_profile($profile,[string]$fast=""){'
    & $a '    _aurora_take_snapshot'
    & $a '    $uid=$profile.username'
    & $a '    if($profile.linked.openai_key)   {$env:OPENAI_API_KEY    =$profile.linked.openai_key}'
    & $a '    if($profile.linked.anthropic_key){$env:ANTHROPIC_API_KEY =$profile.linked.anthropic_key}'
    & $a '    if($profile.linked.gh_token)     {$env:GITHUB_TOKEN      =$profile.linked.gh_token}'
    & $a '    if($profile.linked.aws_key)      {$env:AWS_ACCESS_KEY_ID =$profile.linked.aws_key;$env:AWS_SECRET_ACCESS_KEY=$profile.linked.aws_secret}'
    & $a '    if($profile.linked.ollama_host)  {$env:OLLAMA_HOST       =$profile.linked.ollama_host}'
    & $a '    $profile|ConvertTo-Json -Compress|Set-Content $AURORA_ACCOUNT_FILE -Encoding UTF8'
    & $a '    Write-Host "Logged in as $uid$(if($fast){'' (fast mode)''})" -ForegroundColor Green'
    & $a '}'
    & $a ''
    & $a 'function _aurora_logout_cleanup([string]$fast=""){'
    & $a '    $snap="$HOME\.aurora-shell_files\session_snapshot"'
    & $a '    if(-not(Test-Path $snap)){return}'
    & $a '    Write-Host "Restoring system state..." -ForegroundColor Yellow'
    & $a '    if($fast -ne "--fast"){'
    & $a '        if(Test-Path "$snap\winget.txt"){'
    & $a '            $before=Get-Content "$snap\winget.txt"'
    & $a '            $after=winget list 2>$null'
    & $a '            $new=Compare-Object $before $after|Where-Object{$_.SideIndicator -eq "=>"}'
    & $a '            foreach($pkg in $new){try{winget uninstall --id ($pkg.InputObject -split "\s+")[0] --silent 2>$null}catch{}}'
    & $a '        }'
    & $a '        if(Test-Path "$snap\npm-global.txt"){'
    & $a '            $before=Get-Content "$snap\npm-global.txt"'
    & $a '            $after=npm list -g --depth=0 2>$null'
    & $a '            $new=Compare-Object $before $after -ea SilentlyContinue|Where-Object{$_.SideIndicator -eq "=>"}|ForEach-Object{($_.InputObject -split "@")[0].Trim()}'
    & $a '            foreach($pkg in $new){if($pkg){npm uninstall -g $pkg 2>$null}}'
    & $a '        }'
    & $a '        if(Test-Path "$snap\pip.txt"){'
    & $a '            $before=Get-Content "$snap\pip.txt"|ForEach-Object{($_ -split "\s+")[0]}'
    & $a '            $after=pip list 2>$null|Select-Object -Skip 2|ForEach-Object{($_ -split "\s+")[0]}'
    & $a '            $new=Compare-Object $before $after -ea SilentlyContinue|Where-Object{$_.SideIndicator -eq "=>"}'
    & $a '            foreach($pkg in $new){pip uninstall -y ($pkg.InputObject) 2>$null}'
    & $a '        }'
    & $a '        if((Test-Path "$snap\cargo.txt") -and (Get-Command cargo -ea SilentlyContinue)){'
    & $a '            $before=Get-Content "$snap\cargo.txt"|Where-Object{$_ -notmatch "^\s"}'
    & $a '            $after=cargo install --list 2>$null|Where-Object{$_ -notmatch "^\s"}'
    & $a '            $new=Compare-Object $before $after -ea SilentlyContinue|Where-Object{$_.SideIndicator -eq "=>"}'
    & $a '            foreach($pkg in $new){cargo uninstall ($pkg.InputObject -split "\s+")[0] 2>$null}'
    & $a '        }'
    & $a '    }'
    & $a '    if($fast -ne "--fast" -and (Test-Path "$snap\profile.bak")){Copy-Item "$snap\profile.bak" $PROFILE -Force}'
    & $a '    Remove-Item $snap,$AURORA_ACCOUNT_FILE -Recurse -Force -ea SilentlyContinue'
    & $a '    "OPENAI_API_KEY","ANTHROPIC_API_KEY","GITHUB_TOKEN","AWS_ACCESS_KEY_ID","AWS_SECRET_ACCESS_KEY","OLLAMA_HOST"|ForEach-Object{Remove-Item "Env:$_" -ea SilentlyContinue}'
    & $a '    Write-Host "Logged out. System restored." -ForegroundColor Green'
    & $a '}'
    & $a ''
    & $a 'function aurora_account([string]$opt,[string]$flag=""){'
    & $a '    switch($opt){'
    & $a '        "--create"{'
    & $a '            $uname=Read-Host "Username";$pw1=_read_pw "Password";$pw2=_read_pw "Confirm"'
    & $a '            if($pw1 -ne $pw2){Write-Host "Passwords do not match" -ForegroundColor Red;return}'
    & $a '            $installed=_aurora_scan_installed'
    & $a '            $payload=@{username=$uname;password_hash=(_aurora_hash $pw1);installed=$installed;plugins=@();linked=@{};header="Aurora-Shell";header_mode="BLOCK"}|ConvertTo-Json -Compress'
    & $a '            try{Invoke-RestMethod -Method Post -Uri "$AURORA_WORKER_URL/accounts" -ContentType "application/json" -Body $payload|Out-Null;Write-Host "Account created! Login with: shell.aurora --account --login" -ForegroundColor Green}'
    & $a '            catch{Write-Host "Error: $_" -ForegroundColor Red}'
    & $a '        }'
    & $a '        "--login"{'
    & $a '            $uname=Read-Host "Username";$hash=_aurora_hash(_read_pw "Password")'
    & $a '            try{'
    & $a '                $resp=Invoke-RestMethod -Method Post -Uri "$AURORA_WORKER_URL/accounts/login" -ContentType "application/json" -Body "{`"username`":`"$uname`",`"password_hash`":`"$hash`"}"'
    & $a '                $resp|Add-Member -NotePropertyName password_hash -NotePropertyValue $hash -Force'
    & $a '                _aurora_apply_profile $resp $flag'
    & $a '            }catch{Write-Host "Error: $_" -ForegroundColor Red}'
    & $a '        }'
    & $a '        "--logout"{_aurora_logout_cleanup $flag}'
    & $a '        "--whoami"{'
    & $a '            if(-not(Test-Path $AURORA_ACCOUNT_FILE)){Write-Host "Not logged in";return}'
    & $a '            $p=Get-Content $AURORA_ACCOUNT_FILE|ConvertFrom-Json'
    & $a '            $owner=if($p.is_owner){"  OWNER"}else{""}'
    & $a '            Write-Host "User: $($p.username)$owner | plugins: $($p.plugins -join '', '') | linked: $($p.linked.PSObject.Properties.Name -join '', '')"'
    & $a '        }'
    & $a '        "--link"{'
    & $a '            if(-not(Test-Path $AURORA_ACCOUNT_FILE)){Write-Host "Not logged in" -ForegroundColor Red;return}'
    & $a '            $p=Get-Content $AURORA_ACCOUNT_FILE|ConvertFrom-Json'
    & $a '            $uname=$p.username;$hash=_aurora_hash(_read_pw "Password")'
    & $a '            Write-Host "Link: 1)AWS 2)GitHub 3)OpenAI 4)Anthropic 5)Ollama"'
    & $a '            $linked=switch(Read-Host "Choice"){'
    & $a '                "1"{@{aws_key=(Read-Host "AWS Key ID");aws_secret=(_read_pw "AWS Secret")}}'
    & $a '                "2"{@{gh_token=(_read_pw "GitHub Token")}}'
    & $a '                "3"{@{openai_key=(_read_pw "OpenAI Key")}}'
    & $a '                "4"{@{anthropic_key=(_read_pw "Anthropic Key")}}'
    & $a '                "5"{$h=Read-Host "Ollama Host";@{ollama_host=if($h){$h}else{"localhost:11434"}}}'
    & $a '                default{$null}'
    & $a '            }'
    & $a '            if(-not $linked){Write-Host "Invalid choice" -ForegroundColor Red;return}'
    & $a '            try{Invoke-RestMethod -Method Patch -Uri "$AURORA_WORKER_URL/accounts/$uname" -ContentType "application/json" -Body (@{password_hash=$hash;linked=$linked}|ConvertTo-Json -Compress)|Out-Null;Write-Host "Service linked" -ForegroundColor Green}'
    & $a '            catch{Write-Host "Error: $_" -ForegroundColor Red}'
    & $a '        }'
    & $a '        "--users"{'
    & $a '            if(-not(Test-Path $AURORA_ACCOUNT_FILE)){Write-Host "Not logged in" -ForegroundColor Red;return}'
    & $a '            $p=Get-Content $AURORA_ACCOUNT_FILE|ConvertFrom-Json'
    & $a '            try{(Invoke-RestMethod -Uri "$AURORA_WORKER_URL/accounts" -Headers @{"X-Username"=$p.username;"X-Password-Hash"=$p.password_hash})|ForEach-Object{"$($_.username)$(if($_.is_owner){'' OWNER''})"}}'
    & $a '            catch{Write-Host "Error: $_ (owner only)" -ForegroundColor Red}'
    & $a '        }'
    & $a '        "--audit"{'
    & $a '            $log="$HOME\.aurora-shell_files\login_history.log"'
    & $a '            if(Test-Path $log){Get-Content $log|Select-Object -Last 20|ForEach-Object{Write-Lolcat $_}}'
    & $a '            else{Write-Host "No login history found."}'
    & $a '        }'
    & $a '        "--switch"{'
    & $a '            if(-not $flag){Write-Host "Usage: shell.aurora --account --switch <username>" -ForegroundColor Red;return}'
    & $a '            _aurora_logout_cleanup "--fast"'
    & $a '            $hash=_aurora_hash(_read_pw "Password for $flag")'
    & $a '            try{'
    & $a '                $resp=Invoke-RestMethod -Method Post -Uri "$AURORA_WORKER_URL/accounts/login" -ContentType "application/json" -Body "{`"username`":`"$flag`",`"password_hash`":`"$hash`"}"'
    & $a '                $resp|Add-Member -NotePropertyName password_hash -NotePropertyValue $hash -Force'
    & $a '                _aurora_apply_profile $resp "--fast"'
    & $a '            }catch{Write-Host "Error: $_" -ForegroundColor Red}'
    & $a '        }'
    & $a '        default{'
    & $a '            Write-Host "  --create          Create a new Aurora account"'
    & $a '            Write-Host "  --login           Sign in to your account"'
    & $a '            Write-Host "  --login --fast    Sign in, apply config only (skip installs)"'
    & $a '            Write-Host "  --logout          Sign out and restore system"'
    & $a '            Write-Host "  --logout --fast   Sign out quickly (skip uninstalls)"'
    & $a '            Write-Host "  --link            Link a service (AWS/GitHub/OpenAI/Anthropic/Ollama)"'
    & $a '            Write-Host "  --whoami          Show current logged-in account"'
    & $a '            Write-Host "  --users           List all accounts (owner only)"'
    & $a '            Write-Host "  --audit           Show login history"'
    & $a '            Write-Host "  --switch <user>   Switch to another account (fast)"'
    & $a '        }'
    & $a '    }'
    & $a '}'
    & $a ''

    # ── Module system (jacket-based) ──────────────────────────────────────
    & $a 'function shell_aurora_mc{'
    & $a '    $shellDir="$HOME\.local\shell"'
    & $a '    $packBase="https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/.pack/shell/jackets"'
    & $a '    $arch=if($env:PROCESSOR_ARCHITECTURE -eq "ARM64"){"arm64"}else{"x86_64"}'
    & $a '    New-Item -ItemType Directory -Path "$shellDir\bin","$shellDir\cellar","$shellDir\jackets" -Force|Out-Null'
    & $a '    Write-Host "Installing Aurora-Shell Module System..." -ForegroundColor Cyan'
    & $a '    try{irm "$packBase/index.json" -OutFile "$shellDir\jackets\index.json";Write-Host "  Jacket index fetched" -ForegroundColor Green}catch{Write-Host "  Could not fetch index — will use fallback" -ForegroundColor Yellow}'
    & $a '    $shellScript="$shellDir\bin\shell.ps1"'
    & $a '    $sc=@'''
    & $a 'param([string]$cmd="",[string]$pkg="")'
    & $a '$SHELL_DIR="$HOME\.local\shell"'
    & $a '$JACKET_DIR="$SHELL_DIR\jackets"'
    & $a '$CELLAR_DIR="$SHELL_DIR\cellar"'
    & $a '$PACK_BASE="https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/.pack/shell/jackets"'
    & $a '$ARCH=if($env:PROCESSOR_ARCHITECTURE -eq "ARM64"){"arm64"}else{"x86_64"}'
    & $a '$PLATFORM="windows"'
    & $a 'function _jacket_install([string]$p){'
    & $a '    $idx="$JACKET_DIR\index.json"'
    & $a '    if(-not(Test-Path $idx)){irm "$PACK_BASE/index.json" -OutFile $idx}'
    & $a '    $index=Get-Content $idx|ConvertFrom-Json'
    & $a '    $key="${ARCH}_${PLATFORM}"'
    & $a '    $jacket=$index.jackets.$p.$key'
    & $a '    if(-not $jacket){Write-Host "No jacket for $p ($key)" -ForegroundColor Yellow;_fallback $p;return}'
    & $a '    $url="$PACK_BASE/$($jacket.file)"'
    & $a '    Write-Host "Installing jacket: $p v$($jacket.version)" -ForegroundColor Cyan'
    & $a '    $tmp=[IO.Path]::GetTempPath()+"jacket_$p"'
    & $a '    New-Item -ItemType Directory -Path $tmp -Force|Out-Null'
    & $a '    irm $url -OutFile "$tmp\jacket.tar.gz"'
    & $a '    tar -xzf "$tmp\jacket.tar.gz" -C $tmp'
    & $a '    $dest="$CELLAR_DIR\$p\$($jacket.version)"'
    & $a '    New-Item -ItemType Directory -Path $dest -Force|Out-Null'
    & $a '    Copy-Item "$tmp\*" $dest -Force'
    & $a '    $binSrc="$dest\$($jacket.bin).exe";if(-not(Test-Path $binSrc)){$binSrc="$dest\$($jacket.bin)"}'
    & $a '    Copy-Item $binSrc "$SHELL_DIR\bin\" -Force -ea SilentlyContinue'
    & $a '    Remove-Item $tmp -Recurse -Force'
    & $a '    Write-Host "Installed $p v$($jacket.version)" -ForegroundColor Green'
    & $a '}'
    & $a 'function _fallback([string]$p){'
    & $a '    $cli=try{(Get-Content "$HOME\.aurora-shell_files\cli-packages.json"|ConvertFrom-Json).packages.$p}catch{$null}'
    & $a '    if(-not $cli){Write-Host "Not found in jackets or CLI registry" -ForegroundColor Red;return}'
    & $a '    Write-Host "Fallback: $($cli.install)" -ForegroundColor Yellow'
    & $a '    Invoke-Expression $cli.install'
    & $a '}'
    & $a 'switch($cmd){'
    & $a '    "install"   {_jacket_install $pkg}'
    & $a '    "uninstall" {$b=(Get-Content "$JACKET_DIR\index.json"|ConvertFrom-Json).jackets.$pkg;Remove-Item "$SHELL_DIR\bin\$($b.PSObject.Properties.Value[0].bin)*" -Force -ea SilentlyContinue;Remove-Item "$CELLAR_DIR\$pkg" -Recurse -Force -ea SilentlyContinue;Write-Host "Uninstalled $pkg" -ForegroundColor Green}'
    & $a '    "list"      {Get-ChildItem $CELLAR_DIR -ea SilentlyContinue|ForEach-Object{"$($_.Name) $(Get-ChildItem $_.FullName|Select-Object -First 1 -ExpandProperty Name)"}}'
    & $a '    "search"    {$idx=Get-Content "$JACKET_DIR\index.json"|ConvertFrom-Json;$idx.jackets.PSObject.Properties|Where-Object{$_.Name -like "*$pkg*"}|ForEach-Object{"  $($_.Name) — $($_.Value.PSObject.Properties.Value[0].description)"}}'
    & $a '    "update"    {irm "$PACK_BASE/index.json" -OutFile "$JACKET_DIR\index.json";Write-Host "Index updated" -ForegroundColor Green}'
    & $a '    "outdated"  {$idx=Get-Content "$JACKET_DIR\index.json"|ConvertFrom-Json;Get-ChildItem $CELLAR_DIR -ea SilentlyContinue|ForEach-Object{$n=$_.Name;$iv=Get-ChildItem $_.FullName|Select-Object -First 1 -ExpandProperty Name;$lv=$idx.jackets.$n.PSObject.Properties.Value[0].version;if($iv -ne $lv){"  $n : $iv -> $lv"}}}'
    & $a '    "info"      {$idx=Get-Content "$JACKET_DIR\index.json"|ConvertFrom-Json;$idx.jackets.$pkg.PSObject.Properties|ForEach-Object{"  $($_.Name): v$($_.Value.version) [$($_.Value.source)]"}}'
    & $a '    default     {Write-Host "Usage: shell install|uninstall|list|search|update|outdated|info <package>";Write-Host "Jackets: github.com/Seaus-tech/Aurora-Shell/.pack/shell/jackets"}'
    & $a '}'
    & $a ''''
    & $a '    $sc|Set-Content $shellScript -Encoding UTF8'
    & $a '    $wrapper="$shellDir\bin\shell.cmd"'
    & $a '    "@echo off`npowershell -NoProfile -File `"$shellScript`" %*"|Set-Content $wrapper'
    & $a '    if($env:PATH -notlike "*\.local\shell\bin*"){[System.Environment]::SetEnvironmentVariable("PATH",$env:PATH+";$shellDir\bin","User")}'
    & $a '    $env:PATH+=";$shellDir\bin"'
    & $a '    Write-Host ""'
    & $a '    Write-Host "Aurora-Shell Module System installed!" -ForegroundColor Green'
    & $a '    Write-Host "  shell install <package>  — install from jacket"'
    & $a '    Write-Host "  shell search <query>     — search jackets"'
    & $a '    Write-Host "  shell list               — list installed"'
    & $a '    Write-Host "Restart terminal to apply PATH changes."'
    & $a '}'
    & $a ''

    # ── shell.aurora ──────────────────────────────────────────────────────
    & $a 'function shell.aurora([string]$flag="",[string]$arg2="",[string]$arg3=""){'
    & $a '    switch($flag){'
    & $a '        "--display"  {Show-Aurora}'
    & $a '        "--sys"      {(Get-CimInstance Win32_Processor).Name;(Get-CimInstance Win32_OperatingSystem).Caption}'
    & $a '        "--update"   {'
    & $a '            $b=if($arg2){$arg2}else{"main"}'
    & $a '            $raw=try{irm "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/$b/install.ps1" -TimeoutSec 5}catch{$null}'
    & $a '            if(-not $raw){Write-Host "Could not reach update server." -ForegroundColor Red;return}'
    & $a '            $remoteVer=if($raw -match ''\$VER\s+=\s+"([^"]+)"''){$Matches[1]}else{$null}'
    & $a '            $cols=$Host.UI.RawUI.WindowSize.Width;$line="-"*$cols'
    & $a '            Clear-Host;Write-Lolcat $line;Write-Host ""'
    & $a '            Write-Host ("AURORA-SHELL UPDATE CHECK".PadLeft(($cols+24)/2)) -ForegroundColor Cyan'
    & $a '            Write-Host "";Write-Host "  Installed : v$global:AURORA_VER";Write-Host "  Available : v$remoteVer";Write-Host ""'
    & $a '            if($remoteVer -eq $global:AURORA_VER){Write-Host "  Already up to date." -ForegroundColor Green;Write-Lolcat $line;return}'
    & $a '            Write-Host "  Update available: v$global:AURORA_VER -> v$remoteVer" -ForegroundColor Yellow;Write-Lolcat $line'
    & $a '            if(Test-Path "$HOME\.aurora-shell_files\active_account.json"){'
    & $a '                $p=Get-Content "$HOME\.aurora-shell_files\active_account.json"|ConvertFrom-Json'
    & $a '                $pwSS=Read-Host "Account password for $($p.username)" -AsSecureString'
    & $a '                $pwTxt=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwSS))'
    & $a '                $hash=(Get-FileHash -InputStream([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($pwTxt))) -Algorithm SHA256).Hash.ToLower()'
    & $a '                try{$chk=(Invoke-RestMethod -Method Post -Uri "https://aurora-accounts.yash-behera.workers.dev/accounts/login" -ContentType "application/json" -Body "{`"username`":`"$($p.username)`",`"password_hash`":`"$hash`"}").username}catch{$chk=$null}'
    & $a '                if(-not $chk){Write-Host "Wrong password — cancelled." -ForegroundColor Red;notify "Aurora-Shell" "Update cancelled" "Basso";return}'
    & $a '            } else {'
    & $a '                $yn=Read-Host "No account logged in. Continue? (y/N)"'
    & $a '                if($yn -notin "y","Y"){return}'
    & $a '            }'
    & $a '            notify "Aurora-Shell" "Installing update v$remoteVer" "Ping"'
    & $a '            $t=[IO.Path]::GetTempFileName()+".ps1";$raw|Set-Content $t;& $t;Remove-Item $t'
    & $a '        }'
    & $a '        "--config"   {'
    & $a '            $cfg="$HOME\.aurora-shell_files\aurora-shell_settings.ps1"'
    & $a '            $opened=$false'
    & $a '            foreach($ed in @("code","cursor","kiro","notepad++")){'
    & $a '                if(Get-Command $ed -ea SilentlyContinue){& $ed $cfg;$opened=$true;break}'
    & $a '            }'
    & $a '            if(-not $opened){Start-Process notepad $cfg}'
    & $a '        }'
    & $a '        "--lock"     {'
    & $a '            $pin=_aurora_get_cred "aurora-shell-pin"'
    & $a '            if($pin){Invoke-Auth -ForceAuth -PinOverride $pin}else{Invoke-Auth -ForceAuth}'
    & $a '            Show-Aurora'
    & $a '        }'
    & $a '        "--uninstall"{'
    & $a '            Remove-Item "$HOME\.aurora-shell_files" -Recurse -Force -ea SilentlyContinue'
    & $a '            if(Test-Path $PROFILE){(Get-Content $PROFILE)|Where-Object{$_ -notmatch "aurora-shell_files"}|Set-Content $PROFILE}'
    & $a '            Write-Host "Aurora-Shell uninstalled." -ForegroundColor Green'
    & $a '        }'
    & $a '        "--account"            {aurora_account $arg2 $arg3}'
    & $a '        "--security"           {aurora_security $arg2 $arg3}'
    & $a '        "--modules-components" {shell_aurora_mc}'
    & $a '        "-mc"                  {shell_aurora_mc}'
    & $a '        "--motd"{'
    & $a '            try{$r=irm "https://zenquotes.io/api/today" -TimeoutSec 5;$m="$($r[0].q) — $($r[0].a)";Write-Lolcat $m}catch{Write-Host "No MOTD available."}'
    & $a '        }'
    & $a '        "--doctor"{'
    & $a '            Write-Lolcat "Aurora-Shell Doctor"'
    & $a '            $ok=$true'
    & $a '            if($env:PATH -notlike "*aurora-shell_files*"){Write-Host "WARN: aurora-shell_files not in PATH" -ForegroundColor Yellow;$ok=$false}'
    & $a '            if(-not(Select-String -Quiet "aurora-shell_theme" $PROFILE -ea SilentlyContinue)){Write-Host "WARN: Theme not sourced in profile" -ForegroundColor Yellow;$ok=$false}'
    & $a '            foreach($cmd in @("git","node","npm","figlet","lolcat","jq","fzf")){'
    & $a '                if(Get-Command $cmd -ea SilentlyContinue){Write-Host "OK   $cmd" -ForegroundColor Green}else{Write-Host "MISS $cmd" -ForegroundColor Red;$ok=$false}'
    & $a '            }'
    & $a '            if(-not(Test-Path "$HOME\.aurora-shell_files\aurora-shell_settings.ps1")){Write-Host "MISS settings file — run installer" -ForegroundColor Red;$ok=$false}'
    & $a '            if($ok){Write-Lolcat "All checks passed";notify "Aurora-Shell" "Doctor: all checks passed"}'
    & $a '            else{notify "Aurora-Shell" "Doctor found issues — check your terminal" "Basso"}'
    & $a '        }'
    & $a '        "--sync"{'
    & $a '            if(-not(Test-Path "$HOME\.aurora-shell_files\active_account.json")){Write-Host "Not logged in" -ForegroundColor Red;return}'
    & $a '            $p=Get-Content "$HOME\.aurora-shell_files\active_account.json"|ConvertFrom-Json'
    & $a '            try{Invoke-RestMethod -Method Patch -Uri "https://aurora-accounts.yash-behera.workers.dev/accounts/$($p.username)" -ContentType "application/json" -Body (@{password_hash=$p.password_hash}|ConvertTo-Json -Compress)|Out-Null;Write-Host "Synced to Aurora account" -ForegroundColor Green}'
    & $a '            catch{Write-Host "Sync failed: $_" -ForegroundColor Red}'
    & $a '        }'
    & $a '        "--history"{'
    & $a '            $h=Get-Content (Get-PSReadLineOption).HistorySavePath -ea SilentlyContinue'
    & $a '            if(-not $h){Write-Host "No history found";return}'
    & $a '            if(Get-Command fzf -ea SilentlyContinue){'
    & $a '                $cmd=$h|Select-Object -Unique|fzf --tac --no-sort --prompt="history> " 2>$null'
    & $a '                if($cmd){[Microsoft.PowerShell.PSConsoleReadLine]::Insert($cmd)}'
    & $a '            } else { $h|Select-Object -Last 50 }'
    & $a '        }'
    & $a '        "--run"{'
    & $a '            if(Test-Path "package.json")    {npm start}'
    & $a '            elseif(Test-Path "Cargo.toml")  {cargo run}'
    & $a '            elseif(Test-Path "go.mod")      {go run .}'
    & $a '            elseif(Test-Path "manage.py")   {python manage.py runserver}'
    & $a '            elseif(Test-Path "requirements.txt"){python (Get-ChildItem *.py|Select-Object -First 1 -ExpandProperty Name)}'
    & $a '            elseif(Test-Path "Makefile")    {make}'
    & $a '            elseif(Test-Path "pom.xml")     {mvn spring-boot:run}'
    & $a '            elseif(Test-Path "build.gradle"){.\gradlew bootRun}'
    & $a '            else{Write-Host "No recognisable project type in $(Get-Location)" -ForegroundColor Red}'
    & $a '        }'
    & $a '        default{'
    & $a '            Write-Host "Flags: --display --sys --update [branch] --config --lock --uninstall --account --security --motd --doctor --sync --history --run --modules-components (-mc)"'
    & $a '        }'
    & $a '    }'
    & $a '}'
    & $a ''

    # ── Version check banner ──────────────────────────────────────────────
    & $a 'try{'
    & $a '    $rv=irm "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/install.ps1" -TimeoutSec 3 -ea SilentlyContinue'
    & $a '    if($rv -match ''\$VER\s+=\s+"([^"]+)"''){'
    & $a '        $remoteVer=$Matches[1]'
    & $a '        $lp=$global:AURORA_VER -split "\." | ForEach-Object{[int]$_}'
    & $a '        $rp=$remoteVer          -split "\." | ForEach-Object{[int]$_}'
    & $a '        $newer=$false'
    & $a '        for($i=0;$i -lt 3;$i++){if($rp[$i] -gt $lp[$i]){$newer=$true;break}elseif($rp[$i] -lt $lp[$i]){break}}'
    & $a '        if($newer){Write-Lolcat "Update available (v$global:AURORA_VER -> v$remoteVer) — run: shell.aurora --update";notify "Aurora-Shell" "Update available: v$global:AURORA_VER -> v$remoteVer" "Ping"}'
    & $a '    }'
    & $a '}catch{}'
    & $a ''

    # ── MOTD on shell open ────────────────────────────────────────────────
    & $a 'try{$r=irm "https://zenquotes.io/api/today" -TimeoutSec 2 -ea SilentlyContinue;$m="$($r[0].q) — $($r[0].a)";Write-Host $m -ForegroundColor DarkGray}catch{}'

    $sb.ToString() | Set-Content $THEME_FILE -Encoding UTF8
}

# ── Execute ───────────────────────────────────────────────────────────────────

Sync-Env
Install-DevTools
Run-Wizard
Generate-Theme

# Wire theme into PowerShell profile
if (Test-Path $PROFILE) {
    (Get-Content $PROFILE -ErrorAction SilentlyContinue) |
        Where-Object { $_ -notmatch 'aurora-shell_theme' } |
        Set-Content $PROFILE
}
New-Item -ItemType File -Path $PROFILE -Force -ErrorAction SilentlyContinue | Out-Null
Add-Content $PROFILE ". `"$THEME_FILE`""

# ── Repo discovery (Windows paths, no recursive full-disk scan) ───────────────
Write-Host "`n🌀 Checking for Aurora-Shell repository..." -ForegroundColor Cyan

function Find-AuroraRepo {
    $candidates = @(
        (Get-Location).Path,
        "$HOME\Documents\Aurora-Shell",
        "$HOME\source\repos\Aurora-Shell",
        "$HOME\source\Aurora-Shell",
        "$HOME\src\Aurora-Shell",
        "$HOME\Projects\Aurora-Shell",
        "$HOME\Desktop\Aurora-Shell",
        "$HOME\Aurora-Shell",
        "$DATA_DIR\aurora-shell"
    )
    foreach ($d in $candidates) {
        if (Test-Path "$d\.git") {
            $origin = git -C $d remote get-url origin 2>$null
            if ($origin -eq $GIT_CLONE) { return $d }
        }
    }
    # Bounded wider search — max depth 4, only in HOME
    $found = Get-ChildItem $HOME -Recurse -Depth 4 -Directory -Filter ".git" -Force -ErrorAction SilentlyContinue |
        Where-Object {
            try { (git -C $_.Parent.FullName remote get-url origin 2>$null) -eq $GIT_CLONE } catch { $false }
        } | Select-Object -First 1
    if ($found) { return $found.Parent.FullName }
    return $null
}

$FOUND_REPO = Find-AuroraRepo

if ($FOUND_REPO) {
    Write-Host "Found existing repo at: $FOUND_REPO" -ForegroundColor Green
    git -C $FOUND_REPO pull
    foreach ($f in @("brew-progress.py","spinner.js","wx.js")) {
        Copy-Item "$FOUND_REPO\$f" $DATA_DIR -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "No matching repo found — cloning fresh copy..." -ForegroundColor Yellow
    git clone $GIT_CLONE "$DATA_DIR\aurora-shell"
    foreach ($f in @("brew-progress.py","spinner.js","wx.js")) {
        Copy-Item "$DATA_DIR\aurora-shell\$f" $DATA_DIR -ErrorAction SilentlyContinue
    }
}

# wx wrapper for Windows
if (Test-Path "$DATA_DIR\wx.js") {
    New-Item -ItemType Directory -Path "$DATA_DIR\bin" -Force | Out-Null
    "@echo off`nnode `"$DATA_DIR\wx.js`" %*" | Set-Content "$DATA_DIR\bin\wx.cmd"
}

# Add aurora bin dir to user PATH if not already present
if ($env:PATH -notlike "*aurora-shell_files\bin*") {
    [System.Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";$DATA_DIR\bin", "User")
    $env:PATH += ";$DATA_DIR\bin"
}

Write-Host ""
Write-Host "✅ Aurora-Shell v$VER successfully deployed." -ForegroundColor Green
Write-Host "   Open a new PowerShell window to activate." -ForegroundColor Cyan
Write-Host "   Run: shell.aurora --display   to test your setup." -ForegroundColor Cyan
