#if os(macOS)
    import Cocoa
#else
    import UIKit
#endif
@preconcurrency import AVFoundation

#if os(macOS)
    public typealias _Image = NSImage // swiftlint:disable:this type_name
#else
    public typealias _Image = UIImage // swiftlint:disable:this type_name
#endif

// MARK: - VideoActor

@globalActor
actor VideoActor {
    static let shared: VideoActor = .init()
}

// MARK: - VideoFrame

public struct VideoFrame: @unchecked Sendable {
    public let image: _Image

    public init(image: _Image) {
        self.image = image
    }
}

// MARK: - VideoFramesError

public enum VideoFramesError: Error {
    case videoNotFound
    case framePixelBuffer(String)
    case videoInfo(String)
}

// MARK: - VideoInfo

public struct VideoInfo: Sendable {
    public let duration: Double
    public let fps: Double
    public let size: CGSize
    public var frameCount: Int { Int(self.duration * self.fps) }
    public let isStereoscopic: Bool

    public init(duration: Double, fps: Double, size: CGSize, isStereoscopic: Bool = false) {
        self.duration = duration
        self.fps = min(fps, 240)
        self.size = size
        self.isStereoscopic = isStereoscopic
    }

    public init(url: URL) async throws {
        let asset: AVAsset = .init(url: url)
        try await self.init(asset: asset)
    }

    init(asset: AVAsset) async throws {
        guard let track: AVAssetTrack = try await asset.load(.tracks).first else {
            throw VideoFramesError.videoInfo("Video asset track not found.")
        }
        self.duration = try await CMTimeGetSeconds(asset.load(.duration))
        self.fps = try await Double(track.load(.nominalFrameRate))
        self.size = try await track.load(.naturalSize)
        self.isStereoscopic = try await Self.isStereoscopic(avAsset: asset)
    }

    private static func isStereoscopic(avAsset: AVAsset) async throws -> Bool {
        guard let videoTrack = try await avAsset.loadTracks(withMediaType: .video).first else {
            return false
        }
        // First attempt with format description
        let formatDescriptions: [CMFormatDescription] = try await videoTrack.load(.formatDescriptions)
        for formatDescription: CMFormatDescription in formatDescriptions {
            if let extensions: [String: Any] = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any] {
                let hasLeftEye: Bool = extensions["HasLeftStereoEyeView"] as? Bool ?? false
                let hasRightEye: Bool = extensions["HasRightStereoEyeView"] as? Bool ?? false
                return hasLeftEye && hasRightEye
            }
        }
        return false
    }
}

// MARK: - Asset

struct Asset: Sendable {
    let info: VideoInfo
    let generator: AVAssetImageGenerator
}

public extension String {
    func zfill(_ length: Int) -> String {
        self.fill("0", for: length)
    }

    func sfill(_ length: Int) -> String {
        self.fill(" ", for: length)
    }

    internal func fill(_ char: Character, for length: Int) -> String {
        let diff: Int = (length - count)
        let prefix: String = (diff > 0 ? String(repeating: char, count: diff) : "")
        return prefix + self
    }
}

extension Double {
    var formattedSeconds: String {
        let milliseconds: Int = .init(self.truncatingRemainder(dividingBy: 1.0) * 1000)
        let formattedMilliseconds: String = "\(milliseconds)".zfill(3)
        return "\(Int(self).formattedSeconds).\(formattedMilliseconds)"
    }
}

extension Int {
    var formattedSeconds: String {
        let formatter: DateComponentsFormatter = .init()
        formatter.allowedUnits = [.second, .minute, .hour]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(self))!
    }
}

public func logBar(at index: Int, count: Int, from date: Date, length: Int = 50, clear: Bool = true) {
    let fraction: Double = .init(index) / Double(count - 1)
    var bar: String = ""
    bar += "["
    for i in 0 ..< length {
        let f: Double = .init(i) / Double(length)
        bar += f < fraction ? "=" : " "
    }
    bar += "]"
    let percent: String = "\("\(Int(round(fraction * 100)))".sfill(3))%"
    let progress: String = "\("\(index + 1)".sfill("\(count)".count))/\(count)"
    let timestamp: String = (-date.timeIntervalSinceNow).formattedSeconds
    let msg: String = "\(bar)  \(percent)  \(progress)  \(timestamp)"
    if clear {
        print(msg, "\r", terminator: "")
        fflush(stdout)
    } else {
        print(msg)
    }
}
