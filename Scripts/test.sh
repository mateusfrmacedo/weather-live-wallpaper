#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
sdk="$(xcrun --sdk macosx --show-sdk-path)"
Scripts/build.sh
xcrun clang -fobjc-arc -target arm64-apple-ios17.0-macabi -isysroot "$sdk" \
 -framework Foundation -framework CoreGraphics -framework QuartzCore -framework WeatherKit Tests/render-smoke.m Build/WeatherRuntime.o Build/WeatherService.o Sources/SwiftCall.s -o Build/render-smoke
Build/render-smoke
codesign --verify --deep --strict "Build/Weather Wallpaper.app"
