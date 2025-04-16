@preconcurrency import AVFoundation
import Foundation
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// MARK: - ToVideoError

public enum ToVideoError: String, LocalizedError {
    case notReadyForMoreMediaData
}

public extension ToVideoError {
    var errorDescription: String? {
        switch self {
            case .notReadyForMoreMediaData:
                "Not ready for more media data."
        }
    }
}

// MARK: - VideoFormat

public enum VideoFormat: String, CaseIterable, Sendable {
    case mov
    case mp4
    public var fileType: AVFileType {
        switch self {
            case .mov: .mov
            case .mp4: .mp4
        }
    }
}

// MARK: - VideoCodec

public enum VideoCodec: String, CaseIterable, Sendable {
    case h264
    case proRes
    public var codec: AVVideoCodecType {
        switch self {
            case .h264:
                return .h264
            case .proRes:
                #if os(visionOS)
                    print("VideoFrames - Warning: ProRes is not supported on visionOS. Using h264.")
                    return .h264
                #else
                    return .proRes4444
                #endif
        }
    }
}

public func convertFramesToVideo(
    images: [_Image],
    fps: Double = 30.0,
    kbps: Int = 10000,
    format: VideoFormat = .mov,
    codec: VideoCodec = .h264,
    url: URL,
    frame: (@Sendable (Int) -> Void)? = nil
)
    async throws
{
    precondition(!images.isEmpty)

    let firstImage: _Image = images.first!
    let resolution: CGSize = firstImage.size

    let videoFrames = images.map { VideoFrame(image: $0) }

    final class ContinuationWrapper: @unchecked Sendable {
        var continuation: AsyncStream<VideoFrame>.Continuation? = nil
    }

    let continuation = ContinuationWrapper()
    let stream = AsyncStream<VideoFrame> {
        continuation.continuation = $0
    }

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await convertFramesToVideo(
                stream: stream,
                resolution: resolution,
                fps: fps,
                kbps: kbps,
                format: format,
                codec: codec,
                url: url
            )
        }
        group.addTask {
            for (index, videoFrame) in videoFrames.enumerated() {
                frame?(index)
                continuation.continuation?.yield(videoFrame)
            }
            continuation.continuation?.finish()
        }
        try await group.waitForAll()
    }
}

public func convertFramesToVideo(
    stream: AsyncStream<VideoFrame>,
    resolution: CGSize,
    fps: Double = 30.0,
    kbps: Int = 10000,
    format: VideoFormat = .mov,
    codec: VideoCodec = .h264,
    url: URL
)
    async throws
{
    precondition(fps > 0)
    precondition(kbps > 0)

    let writer = try AVAssetWriter(url: url, fileType: format.fileType)

    let bps: Int = kbps * 1000

    // FPS (29,97 / 999) * 1000 == 30
    // FPS (29,7 / 99) * 100 == 30

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: codec.codec,
        AVVideoWidthKey: resolution.width,
        AVVideoHeightKey: resolution.height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: bps,
        ],
    ])

    writer.add(input)

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: resolution.width,
        kCVPixelBufferHeightKey as String: resolution.height,
    ])

    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    if adaptor.pixelBufferPool == nil {
        print("Error converting images to video: pixelBufferPool nil after starting session")
        return
    }

    let queue = DispatchQueue(label: "video-frames")

    let _: Void = try await withCheckedThrowingContinuation { continuation in
        input.requestMediaDataWhenReady(on: queue) {
            Task {
                do {
                    var frameIndex: Int = 0
                    for await videoFrame in stream {
                        guard input.isReadyForMoreMediaData else {
                            throw ToVideoError.notReadyForMoreMediaData
                        }
                        let time: CMTime = CMTimeMake(
                            value: Int64(frameIndex * 1000),
                            timescale: Int32(fps * 1000)
                        )
                        let pixelBuffer: CVPixelBuffer = try getPixelBuffer(from: videoFrame.image)
                        adaptor.append(pixelBuffer, withPresentationTime: time)
                        frameIndex += 1
                    }
                    input.markAsFinished()
                    writer.finishWriting {
                        if let error = writer.error {
                            continuation.resume(throwing: error)
                            return
                        }
                        continuation.resume()
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

func getPixelBuffer(from image: _Image) throws -> CVPixelBuffer {
    #if os(macOS)
        guard let cgImage: CGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VideoFramesError.framePixelBuffer("CGImage Not Found")
        }
    #else
        guard let cgImage: CGImage = image.cgImage else {
            throw VideoFramesError.framePixelBuffer("CGImage Not Found")
        }
    #endif
    return try getPixelBuffer(from: cgImage)
}

func getPixelBuffer(from cgImage: CGImage) throws -> CVPixelBuffer {
    let osBits: OSType = kCVPixelFormatType_32ARGB
    let bitCount: Int = 8
    let colorSpace: CGColorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
    var maybePixelBuffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferPixelFormatTypeKey: Int(osBits) as CFNumber,
        kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
    ]
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        cgImage.width,
        cgImage.height,
        osBits,
        attrs as CFDictionary,
        &maybePixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
        throw VideoFramesError.framePixelBuffer("CVPixelBufferCreate failed with status \(status)")
    }
    let flags = CVPixelBufferLockFlags(rawValue: 0)
    guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, flags) else {
        throw VideoFramesError.framePixelBuffer("CVPixelBufferLockBaseAddress failed.")
    }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }
    guard
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: bitCount,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else
    {
        throw VideoFramesError.framePixelBuffer("Context failed to be created.")
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return pixelBuffer
}
