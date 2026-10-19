// Adapted from Aerial (MIT). See Aerial-LICENSE and README.md in this directory.
// Settings view model — single "Aerial" entry in the picker.
//
// One choice in the picker, period. The extension dispatches per
// `directDisplayID` at acquire time, so the user enables this single
// Aerial entry on every screen they want and we render the correct
// content for each screen. (See WallpaperXPCHandler.colorForDisplay.)

import AppKit
import Foundation

private let weatherChoiceID = "weather"
private let weatherDisplayName = "Weather Wallpaper · Protótipo"

func buildSettingsViewModelsXPC(thumbnailURL: URL? = nil) -> AnyObject? {
    let bundleID = Bundle.main.bundleIdentifier ?? "local.mateus.WeatherWallpaper.NativePrototype.Extension"
    let groupID = GroupID(id: "weather-group")

    guard let thumbnailURL = thumbnailURL ?? weatherThumbnailURL() else {
        debugLog("  [Settings] Failed to generate thumbnail")
        return makeEmptyGroupsResponse()
    }

    let choiceID = ChoiceID(
        id: weatherChoiceID,
        descriptor: ChoiceIDDescriptor(
            provider: ChoiceProviderID(rawValue: bundleID),
            identifier: weatherChoiceID,
            files: [],
            configuration: Data(weatherChoiceID.utf8),
        ),
    )

    let choiceDescriptor = ChoiceDescriptor(
        id: choiceID,
        provider: ChoiceProviderID(rawValue: bundleID),
        identifier: weatherChoiceID,
        name: weatherDisplayName,
        localizedDescription: "Clima animado ao bloquear; estático no desktop",
        thumbnail: .image(url: thumbnailURL),
        isDownloaded: true,
        options: [],
    )

    let item = SettingsItem(
        id: choiceID,
        localizedName: weatherDisplayName,
        thumbnail: .image(url: thumbnailURL),
        choice: choiceDescriptor,
        contentBadge: .none,
        showInTopLevel: true,
        sortOrder: 0,
        disposability: .none,
    )

    let group = SettingsGroup(
        id: groupID,
        items: [item],
        localizedName: "Weather Wallpaper · Protótipo",
        disposability: .none,
        sortOrder: -50,
        sortID: GroupSortID(id: "local.mateus.weather"),
        allChoiceID: nil,
        shouldHideItemLabels: false,
        contextMenu: nil,
        thumbnail: nil,
    )

    let viewModel = SettingsViewModel(
        groups: [group],
        refreshPolicy: .default,
        isModificationDisabled: false,
    )

    // Same Aerial group/item surfaced in both the Wallpaper picker
    // and the Screen Saver picker. WallpaperAgent's discovery uses the
    // non-nil `screenSaver:` field as the eligibility signal — Apple's
    // own WallpaperAerialsExtension does the same (Phosphene leaves it
    // nil and is wallpaper-only by choice).
    let viewModels = SettingsViewModels(
        desktop: viewModel,
        screenSaver: viewModel,
    )

    return remapToRealXPC(viewModels)
}

/// Fallback: empty groups view model.
func makeEmptyGroupsResponse() -> AnyObject? {
    let emptyViewModel = SettingsViewModel(
        groups: [],
        refreshPolicy: .default,
        isModificationDisabled: false,
    )
    let empty = SettingsViewModels(
        desktop: emptyViewModel,
        screenSaver: emptyViewModel,
    )
    return remapToRealXPC(empty)
}

/// Archive via ShimViewModelsXPC, remap class name on unarchive to WallpaperSettingsViewModelsXPC.
private func remapToRealXPC(_ viewModels: SettingsViewModels) -> AnyObject? {
    let shim = ShimViewModelsXPC(value: viewModels)

    let data: Data
    do {
        data = try NSKeyedArchiver.archivedData(withRootObject: shim, requiringSecureCoding: false)
    } catch {
        debugLog("  [Remap] Archive failed: \(error)")
        return nil
    }

    guard let realClass = objc_getClass("WallpaperSettingsViewModelsXPC") as? AnyClass else {
        debugLog("  [Remap] WallpaperSettingsViewModelsXPC class not found")
        return nil
    }

    guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
        debugLog("  [Remap] Failed to create unarchiver")
        return nil
    }
    unarchiver.requiresSecureCoding = false
    unarchiver.decodingFailurePolicy = .setErrorAndReturn
    unarchiver.setClass(realClass, forClassName: "ShimViewModelsXPC")

    let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
    if let error = unarchiver.error {
        debugLog("  [Remap] Unarchive error: \(error)")
    }
    unarchiver.finishDecoding()

    return result as AnyObject?
}

/// Stage the bundled Aerial thumbnail into the Caches directory and return its URL.
/// (System Settings reads this URL; staging to our Caches dir matches the location the
/// previous generated thumbnail used and is known to be readable by WallpaperAgent.)
private func weatherThumbnailURL() -> URL? {
    let fm = FileManager.default
    guard let src = Bundle.main.url(forResource: "weather-thumbnail", withExtension: "png") else {
        debugLog("  [Settings] Bundled thumbnail not found")
        return nil
    }
    guard let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        return src
    }
    try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    let dst = cacheDir.appendingPathComponent("weather-thumbnail.png")
    do {
        try Data(contentsOf: src).write(to: dst, options: .atomic)
        return dst
    } catch {
        debugLog("  [Settings] Failed to stage thumbnail: \(error)")
        return src
    }
}
