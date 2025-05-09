import ArgumentParser
import Cocoa
import Foundation
import VideoFrames

// MARK: - VideoToFramesError

enum VideoToFramesError: Error {
    case videoNotFound
    case videoFrameConversionFail(String)
    case unsupportedImageFormat
}

// MARK: - ImageFormat

enum ImageFormat {
    case png
    case jpg(Double)
    case tiff

    var ext: String {
        switch self {
            case .png:
                "png"

            case .jpg:
                "jpg"

            case .tiff:
                "tiff"
        }
    }

    var storageType: NSBitmapImageRep.FileType {
        switch self {
            case .png:
                .png

            case .jpg:
                .jpeg

            case .tiff:
                .tiff
        }
    }

    var properties: [NSBitmapImageRep.PropertyKey: Any] {
        switch self {
            case let .jpg(quality):
                [.compressionFactor: quality]

            default:
                [:]
        }
    }
}

// MARK: - VideoToFrames

struct VideoToFrames: ParsableCommand {
    @Argument() var video: URL

    @Argument() var folder: URL

    @Option() var format: String?

    @Option() var quality: Double?

    @Flag() var force: Bool

    func run() throws {
        let startDate: Date = .init()

        guard FileManager.default.fileExists(atPath: self.video.path) else {
            throw VideoToFramesError.videoNotFound
        }
        if !FileManager.default.fileExists(atPath: self.folder.path) {
            try FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
        }

        let videoName: String = self.video.deletingPathExtension().lastPathComponent

        let imageFormat: ImageFormat
        if self.format == nil {
            imageFormat = .jpg(0.8)
        } else if self.format == ImageFormat.png.ext {
            imageFormat = .png
        } else if self.format == ImageFormat.jpg(0).ext {
            imageFormat = .jpg(self.quality ?? 0.8)
        } else if self.format == ImageFormat.tiff.ext {
            imageFormat = .tiff
        } else {
            print("supported image formats are png, jpg and tiff.")
            throw VideoToFramesError.unsupportedImageFormat
        }

        try convertVideoToFramesSync(from: self.video, force: self.force) { image, index, count in
            logBar(at: index, count: count, from: startDate)
            let name: String = "\(videoName)_\("\(index)".zfill(6)).\(imageFormat.ext)"
            let url: URL = self.folder.appendingPathComponent(name)
            guard let rep: Data = image.tiffRepresentation else {
                throw VideoToFramesError.videoFrameConversionFail("tiff not found")
            }
            guard let bitmap = NSBitmapImageRep(data: rep) else {
                throw VideoToFramesError.videoFrameConversionFail("bitmap not found")
            }
            guard
                let data: Data = bitmap.representation(
                    using: imageFormat.storageType,
                    properties: imageFormat.properties
                ) else
            {
                throw VideoToFramesError.videoFrameConversionFail("rep not found")
            }
            try data.write(to: url)
            if index + 1 == count {
                logBar(at: index, count: count, from: startDate, clear: false)
            }
        }
    }
}

VideoToFrames.main()
