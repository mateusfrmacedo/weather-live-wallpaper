#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
# Run build-native-prototype.sh first.
sdk="$(xcrun --sdk macosx --show-sdk-path)"
app="$PWD/Build/Native Mode Tests.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/PlugIns"
ditto "${WEATHER_MODE_TEST_APP:-Build/Weather Wallpaper Native.app}/Contents/PlugIns/DesktopBridge.bundle" "$app/Contents/PlugIns/DesktopBridge.bundle"
cp Sources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier local.mateus.WeatherWallpaper.NativeModeTests' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleExecutable ModeTests' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName ModeTestScene' "$app/Contents/Info.plist"
xcrun clang -fobjc-arc -target arm64-apple-ios17.0-macabi -isysroot "$sdk" \
 -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
 -framework UIKit -framework Foundation -framework QuartzCore -framework ImageIO -framework CoreGraphics -framework MetalKit -framework Metal -framework WeatherKit -framework AVFoundation -framework CoreVideo -framework CoreMedia \
 Tests/NativeWallpaper/modes.m Sources/NativeWallpaper/SceneExporter.m Build/WeatherRuntime.o Build/WeatherService.o Sources/SwiftCall.s -o "$app/Contents/MacOS/ModeTests"
codesign --force --sign - "$app"
log="$PWD/Build/test-native-modes.log"
: > "$log"
open -W -n --stdout "$log" --stderr "$log" "$app"
cat "$log"
rg -q 'PASS: mode changes' "$log"
