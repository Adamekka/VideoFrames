import ArgumentParser
import Cocoa
import Foundation
import VideoFrames

// MARK: - VideoToFramesError

enum VideoToFramesError: Error {
    case framesFolderNotFound
    case videoFrameBadData
    case unsupportedVideoFormat
    case noFramesFound
    case imageCorrupt(String)
}

// MARK: - VideoToFrames

struct VideoToFrames: ParsableCommand {
    @Argument() var folder: URL

    @Argument() var video: URL

    @Option(name: .long) var fps: Int?

    @Option(name: .long) var kbps: Int?

    func run() throws {
        let startDate: Date = .init()

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: self.folder.path, isDirectory: &isDir) else {
            throw VideoToFramesError.framesFolderNotFound
        }
        guard isDir.boolValue else {
            throw VideoToFramesError.framesFolderNotFound
        }

        let imageURLs: [URL] = try FileManager.default.contentsOfDirectory(atPath: self.folder.path)
            .sorted { nameA, nameB -> Bool in
                nameA < nameB
            }
            .map { name -> URL in
                self.folder.appendingPathComponent(name)
            }
            .filter { url -> Bool in
                ["png", "jpg", "tiff"].contains(url.pathExtension.lowercased())
            }
        guard !imageURLs.isEmpty else {
            throw VideoToFramesError.noFramesFound
        }

        if FileManager.default.fileExists(atPath: self.video.path) {
            print("override video? y/n")
            guard ["y", "yes"].contains(readLine()) else {
                return
            }
            try FileManager.default.removeItem(at: self.video)
        }

        let format: String = self.video.pathExtension
        guard let videoFormat: VideoFormat = VideoFormat(rawValue: format) else {
            print("supported formats: \(VideoFormat.allCases.map(\.rawValue).joined(separator: ", "))")
            throw VideoToFramesError.unsupportedVideoFormat
        }

        var result: Result<Void, Error>!
        let group: DispatchGroup = .init()
        group.enter()
        try convertFramesToVideo(
            count: imageURLs.count,
            image: { index in
                let url: URL = imageURLs[index]
                guard let image: NSImage = NSImage(contentsOf: url) else {
                    throw VideoToFramesError.imageCorrupt(url.lastPathComponent)
                }
                return image
            },
            fps: self.fps ?? 30,
            kbps: self.kbps ?? 1000,
            as: videoFormat,
            url: self.video,
            frame: { index in
                logBar(at: index, count: imageURLs.count, from: startDate)
            },
            completion: { res in
                logBar(at: imageURLs.count - 1, count: imageURLs.count, from: startDate, clear: false)
                result = res
                group.leave()
            }
        )
        group.wait()
        try result.get()
    }
}

VideoToFrames.main()
