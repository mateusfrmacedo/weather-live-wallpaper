#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
sdk="$(xcrun --sdk macosx --show-sdk-path)"
app="$PWD/Build/Weather Wallpaper.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun clang -fobjc-arc -framework AppKit Scripts/make-icon.m -o Build/make-icon
Build/make-icon /System/Applications/Weather.app/Contents/Resources/AppIcon.icns Build/AppIcon.iconset
xcrun iconutil -c icns Build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
xcrun swiftc -target arm64-apple-ios17.0-macabi -sdk "$sdk" -parse-as-library -emit-object Sources/WeatherRuntime.swift -o Build/WeatherRuntime.o
xcrun swiftc -target arm64-apple-ios17.0-macabi -sdk "$sdk" -parse-as-library -emit-object Sources/WeatherService.swift -o Build/WeatherService.o
bridge="$app/Contents/PlugIns/DesktopBridge.bundle"
mkdir -p "$bridge/Contents/MacOS"
xcrun clang -fobjc-arc -bundle -target arm64-apple-macos14.0 -isysroot "$sdk" -framework AppKit -framework ServiceManagement -framework Carbon Sources/DesktopBridge.m -o "$bridge/Contents/MacOS/DesktopBridge"
cat > "$bridge/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>DesktopBridge</string><key>CFBundleIdentifier</key><string>local.mateus.WeatherWallpaper.DesktopBridge</string><key>CFBundlePackageType</key><string>BNDL</string><key>NSPrincipalClass</key><string>DesktopBridge</string></dict></plist>
PLIST
codesign --force --sign - "$bridge"
xcrun clang -fobjc-arc -target arm64-apple-ios17.0-macabi -isysroot "$sdk" \
 -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
 -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -framework MetalKit -framework Metal -framework WeatherKit \
 Sources/main.m Build/WeatherRuntime.o Build/WeatherService.o Sources/SwiftCall.s -o "$app/Contents/MacOS/WeatherWallpaper"
cp Sources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "$app"
