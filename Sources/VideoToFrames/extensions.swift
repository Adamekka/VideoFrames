import ArgumentParser
import Cocoa
import Foundation

// MARK: - URL + ExpressibleByArgument

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        let path: String = argument.replacingOccurrences(of: "\\ ", with: " ")
        if path.starts(with: "/") {
            self = URL(fileURLWithPath: path)
        } else if path.starts(with: "~/") {
            if #available(OSX 10.12, *) {
                self = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path.replacingOccurrences(
                    of: "~/",
                    with: ""
                ))
            } else {
                return nil
            }
        } else {
            let callURL: URL = .init(fileURLWithPath: CommandLine.arguments.first!).deletingLastPathComponent()
            if argument == "." {
                self = callURL
            } else {
                self = callURL.appendingPathComponent(path)
            }
        }
    }
}

public extension String {
    func zfill(_ length: Int) -> String {
        let diff: Int = (length - count)
        let prefix: String = (diff > 0 ? String(repeating: "0", count: diff) : "")
        return prefix + self
    }

    func sfill(_ length: Int) -> String {
        let diff: Int = (length - count)
        let prefix: String = (diff > 0 ? String(repeating: " ", count: diff) : "")
        return prefix + self
    }
}
