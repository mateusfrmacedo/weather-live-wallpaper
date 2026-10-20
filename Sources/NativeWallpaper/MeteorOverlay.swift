import AppKit
import QuartzCore
import ImageIO

// The fast foreground meteor is composited at the display cadence, independently
// of the slower weather movie. It is never compressed or resampled into 24 fps.
final class WallpaperMeteor {
    let layer = CALayer()
    private let sprite = CALayer()
    private let duration: Double
    private let period: Double
    private let opacity: Float

    init?(directory: URL, metadata: [String: Any]) {
        guard metadata["meteorOverlay"] as? Bool == true,
              let source = CGImageSourceCreateWithURL(directory.appendingPathComponent("meteor.png") as CFURL, nil),
              let texture = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        duration = 1.1; period = 13; opacity = 0.24
        layer.isGeometryFlipped = true; layer.masksToBounds = true
        sprite.contents = texture; sprite.opacity = 0
        layer.addSublayer(sprite)
    }
    func resize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard layer.bounds.size != size || sprite.animation(forKey: "meteor") == nil else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.frame = CGRect(origin: .zero, size: size)
        let length = min(180, max(90, size.width * 0.12))
        sprite.bounds = CGRect(x: 0, y: 0, width: length, height: 2)
        let start = CGPoint(x: size.width * 0.76, y: size.height * 0.17)
        let end = CGPoint(x: size.width * 0.46, y: size.height * 0.27)
        sprite.transform = CATransform3DMakeRotation(-atan2(size.height * 0.10, size.width * 0.30), 0, 0, 1)
        CATransaction.commit()
        let position = CAKeyframeAnimation(keyPath: "position")
        position.values = [NSValue(point: start), NSValue(point: start), NSValue(point: end), NSValue(point: end)]
        position.keyTimes = [0, NSNumber(value: 1 / period), NSNumber(value: (1 + duration) / period), 1]
        position.calculationMode = .linear
        let alpha = CAKeyframeAnimation(keyPath: "opacity")
        alpha.values = [0, 0, opacity, opacity, 0, 0]
        alpha.keyTimes = [0, NSNumber(value: 1 / period), NSNumber(value: (1 + duration * 0.12) / period), NSNumber(value: (1 + duration * 0.82) / period), NSNumber(value: (1 + duration) / period), 1]
        let group = CAAnimationGroup()
        group.animations = [position, alpha]; group.duration = period; group.repeatCount = .infinity
        group.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        sprite.add(group, forKey: "meteor")
    }
    func setRate(_ value: Float) {
        guard layer.speed != value else { return }
        let local = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = value; layer.beginTime = 0
        if value == 0 { layer.timeOffset = local }
        else { layer.timeOffset = 0; layer.beginTime = CACurrentMediaTime() - local / Double(value) }
    }
}
