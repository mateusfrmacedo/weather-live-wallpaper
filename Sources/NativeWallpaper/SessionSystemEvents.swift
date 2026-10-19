import AppKit
import CoreGraphics

// Observe real session events as well as WallpaperAgent updates. In particular,
// the lock UI can appear over an existing desktop context without a new acquire.
final class SessionSystemEvents {
    enum Event { case locked, unlocked, saverStarted, saverStopped }
    private(set) var locked: Bool
    private(set) var saverRunning = false
    var onChange: ((Bool, Bool) -> Void)?
    private var tokens: [NSObjectProtocol] = []
    private var timer: Timer?
    private let lockReader: () -> Bool?

    init(observe: Bool = true, lockReader: @escaping () -> Bool? = SessionSystemEvents.readLockState) {
        self.lockReader = lockReader
        locked = lockReader() ?? false
        guard observe else { return }
        let names: [(String, Event)] = [
            ("com.apple.screenIsLocked", .locked), ("com.apple.screenIsUnlocked", .unlocked),
            ("com.apple.screensaver.didstart", .saverStarted), ("com.apple.screensaver.didstop", .saverStopped)
        ]
        for (name, event) in names {
            tokens.append(DistributedNotificationCenter.default().addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] _ in self?.handle(event) })
        }
        // Recover a missed notification, including an extension launched while locked.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshLockState() }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    func handle(_ event: Event) {
        switch event {
        case .locked: locked = true
        case .unlocked: locked = false; saverRunning = false
        case .saverStarted: saverRunning = true
        case .saverStopped: saverRunning = false
        }
        debugLog("Session event: \(event), locked=\(locked) saver=\(saverRunning)")
        onChange?(locked, saverRunning)
    }
    func refreshLockState() {
        guard let actual = lockReader(), actual != locked else { return }
        handle(actual ? .locked : .unlocked)
    }
    static func readLockState() -> Bool? {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else { return nil }
        return dictionary["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
    deinit {
        timer?.invalidate()
        for token in tokens { DistributedNotificationCenter.default().removeObserver(token) }
    }
}
