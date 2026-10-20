import AppKit
import AVFoundation
import CoreImage
import QuartzCore

// All sessions and their layers are owned by the main queue.
final class WeatherWallpaperSession {
    let context: CAContext
    let root = CALayer()
    let imageLayer = CALayer()
    private(set) var image: CGImage?
    private(set) var generation: String?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var output: AVPlayerItemVideoOutput?
    private var displayTimer: Timer?
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private var policy = WallpaperPlaybackPolicy()
    private var requestedMode = "default"
    private var requestedSuspended = false
    private var isPreview = false
    private var systemLocked = false
    private var saverRunning = false
    private var movieURL: URL?
    private(set) var renderedFrameCount = 0
    private var meteor: WallpaperMeteor?
    private var playbackObserver: NSKeyValueObservation?

    init?(size: CGSize, scale: CGFloat, displayID: UInt32?) {
        var options: [String: Any] = ["contentsScale": scale]
        if let displayID { options["displayId"] = displayID }
        guard let context = CAContext.remoteContext(withOptions: options) as? CAContext, context.contextId != 0 else { return nil }
        self.context = context
        root.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.38, alpha: 1).cgColor
        root.masksToBounds = true
        imageLayer.contentsGravity = .resize
        imageLayer.masksToBounds = true
        root.addSublayer(imageLayer)
        resize(size: size, scale: scale)
        context.layer = root
    }
    func resize(size: CGSize, scale: CGFloat) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.frame = CGRect(origin: .zero, size: size)
        root.contentsScale = scale
        imageLayer.frame = Self.topAnchoredFill(image: image.map {CGSize(width: $0.width, height: $0.height)} ?? size, destination: size)
        meteor?.resize(size)
        imageLayer.contentsScale = scale
        CATransaction.commit()
    }
    // Keep the complete upper edge when a 16:10 capture fills a 16:9 monitor.
    // Centre cropping previously removed the lunar disc near that edge.
    static func topAnchoredFill(image: CGSize, destination: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: destination) }
        let scale = max(destination.width / image.width, destination.height / image.height)
        let width = image.width * scale, height = image.height * scale
        return CGRect(x: (destination.width - width) / 2, y: destination.height - height, width: width, height: height)
    }
    func update(mode: String?, suspended: Bool?, preview: Bool? = nil) {
        if let mode { requestedMode = mode }
        if let suspended { requestedSuspended = suspended }
        if let preview { isPreview = preview }
        applyPlaybackState()
    }
    func updateSystemState(locked: Bool, saverRunning: Bool) {
        if (systemLocked && !locked) || (self.saverRunning && !saverRunning) {
            if requestedMode == "locked" || (requestedMode == "idle" && !isPreview) { requestedMode = "default" }
        }
        systemLocked = locked; self.saverRunning = saverRunning
        applyPlaybackState()
    }
    private func applyPlaybackState() {
        let mode = systemLocked ? "locked" : saverRunning ? "idle" : requestedMode
        let previous = policy.phase
        policy.update(mode: mode, suspended: requestedSuspended, now: ProcessInfo.processInfo.systemUptime)
        let rate = policy.rate(at: ProcessInfo.processInfo.systemUptime)
        meteor?.setRate(rate)
        if rate > 0 { startPlaybackIfNeeded(); startTimer() }
        else { player?.pause(); stopTimer() }
        if previous != policy.phase { debugLog("Playback \(previous) -> \(policy.phase), mode=\(mode) decoded=\(renderedFrameCount)") }
    }
    func loadLatestScene(from rootOverride: URL? = nil) {
        let rootURL = rootOverride ?? URL(fileURLWithPath: "/Users/Shared/WeatherWallpaper/\(getuid())", isDirectory: true)
        guard let data = try? Data(contentsOf: rootURL.appendingPathComponent("current.json")),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              manifest["version"] as? Int == 1,
              let next = manifest["generation"] as? String,
              UUID(uuidString: next) != nil, next != generation else { return }
        let directory = rootURL.appendingPathComponent(next, isDirectory: true)
        let movie = directory.appendingPathComponent("sky.mov")
        guard FileManager.default.isReadableFile(atPath: movie.path),
              let source = CGImageSourceCreateWithURL(directory.appendingPathComponent("poster.png") as CFURL, nil),
              let poster = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
        generation = next
        meteor?.layer.removeFromSuperlayer()
        meteor = WallpaperMeteor(directory: directory, metadata: manifest)
        if let meteor { root.addSublayer(meteor.layer); meteor.resize(root.bounds.size); meteor.setRate(policy.rate(at: ProcessInfo.processInfo.systemUptime)) }
        player?.pause(); player = nil; looper = nil; output = nil; playbackObserver = nil
        movieURL = movie
        setImage(poster, crossfade: image != nil)
        // A weather update must never restart desktop animation.
        if policy.rate(at: ProcessInfo.processInfo.systemUptime) > 0 { startPlaybackIfNeeded(); startTimer() }
        debugLog("Loaded scene \(next), phase=\(policy.phase)")
    }
    private func startPlaybackIfNeeded() {
        guard player == nil, let movieURL else { return }
        let item = AVPlayerItem(url: movieURL)
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        self.player = player
        looper = AVPlayerLooper(player: player, templateItem: item)
        // The looper creates replicas: attach output to each current item, not the template.
        playbackObserver = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.player === player, let current = player.currentItem else { return }
                let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange])
                current.add(output); self.output = output
            }
        }
    }
    private func startTimer() {
        guard displayTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common); displayTimer = timer
    }
    private func stopTimer() { displayTimer?.invalidate(); displayTimer = nil }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let rate = policy.rate(at: now)
        guard rate > 0 else {
            player?.pause(); meteor?.setRate(0); stopTimer()
            debugLog("Playback frozen, decoded=\(renderedFrameCount)")
            return
        }
        player?.rate = rate
        meteor?.setRate(rate)
        guard let output else { return }
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time), let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let frame = ciContext.createCGImage(ci, from: ci.extent, format: .RGBA16, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else { return }
        renderedFrameCount += 1
        if renderedFrameCount == 1 { debugLog("First animated frame decoded") }
        setImage(frame, crossfade: false)
    }
    private func setImage(_ frame: CGImage, crossfade: Bool) {
        if crossfade, let image {
            let animation = CABasicAnimation(keyPath: "contents")
            animation.fromValue = image; animation.toValue = frame
            animation.duration = 2; animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            imageLayer.add(animation, forKey: "weather-change")
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        imageLayer.contents = frame; image = frame
        imageLayer.frame = Self.topAnchoredFill(image: CGSize(width: frame.width, height: frame.height), destination: root.bounds.size)
        CATransaction.commit()
    }
    func stop() {
        player?.pause(); player = nil; looper = nil; output = nil
        playbackObserver = nil; meteor?.layer.removeFromSuperlayer(); meteor = nil; stopTimer(); context.layer = nil
    }
    deinit { displayTimer?.invalidate() }
}
