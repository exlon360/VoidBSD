# VoidBSD

VoidBSD is a small FreeBSD desktop remix recipe: stock FreeBSD base, KDE
Plasma, SDDM login, Kitty with a Tokyo Night theme, a generated neon night
wallpaper, a bottom Plasma taskbar, and KRunner on `Alt+Space` for app search.

The default target is FreeBSD `15.1-RELEASE` on `amd64`, because FreeBSD lists
15.1 as the current production release.

## What This Builds

- FreeBSD base system from official release sets.
- KDE Plasma via FreeBSD packages.
- SDDM enabled as the graphical login manager.
- Kitty configured globally with Tokyo Night colors.
- Fastfetch configured with a Void-style BSD ASCII logo.
- A project wallpaper installed as a KDE wallpaper package.
- First-login Plasma setup that applies the wallpaper, dark KDE colors, a
  bottom panel/taskbar if the profile has none, and explicit KRunner
  `Alt+Space` shortcuts.
- Zen Browser install hook, with Firefox as the practical fallback when no
  native FreeBSD Zen package is available.

## Quick Start In A VM

The primary release artifact is the preinstalled disk image:

```text
voidbsd-15.1-RELEASE-amd64.raw.xz
```

It boots with FreeBSD already installed. The generated VM image includes a
default desktop user:

```text
user: voidbsd
pass: voidbsd
```

On Windows, after downloading the release assets into `dist\voidbsd-latest`,
boot the preinstalled image with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\run-voidbsd-vm.ps1
```

## Quick Start On An Installed FreeBSD System

Run this from a fresh FreeBSD install:

```sh
su -
cd /path/to/VoidBSD
sh scripts/install-voidbsd.sh
```

After the next graphical login, the first-login autostart script applies the
Plasma, Kitty, and Fastfetch defaults for that user.

## Build A Bootable Raw Image

Run this on a FreeBSD host, not on Windows:

```sh
su -
cd /path/to/VoidBSD
sh scripts/build-raw-image.sh
```

The image is written to `out/voidbsd-15.1-RELEASE-amd64.raw` by default. You
can override the target release and size:

```sh
FREEBSD_VERSION=15.1-RELEASE IMAGE_SIZE=32G sh scripts/build-raw-image.sh
```

The script prompts for a root password when it has an interactive terminal. For
fully unattended image builds, set `SKIP_PASSWORD_PROMPT=yes` and configure
users/passwords through your own image pipeline before shipping the image.
For the release VM image, the GitHub workflow sets `VOIDBSD_IMAGE_USER=voidbsd`
and `VOIDBSD_IMAGE_PASSWORD=voidbsd`, then seeds that user and enables SDDM
auto-login.

## Build An Installer ISO

This is now the secondary/manual path. It still boots FreeBSD's installer,
because an ISO is install media, not the preinstalled VoidBSD system.

Run this on a FreeBSD host with `/usr/src` installed:

```sh
su -
cd /path/to/VoidBSD
sh scripts/build-installer-iso.sh
```

The ISO builder fetches the official FreeBSD `bootonly.iso`, injects a VoidBSD
distribution set, and repacks the media with FreeBSD's architecture-specific
`mkisoimages.sh`. The resulting ISO boots into the normal FreeBSD installer.
Before `bsdinstall` starts, VoidBSD Setup asks for region and then shows
`Use disk` or `Wipe disk`. The wipe path excludes mounted installer/current
system disks where FreeBSD exposes that mapping and requires typing
`WIPE <disk>` before it proceeds. During install, leave the `voidbsd`
distribution selected; on first boot it runs the VoidBSD desktop bootstrap and
disables itself after success.

See [docs/iso-image.md](docs/iso-image.md) for the resource map and install
notes.

## Checks

On this Windows workstation, Git Bash is available at
`C:\Program Files\Git\bin\bash.exe` even though `bash` is not on `PATH`.
You can run the local script syntax checks with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-windows.ps1
```

The repo also includes a GitHub Actions workflow at
`.github/workflows/freebsd.yml` that runs the checks inside a FreeBSD VM.

## GitHub Remote

GitHub CLI is expected either on `PATH` as `gh` or at
`%LOCALAPPDATA%\VoidBSD\tools\bin\gh.exe`. To authenticate and create/push a
public GitHub repo:

```powershell
& "$env:LOCALAPPDATA\VoidBSD\tools\bin\gh.exe" auth login
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/setup-github.ps1
```

Use `-Visibility private` only if you intentionally want the repo private.

## Zen Browser

Zen currently publishes official downloads for macOS, Windows, and Linux. This
project still has a Zen install path:

```sh
ZEN_PKG_URL=https://example.invalid/zen-browser-freebsd.pkg sh scripts/install-voidbsd.sh
```

If a native `zen-browser` package appears in your configured FreeBSD package
repo, the installer will use it. If neither a package nor `ZEN_PKG_URL` is
available, the installer installs Firefox so the desktop image remains usable.
Set `VOIDBSD_REQUIRE_ZEN=yes` to make missing Zen support fail the install.

## Useful Overrides

- `ROOTDIR=/mnt`: apply the setup into a mounted FreeBSD root instead of `/`.
- `FREEBSD_VERSION=15.1-RELEASE`: release set used by `build-raw-image.sh`.
- `MACHINE=amd64 ARCH=amd64`: release directory pair.
- `PKG_ABI=FreeBSD:15:amd64`: package ABI override for cross-release image
  builds. The image builder sets this automatically from `FREEBSD_VERSION`.
- `IMAGE_SIZE=20G`: raw image size.
- `ISO_FLAVOR=bootonly`: source ISO flavor for `build-installer-iso.sh`.
- `SOURCE_ISO=/path/to/FreeBSD-15.1-RELEASE-amd64-bootonly.iso`: reuse an
  existing FreeBSD ISO for `build-installer-iso.sh`.
- `VOIDBSD_ALLOW_BOOT_DISK_WIPE=yes`: expert-only override that allows the ISO
  setup to offer mounted/boot media as wipe targets.
- `VOIDBSD_INSTALL_ZEN=no`: skip the Zen hook entirely.
- `VOIDBSD_REQUIRE_ZEN=yes`: fail if Zen cannot be installed natively.

## Notes

This is a build recipe, not a fork of FreeBSD. It keeps the base system stock
and layers desktop packages plus `/usr/local` configuration on top.
