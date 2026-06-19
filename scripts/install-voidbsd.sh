#!/bin/sh
set -eu

die() {
	printf '%s\n' "error: $*" >&2
	exit 1
}

warn() {
	printf '%s\n' "warning: $*" >&2
}

info() {
	printf '%s\n' "==> $*"
}

project_root() {
	CDPATH= cd -- "$(dirname -- "$0")/.." && pwd
}

packages_from_file() {
	sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$1"
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

sysrc_set() {
	mkdir -p "$ROOTDIR/etc"
	touch "$ROOTDIR/etc/rc.conf"
	sysrc -f "$ROOTDIR/etc/rc.conf" "$1=$2" >/dev/null
}

copy_overlay() {
	info "Installing VoidBSD overlay"
	( cd "$PROJECT_ROOT/overlay" && tar -cf - . ) | ( cd "$ROOTDIR" && tar -xpf - )

	for path in \
		/usr/local/etc/rc.d/voidbsd_gpu_detect \
		/usr/local/libexec/voidbsd/first-login.sh
	do
		if [ -f "$ROOTDIR$path" ]; then
			chmod 555 "$ROOTDIR$path"
		fi
	done
}

configure_sddm_theme() {
	theme_dir="$ROOTDIR/usr/local/share/sddm/themes/breeze"
	if [ -d "$theme_dir" ]; then
		info "Setting SDDM Breeze background"
		cat > "$theme_dir/theme.conf.user" <<'EOF'
[General]
background=/usr/local/share/wallpapers/voidbsd-night/contents/images/3840x2160.png
type=image
EOF
	fi
}

install_required_packages() {
	required_packages=$(packages_from_file "$PROJECT_ROOT/pkg/required.txt" | tr '\n' ' ')
	if [ -n "$required_packages" ]; then
		info "Installing required packages"
		# Word splitting is intentional: package names come from our manifest.
		# shellcheck disable=SC2086
		pkg_cmd install -y $required_packages
	fi
}

install_optional_packages() {
	info "Installing optional packages"
	packages_from_file "$PROJECT_ROOT/pkg/optional.txt" | while IFS= read -r package; do
		if ! pkg_cmd install -y "$package"; then
			warn "optional package '$package' was not installed"
		fi
	done
}

configure_services() {
	info "Configuring FreeBSD services"
	sysrc_set dbus_enable YES
	sysrc_set sddm_enable YES
	sysrc_set powerd_enable YES
	sysrc_set voidbsd_gpu_detect_enable YES
}

main() {
	ROOTDIR=${ROOTDIR:-/}
	PROJECT_ROOT=$(project_root)

	[ "$(uname -s)" = "FreeBSD" ] || die "run this installer on FreeBSD"
	[ "$(id -u)" -eq 0 ] || die "run this installer as root"

	case "$ROOTDIR" in
		/*) ;;
		*) die "ROOTDIR must be an absolute path" ;;
	esac

	[ -d "$ROOTDIR" ] || die "ROOTDIR does not exist: $ROOTDIR"

	info "Bootstrapping pkg"
	pkg_cmd bootstrap -fy || true
	pkg_cmd update -f

	install_required_packages
	install_optional_packages
	copy_overlay
	configure_services
	configure_sddm_theme

	if [ "${VOIDBSD_INSTALL_ZEN:-yes}" = "yes" ]; then
		info "Running Zen Browser install hook"
		if ! ROOTDIR="$ROOTDIR" PKG_ABI="${PKG_ABI:-}" sh "$PROJECT_ROOT/scripts/install-zen.sh"; then
			if [ "${VOIDBSD_REQUIRE_ZEN:-no}" = "yes" ]; then
				die "Zen Browser is required but was not installed"
			fi
			warn "Zen Browser was not installed; Firefox fallback remains available"
		fi
	fi

	info "VoidBSD desktop setup complete"
}

main "$@"
