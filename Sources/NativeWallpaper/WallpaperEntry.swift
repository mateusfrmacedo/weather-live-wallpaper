import AppKit
import ExtensionFoundation
import os

private let logger = Logger(subsystem: "local.mateus.WeatherWallpaper.NativePrototype", category: "wallpaper")
func debugLog(_ message: String) { logger.notice("\(message, privacy: .public)") }

@main
final class WeatherWallpaperExtension: NSObject, AppExtension {
    required override init() {
        super.init()
        if dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_NOW) == nil {
            debugLog("WallpaperExtensionKit unavailable")
        }
        WWPrepareSnapshotEncoding()
        observeWallpaperSessionEvents()
        debugLog("Started native extension: \(Bundle.main.bundleURL.path)")
    }
    var configuration: some AppExtensionConfiguration { WeatherWallpaperConfiguration() }
}
