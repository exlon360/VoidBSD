param(
    [string]$IsoPath = "",
    [string]$ImagePath = "",
    [string]$ImageXzPath = "",
    [string]$DiskPath = "",
    [string]$QemuDir = "",
    [int]$MemoryMb = 4096,
    [int]$Cpus = 2,
    [int]$DiskGb = 40,
    [switch]$InstallerIso,
    [switch]$ResetDisk,
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

function Find-Xz {
    $xz = Find-CommandPath @("xz.exe", "xz")
    if ($xz) {
        return $xz
    }

    $gitXz = "C:\Program Files\Git\mingw64\bin\xz.exe"
    if (Test-Path $gitXz) {
        return $gitXz
    }

    return $null
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

if (-not $IsoPath) {
    $IsoPath = Join-Path $root "dist\voidbsd-latest\voidbsd-15.1-RELEASE-amd64-bootonly.iso"
}
if (-not $ImagePath) {
    $ImagePath = Join-Path $root "dist\voidbsd-latest\voidbsd-15.1-RELEASE-amd64.raw"
}
if (-not $ImageXzPath) {
    $ImageXzPath = "$ImagePath.xz"
}
if (-not $DiskPath) {
    $DiskPath = Join-Path $root "vm\voidbsd.qcow2"
}

$IsoPath = [System.IO.Path]::GetFullPath($IsoPath)
$ImagePath = [System.IO.Path]::GetFullPath($ImagePath)
$ImageXzPath = [System.IO.Path]::GetFullPath($ImageXzPath)
$DiskPath = [System.IO.Path]::GetFullPath($DiskPath)

if ($InstallerIso -and -not (Test-Path $IsoPath)) {
    throw "VoidBSD installer ISO not found at $IsoPath. Download it with: gh release download voidbsd-latest --repo exlon360/VoidBSD --dir dist\voidbsd-latest"
}

if ($QemuDir) {
    $qemuSystem = Join-Path $QemuDir "qemu-system-x86_64.exe"
    $qemuImg = Join-Path $QemuDir "qemu-img.exe"
} else {
    $qemuSystem = Find-CommandPath @("qemu-system-x86_64.exe", "qemu-system-x86_64")
    $qemuImg = Find-CommandPath @("qemu-img.exe", "qemu-img")

    if (-not $qemuSystem -or -not $qemuImg) {
        $commonDirs = @(
            "$env:LOCALAPPDATA\VoidBSD\qemu",
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
    throw "QEMU is not installed or not on PATH. Install it, then rerun this script."
}

New-Item -ItemType Directory -Force -Path (Split-Path $DiskPath -Parent) | Out-Null

if ($ResetDisk -and (Test-Path $DiskPath)) {
    Remove-Item -LiteralPath $DiskPath -Force
}

if ($InstallerIso -and -not (Test-Path $DiskPath)) {
    & $qemuImg create -f qcow2 $DiskPath "$($DiskGb)G"
    if ($LASTEXITCODE -ne 0) {
        throw "qemu-img failed to create $DiskPath"
    }
}

if (-not $InstallerIso -and -not (Test-Path $DiskPath)) {
    if (-not (Test-Path $ImagePath)) {
        if (-not (Test-Path $ImageXzPath)) {
            throw "Preinstalled VoidBSD image not found at $ImagePath or $ImageXzPath. Download the image release asset into dist\voidbsd-latest first."
        }

        $xz = Find-Xz
        if (-not $xz) {
            throw "Found $ImageXzPath but could not find xz.exe. Git for Windows includes it at C:\Program Files\Git\mingw64\bin\xz.exe."
        }

        & $xz -dk $ImageXzPath
        if ($LASTEXITCODE -ne 0) {
            throw "xz failed to extract $ImageXzPath"
        }
    }

    & $qemuImg convert -f raw -O qcow2 $ImagePath $DiskPath
    if ($LASTEXITCODE -ne 0) {
        throw "qemu-img failed to convert $ImagePath to $DiskPath"
    }
}

$accel = if ($UseWhpx) { "whpx" } else { "tcg" }
$bootArgs = if ($InstallerIso) {
    @("-cdrom", $IsoPath, "-boot", "order=d")
} else {
    @("-boot", "order=c")
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
Write-Host "Disk: $DiskPath"
if ($InstallerIso) {
    Write-Host "ISO : $IsoPath"
    Write-Host "Mode: installer ISO"
    Write-Host ""
    Write-Host "Inside the installer, the VM disk is safe to wipe. It is only this file: $DiskPath"
} else {
    Write-Host "Mode: preinstalled VoidBSD disk"
    Write-Host "User: voidbsd"
    Write-Host "Pass: voidbsd"
}

& $qemuSystem @args
