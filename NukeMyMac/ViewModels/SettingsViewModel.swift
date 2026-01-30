import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Singleton

    static let shared = SettingsViewModel(shared: true)

    private let isShared: Bool

    // MARK: - App Storage Keys

    private enum StorageKeys {
        static let selectedCategories = "selectedCategories"
        static let skipHiddenFiles = "skipHiddenFiles"
        static let confirmBeforeDelete = "confirmBeforeDelete"
        static let suppressDeleteConfirmation = "suppressDeleteConfirmation"
        static let autoRefreshDiskUsage = "autoRefreshDiskUsage"
        static let showDestructiveWarnings = "showDestructiveWarnings"
        static let sortOrder = "sortOrder"
        static let groupByCategory = "groupByCategory"
        static let minimumFileSize = "minimumFileSize"
        static let oldDownloadsDays = "oldDownloadsDays"
        static let reduceAnimations = "reduceAnimations"
    }

    // MARK: - Published Properties with AppStorage backing

    /// Categories enabled for scanning - stored as comma-separated raw values
    @AppStorage(StorageKeys.selectedCategories)
    var selectedCategoriesRaw: String = CleanCategory.allCases.map { $0.rawValue }.joined(separator: ",")

    /// Whether to skip hidden files during scanning
    @AppStorage(StorageKeys.skipHiddenFiles)
    var skipHiddenFiles: Bool = true

    /// Whether to show confirmation dialog before deleting
    @AppStorage(StorageKeys.confirmBeforeDelete)
    var confirmBeforeDelete: Bool = true

    /// Whether the user has chosen to suppress delete confirmations ("Don't ask again")
    @AppStorage(StorageKeys.suppressDeleteConfirmation)
    var suppressDeleteConfirmation: Bool = false

    /// Whether to reduce animations for accessibility
    @AppStorage(StorageKeys.reduceAnimations)
    var reduceAnimations: Bool = false

    /// Auto-refresh disk usage after operations
    @AppStorage(StorageKeys.autoRefreshDiskUsage)
    var autoRefreshDiskUsage: Bool = true

    /// Show warnings for destructive categories
    @AppStorage(StorageKeys.showDestructiveWarnings)
    var showDestructiveWarnings: Bool = true

    /// Sort order for scan results
    @AppStorage(StorageKeys.sortOrder)
    var sortOrderRaw: String = SortOrder.sizeDescending.rawValue

    /// Group items by category in results view
    @AppStorage(StorageKeys.groupByCategory)
    var groupByCategory: Bool = true

    /// Minimum file size to include (in bytes, 0 = no minimum)
    @AppStorage(StorageKeys.minimumFileSize)
    var minimumFileSize: Int = 0

    /// Days threshold for old downloads
    @AppStorage(StorageKeys.oldDownloadsDays)
    var oldDownloadsDays: Int = 30

    // MARK: - Computed Properties

    /// Get selected categories as array
    var selectedCategories: Set<CleanCategory> {
        get {
            let rawValues = selectedCategoriesRaw.split(separator: ",").map { String($0) }
            let categories = rawValues.compactMap { CleanCategory(rawValue: $0) }
            return Set(categories)
        }
        set {
            selectedCategoriesRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }

    /// Get enabled categories for scanning (same as selected)
    var enabledCategories: [CleanCategory] {
        Array(selectedCategories)
    }

    /// Get sort order enum
    var sortOrder: SortOrder {
        get {
            SortOrder(rawValue: sortOrderRaw) ?? .sizeDescending
        }
        set {
            sortOrderRaw = newValue.rawValue
        }
    }

    /// Check if a category is selected
    func isCategorySelected(_ category: CleanCategory) -> Bool {
        selectedCategories.contains(category)
    }

    // MARK: - Category Management

    func toggleCategory(_ category: CleanCategory) {
        var categories = selectedCategories
        if categories.contains(category) {
            categories.remove(category)
        } else {
            categories.insert(category)
        }
        selectedCategories = categories
        objectWillChange.send()
    }

    func enableCategory(_ category: CleanCategory) {
        var categories = selectedCategories
        categories.insert(category)
        selectedCategories = categories
        objectWillChange.send()
    }

    func disableCategory(_ category: CleanCategory) {
        var categories = selectedCategories
        categories.remove(category)
        selectedCategories = categories
        objectWillChange.send()
    }

    func selectAllCategories() {
        selectedCategories = Set(CleanCategory.allCases)
        objectWillChange.send()
    }

    func deselectAllCategories() {
        selectedCategories = []
        objectWillChange.send()
    }

    func selectSafeCategories() {
        // Select only non-destructive categories
        let safeCategories = CleanCategory.allCases.filter { !$0.isDestructive }
        selectedCategories = Set(safeCategories)
        objectWillChange.send()
    }

    // MARK: - Destructive Category Helpers

    var hasDestructiveCategoriesSelected: Bool {
        selectedCategories.contains { $0.isDestructive }
    }

    var selectedDestructiveCategories: [CleanCategory] {
        enabledCategories.filter { $0.isDestructive }
    }

    // MARK: - Reset

    func resetToDefaults() {
        selectedCategoriesRaw = CleanCategory.allCases.map { $0.rawValue }.joined(separator: ",")
        skipHiddenFiles = true
        confirmBeforeDelete = true
        suppressDeleteConfirmation = false
        reduceAnimations = false
        autoRefreshDiskUsage = true
        showDestructiveWarnings = true
        sortOrderRaw = SortOrder.sizeDescending.rawValue
        groupByCategory = true
        minimumFileSize = 0
        oldDownloadsDays = 30
        objectWillChange.send()
    }

    // MARK: - Initialization

    init(shared: Bool = false) {
        self.isShared = shared
    }
}

// MARK: - Sort Order Enum

enum SortOrder: String, CaseIterable, Identifiable {
    case sizeDescending = "Size (Largest First)"
    case sizeAscending = "Size (Smallest First)"
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case dateNewest = "Date (Newest First)"
    case dateOldest = "Date (Oldest First)"
    case category = "Category"

    var id: String { rawValue }

    func sort(_ items: [ScannedItem]) -> [ScannedItem] {
        switch self {
        case .sizeDescending:
            return items.sorted { $0.size > $1.size }
        case .sizeAscending:
            return items.sorted { $0.size < $1.size }
        case .nameAscending:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .dateNewest:
            return items.sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
        case .dateOldest:
            return items.sorted { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) }
        case .category:
            return items.sorted { $0.category.rawValue < $1.category.rawValue }
        }
    }
}

// MARK: - Settings Binding Helpers

extension SettingsViewModel {
    /// Create a binding for a specific category's selection state
    func binding(for category: CleanCategory) -> Binding<Bool> {
        Binding(
            get: { self.isCategorySelected(category) },
            set: { isSelected in
                if isSelected {
                    self.enableCategory(category)
                } else {
                    self.disableCategory(category)
                }
            }
        )
    }
}
