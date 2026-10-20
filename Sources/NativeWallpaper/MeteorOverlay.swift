import AppKit
import QuartzCore
import ImageIO

// The fast foreground meteor is composited at the display cadence, independently
// of the slower weather movie. It is never compressed or resampled into 24 fps.
final class WallpaperMeteor {
    let layer = CALayer()
    private let texture: CGImage
    private let seed = UInt32.random(in: .min ... .max)

    init?(directory: URL, metadata: [String: Any]) {
        guard metadata["meteorOverlay"] as? Bool == true,
              let source = CGImageSourceCreateWithURL(directory.appendingPathComponent("meteor.png") as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        texture = image
        layer.isGeometryFlipped = true; layer.masksToBounds = true
    }
    func resize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard layer.bounds.size != size || layer.sublayers?.isEmpty != false else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.frame = CGRect(origin: .zero, size: size)
        WWBuildMeteorLayers(layer, texture, size, seed)
        CATransaction.commit()
    }
    func setRate(_ value: Float) {
        guard layer.speed != value else { return }
        let local = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = value; layer.beginTime = 0
        if value == 0 { layer.timeOffset = local }
        else { layer.timeOffset = 0; layer.beginTime = CACurrentMediaTime() - local / Double(value) }
    }
}
