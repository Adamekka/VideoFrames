import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(VideoFramesTests.allTests),
        ]
    }
#endif
