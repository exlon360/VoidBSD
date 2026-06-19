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

ROOTDIR=${ROOTDIR:-/}
case "$ROOTDIR" in
	/*) ;;
	*) die "ROOTDIR must be an absolute path" ;;
esac

user_record=$(pw -R "$ROOTDIR" usershow "$user_name")
uid=$(printf '%s\n' "$user_record" | awk -F: '{print $3}')
gid=$(printf '%s\n' "$user_record" | awk -F: '{print $4}')
home_dir=$(printf '%s\n' "$user_record" | awk -F: '{print $9}')
target_home="$ROOTDIR$home_dir"

[ -d "$target_home" ] || die "home directory not found for $user_name: $target_home"

target_path() {
	printf '%s%s\n' "$ROOTDIR" "$1"
}

install -d -o "$uid" -g "$gid" "$target_home/.config/kitty"
if [ ! -f "$target_home/.config/kitty/kitty.conf" ]; then
	cp "$(target_path /usr/local/etc/xdg/kitty/kitty.conf)" "$target_home/.config/kitty/kitty.conf"
	chown "$uid:$gid" "$target_home/.config/kitty/kitty.conf"
fi

install -d -o "$uid" -g "$gid" "$target_home/.config/fastfetch"
if [ ! -f "$target_home/.config/fastfetch/config.jsonc" ] && [ -f "$(target_path /usr/local/etc/xdg/fastfetch/config.jsonc)" ]; then
	cp "$(target_path /usr/local/etc/xdg/fastfetch/config.jsonc)" "$target_home/.config/fastfetch/config.jsonc"
	chown "$uid:$gid" "$target_home/.config/fastfetch/config.jsonc"
fi

install -d -o "$uid" -g "$gid" "$target_home/.config"
if [ ! -f "$target_home/.config/kglobalshortcutsrc" ]; then
	cp "$(target_path /usr/local/share/voidbsd/defaults/kglobalshortcutsrc)" "$target_home/.config/kglobalshortcutsrc"
	chown "$uid:$gid" "$target_home/.config/kglobalshortcutsrc"
fi

printf '%s\n' "configured VoidBSD user defaults for $user_name"
