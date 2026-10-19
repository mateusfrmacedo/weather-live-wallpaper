#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
Scripts/build.sh
sdk="$(xcrun --sdk macosx --show-sdk-path)"
app="$PWD/Build/Render Tests.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/PlugIns"
ditto "Build/Weather Wallpaper.app/Contents/PlugIns/DesktopBridge.bundle" "$app/Contents/PlugIns/DesktopBridge.bundle"
cp Sources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier local.mateus.WeatherWallpaper.RenderTests' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleExecutable RenderTests' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName RenderTestSceneDelegate' "$app/Contents/Info.plist"
xcrun clang -fobjc-arc -target arm64-apple-ios17.0-macabi -isysroot "$sdk" \
 -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
 -framework UIKit -framework Foundation -framework QuartzCore -framework ImageIO -framework CoreGraphics -framework MetalKit -framework Metal -framework WeatherKit \
 Tests/render-live.m Build/WeatherRuntime.o Build/WeatherService.o Sources/SwiftCall.s -o "$app/Contents/MacOS/RenderTests"
codesign --force --sign - "$app"
log="$PWD/Build/test-live-output.log"
: > "$log"
open -W -n --stdout "$log" --stderr "$log" "$app"
cat "$log"
rg -q 'PASS: 200 updates' "$log"
