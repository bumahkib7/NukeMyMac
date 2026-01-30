import Foundation

struct ScanResult {
    var items: [ScannedItem]
    var totalSize: Int64
    var scanDuration: TimeInterval
    var errorMessages: [String]

    init(items: [ScannedItem] = [], scanDuration: TimeInterval = 0, errorMessages: [String] = []) {
        self.items = items
        self.totalSize = items.reduce(0) { $0 + $1.size }
        self.scanDuration = scanDuration
        self.errorMessages = errorMessages
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var selectedItems: [ScannedItem] {
        items.filter { $0.isSelected }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }

    func itemsByCategory() -> [CleanCategory: [ScannedItem]] {
        Dictionary(grouping: items, by: { $0.category })
    }

    func sizeByCategory() -> [CleanCategory: Int64] {
        var result: [CleanCategory: Int64] = [:]
        for (category, items) in itemsByCategory() {
            result[category] = items.reduce(0) { $0 + $1.size }
        }
        return result
    }

    mutating func selectAll() {
        for i in items.indices {
            items[i].isSelected = true
        }
    }

    mutating func deselectAll() {
        for i in items.indices {
            items[i].isSelected = false
        }
    }

    mutating func toggleCategory(_ category: CleanCategory) {
        let categoryItems = items.filter { $0.category == category }
        let allSelected = categoryItems.allSatisfy { $0.isSelected }

        for i in items.indices where items[i].category == category {
            items[i].isSelected = !allSelected
        }
    }
}
