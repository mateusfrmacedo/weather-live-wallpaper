#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
Scripts/build-native-prototype.sh
sdk="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang -fobjc-arc -framework Foundation Tests/NativeWallpaper/update-policy.m -o Build/test-native-update-policy
Build/test-native-update-policy
log="$PWD/Build/native-export-test.log"
: > "$log"
open -W -n --env WEATHER_NATIVE_TEST_ONCE=1 --env WEATHER_NATIVE_TEST_HIDDEN=1 --stdout "$log" --stderr "$log" 'Build/Weather Wallpaper Native.app'
cat "$log"
rg -q 'PASS: native scene export' "$log"
Scripts/test-native-runtime.sh
