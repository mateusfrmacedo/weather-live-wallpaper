#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
Scripts/build.sh
sdk="$(xcrun --sdk macosx --show-sdk-path)"
app="$PWD/Build/Weather Wallpaper Native.app"
ditto 'Build/Weather Wallpaper.app' "$app"
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier local.mateus.WeatherWallpaper.NativePrototype' "$plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleName Weather Wallpaper Native' "$plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleDisplayName Weather Wallpaper Native' "$plist"
/usr/libexec/PlistBuddy -c 'Set UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName NativeWeatherSceneDelegate' "$plist"
bridge="$app/Contents/PlugIns/DesktopBridge.bundle"
/usr/libexec/PlistBuddy -c 'Set NSPrincipalClass NativeDesktopBridge' "$bridge/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier local.mateus.WeatherWallpaper.NativePrototype.DesktopBridge' "$bridge/Contents/Info.plist"
xcrun clang -fobjc-arc -bundle -target arm64-apple-macos14.0 -isysroot "$sdk" \
 -framework AppKit -framework ServiceManagement -framework Carbon \
 Sources/NativeWallpaper/PrototypeBridge.m -o "$bridge/Contents/MacOS/DesktopBridge"
codesign --force --sign - "$bridge"
xcrun clang -fobjc-arc -target arm64-apple-ios17.0-macabi -isysroot "$sdk" \
 -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
 -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -framework MetalKit -framework Metal -framework WeatherKit -framework AVFoundation -framework CoreVideo -framework CoreMedia \
 Sources/NativeWallpaper/PrototypeHost.m Sources/NativeWallpaper/SceneExporter.m \
 Build/WeatherRuntime.o Build/WeatherService.o Sources/SwiftCall.s -o "$app/Contents/MacOS/WeatherWallpaper"
extension="$app/Contents/Extensions/WeatherWallpaper.appex"
mkdir -p "$extension/Contents/MacOS" "$extension/Contents/Resources"
cp "$app/Contents/Resources/AppIcon.icns" "$extension/Contents/Resources/AppIcon.icns"
# Build a self-contained thumbnail; no dependency on a previously exported scene.
sips -s format png -Z 320 "$app/Contents/Resources/AppIcon.icns" --out "$extension/Contents/Resources/weather-thumbnail.png" >/dev/null
cat > "$extension/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WeatherWallpaperExtension</string>
<key>CFBundleIdentifier</key><string>local.mateus.WeatherWallpaper.NativePrototype.Extension</string>
<key>CFBundleName</key><string>Weather Wallpaper</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleDevelopmentRegion</key><string>pt_BR</string>
<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
<key>CFBundleDisplayName</key><string>Weather Wallpaper · Protótipo</string>
<key>CFBundlePackageType</key><string>XPC!</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>EXAppExtensionAttributes</key><dict><key>EXExtensionPointIdentifier</key><string>com.apple.wallpaper</string></dict>
</dict></plist>
PLIST
cat > Build/native-wallpaper.entitlements <<PLIST
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.temporary-exception.files.absolute-path.read-only</key><array><string>/Users/Shared/WeatherWallpaper-$(id -u)/</string></array>
</dict></plist>
PLIST
xcrun clang -fobjc-arc -target arm64-apple-macos27.0 -isysroot "$sdk" \
 -c Sources/NativeWallpaper/WallpaperRuntime.m -o Build/WallpaperRuntime.o
xcrun swiftc -swift-version 5 -application-extension -Xlinker -application_extension -Xlinker -e -Xlinker _NSExtensionMain -target arm64-apple-macos27.0 -sdk "$sdk" -parse-as-library \
 -import-objc-header Sources/NativeWallpaper/WallpaperPrivate.h \
 -framework AppKit -framework QuartzCore -framework AVFoundation -framework IOSurface -framework CoreImage -framework ExtensionFoundation \
 Sources/NativeWallpaper/*.swift Build/WallpaperRuntime.o -o "$extension/Contents/MacOS/WeatherWallpaperExtension"
codesign --force --sign - --entitlements Build/native-wallpaper.entitlements "$extension"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
echo "$app"
