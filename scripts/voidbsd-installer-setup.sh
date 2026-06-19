#!/bin/sh
set -u

BACKTITLE="VoidBSD Setup"
DIST_SET="base.txz kernel.txz voidbsd.txz"
LOG=/tmp/voidbsd-installer-setup.log

log() {
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG" 2>/dev/null || true
}

dialog_tool() {
	if command -v bsddialog >/dev/null 2>&1; then
		printf '%s\n' bsddialog
	elif command -v dialog >/dev/null 2>&1; then
		printf '%s\n' dialog
	else
		return 1
	fi
}

show_msg() {
	title=$1
	text=$2
	if tool=$(dialog_tool); then
		"$tool" --backtitle "$BACKTITLE" --title "$title" --msgbox "$text" 12 72
	else
		printf '\n%s\n%s\n\n' "$title" "$text"
		printf 'Press Enter to continue... '
		read -r _answer
	fi
}

choose_menu() {
	title=$1
	text=$2
	shift 2

	if tool=$(dialog_tool); then
		exec 3>&1
		choice=$("$tool" --backtitle "$BACKTITLE" --title "$title" --menu "$text" 18 76 8 "$@" 2>&1 1>&3)
		status=$?
		exec 3>&-
		[ "$status" -eq 0 ] || return 1
		printf '%s\n' "$choice"
	else
		printf '\n%s\n%s\n' "$title" "$text"
		i=1
		for item in "$@"; do
			if [ $((i % 2)) -eq 1 ]; then
				tag=$item
			else
				printf '  %s) %s - %s\n' "$(( (i + 1) / 2 ))" "$tag" "$item"
			fi
			i=$((i + 1))
		done
		printf 'Select: '
		read -r selected
		i=1
		for item in "$@"; do
			if [ $((i % 2)) -eq 1 ]; then
				tag=$item
				idx=$(( (i + 1) / 2 ))
				[ "$selected" = "$idx" ] && printf '%s\n' "$tag" && return 0
			fi
			i=$((i + 1))
		done
		return 1
	fi
}

input_box() {
	title=$1
	text=$2
	default=${3:-}

	if tool=$(dialog_tool); then
		exec 3>&1
		value=$("$tool" --backtitle "$BACKTITLE" --title "$title" --inputbox "$text" 10 72 "$default" 2>&1 1>&3)
		status=$?
		exec 3>&-
		[ "$status" -eq 0 ] || return 1
		printf '%s\n' "$value"
	else
		printf '%s [%s]: ' "$text" "$default"
		read -r value
		[ -n "$value" ] || value=$default
		printf '%s\n' "$value"
	fi
}

normalize_disk_parent() {
	provider=$1
	provider=${provider#/dev/}
	provider=${provider%.eli}
	case "$provider" in
		*n[0-9]p[0-9]*) printf '%s\n' "${provider%%p[0-9]*}" ;;
		*p[0-9]*) printf '%s\n' "${provider%%p[0-9]*}" ;;
		*s[0-9][a-z]) printf '%s\n' "${provider%%s[0-9][a-z]}" ;;
		*s[0-9]) printf '%s\n' "${provider%%s[0-9]}" ;;
		*) printf '%s\n' "$provider" ;;
	esac
}

