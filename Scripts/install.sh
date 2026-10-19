#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
Scripts/build-native-prototype.sh --release
target="$HOME/Applications/Weather Wallpaper.app"
if [[ -e "$target" ]]; then
 identity=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target/Contents/Info.plist")
 [[ "$identity" == local.mateus.WeatherWallpaper ]] || { echo "Outro aplicativo já ocupa o destino." >&2; exit 1; }
fi
mkdir -p "$HOME/Applications"
ditto "Build/ReleaseApp/Weather Wallpaper.app" "$target"
codesign --verify --deep --strict "$target"
echo "$target"
