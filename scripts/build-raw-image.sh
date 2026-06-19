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

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

project_root() {
	CDPATH= cd -- "$(dirname -- "$0")/.." && pwd
}

fetch_set() {
	set_name=$1
	if [ ! -f "$SETS_DIR/$set_name" ]; then
		info "Fetching $set_name"
		fetch -o "$SETS_DIR/$set_name" "$RELEASE_URL/$set_name"
	fi
}

cleanup() {
	set +e
	if [ -n "${MNT:-}" ]; then
		mount | grep -q " on $MNT/boot/efi " && umount "$MNT/boot/efi"
		mount | grep -q " on $MNT/dev " && umount "$MNT/dev"
		mount | grep -q " on $MNT " && umount "$MNT"
	fi
	if [ -n "${MD:-}" ]; then
		mdconfig -d -u "${MD#md}"
	fi
}

write_boot_config() {
	cat > "$MNT/etc/fstab" <<'EOF'
# Device                  Mountpoint  FStype   Options  Dump  Pass#
/dev/gpt/voidbsd-root    /           ufs      rw       1     1
/dev/gpt/voidbsd-efi     /boot/efi   msdosfs  rw       2     2
EOF

	cat >> "$MNT/boot/loader.conf" <<'EOF'
autoboot_delay="3"
vfs.root.mountfrom="ufs:/dev/gpt/voidbsd-root"
EOF
}

install_efi_loader() {
	case "$ARCH" in
		amd64) efi_name=bootx64.efi ;;
		aarch64) efi_name=bootaa64.efi ;;
		*) die "unsupported UEFI fallback loader name for ARCH=$ARCH" ;;
	esac

	mkdir -p "$MNT/boot/efi/efi/boot"
	cp "$MNT/boot/loader.efi" "$MNT/boot/efi/efi/boot/$efi_name"
}

prompt_for_root_password() {
	if [ "${SKIP_PASSWORD_PROMPT:-no}" = "yes" ]; then
		warn "root password prompt skipped; configure credentials before using this image"
		return 0
	fi

	if [ -t 0 ]; then
		info "Set the root password for the image"
		chroot "$MNT" passwd root
	else
		warn "no interactive terminal; root password was not set"
	fi
}

main() {
	PROJECT_ROOT=$(project_root)
	FREEBSD_VERSION=${FREEBSD_VERSION:-15.1-RELEASE}
	FREEBSD_MAJOR=${FREEBSD_VERSION%%.*}
	MACHINE=${MACHINE:-amd64}
	ARCH=${ARCH:-amd64}
	PKG_ABI=${PKG_ABI:-"FreeBSD:$FREEBSD_MAJOR:$ARCH"}
	IMAGE_SIZE=${IMAGE_SIZE:-20G}
	OUTDIR=${OUTDIR:-"$PROJECT_ROOT/out"}
	WORKDIR=${WORKDIR:-"$OUTDIR/work"}
	SETS_DIR="$WORKDIR/sets"
	MNT="$WORKDIR/mnt"
	IMAGE="$OUTDIR/voidbsd-$FREEBSD_VERSION-$ARCH.raw"
	RELEASE_URL=${RELEASE_URL:-"https://download.freebsd.org/releases/$MACHINE/$ARCH/$FREEBSD_VERSION"}
	MD=

	[ "$(uname -s)" = "FreeBSD" ] || die "run this image builder on FreeBSD"
	[ "$(id -u)" -eq 0 ] || die "run this image builder as root"

	for cmd in fetch tar truncate mdconfig gpart newfs newfs_msdos mount mount_msdosfs umount chroot pkg; do
		need_cmd "$cmd"
	done

	trap cleanup EXIT INT TERM

	mkdir -p "$OUTDIR" "$SETS_DIR" "$MNT"

	fetch_set base.txz
	fetch_set kernel.txz
	if [ "$ARCH" = "amd64" ]; then
		fetch_set lib32.txz
	fi

	if [ -e "$IMAGE" ]; then
		die "image already exists: $IMAGE"
	fi

	info "Creating raw disk image: $IMAGE"
	truncate -s "$IMAGE_SIZE" "$IMAGE"
	MD=$(mdconfig -a -t vnode -f "$IMAGE")

	gpart create -s gpt "$MD"
	gpart add -a 4k -s 260M -t efi -l voidbsd-efi "$MD"
	gpart add -a 4k -t freebsd-ufs -l voidbsd-root "$MD"
	newfs_msdos -F 32 -c 1 "/dev/${MD}p1"
	newfs -U "/dev/${MD}p2"

	mount "/dev/${MD}p2" "$MNT"
	tar -xpf "$SETS_DIR/base.txz" -C "$MNT"
	tar -xpf "$SETS_DIR/kernel.txz" -C "$MNT"
	if [ "$ARCH" = "amd64" ]; then
		tar -xpf "$SETS_DIR/lib32.txz" -C "$MNT"
	fi

	mkdir -p "$MNT/boot/efi" "$MNT/dev"
	mount_msdosfs "/dev/${MD}p1" "$MNT/boot/efi"
	mount -t devfs devfs "$MNT/dev"

	install_efi_loader
	gpart bootcode -b "$MNT/boot/pmbr" -p "$MNT/boot/gptboot" -i 2 "$MD"
	write_boot_config

	cp /etc/resolv.conf "$MNT/etc/resolv.conf"
	ROOTDIR="$MNT" PKG_ABI="$PKG_ABI" sh "$PROJECT_ROOT/scripts/install-voidbsd.sh"
	prompt_for_root_password

	info "Image build complete: $IMAGE"
}

main "$@"
