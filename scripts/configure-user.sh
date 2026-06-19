#!/bin/sh
set -eu

die() {
	printf '%s\n' "error: $*" >&2
	exit 1
}

user_name=${1:-}
[ -n "$user_name" ] || die "usage: sh scripts/configure-user.sh <user>"
[ "$(uname -s)" = "FreeBSD" ] || die "run this on FreeBSD"
[ "$(id -u)" -eq 0 ] || die "run this as root"

home_dir=$(pw usershow "$user_name" | awk -F: '{print $9}')
[ -d "$home_dir" ] || die "home directory not found for $user_name"

install -d -o "$user_name" -g "$user_name" "$home_dir/.config/kitty"
if [ ! -f "$home_dir/.config/kitty/kitty.conf" ]; then
	cp /usr/local/etc/xdg/kitty/kitty.conf "$home_dir/.config/kitty/kitty.conf"
	chown "$user_name:$user_name" "$home_dir/.config/kitty/kitty.conf"
fi

install -d -o "$user_name" -g "$user_name" "$home_dir/.config/fastfetch"
if [ ! -f "$home_dir/.config/fastfetch/config.jsonc" ] && [ -f /usr/local/etc/xdg/fastfetch/config.jsonc ]; then
	cp /usr/local/etc/xdg/fastfetch/config.jsonc "$home_dir/.config/fastfetch/config.jsonc"
	chown "$user_name:$user_name" "$home_dir/.config/fastfetch/config.jsonc"
fi

install -d -o "$user_name" -g "$user_name" "$home_dir/.config"
if [ ! -f "$home_dir/.config/kglobalshortcutsrc" ]; then
	cp /usr/local/share/voidbsd/defaults/kglobalshortcutsrc "$home_dir/.config/kglobalshortcutsrc"
	chown "$user_name:$user_name" "$home_dir/.config/kglobalshortcutsrc"
fi

printf '%s\n' "configured VoidBSD user defaults for $user_name"
