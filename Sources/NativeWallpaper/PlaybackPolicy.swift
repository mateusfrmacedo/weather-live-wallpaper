import Foundation

struct WallpaperPlaybackPolicy {
    enum Phase: Equatable { case still, moving, settling, suspended }
    private(set) var phase: Phase = .still
    private var stopTime: TimeInterval = 0
    let settlingDuration: TimeInterval = 2.5

    mutating func update(mode: String, suspended: Bool, now: TimeInterval) {
        if suspended { phase = .suspended; return }
        if mode == "locked" || mode == "idle" { phase = .moving; return }
        if phase == .moving || phase == .suspended {
            phase = .settling
            stopTime = now + settlingDuration
        }
    }
    mutating func rate(at now: TimeInterval) -> Float {
        switch phase {
        case .still, .suspended: return 0
        case .moving: return 1
        case .settling:
            let remaining = stopTime - now
            if remaining <= 0 { phase = .still; return 0 }
            return Float(min(1, remaining / settlingDuration))
        }
    }
}
