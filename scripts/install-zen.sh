#!/bin/sh
set -eu

warn() {
	printf '%s\n' "warning: $*" >&2
}

info() {
	printf '%s\n' "==> $*"
}

pkg_cmd() {
	if [ "$ROOTDIR" = "/" ]; then
		if [ -n "${PKG_ABI:-}" ]; then
			pkg -o "ABI=$PKG_ABI" "$@"
		else
			pkg "$@"
		fi
	else
		if [ -n "${PKG_ABI:-}" ]; then
			pkg -r "$ROOTDIR" -o "ABI=$PKG_ABI" "$@"
		else
			pkg -r "$ROOTDIR" "$@"
		fi
	fi
}

zen_is_installed() {
	pkg_cmd info -e zen-browser >/dev/null 2>&1
}

zen_exists_in_repo() {
	pkg_cmd search -q zen-browser 2>/dev/null | grep -Eq '^zen-browser(-[0-9].*)?$'
}

install_from_url() {
	tmp_pkg="${TMPDIR:-/tmp}/zen-browser-freebsd.pkg"
	fetch -o "$tmp_pkg" "$ZEN_PKG_URL"
	pkg_cmd add -f "$tmp_pkg"
	rm -f "$tmp_pkg"
}

main() {
	ROOTDIR=${ROOTDIR:-/}

	if zen_is_installed; then
		info "Zen Browser is already installed"
		return 0
	fi

	if zen_exists_in_repo; then
		info "Installing Zen Browser from configured FreeBSD package repo"
		pkg_cmd install -y zen-browser
		return 0
	fi

	if [ -n "${ZEN_PKG_URL:-}" ]; then
		info "Installing Zen Browser from ZEN_PKG_URL"
		install_from_url
		return 0
	fi

	warn "no native FreeBSD Zen Browser package was found"
	warn "set ZEN_PKG_URL to a trusted FreeBSD .pkg build to preinstall Zen"

	if [ "${VOIDBSD_REQUIRE_ZEN:-no}" = "yes" ]; then
		return 1
	fi

	info "Keeping Firefox installed as the browser fallback"
	pkg_cmd install -y firefox
}

main "$@"
