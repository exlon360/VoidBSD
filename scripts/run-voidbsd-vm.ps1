param(
    [string]$IsoPath = "",
    [string]$DiskPath = "",
    [string]$QemuDir = "",
    [int]$MemoryMb = 4096,
    [int]$Cpus = 2,
    [int]$DiskGb = 40,
    [switch]$BootDisk,
    [switch]$UseWhpx
)

$ErrorActionPreference = "Stop"

function Find-CommandPath {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }

    return $null
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

if (-not $IsoPath) {
    $IsoPath = Join-Path $root "dist\voidbsd-latest\voidbsd-15.1-RELEASE-amd64-bootonly.iso"
}
if (-not $DiskPath) {
    $DiskPath = Join-Path $root "vm\voidbsd.qcow2"
}

$IsoPath = [System.IO.Path]::GetFullPath($IsoPath)
$DiskPath = [System.IO.Path]::GetFullPath($DiskPath)

if (-not (Test-Path $IsoPath)) {
    throw "VoidBSD ISO not found at $IsoPath. Download it with: gh release download voidbsd-latest --repo exlon360/VoidBSD --dir dist\voidbsd-latest"
}

if ($QemuDir) {
    $qemuSystem = Join-Path $QemuDir "qemu-system-x86_64.exe"
    $qemuImg = Join-Path $QemuDir "qemu-img.exe"
} else {
    $qemuSystem = Find-CommandPath @("qemu-system-x86_64.exe", "qemu-system-x86_64")
    $qemuImg = Find-CommandPath @("qemu-img.exe", "qemu-img")

    if (-not $qemuSystem -or -not $qemuImg) {
        $commonDirs = @(
            "C:\Program Files\qemu",
            "$env:LOCALAPPDATA\Programs\QEMU",
            "$env:LOCALAPPDATA\QEMU"
        )
        foreach ($dir in $commonDirs) {
            if (-not $qemuSystem -and (Test-Path (Join-Path $dir "qemu-system-x86_64.exe"))) {
                $qemuSystem = Join-Path $dir "qemu-system-x86_64.exe"
            }
            if (-not $qemuImg -and (Test-Path (Join-Path $dir "qemu-img.exe"))) {
                $qemuImg = Join-Path $dir "qemu-img.exe"
            }
        }
    }
}

if (-not (Test-Path $qemuSystem) -or -not (Test-Path $qemuImg)) {
    throw "QEMU is not installed or not on PATH. Install it, then rerun this script. The ISO is already downloaded and verified."
}

New-Item -ItemType Directory -Force -Path (Split-Path $DiskPath -Parent) | Out-Null

if (-not (Test-Path $DiskPath)) {
    & $qemuImg create -f qcow2 $DiskPath "$($DiskGb)G"
    if ($LASTEXITCODE -ne 0) {
        throw "qemu-img failed to create $DiskPath"
    }
}

$accel = if ($UseWhpx) { "whpx" } else { "tcg" }
$bootArgs = if ($BootDisk) {
    @("-boot", "order=c")
} else {
    @("-cdrom", $IsoPath, "-boot", "order=d")
}

$args = @(
    "-name", "VoidBSD",
    "-machine", "q35",
    "-accel", $accel,
    "-m", $MemoryMb,
    "-smp", $Cpus,
    "-drive", "file=$DiskPath,if=virtio,format=qcow2",
    "-netdev", "user,id=net0",
    "-device", "virtio-net-pci,netdev=net0",
    "-device", "virtio-vga",
    "-display", "default"
) + $bootArgs

Write-Host "Starting VoidBSD VM"
Write-Host "ISO : $IsoPath"
Write-Host "Disk: $DiskPath"
Write-Host "Mode: $(if ($BootDisk) { 'boot installed disk' } else { 'boot installer ISO' })"
Write-Host ""
Write-Host "Inside the installer, the VM disk is safe to wipe. It is only this file: $DiskPath"

& $qemuSystem @args
