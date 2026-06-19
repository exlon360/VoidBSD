# ISO Image Resources

Checked on 2026-06-19.

## Best References

- FreeBSD image choices:
  <https://www.freebsd.org/where/>

  FreeBSD documents `disc1`, `dvd1`, `bootonly`, `memstick`, and
  `mini-memstick`; `dvd1` is the safest base for this project because it carries
  the traditional distribution sets needed for custom `bsdinstall` payloads.

- FreeBSD release builder:
  <https://man.freebsd.org/cgi/man.cgi?query=release&sektion=7&format=html>

  The `release(7)` page documents the `cdrom`, `dvdrom`, and `memstick`
  targets. It also points at `/usr/src/release`, where the official release
  media scripts live.

- FreeBSD installer scripting:
  <https://man.freebsd.org/cgi/man.cgi?query=bsdinstall&sektion=8&format=html>

  `bsdinstall(8)` documents scripted installs, custom distributions, and
  `/etc/installerconfig`. The important bit for VoidBSD is that release media
  can carry extra `.txz` distribution sets under `/usr/freebsd-dist`.

- Official ISO repack script:
  <https://raw.githubusercontent.com/freebsd/freebsd-src/main/release/amd64/mkisoimages.sh>

  The architecture script wraps `makefs`, creates BIOS/UEFI boot entries, and
  uses `mkimg` to make hybrid boot metadata.

- Low-level tools:
  <https://man.freebsd.org/cgi/man.cgi?query=makefs&sektion=8&format=html>
  and
  <https://man.freebsd.org/cgi/man.cgi?query=mkimg&sektion=1&format=html>

  These are useful if you outgrow the project script and want to build your own
  release media pipeline.

- FreeBSD installation handbook:
  <https://docs.freebsd.org/en/books/handbook/bsdinstall/>

  Use this for device preparation, checksum verification, and writing installer
  images to USB devices.

## Project ISO Workflow

Build the installer ISO on FreeBSD:

```sh
su -
cd /path/to/VoidBSD
sh scripts/build-installer-iso.sh
```

Output:

```text
out/voidbsd-15.1-RELEASE-amd64-dvd1.iso
out/voidbsd-15.1-RELEASE-amd64-dvd1.iso.sha256
```

The script:

1. Downloads or reuses the official FreeBSD `dvd1.iso`.
2. Extracts it into a work directory.
3. Installs the VoidBSD setup launcher into the ISO boot environment.
4. Builds `voidbsd.txz`, a custom distribution set containing this project and
   a one-shot first-boot bootstrap service.
5. Adds `voidbsd.txz` to `/usr/freebsd-dist/MANIFEST`.
6. Rebuilds a bootable BIOS/UEFI ISO using `/usr/src/release/amd64/mkisoimages.sh`.

It does not add `/etc/installerconfig` by default, so it does not perform an
unattended disk wipe. The VoidBSD setup launcher is interactive and then hands
off to FreeBSD's normal `bsdinstall` flow.

## Installing From The ISO

1. Boot the ISO in a VM or burn it to DVD.
2. Pick a region in VoidBSD Setup.
3. Choose `Use disk` for FreeBSD guided/manual partitioning, or `Wipe disk`
   for a selected full-disk install.
4. If choosing `Wipe disk`, type the exact confirmation shown on screen.
5. Continue through the normal FreeBSD installer.
6. When distribution sets are shown, leave `voidbsd` selected.
7. Finish the install and reboot into the new system.
8. On first boot, `voidbsd_bootstrap` installs KDE Plasma, SDDM, Kitty,
   the wallpaper/theme defaults, and the Zen hook or Firefox fallback.
9. The bootstrap disables itself after a successful run and schedules a reboot.

## Wipe Safety

The `Wipe disk` option is intentionally guarded:

- It only lists disk devices reported by `kern.disks`.
- It filters out optical, memory disk, and floppy-style devices.
- It excludes mounted disk parents, including common installer-media labels
  resolved through `glabel status`.
- It requires typing `WIPE <disk>` before setting `PARTITIONS=<disk>` for
  `bsdinstall`.

The expert override `VOIDBSD_ALLOW_BOOT_DISK_WIPE=yes` exists for unusual lab
media only. Do not use it on a workstation you care about.

The bootstrap needs network access for packages. If the first boot has no
network, fix networking and reboot; the bootstrap stays enabled until it
finishes successfully.

## USB Note

FreeBSD's handbook recommends `memstick.img` for USB installs. The ISO produced
here is best for VMs and optical media. FreeBSD's `mkisoimages.sh` creates
hybrid boot metadata, so writing the ISO to USB may work on many machines, but
for dependable USB media use the project raw-image path or extend the official
release `memstick` target.
