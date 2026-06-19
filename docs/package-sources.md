# Package And Platform Notes

Checked on 2026-06-19:

- FreeBSD lists `15.1` as the current production release:
  <https://www.freebsd.org/releases/>
- The FreeBSD Handbook documents Plasma package paths, including
  `pkg install kde`, `pkg install plasma6-plasma`, `pkg install sddm`, and
  enabling `dbus_enable` and `sddm_enable` in `rc.conf`:
  <https://docs.freebsd.org/en/books/handbook/desktop/>
- FreshPorts describes `x11/kde` as the Plasma Desktop and KDE Applications
  meta port:
  <https://www.freshports.org/x11/kde/>
- Zen's official download page currently advertises macOS, Windows, and Linux,
  so this repo supports native FreeBSD Zen through `zen-browser` package
  discovery or a `ZEN_PKG_URL` override:
  <https://zen-browser.app/download/>
- Fastfetch documents JSONC configuration and custom file-based logos:
  <https://github.com/fastfetch-cli/fastfetch/wiki/Configuration>
  and
  <https://github.com/fastfetch-cli/fastfetch/wiki/Logo-options>
- Fastfetch is available on FreeBSD through `pkg install fastfetch`:
  <https://github.com/fastfetch-cli/fastfetch>
- The FreeBSD GitHub Actions workflow uses `vmactions/freebsd-vm@v1`:
  <https://github.com/vmactions/freebsd-vm>
- FreeBSD release media starts the installer from `release/rc.local`, which
  VoidBSD wraps so its setup screen appears before `bsdinstall`:
  <https://raw.githubusercontent.com/freebsd/freebsd-src/main/release/rc.local>
