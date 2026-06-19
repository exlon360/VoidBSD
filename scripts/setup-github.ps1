param(
    [string]$RepositoryName = "VoidBSD",
    [ValidateSet("private", "public", "internal")]
    [string]$Visibility = "public",
    [string]$CommitMessage = "Initial VoidBSD scaffold"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$ghCandidates = @(
    (Get-Command gh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    "$env:LOCALAPPDATA\VoidBSD\tools\bin\gh.exe"
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

$gh = $ghCandidates | Select-Object -First 1
if (-not $gh) {
    throw "GitHub CLI was not found. Install it with winget install --id GitHub.cli -e or rerun the Codex setup."
}

$authOutput = & $gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host $authOutput
    throw "GitHub CLI is installed but not authenticated. Run: `"$gh`" auth login"
}

if (-not (git rev-parse --verify HEAD 2>$null)) {
    git branch -M main
    git add -A
    git commit -m $CommitMessage
}

if (-not (git remote get-url origin 2>$null)) {
    & $gh repo create $RepositoryName "--$Visibility" --source=. --remote=origin --push
} else {
    git push -u origin (git branch --show-current)
}

Write-Host "GitHub remote configured for $RepositoryName and current branch pushed."
