import Foundation
import SwiftUI

struct DuplicateGroup: Identifiable, Hashable {
    let id = UUID()
    let hash: String
    let size: Int64
    var files: [DuplicateFile]

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var wastedSpace: Int64 {
        size * Int64(max(0, files.count - 1))
    }

    var totalWastedSize: Int64 {
        wastedSpace
    }

    var formattedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: wastedSpace, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.id == rhs.id
    }
}

struct DuplicateFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var modificationDate: Date?
    var isSelected: Bool = false
    var isOriginal: Bool = false

    // Convenience initializer for scanners that have creation date
    init(url: URL, creationDate: Date? = nil, modificationDate: Date? = nil) {
        self.url = url
        self.modificationDate = modificationDate ?? creationDate
    }

    // Simple initializer
    init(url: URL, modificationDate: Date?) {
        self.url = url
        self.modificationDate = modificationDate
    }

    var path: String { url.deletingLastPathComponent().path }
    var name: String { url.lastPathComponent }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: DuplicateFile, rhs: DuplicateFile) -> Bool {
        lhs.url == rhs.url
    }
}
