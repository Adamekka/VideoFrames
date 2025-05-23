import Foundation
#if os(macOS)
    import Cocoa
#else
    import UIKit
#endif
import AVFoundation

public func convertVideoToFrames(from url: URL) async throws -> [_Image] {
    var frames: [_Image] = []
    let asset: Asset = try await makeAsset(from: url)
    for i in 0 ..< asset.info.frameCount {
        let image: _Image = try await getFrame(at: i, info: asset.info, with: asset.generator)
        frames.append(image)
    }
    return frames
}

public func convertVideoToFrames(
    from url: URL,
    frameCount: ((Int) -> Void)? = nil,
    progress: ((Int) -> Void)? = nil
)
    async throws -> [_Image]
{
    var frames: [_Image] = []
    let asset: Asset = try await makeAsset(from: url)
    frameCount?(asset.info.frameCount)
    for i in 0 ..< asset.info.frameCount {
        progress?(i)
        let image: _Image = try await getFrame(at: i, info: asset.info, with: asset.generator)
        frames.append(image)
    }
    return frames
}

public func convertVideoToFrames(
    from url: URL,
    info: VideoInfo? = nil
)
    async throws -> AsyncThrowingStream<_Image, Error>
{
    let asset: Asset = try await makeAsset(from: url, info: info)
    let frameCount: Int = asset.info.frameCount
    return AsyncThrowingStream { stream in
        Task {
            for index in 0 ..< frameCount {
                do {
                    let image: _Image = try await getFrame(at: index, info: asset.info, with: asset.generator)
                    stream.yield(image)
                } catch {
                    stream.finish(throwing: error)
                    break
                }
            }
            stream.finish()
        }
    }
}

public func convertVideoToFramesWithWithHandlerSync(
    from url: URL,
    frame: (_Image, Int, Int) throws -> Void
)
    async throws
{
    let asset: Asset = try await makeAsset(from: url)
    let count: Int = asset.info.frameCount
    for i in 0 ..< count {
        let image: _Image = try await getFrame(at: i, info: asset.info, with: asset.generator)
        try frame(image, i, count)
    }
}

// MARK: - Asset

func makeAsset(from url: URL, info: VideoInfo? = nil) async throws -> Asset {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw VideoFramesError.videoNotFound
    }
    let asset: AVAsset = .init(url: url)
    let videoInfo: VideoInfo = if let info {
        info
    } else {
        try await VideoInfo(asset: asset)
    }
    let generator: AVAssetImageGenerator = .init(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator
        .requestedTimeToleranceBefore = .zero // CMTime(value: CMTimeValue(1), timescale: CMTimeScale(videoInfo.fps))
    generator
        .requestedTimeToleranceAfter = .zero // CMTime(value: CMTimeValue(1), timescale: CMTimeScale(videoInfo.fps))
    return Asset(info: videoInfo, generator: generator)
}

// MARK: - VideoFrameError

enum VideoFrameError: LocalizedError {
    case videoFrameIndexOutOfBounds(frameIndex: Int, frameCount: Int, frameRate: Double)

    var errorDescription: String? {
        switch self {
            case let .videoFrameIndexOutOfBounds(frameIndex, frameCount, frameRate):
                "Video Frames - Video Frame Index Out of Range (Frame Index: \(frameIndex), Frame Count: \(frameCount), Frame Rate: \(frameRate))"
        }
    }
}

public func videoFrame(at frameIndex: Int, from url: URL, info: VideoInfo? = nil) async throws -> _Image {
    let asset: Asset = try await makeAsset(from: url, info: info)
    guard frameIndex >= 0 && frameIndex < asset.info.frameCount else {
        throw VideoFrameError.videoFrameIndexOutOfBounds(
            frameIndex: frameIndex,
            frameCount: asset.info.frameCount,
            frameRate: asset.info.fps
        )
    }
    return try await getFrame(at: frameIndex, info: asset.info, with: asset.generator)
}

func getFrame(at frameIndex: Int, info: VideoInfo, with generator: AVAssetImageGenerator) async throws -> _Image {
    let time: CMTime = .init(
        value: CMTimeValue(frameIndex * 1_000_000),
        timescale: CMTimeScale(info.fps * 1_000_000)
    )
    #if os(visionOS)
        let (cgImage, _): (CGImage, CMTime) = try await generator.image(at: time)
    #else
        let cgImage: CGImage
        if #available(iOS 16, tvOS 16, macOS 13, visionOS 1.0, *) {
            (cgImage, _) = try await generator.image(at: time)
        } else {
            cgImage = try generator.copyCGImage(at: time, actualTime: nil)
        }
    #endif
    #if os(macOS)
        let image: NSImage = .init(cgImage: cgImage, size: info.size)
    #else
        let image: UIImage = .init(cgImage: cgImage)
    #endif
    return image
}
