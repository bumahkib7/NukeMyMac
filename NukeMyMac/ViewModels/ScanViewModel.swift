import Foundation
import SwiftUI
import Combine

@MainActor
final class ScanViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isScanning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentCategory: CleanCategory?
    @Published var statusMessage: String = ""
    @Published var scanResult: ScanResult?
    @Published var errorMessage: String?

    // MARK: - Services

    private let diskScanner = DiskScanner.shared

    // MARK: - Computed Properties

    var hasResults: Bool {
        guard let result = scanResult else { return false }
        return !result.items.isEmpty
    }

    var totalItemsFound: Int {
        scanResult?.items.count ?? 0
    }

    var totalSize: Int64 {
        scanResult?.totalSize ?? 0
    }

    var formattedTotalSize: String {
        scanResult?.formattedTotalSize ?? "0 bytes"
    }

    var itemsByCategory: [CleanCategory: [ScannedItem]] {
        scanResult?.itemsByCategory() ?? [:]
    }

    var sizeByCategory: [CleanCategory: Int64] {
        scanResult?.sizeByCategory() ?? [:]
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    // MARK: - Scanning Methods

    /// Scan all provided categories
    func scan(categories: [CleanCategory]) async {
        guard !isScanning else { return }

        isScanning = true
        progress = 0.0
        errorMessage = nil
        statusMessage = "Preparing to scan..."

        let result = await diskScanner.scan(categories: categories, progress: { [weak self] prog, message in
            Task { @MainActor in
                self?.progress = prog
                self?.statusMessage = message
                // Extract current category from message if possible
                if let categoryName = self?.extractCategoryFromMessage(message) {
                    self?.currentCategory = CleanCategory.allCases.first { $0.rawValue == categoryName }
                }
            }
        }, fileFound: { _, _, _ in
            // ScanViewModel doesn't track individual files
        })

        scanResult = result
        isScanning = false
        progress = 1.0
        currentCategory = nil

        if !result.errorMessages.isEmpty {
            errorMessage = result.errorMessages.joined(separator: "\n")
        }

        statusMessage = "Scan complete. Found \(result.items.count) items."
    }

    /// Scan a single category
    func scanCategory(_ category: CleanCategory) async {
        guard !isScanning else { return }

        isScanning = true
        progress = 0.0
        currentCategory = category
        errorMessage = nil
        statusMessage = "Scanning \(category.rawValue)..."

        let result = await diskScanner.scan(categories: [category], progress: { [weak self] prog, message in
            Task { @MainActor in
                self?.progress = prog
                self?.statusMessage = message
            }
        }, fileFound: { _, _, _ in
            // ScanViewModel doesn't track individual files
        })

        // Merge with existing results
        mergeResults(result, for: category)

        isScanning = false
        progress = 1.0
        currentCategory = nil

        if !result.errorMessages.isEmpty {
            errorMessage = result.errorMessages.joined(separator: "\n")
        }

        statusMessage = "Finished scanning \(category.rawValue)"
    }

    /// Scan multiple categories in sequence
    func scanCategories(_ categories: [CleanCategory]) async {
        guard !isScanning else { return }

        for category in categories {
            await scanCategory(category)
        }
    }

    /// Rescan a specific category, replacing its previous results
    func rescanCategory(_ category: CleanCategory) async {
        // Remove existing items for this category
        if var result = scanResult {
            result.items.removeAll { $0.category == category }
            scanResult = result
        }

        await scanCategory(category)
    }

    // MARK: - Helper Methods

    private func mergeResults(_ newResult: ScanResult, for category: CleanCategory) {
        if var existingResult = scanResult {
            // Remove old items from this category
            existingResult.items.removeAll { $0.category == category }
            // Add new items
            existingResult.items.append(contentsOf: newResult.items)
            // Create new ScanResult with merged data
            scanResult = ScanResult(
                items: existingResult.items,
                scanDuration: existingResult.scanDuration + newResult.scanDuration,
                errorMessages: existingResult.errorMessages + newResult.errorMessages
            )
        } else {
            scanResult = newResult
        }
    }

    private func extractCategoryFromMessage(_ message: String) -> String? {
        // Message format: "Scanning Category Name..."
        if message.hasPrefix("Scanning ") && message.hasSuffix("...") {
            let start = message.index(message.startIndex, offsetBy: 9)
            let end = message.index(message.endIndex, offsetBy: -3)
            return String(message[start..<end])
        }
        return nil
    }

    // MARK: - Selection Methods

    func selectAllInCategory(_ category: CleanCategory) {
        guard var result = scanResult else { return }
        for i in result.items.indices where result.items[i].category == category {
            result.items[i].isSelected = true
        }
        scanResult = result
    }

    func deselectAllInCategory(_ category: CleanCategory) {
        guard var result = scanResult else { return }
        for i in result.items.indices where result.items[i].category == category {
            result.items[i].isSelected = false
        }
        scanResult = result
    }

    func toggleItemSelection(_ item: ScannedItem) {
        guard var result = scanResult,
              let index = result.items.firstIndex(where: { $0.id == item.id }) else { return }
        result.items[index].isSelected.toggle()
        scanResult = result
    }

    // MARK: - Utility Methods

    func itemsForCategory(_ category: CleanCategory) -> [ScannedItem] {
        scanResult?.items.filter { $0.category == category } ?? []
    }

    func sizeForCategory(_ category: CleanCategory) -> Int64 {
        itemsForCategory(category).reduce(0) { $0 + $1.size }
    }

    func formattedSizeForCategory(_ category: CleanCategory) -> String {
        ByteCountFormatter.string(fromByteCount: sizeForCategory(category), countStyle: .file)
    }

    func selectedItemsInCategory(_ category: CleanCategory) -> [ScannedItem] {
        itemsForCategory(category).filter { $0.isSelected }
    }

    func selectedSizeInCategory(_ category: CleanCategory) -> Int64 {
        selectedItemsInCategory(category).reduce(0) { $0 + $1.size }
    }

    // MARK: - Reset

    func reset() {
        scanResult = nil
        progress = 0.0
        statusMessage = ""
        errorMessage = nil
        currentCategory = nil
        isScanning = false
    }

    func clearCategory(_ category: CleanCategory) {
        guard var result = scanResult else { return }
        result.items.removeAll { $0.category == category }
        scanResult = result
    }
}
