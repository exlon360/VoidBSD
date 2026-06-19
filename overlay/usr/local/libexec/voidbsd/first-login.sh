#!/bin/sh
set -u

wallpaper=/usr/local/share/wallpapers/voidbsd-night/contents/images/3840x2160.png

log() {
	logger -t voidbsd-first-login "$*" 2>/dev/null || true
}

kwrite() {
	for tool in kwriteconfig6 kwriteconfig5 kwriteconfig; do
		if command -v "$tool" >/dev/null 2>&1; then
			"$tool" "$@"
			return $?
		fi
	done
	return 1
}

apply_shortcuts() {
	value=$(printf 'Alt+Space\tAlt+F2,Alt+Space\tAlt+F2,KRunner')
	kwrite --file kglobalshortcutsrc --group krunner.desktop --key _launch "$value" || true
	kwrite --file kglobalshortcutsrc --group org.kde.krunner.desktop --key _launch "$value" || true
}

apply_colors() {
	if command -v lookandfeeltool >/dev/null 2>&1; then
		lookandfeeltool -a org.kde.breezedark.desktop >/dev/null 2>&1 || true
	fi

	if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
		plasma-apply-colorscheme VoidNight >/dev/null 2>&1 || true
	fi
}

apply_wallpaper_cli() {
	if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
		plasma-apply-wallpaperimage "$wallpaper" >/dev/null 2>&1 && return 0
	fi
	return 1
}

apply_plasma_script() {
	script=$(cat <<'JS'
var wallpaper = "file:///usr/local/share/wallpapers/voidbsd-night/contents/images/3840x2160.png";
var ds = desktops();
for (var i = 0; i < ds.length; i++) {
    ds[i].wallpaperPlugin = "org.kde.image";
    ds[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    ds[i].writeConfig("Image", wallpaper);
}

var hasBottomPanel = false;
var ps = panels();
for (var j = 0; j < ps.length; j++) {
    if (String(ps[j].location).toLowerCase() == "bottom") {
        hasBottomPanel = true;
    }
}

if (!hasBottomPanel) {
    var panel = new Panel;
    panel.location = "bottom";
    panel.height = 44;
    panel.addWidget("org.kde.plasma.kickoff");
    panel.addWidget("org.kde.plasma.icontasks");
    panel.addWidget("org.kde.plasma.marginsseparator");
    panel.addWidget("org.kde.plasma.systemtray");
    panel.addWidget("org.kde.plasma.digitalclock");
}
JS
)

	for qdbus in qdbus6 qdbus-qt6 qdbus; do
		if command -v "$qdbus" >/dev/null 2>&1; then
			"$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" >/dev/null 2>&1 && return 0
		fi
	done

	return 1
}

seed_kitty() {
	mkdir -p "$config_home/kitty"
	if [ ! -f "$config_home/kitty/kitty.conf" ] && [ -f /usr/local/etc/xdg/kitty/kitty.conf ]; then
		cp /usr/local/etc/xdg/kitty/kitty.conf "$config_home/kitty/kitty.conf"
	fi
}

seed_fastfetch() {
	mkdir -p "$config_home/fastfetch"
	if [ ! -f "$config_home/fastfetch/config.jsonc" ] && [ -f /usr/local/etc/xdg/fastfetch/config.jsonc ]; then
		cp /usr/local/etc/xdg/fastfetch/config.jsonc "$config_home/fastfetch/config.jsonc"
	fi
}

main() {
	[ -n "${HOME:-}" ] || exit 0

	config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
	done_file="$config_home/voidbsd/first-login.done"

	[ -f "$done_file" ] && exit 0

	mkdir -p "$config_home/voidbsd"

	seed_kitty
	seed_fastfetch
	apply_shortcuts
	apply_colors

	sleep 4
	apply_wallpaper_cli || apply_plasma_script || log "could not apply Plasma wallpaper/layout"

	touch "$done_file"
}

main "$@"
