$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$bashCandidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\sh.exe"
)

$bash = $bashCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $bash) {
    throw "Git Bash was not found. Install Git for Windows or add sh/bash to PATH."
}

$unixRepo = $repoRoot -replace '\\', '/'
if ($unixRepo -match '^([A-Za-z]):/(.*)$') {
    $unixRepo = "/$($Matches[1].ToLower())/$($Matches[2])"
}

$script = @'
set -eu
files="
scripts/install-voidbsd.sh
scripts/install-zen.sh
scripts/build-raw-image.sh
scripts/build-installer-iso.sh
scripts/configure-user.sh
overlay/usr/local/libexec/voidbsd/first-login.sh
overlay/usr/local/etc/rc.d/voidbsd_gpu_detect
"
for file in $files; do
    sh -n "$file"
done
echo shell-syntax-ok
'@

& $bash -lc "cd '$unixRepo' && $script"

$fastfetchConfig = Join-Path $repoRoot "overlay/usr/local/etc/xdg/fastfetch/config.jsonc"
Get-Content -Raw $fastfetchConfig | ConvertFrom-Json | Out-Null
Write-Host "fastfetch-config-json-ok"

