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
3. Builds `voidbsd.txz`, a custom distribution set containing this project and
   a one-shot first-boot bootstrap service.
4. Adds `voidbsd.txz` to `/usr/freebsd-dist/MANIFEST`.
5. Rebuilds a bootable BIOS/UEFI ISO using `/usr/src/release/amd64/mkisoimages.sh`.

It does not add `/etc/installerconfig` by default, so it does not perform an
unattended disk wipe. The FreeBSD installer remains interactive.

## Installing From The ISO

1. Boot the ISO in a VM or burn it to DVD.
2. Run the normal FreeBSD installer.
3. When distribution sets are shown, leave `voidbsd` selected.
4. Finish the install and reboot into the new system.
5. On first boot, `voidbsd_bootstrap` installs KDE Plasma, SDDM, Kitty,
   the wallpaper/theme defaults, and the Zen hook or Firefox fallback.
6. The bootstrap disables itself after a successful run and schedules a reboot.

The bootstrap needs network access for packages. If the first boot has no
network, fix networking and reboot; the bootstrap stays enabled until it
finishes successfully.

## USB Note

FreeBSD's handbook recommends `memstick.img` for USB installs. The ISO produced
here is best for VMs and optical media. FreeBSD's `mkisoimages.sh` creates
hybrid boot metadata, so writing the ISO to USB may work on many machines, but
for dependable USB media use the project raw-image path or extend the official
release `memstick` target.
