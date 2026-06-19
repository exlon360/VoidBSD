#!/bin/sh
set -eu

die() {
	printf '%s\n' "error: $*" >&2
	exit 1
}

info() {
	printf '%s\n' "==> $*" >&2
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

project_root() {
	CDPATH= cd -- "$(dirname -- "$0")/.." && pwd
}

copy_project() {
	info "Copying project payload"
	mkdir -p "$DIST_STAGE/usr/local/voidbsd"
	(
		cd "$PROJECT_ROOT"
		tar \
			--exclude './.git' \
			--exclude './out' \
			--exclude './work' \
			--exclude './*.iso' \
			--exclude './*.raw' \
			-cf - .
	) | (
		cd "$DIST_STAGE/usr/local/voidbsd"
		tar -xpf -
	)
}

write_bootstrap_service() {
	info "Writing first-boot bootstrap service"
	mkdir -p "$DIST_STAGE/usr/local/etc/rc.d" "$DIST_STAGE/etc/rc.conf.d"

	cat > "$DIST_STAGE/usr/local/etc/rc.d/voidbsd_bootstrap" <<'EOF'
#!/bin/sh

# PROVIDE: voidbsd_bootstrap
# REQUIRE: NETWORKING
# BEFORE: LOGIN
# KEYWORD: nojail

. /etc/rc.subr

name=voidbsd_bootstrap
rcvar=voidbsd_bootstrap_enable
start_cmd=voidbsd_bootstrap_start

voidbsd_bootstrap_start() {
	log=/var/log/voidbsd-bootstrap.log
	project=/usr/local/voidbsd

	echo "VoidBSD bootstrap starting at $(date)" >> "$log"

	if [ ! -x "$project/scripts/install-voidbsd.sh" ]; then
		echo "VoidBSD project payload missing: $project" >> "$log"
		return 1
	fi

	if ROOTDIR=/ sh "$project/scripts/install-voidbsd.sh" >> "$log" 2>&1; then
		echo "VoidBSD bootstrap completed at $(date)" >> "$log"
		rm -f /etc/rc.conf.d/voidbsd_bootstrap
		sysrc voidbsd_bootstrap_enable=NO >/dev/null 2>&1 || true
		shutdown -r +1 "VoidBSD desktop bootstrap complete"
	else
		echo "VoidBSD bootstrap failed at $(date); leaving service enabled for retry" >> "$log"
		return 1
	fi
}

load_rc_config "$name"
: ${voidbsd_bootstrap_enable:=NO}
run_rc_command "$1"
EOF

	chmod 555 "$DIST_STAGE/usr/local/etc/rc.d/voidbsd_bootstrap"
	cat > "$DIST_STAGE/etc/rc.conf.d/voidbsd_bootstrap" <<'EOF'
voidbsd_bootstrap_enable="YES"
EOF
}

create_distribution_set() {
	info "Creating voidbsd.txz distribution set"
	mkdir -p "$ISO_ROOT/usr/freebsd-dist"
	tar -cJpf "$ISO_ROOT/usr/freebsd-dist/voidbsd.txz" -C "$DIST_STAGE" .

	hash=$(sha256 -q "$ISO_ROOT/usr/freebsd-dist/voidbsd.txz")
	nfiles=$(tar tvf "$ISO_ROOT/usr/freebsd-dist/voidbsd.txz" | wc -l | tr -d ' ')
	manifest="$ISO_ROOT/usr/freebsd-dist/MANIFEST"
	tmp_manifest="$manifest.tmp"

	if [ ! -f "$manifest" ]; then
		info "Fetching FreeBSD distribution MANIFEST"
		fetch -o "$manifest" "$DIST_URL/MANIFEST"
	fi

	if [ -f "$manifest" ]; then
		grep -v '^voidbsd.txz	' "$manifest" > "$tmp_manifest" || true
	else
		: > "$tmp_manifest"
	fi

	printf 'voidbsd.txz\t%s\t%s\tvoidbsd\t"VoidBSD desktop bootstrap"\ton\n' "$hash" "$nfiles" >> "$tmp_manifest"
	mv "$tmp_manifest" "$manifest"
}

fetch_source_iso() {
	if [ -n "${SOURCE_ISO:-}" ]; then
		[ -f "$SOURCE_ISO" ] || die "SOURCE_ISO does not exist: $SOURCE_ISO"
		printf '%s\n' "$SOURCE_ISO"
		return 0
	fi

	iso_name="FreeBSD-$FREEBSD_VERSION-$ARCH-$ISO_FLAVOR.iso"
	iso_path="$WORKDIR/$iso_name"
	iso_url="${ISO_URL:-https://download.freebsd.org/releases/ISO-IMAGES/$RELEASE_SERIES/$iso_name}"

	if [ ! -f "$iso_path" ]; then
		info "Fetching $iso_url"
		fetch -o "$iso_path" "$iso_url"
	fi

	printf '%s\n' "$iso_path"
}

extract_iso() {
	info "Extracting source ISO"
	rm -rf "$ISO_ROOT"
	mkdir -p "$ISO_ROOT"
	tar -xpf "$SOURCE_ISO_PATH" -C "$ISO_ROOT"
}

install_setup_launcher() {
	info "Installing VoidBSD setup launcher into ISO"
	mkdir -p "$ISO_ROOT/usr/local/libexec/voidbsd"
	cp "$PROJECT_ROOT/scripts/voidbsd-installer-setup.sh" "$ISO_ROOT/usr/local/libexec/voidbsd/installer-setup.sh"
	chmod 555 "$ISO_ROOT/usr/local/libexec/voidbsd/installer-setup.sh"

	if [ -f "$ISO_ROOT/etc/rc.local" ] && [ ! -f "$ISO_ROOT/etc/rc.local.freebsd" ]; then
		cp "$ISO_ROOT/etc/rc.local" "$ISO_ROOT/etc/rc.local.freebsd"
	fi

	cat > "$ISO_ROOT/etc/rc.local" <<'EOF'
#!/bin/sh

mkdir -p /tmp/bsdinstall_etc

if [ -x /usr/local/libexec/voidbsd/installer-setup.sh ]; then
	exec /usr/local/libexec/voidbsd/installer-setup.sh
fi

if [ -x /etc/rc.local.freebsd ]; then
	exec /etc/rc.local.freebsd
fi

exec /usr/libexec/bsdinstall/startbsdinstall primary
EOF
	chmod 555 "$ISO_ROOT/etc/rc.local"
}

fetch_release_tooling() {
	tool_root="$WORKDIR/release"
	src_ref=${FREEBSD_SRC_REF:-"releng/$RELEASE_SERIES"}

	mkdir -p "$tool_root/$TARGET" "$tool_root/scripts"

	fetch_from_ref() {
		ref=$1
		fetch -o "$tool_root/$TARGET/mkisoimages.sh" "https://raw.githubusercontent.com/freebsd/freebsd-src/$ref/release/$TARGET/mkisoimages.sh"
		fetch -o "$tool_root/scripts/tools.subr" "https://raw.githubusercontent.com/freebsd/freebsd-src/$ref/release/scripts/tools.subr"
	}

	info "Fetching FreeBSD release tooling from freebsd-src $src_ref"
	if ! fetch_from_ref "$src_ref"; then
		info "Falling back to freebsd-src main for release tooling"
		fetch_from_ref main
	fi

	chmod 555 "$tool_root/$TARGET/mkisoimages.sh"
	printf '%s\n' "$tool_root/$TARGET/mkisoimages.sh"
}

build_iso() {
	mkiso="$SRC_DIR/release/$TARGET/mkisoimages.sh"
	if [ ! -f "$mkiso" ]; then
		mkiso=$(fetch_release_tooling)
	fi

	if [ -e "$OUTPUT_ISO" ] && [ "${FORCE:-no}" != "yes" ]; then
		die "output ISO exists; set FORCE=yes to overwrite: $OUTPUT_ISO"
	fi

	rm -f "$OUTPUT_ISO" "$OUTPUT_ISO.sha256"

	info "Repacking bootable ISO"
	sh "$mkiso" -b "$VOLUME_LABEL" "$OUTPUT_ISO" "$ISO_ROOT"
	sha256 "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"
}

main() {
	PROJECT_ROOT=$(project_root)
	FREEBSD_VERSION=${FREEBSD_VERSION:-15.1-RELEASE}
	RELEASE_SERIES=${RELEASE_SERIES:-$(printf '%s\n' "$FREEBSD_VERSION" | sed 's/-.*//')}
	TARGET=${TARGET:-amd64}
	ARCH=${ARCH:-amd64}
	ISO_FLAVOR=${ISO_FLAVOR:-bootonly}
	SRC_DIR=${SRC_DIR:-/usr/src}
	OUTDIR=${OUTDIR:-"$PROJECT_ROOT/out"}
	WORKDIR=${WORKDIR:-"$OUTDIR/iso-work"}
	ISO_ROOT="$WORKDIR/iso-root"
	DIST_STAGE="$WORKDIR/voidbsd-dist"
	VOLUME_LABEL=${VOLUME_LABEL:-$(printf 'VOIDBSD_%s_%s' "$RELEASE_SERIES" "$ARCH" | tr '.-' '__' | tr '[:lower:]' '[:upper:]')}
	DIST_URL=${DIST_URL:-"https://download.freebsd.org/releases/$TARGET/$ARCH/$FREEBSD_VERSION"}
	OUTPUT_ISO=${OUTPUT_ISO:-"$OUTDIR/voidbsd-$FREEBSD_VERSION-$ARCH-$ISO_FLAVOR.iso"}

	[ "$(uname -s)" = "FreeBSD" ] || die "run this ISO builder on FreeBSD"

	for cmd in fetch grep mkdir mv rm sed sha256 tar tr wc; do
		need_cmd "$cmd"
	done

	mkdir -p "$OUTDIR" "$WORKDIR"

	SOURCE_ISO_PATH=$(fetch_source_iso)
	extract_iso
	install_setup_launcher

	rm -rf "$DIST_STAGE"
	mkdir -p "$DIST_STAGE"
	copy_project
	write_bootstrap_service
	create_distribution_set
	build_iso

	info "ISO build complete: $OUTPUT_ISO"
	info "Checksum written: $OUTPUT_ISO.sha256"
}

main "$@"