mounted_disk_parents() {
	mount | awk '$1 ~ "^/dev/" { sub("^/dev/", "", $1); print $1 }' | while IFS= read -r provider; do
		case "$provider" in
			ufs/*|iso9660/*|label/*)
				if command -v glabel >/dev/null 2>&1; then
					resolved=$(glabel status 2>/dev/null | awk -v name="$provider" '$1 == name { print $3; exit }')
					[ -n "$resolved" ] && provider=$resolved
				fi
				;;
		esac
		normalize_disk_parent "$provider"
	done | sort -u
}

disk_size() {
	disk=$1
	if command -v diskinfo >/dev/null 2>&1; then
		bytes=$(diskinfo -v "/dev/$disk" 2>/dev/null | awk '/bytes$/ { print $1; exit }')
		if [ -n "$bytes" ]; then
			awk -v b="$bytes" 'BEGIN {
				gb = b / 1000000000;
				if (gb >= 1000) {
					printf "%.1f TB", gb / 1000;
				} else {
					printf "%.1f GB", gb;
				}
			}'
			return 0
		fi
	fi
	printf 'unknown size'
}

safe_disks() {
	excluded=$(mounted_disk_parents)
	sysctl -n kern.disks 2>/dev/null | tr ' ' '\n' | while IFS= read -r disk; do
		[ -n "$disk" ] || continue
		case "$disk" in
			cd*|acd*|fd*|md*) continue ;;
		esac
		[ -c "/dev/$disk" ] || continue
		if printf '%s\n' "$excluded" | grep -qx "$disk"; then
			[ "${VOIDBSD_ALLOW_BOOT_DISK_WIPE:-no}" = "yes" ] || continue
		fi
		printf '%s\n' "$disk"
	done
}

choose_region() {
	choice=$(choose_menu "Region" "Pick the closest region. You can still adjust details in the FreeBSD installer." \
		US_PACIFIC "United States - Pacific" \
		US_EASTERN "United States - Eastern" \
		GB "United Kingdom" \
		EU_CENTRAL "Europe - Central" \
		IN "India" \
		JP "Japan" \
		UTC "UTC / Server default" \
		CUSTOM "Type timezone manually") || return 1

	case "$choice" in
		US_PACIFIC) VOIDBSD_TIMEZONE=America/Los_Angeles; VOIDBSD_KEYMAP=us.kbd; VOIDBSD_LOCALE=en_US.UTF-8 ;;
		US_EASTERN) VOIDBSD_TIMEZONE=America/New_York; VOIDBSD_KEYMAP=us.kbd; VOIDBSD_LOCALE=en_US.UTF-8 ;;
		GB) VOIDBSD_TIMEZONE=Europe/London; VOIDBSD_KEYMAP=uk.kbd; VOIDBSD_LOCALE=en_GB.UTF-8 ;;
		EU_CENTRAL) VOIDBSD_TIMEZONE=Europe/Berlin; VOIDBSD_KEYMAP=us.kbd; VOIDBSD_LOCALE=en_US.UTF-8 ;;
		IN) VOIDBSD_TIMEZONE=Asia/Kolkata; VOIDBSD_KEYMAP=us.kbd; VOIDBSD_LOCALE=en_US.UTF-8 ;;
		JP) VOIDBSD_TIMEZONE=Asia/Tokyo; VOIDBSD_KEYMAP=jp.kbd; VOIDBSD_LOCALE=ja_JP.UTF-8 ;;
		UTC) VOIDBSD_TIMEZONE=UTC; VOIDBSD_KEYMAP=us.kbd; VOIDBSD_LOCALE=en_US.UTF-8 ;;
		CUSTOM)
			VOIDBSD_TIMEZONE=$(input_box "Timezone" "Timezone name, for example America/Los_Angeles" "UTC") || return 1
			VOIDBSD_KEYMAP=$(input_box "Keyboard" "FreeBSD keymap name" "us.kbd") || return 1
			VOIDBSD_LOCALE=$(input_box "Locale" "Locale name" "en_US.UTF-8") || return 1
			;;
	esac

	export VOIDBSD_TIMEZONE VOIDBSD_KEYMAP VOIDBSD_LOCALE
	log "region timezone=$VOIDBSD_TIMEZONE keymap=$VOIDBSD_KEYMAP locale=$VOIDBSD_LOCALE"
}

write_region_hint() {
	tmpetc=${BSDINSTALL_TMPETC:-/tmp/bsdinstall_etc}
	mkdir -p "$tmpetc"

	cat > /tmp/voidbsd-region.env <<EOF
VOIDBSD_TIMEZONE='$VOIDBSD_TIMEZONE'
VOIDBSD_KEYMAP='$VOIDBSD_KEYMAP'
VOIDBSD_LOCALE='$VOIDBSD_LOCALE'
EOF

	if [ -n "${VOIDBSD_KEYMAP:-}" ]; then
		printf 'keymap="%s"\n' "$VOIDBSD_KEYMAP" >> "$tmpetc/rc.conf"
	fi

	if [ -n "${VOIDBSD_TIMEZONE:-}" ] && [ -r "/usr/share/zoneinfo/$VOIDBSD_TIMEZONE" ]; then
		cp "/usr/share/zoneinfo/$VOIDBSD_TIMEZONE" "$tmpetc/localtime"
	fi
}

confirm_wipe() {
	disk=$1
	size=$(disk_size "$disk")
	text="This will erase /dev/$disk ($size) and install VoidBSD there.

This screen refuses to wipe mounted installer/current-system disks unless VOIDBSD_ALLOW_BOOT_DISK_WIPE=yes is set.

Type exactly: WIPE $disk"
	confirm=$(input_box "Confirm Wipe" "$text" "") || return 1
	[ "$confirm" = "WIPE $disk" ]
}

choose_wipe_disk() {
	disks=$(safe_disks)
	if [ -z "$disks" ]; then
		show_msg "No Safe Disk" "No wipe-safe install disk was found. Choose guided/manual setup instead."
		return 1
	fi

	set --
	for disk in $disks; do
		set -- "$@" "$disk" "$(disk_size "$disk")"
	done

	disk=$(choose_menu "Wipe Disk" "Choose the disk to erase and install VoidBSD onto." "$@") || return 1
	confirm_wipe "$disk" || {
		show_msg "Not Wiping" "Confirmation did not match. No disk was erased."
		return 1
	}

	export PARTITIONS="$disk"
	log "wipe mode selected disk=$disk"
}

choose_disk_mode() {
	mode=$(choose_menu "Disk Setup" "Choose how VoidBSD should use storage." \
		USE "Use disk with FreeBSD guided/manual setup. Safest for dual-boot or existing data." \
		WIPE "Wipe disk and install VoidBSD. Requires disk selection and typed confirmation." \
		SHELL "Open a shell. Advanced manual recovery/setup.") || return 1

	case "$mode" in
		USE)
			unset PARTITIONS
			log "use disk guided/manual mode"
			;;
		WIPE)
			choose_wipe_disk || choose_disk_mode
			;;
		SHELL)
			show_msg "Shell" "Type exit when you want to return to VoidBSD Setup."
			/bin/sh
			choose_disk_mode
			;;
	esac
}

apply_current_keymap() {
	[ -n "${VOIDBSD_KEYMAP:-}" ] || return 0
	if command -v kbdcontrol >/dev/null 2>&1; then
		kbdcontrol -l "$VOIDBSD_KEYMAP" >/dev/null 2>&1 || true
	fi
}

run_installer() {
	export DISTRIBUTIONS="$DIST_SET"
	export BSDINSTALL_CONFIGCURRENT=YES
	export BSDINSTALL_SKIP_KEYMAP=YES
	export BSDINSTALL_SKIP_TIME=YES
	if [ -z "${BSDINSTALL_DISTSITE:-}" ]; then
		release=$(freebsd-version -u 2>/dev/null | sed 's/-p[0-9][0-9]*$//' || true)
		[ -n "$release" ] || release="15.1-RELEASE"
		arch=$(uname -m)
		export BSDINSTALL_DISTSITE="https://download.freebsd.org/releases/$arch/$arch/$release/"
	fi
	write_region_hint
	if [ -n "${PARTITIONS:-}" ]; then
		disk_mode="wipe $PARTITIONS"
	else
		disk_mode="guided/manual"
	fi

	show_msg "Ready" "VoidBSD will now start the FreeBSD installer.

Region: ${VOIDBSD_TIMEZONE:-unset}
Disk mode: $disk_mode

The standard installer still handles hostname, networking, users, and passwords."

	if bsdinstall auto; then
		log "bsdinstall completed"
	else
		show_msg "Installer Exit" "The installer exited or was cancelled. A shell will open for recovery."
		/bin/sh
	fi
}

main() {
	clear
	show_msg "Welcome" "VoidBSD Setup keeps the installer lean:

1. Pick region.
2. Choose Use disk or a guarded Wipe disk install.
3. Continue in the standard FreeBSD installer."

	choose_region || exit 1
	apply_current_keymap
	choose_disk_mode || exit 1
	run_installer
}

main "$@"
