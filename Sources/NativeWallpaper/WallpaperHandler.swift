import AppKit
import Foundation

private var sessions: [String: WeatherWallpaperSession] = [:]
private var refreshTimer: Timer?

private func identifier(_ object: Any?) -> String? {
    guard let object else { return nil }
    let description = String(describing: Mirror(reflecting: object).children.first?.value ?? object)
    guard let range = description.range(of: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}", options: .regularExpression) else { return nil }
    return String(description[range]).uppercased()
}

private var systemEvents: SessionSystemEvents?

func observeWallpaperSessionEvents() {
    guard systemEvents == nil else { return }
    let events = SessionSystemEvents()
    events.onChange = { locked, saver in
        for session in sessions.values { session.updateSystemState(locked: locked, saverRunning: saver) }
    }
    systemEvents = events
}

final class WeatherWallpaperHandler: NSObject, WallpaperExtensionXPCProtocol {
    weak var proxy: (any WallpaperExtensionProxyXPCProtocol)?
    func acquire(withId id: Any?, request: Any?, reply: @escaping @Sendable (Any?, Error?) -> Void) {
        guard let key = identifier(id) else { reply(nil, error("Identificador de wallpaper inválido")); return }
        let request = WallpaperRequest(request)
        DispatchQueue.main.async {
            if refreshTimer == nil {
                let timer = Timer(timeInterval: 5, repeats: true) { _ in
                    for session in sessions.values { session.loadLatestScene() }
                }
                RunLoop.main.add(timer, forMode: .common); refreshTimer = timer
            }
            guard let session = sessions[key] ?? WeatherWallpaperSession(size: request.size ?? CGSize(width: 1920, height: 1080), scale: request.scale ?? 1, displayID: request.displayID),
                  let remote = WWRemoteContext(session.context.contextId) else {
                reply(nil, self.error("Não foi possível criar o contexto nativo")); return
            }
            observeWallpaperSessionEvents()
            if let events = systemEvents { session.updateSystemState(locked: events.locked, saverRunning: events.saverRunning) }
            sessions[key] = session
            session.resize(size: request.size ?? session.root.bounds.size, scale: request.scale ?? session.root.contentsScale)
            session.loadLatestScene()
            session.update(mode: request.mode, suspended: request.suspended, preview: request.preview)
            debugLog("Acquire \(key) mode=\(request.mode ?? "unchanged") activity=\(request.activity ?? "unchanged") preview=\(String(describing: request.preview)) context=\(session.context.contextId)")
            reply(remote, nil)
        }
    }
    func update(withId id: Any?, request: Any?, reply: @escaping @Sendable (Error?) -> Void) {
        guard let key = identifier(id) else { reply(error("Identificador inválido")); return }
        let request = WallpaperRequest(request)
        DispatchQueue.main.async {
            if let session = sessions[key] {
                session.resize(size: request.size ?? session.root.bounds.size, scale: request.scale ?? session.root.contentsScale)
                session.loadLatestScene()
                session.update(mode: request.mode, suspended: request.suspended, preview: request.preview)
                debugLog("Update \(key) mode=\(request.mode ?? "unchanged") activity=\(request.activity ?? "unchanged") preview=\(String(describing: request.preview))")
            }
            reply(nil)
        }
    }
    func invalidate(withId id: Any?, reply: @escaping @Sendable (Error?) -> Void) {
        let key = identifier(id)
        DispatchQueue.main.async {
            if let key { sessions.removeValue(forKey: key)?.stop() }
            if sessions.isEmpty { refreshTimer?.invalidate(); refreshTimer = nil }
            reply(nil)
        }
    }
    func snapshot(withId id: Any?, reply: @escaping @Sendable (Any?, Error?) -> Void) {
        let key = identifier(id)
        DispatchQueue.main.async {
            let image = key.flatMap { sessions[$0]?.image }
            reply(WWCreateSnapshot(image), nil)
        }
    }
    func handleDebugRequest(for request: Any?, reply: @escaping @Sendable (Any?, Error?) -> Void) { reply(nil, nil) }
    func handleNotification(withNamed name: Any?, reply: @escaping @Sendable (Error?) -> Void) {
        DispatchQueue.main.async { for session in sessions.values { session.loadLatestScene() }; reply(nil) }
    }
    private func error(_ message: String) -> NSError { NSError(domain: "WeatherWallpaperExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
