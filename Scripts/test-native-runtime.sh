#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
sdk="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang -fobjc-arc -target arm64-apple-macos27.0 -isysroot "$sdk" \
 -c Sources/NativeWallpaper/WallpaperRuntime.m -o Build/WallpaperRuntime.o
xcrun swiftc -swift-version 5 -target arm64-apple-macos27.0 -sdk "$sdk" -parse-as-library \
 -import-objc-header Sources/NativeWallpaper/WallpaperPrivate.h \
 -framework AppKit -framework QuartzCore -framework AVFoundation -framework IOSurface -framework CoreImage \
 Sources/NativeWallpaper/PlaybackPolicy.swift Sources/NativeWallpaper/WallpaperSession.swift \
 Sources/NativeWallpaper/WallpaperRequest.swift Sources/NativeWallpaper/SessionSystemEvents.swift \
 Sources/NativeWallpaper/CodableShims.swift Sources/NativeWallpaper/SettingsProvider.swift \
 Tests/NativeWallpaper/runtime.swift Build/WallpaperRuntime.o -o Build/test-native-runtime
Build/test-native-runtime
