import Testing
@testable import VideoFrames
import XCTest

final class VideoFramesTests: XCTestCase {
    private var repoURL: URL!
    private var videoURL: URL!

    override func setUp() {
        #if os(macOS)
            if #available(OSX 10.12, *) {
                repoURL = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Coding/VideoFrames/")
            }
        #endif
        self.videoURL = self.repoURL.appendingPathComponent("Resources/TestVideo.mp4")
        XCTAssert(FileManager.default.fileExists(atPath: self.videoURL.path))
    }

    override func tearDown() {
        self.repoURL = nil
        self.videoURL = nil
        super.tearDown()
    }

    #if os(macOS)

        // func testConvertVideoToFramesAsync() {
        //     let expectation = self.expectation(description: "Render")
        //     var frames: [Int] = []
        //     try! convertVideoToFramesAsync(from: self.videoURL, frame: { _, index in
        //         frames.append(index)
        //         print("render", index)
        //     }) { result in
        //         switch result {
        //             case .success:
        //                 break
        //             case let .failure(error):
        //                 XCTFail(error.localizedDescription)
        //         }
        //         expectation.fulfill()
        //     }
        //     waitForExpectations(timeout: 1, handler: nil)
        //     print(frames)
        //     XCTAssertEqual(frames.count, 100)
        // }

        func testConvertVideoToFrames() async {
            let frames: [NSImage]? = try? await convertVideoToFrames(from: self.videoURL)
            guard let frames: [NSImage] = consume frames else {
                XCTAssert(false)
                return
            }
            XCTAssertEqual(frames.count, 442)
        }

        func testConvertFramesToVideo() async {
            let frames: [NSImage]? = try? await convertVideoToFrames(from: self.videoURL)
            guard let frames: [NSImage] = consume frames else {
                XCTAssert(false)
                return
            }
            let url: URL = self.repoURL.appendingPathComponent("Resources/TestVideoOut.mp4")
            try? FileManager.default.removeItem(at: url)
            try? convertFramesToVideo(images: frames, fps: 30, url: url)
            XCTAssert(FileManager.default.fileExists(atPath: url.path))
        }

        @MainActor static let allTests: [(String, (VideoFramesTests) -> () async -> Void)] = [
            ("testConvertVideoToFrames", testConvertVideoToFrames),
            ("testConvertFramesToVideo", testConvertFramesToVideo),
        ]

    #else

        static var allTests: [(String, () -> Void)] = []

    #endif
}
