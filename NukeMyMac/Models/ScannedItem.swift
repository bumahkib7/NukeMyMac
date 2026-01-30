import Foundation

struct ScannedItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let size: Int64
    let category: CleanCategory
    let modificationDate: Date?
    var isSelected: Bool

    init(url: URL, size: Int64, category: CleanCategory, modificationDate: Date? = nil) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.size = size
        self.category = category
        self.modificationDate = modificationDate
        self.isSelected = true
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScannedItem, rhs: ScannedItem) -> Bool {
        lhs.id == rhs.id
    }
}
