#!/bin/sh

if [ -t 1 ] && [ -z "${VOIDBSD_FASTFETCH_DONE:-}" ] && command -v fastfetch >/dev/null 2>&1; then
	VOIDBSD_FASTFETCH_DONE=1
	export VOIDBSD_FASTFETCH_DONE
	if [ -f "$HOME/.config/fastfetch/config.jsonc" ]; then
		fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
	elif [ -f /usr/local/etc/xdg/fastfetch/config.jsonc ]; then
		fastfetch --config /usr/local/etc/xdg/fastfetch/config.jsonc
	else
		fastfetch
	fi
fi

shell=${SHELL:-/bin/sh}
case "$shell" in
	*/terminal-login.sh|*/false|*/nologin|'') shell=/bin/sh ;;
esac

exec "$shell" -l
