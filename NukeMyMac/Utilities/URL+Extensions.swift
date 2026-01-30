import Foundation

extension URL {
    var fileSize: Int64? {
        let resourceValues = try? resourceValues(forKeys: [.fileSizeKey])
        return resourceValues?.fileSize.map { Int64($0) }
    }

    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}
