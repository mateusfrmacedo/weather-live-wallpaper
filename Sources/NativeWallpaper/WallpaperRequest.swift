import CoreGraphics
import Foundation

// Acquire requests contain a complete value; updates can contain optional fields
// inside additional wrappers. Missing values must leave the hosted session alone.
struct WallpaperRequest {
    var size: CGSize?
    var scale: CGFloat?
    var displayID: UInt32?
    var mode: String?
    var activity: String?
    var preview: Bool?
    var suspended: Bool? { activity.map { $0 == "suspended" } }

    init(_ object: Any?) {
        guard let object else { return }
        mode = Self.field("presentationMode", in: object).flatMap { Self.token($0, among: ["default", "locked", "idle"]) }
        activity = Self.field("activityState", in: object).flatMap { Self.token($0, among: ["active", "inactive", "suspended"]) }
        preview = Self.field("isPreview", in: object).flatMap(Self.unwrap) as? Bool
        if let destination = Self.field("destination", in: object) {
            if let value = Self.field("size", in: destination).flatMap(Self.unwrap) as? CGSize,
               value.width.isFinite, value.height.isFinite,
               value.width >= 1, value.height >= 1, value.width <= 16384, value.height <= 16384 { size = value }
            if let value = Self.field("scaleFactor", in: destination).flatMap(Self.unwrap) as? CGFloat, value.isFinite { scale = min(4, max(1, value)) }
            displayID = Self.field("directDisplayID", in: destination).flatMap(Self.unwrap) as? UInt32
        }
        // Some private types expose their enum fields only in their description.
        if mode == nil || activity == nil {
            let value = Mirror(reflecting: object).children.first?.value ?? object
            let description = String(describing: value)
            if mode == nil { mode = Self.describedField("presentationMode", in: description, among: ["default", "locked", "idle"]) }
            if activity == nil { activity = Self.describedField("activityState", in: description, among: ["active", "inactive", "suspended"]) }
        }
    }
    private static func unwrap(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional { return mirror.children.first.flatMap { unwrap($0.value) } }
        return value
    }
    private static func field(_ name: String, in value: Any) -> Any? {
        var remaining = 256
        func visit(_ value: Any, depth: Int) -> Any? {
            guard depth < 8, remaining > 0, let value = unwrap(value) else { return nil }
            remaining -= 1
            var mirror: Mirror? = Mirror(reflecting: value)
            while let current = mirror {
                for child in current.children where child.label == name { return child.value }
                for child in current.children { if let found = visit(child.value, depth: depth + 1) { return found } }
                mirror = current.superclassMirror
            }
            return nil
        }
        return visit(value, depth: 0)
    }
    private static func token(_ value: Any, among allowed: [String]) -> String? {
        guard let value = unwrap(value) else { return nil }
        let description = String(describing: value)
        return allowed.first { description.range(of: "(?<![A-Za-z])\($0)(?![A-Za-z])", options: .regularExpression) != nil }
    }
    private static func describedField(_ name: String, in description: String, among allowed: [String]) -> String? {
        guard let range = description.range(of: "\(name): ") else { return nil }
        let tail = description[range.upperBound...].prefix(160)
        let value = tail.prefix { $0 != "," }
        return token(String(value), among: allowed)
    }
}
