import AppKit
import AVFoundation

func debugLog(_ message: String) { NSLog("%@", message) }
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError("FAIL: \(message)") }
}
func run(for seconds: TimeInterval) { RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds)) }

@main struct NativeWallpaperTests {
    static func main() {
        // Run synchronously so nested run loops can drain KVO/main-queue callbacks.
        do {
            enum Presentation { case `default`, locked, idle }
            enum Activity { case active, suspended }
            struct Changes {
                var presentationMode: Presentation?
                var activityState: Activity?
            }
            struct Envelope { var changes: Changes? }
            final class Update: NSObject { let box: Envelope; init(_ value: Envelope) { box = value } }
            let update = WallpaperRequest(Update(Envelope(changes: Changes(presentationMode: .locked, activityState: .active))))
            check(update.mode == "locked" && update.suspended == false, "read nested partial lock update")
            let empty = WallpaperRequest(Update(Envelope(changes: nil)))
            check(empty.mode == nil && empty.suspended == nil && empty.size == nil && empty.scale == nil, "missing fields must not reset session state or geometry")
            let sleep = WallpaperRequest(Update(Envelope(changes: Changes(presentationMode: nil, activityState: .suspended))))
            check(sleep.mode == nil && sleep.suspended == true, "activity-only update")
            var policy = WallpaperPlaybackPolicy()
            check(policy.rate(at: 0) == 0, "desktop starts still")
            policy.update(mode: "locked", suspended: false, now: 1)
            check(policy.rate(at: 1) == 1, "lock starts playback")
            policy.update(mode: "default", suspended: false, now: 2)
            check(policy.rate(at: 3) > 0 && policy.rate(at: 3) < 1, "unlock slows playback")
            policy.update(mode: "default", suspended: false, now: 3.5)
            check(policy.rate(at: 4.6) == 0, "repeated updates must not extend the ramp")
            policy.update(mode: "idle", suspended: false, now: 5)
            check(policy.rate(at: 5) == 1, "screen saver animates")
            policy.update(mode: "idle", suspended: true, now: 6)
            check(policy.rate(at: 6) == 0, "sleep suspends rendering")
            policy.update(mode: "locked", suspended: false, now: 7)
            check(policy.rate(at: 7) == 1, "wake resumes lock playback")
        }
        // Apple laptop/desktop panels and the user's QHD external monitor.
        let displays: [CGSize] = [CGSize(width: 2560,height: 1664),CGSize(width: 2880,height: 1864),CGSize(width: 3024,height: 1964),CGSize(width: 3456,height: 2234),CGSize(width: 4480,height: 2520),CGSize(width: 5120,height: 2880),CGSize(width: 6016,height: 3384),CGSize(width: 2560,height: 1440)]
        for display in displays {
            let frame = WeatherWallpaperSession.topAnchoredFill(image: CGSize(width: 3024,height: 1964), destination: display)
            check(abs(frame.maxY-display.height)<0.01 && frame.width>=display.width && frame.height>=display.height,"display fill preserves upper edge and covers canvas")
        }
        guard dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_NOW) != nil else { fatalError("private framework missing") }
        let thumbnail = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Build/Weather Wallpaper Native.app/Contents/Extensions/WeatherWallpaper.appex/Contents/Resources/weather-thumbnail.png")
        guard let models = buildSettingsViewModelsXPC(thumbnailURL: thumbnail) else { fatalError("settings ABI mismatch") }
        check(NSStringFromClass(type(of: models)) == "WallpaperSettingsViewModelsXPC", "real settings XPC object")
        do {
            guard let session = WeatherWallpaperSession(size: CGSize(width: 960, height: 540), scale: 2, displayID: nil) else { fatalError("CAContext unavailable") }
            check(WWRemoteContext(session.context.contextId) != nil, "remote-context ABI")
            session.loadLatestScene()
            check(session.image != nil && session.generation != nil, "published movie and poster load")
            let meteor = session.root.sublayers?.count == 2 ? session.root.sublayers?.last : nil
            if let meteor {
                check(meteor.speed == 0,"meteor is initially paused on the static desktop")
                let trajectory = meteor.sublayers?.first?.animation(forKey: "meteor") as? CAAnimationGroup
                check(meteor.sublayers?.count == 16, "meteors use varied bursts instead of one fixed repeating route")
                if let track = trajectory?.animations?.first as? CAKeyframeAnimation, let times = track.keyTimes, let duration = trajectory?.duration {
                    let lifetime = (times[2].doubleValue - times[1].doubleValue) * duration
                    check((0.479 ... 0.521).contains(lifetime), "meteor retains Weather's half-second lifetime")
                } else { fatalError("Missing meteor trajectory") }
                check(trajectory?.animations?.count == 4, "meteor animates travel, opacity, length and thickness")
                var starts = [Double]()
                for sprite in meteor.sublayers ?? [] {
                    guard let group = sprite.animation(forKey: "meteor") as? CAAnimationGroup,
                          let motion = group.animations?.first as? CAKeyframeAnimation,
                          let times = motion.keyTimes,
                          let width = group.animations?[2] as? CAKeyframeAnimation,
                          let lengths = width.values as? [NSNumber] else { fatalError("Missing meteor tracks") }
                    starts.append(times[1].doubleValue * group.duration)
                    let lifetime = (times[2].doubleValue - times[1].doubleValue) * group.duration
                    check((0.479 ... 0.521).contains(lifetime), "all meteor passages retain the native lifetime range")
                    check(lengths[3].doubleValue > lengths[0].doubleValue * 3 && lengths[4].doubleValue < lengths[3].doubleValue, "trail grows and then contracts before disappearing")
                }
                for pair in zip(starts, starts.dropFirst()) { check((11 ... 15).contains(pair.1 - pair.0), "burst spacing follows the native random range") }
                check(Set(starts.dropFirst().enumerated().map { starts[$0.offset + 1] - starts[$0.offset] }).count > 1, "burst intervals vary")
            }
            check(WWCreateSnapshot(session.image) != nil, "snapshot IOSurface ABI")
            session.update(mode: "default", suspended: false)
            run(for: 0.5)
            check(session.renderedFrameCount == 0, "static desktop does no frame decoding")
            session.update(mode: "locked", suspended: false)
            run(for: 2)
            check(session.renderedFrameCount > 5, "lock renders actual video frames")
            check(session.image?.bitsPerComponent == 16, "movie decoding retains precision for dark gradients")
            check(meteor == nil || meteor?.speed == 1,"meteor animates independently of weather movie timestamps")
            let meteorStart = meteor?.sublayers?.first?.animation(forKey: "meteor")?.beginTime
            session.resize(size: session.root.bounds.size,scale: session.root.contentsScale)
            check(meteor?.sublayers?.first?.animation(forKey: "meteor")?.beginTime == meteorStart,"unchanged geometry does not restart the meteor")
            let beforePartialUpdate = session.renderedFrameCount
            session.update(mode: nil, suspended: nil)
            run(for: 0.3)
            check(session.renderedFrameCount > beforePartialUpdate, "partial update preserves locked playback")
            session.update(mode: "default", suspended: false)
            run(for: 3)
            let frozenCount = session.renderedFrameCount
            run(for: 1)
            check(session.renderedFrameCount == frozenCount, "desktop stops decoding after unlock")
            check(meteor == nil || meteor?.speed == 0,"meteor also stops after unlock")
            session.loadLatestScene()
            run(for: 0.25)
            check(session.renderedFrameCount == frozenCount, "weather refresh does not restart animation")
            let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try! FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: fixture) }
            let nextGeneration = UUID().uuidString
            let published = URL(fileURLWithPath: "/Users/Shared/WeatherWallpaper/\(getuid())").appendingPathComponent(session.generation!)
            try! FileManager.default.copyItem(at: published, to: fixture.appendingPathComponent(nextGeneration))
            try! JSONSerialization.data(withJSONObject: ["version": 1, "generation": nextGeneration]).write(to: fixture.appendingPathComponent("current.json"))
            session.loadLatestScene(from: fixture)
            run(for: 0.3)
            check(session.generation == nextGeneration && session.renderedFrameCount == frozenCount, "new weather scene crossfades without decoding")
            try! Data("invalid manifest".utf8).write(to: fixture.appendingPathComponent("current.json"))
            session.loadLatestScene(from: fixture)
            check(session.generation == nextGeneration && session.image != nil, "invalid or incomplete update keeps last good scene")
            session.update(mode: "idle", suspended: false)
            run(for: 1)
            check(session.renderedFrameCount > frozenCount, "screen saver resumes")
            session.update(mode: "idle", suspended: true)
            let suspendedCount = session.renderedFrameCount
            run(for: 0.5)
            check(session.renderedFrameCount == suspendedCount, "display sleep stops decoding")
            // The regression: lock/unlock delivered to an existing desktop
            // context, with a partial/default WallpaperAgent update in between.
            var actualLock = false
            let events = SessionSystemEvents(observe: false, lockReader: { actualLock })
            events.onChange = { locked, saver in session.updateSystemState(locked: locked, saverRunning: saver) }
            session.update(mode: "default", suspended: false)
            run(for: 3)
            let beforeLock = session.renderedFrameCount
            events.handle(.locked)
            session.update(mode: "default", suspended: nil)
            run(for: 1)
            check(session.renderedFrameCount > beforeLock, "session lock event animates even when the agent update is incomplete")
            events.handle(.unlocked)
            run(for: 3)
            let afterUnlock = session.renderedFrameCount
            run(for: 0.5)
            check(session.renderedFrameCount == afterUnlock, "unlock event settles to static desktop")
            actualLock = true; events.refreshLockState()
            run(for: 0.5)
            check(session.renderedFrameCount > afterUnlock, "session query recovers missed lock event")
            actualLock = false; events.refreshLockState()
            run(for: 3)
            let beforeSaver = session.renderedFrameCount
            events.handle(.saverStarted)
            run(for: 0.5)
            check(session.renderedFrameCount > beforeSaver, "screen saver system event animates")
            events.handle(.saverStopped)
            run(for: 3)
            let afterSaver = session.renderedFrameCount
            run(for: 0.25)
            check(session.renderedFrameCount == afterSaver, "screen saver stop settles to static desktop")
            session.stop()
            NSLog("PASS: native wallpaper ABI, partial request parsing, actual video playback, lock/unlock events, static desktop, sleep/resume")
        }
    }
}
