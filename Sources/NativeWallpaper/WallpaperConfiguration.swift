// Adapted from Aerial (MIT). See Aerial-LICENSE and README.md in this directory.
// XPC connection configuration for the wallpaper extension.
//
// Accepts incoming connections from WallpaperAgent, sets up class whitelists
// for all XPC type parameters, and wires up the handler.

import ExtensionFoundation
import Foundation

struct WeatherWallpaperConfiguration: AppExtensionConfiguration {
    func accept(connection: NSXPCConnection) -> Bool {
        debugLog("XPC accept from PID=\(connection.processIdentifier)")

        let exported = NSXPCInterface(with: (any WallpaperExtensionXPCProtocol).self)

        let typeNames = [
            "WallpaperIDXPC",
            "WallpaperCreationRequestXPC",
            "WallpaperUpdateRequestXPC",
            "WallpaperRemoteContextXPC",
            "WallpaperSnapshotXPC",
            "WallpaperContentTypeSetXPC",
            "WallpaperChoiceIDXPC",
            "WallpaperChoiceIDsXPC",
            "WallpaperExtensionChoiceRequestXPC",
            "WallpaperChoiceRequestAdditionResultXPC",
            "WallpaperDebugRequestXPC",
            "WallpaperDebugResponseXPC",
            "WallpaperMigrationVersionXPC",
            "WallpaperSettingsViewModelsXPC",
            "AuditTokenXPC",
        ]

        let allTypes = NSMutableSet()
        var missing: [String] = []
        for name in typeNames {
            if let cls = objc_getClass(name) {
                allTypes.add(cls)
            } else {
                missing.append(name)
            }
        }
        if !missing.isEmpty {
            debugLog("  MISSING runtime types: \(missing.joined(separator: ", "))")
        }
        allTypes.add(NSString.self)
        allTypes.add(NSNumber.self)
        allTypes.add(NSData.self)
        allTypes.add(NSArray.self)
        allTypes.add(NSDictionary.self)
        allTypes.add(NSURL.self)
        allTypes.add(NSError.self)

        // Element-wise bridge (verified identical to the NSSet force-bridge
        // for ObjC class objects); an `as!` here would abort the extension
        // on the very first XPC accept.
        let classes = Set(allTypes.compactMap { $0 as? AnyHashable })
        if classes.count != allTypes.count {
            debugLog("  WARNING: class whitelist bridge dropped \(allTypes.count - classes.count) entries")
        }

        let selectors: [(Selector, Int, Bool)] = [
            (#selector(WeatherWallpaperHandler.acquire(withId:request:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.acquire(withId:request:reply:)), 1, false),
            (#selector(WeatherWallpaperHandler.acquire(withId:request:reply:)), 0, true),
            (#selector(WeatherWallpaperHandler.update(withId:request:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.update(withId:request:reply:)), 1, false),
            (#selector(WeatherWallpaperHandler.invalidate(withId:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.snapshot(withId:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.snapshot(withId:reply:)), 0, true),
            (#selector(WeatherWallpaperHandler.provideSettingsViewModels(withContentTypes:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.provideSettingsViewModels(withContentTypes:reply:)), 0, true),
            (#selector(WeatherWallpaperHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 1, false),
            (#selector(WeatherWallpaperHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, true),
            (#selector(WeatherWallpaperHandler.removeChoiceRequest(withChoiceRequest:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.selectedChoicesDidChange(for:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 1, false),
            (#selector(WeatherWallpaperHandler.isChoiceDownloaded(with:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.download(withChoiceID:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.pauseDownload(for:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.cancelDownload(for:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.resumeDownload(for:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.removeDownload(for:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.migrateSelectedChoice(for:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.migrateSelectedChoice(for:reply:)), 0, true),
            (#selector(WeatherWallpaperHandler.migrate(from:to:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.migrate(from:to:reply:)), 1, false),
            (#selector(WeatherWallpaperHandler.skipShuffledContent(withId:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.canSkipShuffledContent(withId:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.handleDebugRequest(for:reply:)), 0, false),
            (#selector(WeatherWallpaperHandler.handleDebugRequest(for:reply:)), 0, true),
            (#selector(WeatherWallpaperHandler.handleNotification(withNamed:reply:)), 0, false),
        ]

        for (sel, idx, isReply) in selectors {
            exported.setClasses(classes, for: sel, argumentIndex: idx, ofReply: isReply)
        }

        connection.exportedInterface = exported
        connection.remoteObjectInterface = NSXPCInterface(with: (any WallpaperExtensionProxyXPCProtocol).self)

        let handler = WeatherWallpaperHandler()
        connection.exportedObject = handler

        connection.interruptionHandler = { debugLog("XPC interrupted") }
        connection.invalidationHandler = { [weak handler] in
            handler?.proxy = nil
            debugLog("XPC invalidated")

        }

        connection.resume()

        handler.proxy = connection.remoteObjectProxy as? (any WallpaperExtensionProxyXPCProtocol)

        debugLog("XPC accepted")
        return true
    }
}
