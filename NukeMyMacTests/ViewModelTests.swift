//
//  ViewModelTests.swift
//  NukeMyMacTests
//
//  Tests for ViewModels
//

import XCTest
import SwiftUI
@testable import NukeMyMac

// MARK: - SettingsViewModel Tests

@MainActor
final class SettingsViewModelTests: XCTestCase {

    var viewModel: SettingsViewModel!

    override func setUp() async throws {
        viewModel = SettingsViewModel()
        viewModel.resetToDefaults()
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    // MARK: - Default Values

    func testDefaultValues() throws {
        XCTAssertTrue(viewModel.skipHiddenFiles)
        XCTAssertTrue(viewModel.confirmBeforeDelete)
        XCTAssertTrue(viewModel.autoRefreshDiskUsage)
        XCTAssertTrue(viewModel.showDestructiveWarnings)
        XCTAssertTrue(viewModel.groupByCategory)
        XCTAssertEqual(viewModel.minimumFileSize, 0)
        XCTAssertEqual(viewModel.oldDownloadsDays, 30)
        XCTAssertEqual(viewModel.sortOrder, .sizeDescending)
    }

    func testAllCategoriesSelectedByDefault() throws {
        XCTAssertEqual(viewModel.selectedCategories.count, CleanCategory.allCases.count)

        for category in CleanCategory.allCases {
            XCTAssertTrue(viewModel.isCategorySelected(category), "Category \(category.rawValue) should be selected by default")
        }
    }

    // MARK: - Category Toggle

    func testToggleCategory() throws {
        XCTAssertTrue(viewModel.isCategorySelected(.systemCaches))

        viewModel.toggleCategory(.systemCaches)
        XCTAssertFalse(viewModel.isCategorySelected(.systemCaches))

        viewModel.toggleCategory(.systemCaches)
        XCTAssertTrue(viewModel.isCategorySelected(.systemCaches))
    }

    func testEnableCategory() throws {
        viewModel.disableCategory(.docker)
        XCTAssertFalse(viewModel.isCategorySelected(.docker))

        viewModel.enableCategory(.docker)
        XCTAssertTrue(viewModel.isCategorySelected(.docker))
    }

    func testDisableCategory() throws {
        XCTAssertTrue(viewModel.isCategorySelected(.trash))

        viewModel.disableCategory(.trash)
        XCTAssertFalse(viewModel.isCategorySelected(.trash))
    }

    func testSelectAllCategories() throws {
        viewModel.deselectAllCategories()
        XCTAssertEqual(viewModel.selectedCategories.count, 0)

        viewModel.selectAllCategories()
        XCTAssertEqual(viewModel.selectedCategories.count, CleanCategory.allCases.count)
    }

    func testDeselectAllCategories() throws {
        XCTAssertEqual(viewModel.selectedCategories.count, CleanCategory.allCases.count)

        viewModel.deselectAllCategories()
        XCTAssertEqual(viewModel.selectedCategories.count, 0)
    }

    func testSelectSafeCategories() throws {
        viewModel.deselectAllCategories()
        viewModel.selectSafeCategories()

        // Should select all non-destructive categories
        for category in CleanCategory.allCases {
            if category.isDestructive {
                XCTAssertFalse(viewModel.isCategorySelected(category), "Destructive category \(category.rawValue) should NOT be selected")
            } else {
                XCTAssertTrue(viewModel.isCategorySelected(category), "Safe category \(category.rawValue) should be selected")
            }
        }
    }

    // MARK: - Destructive Category Helpers

    func testHasDestructiveCategoriesSelected() throws {
        viewModel.selectAllCategories()
        XCTAssertTrue(viewModel.hasDestructiveCategoriesSelected)

        viewModel.selectSafeCategories()
        XCTAssertFalse(viewModel.hasDestructiveCategoriesSelected)

        // Add one destructive category
        viewModel.enableCategory(.largeFiles)
        XCTAssertTrue(viewModel.hasDestructiveCategoriesSelected)
    }

    func testSelectedDestructiveCategories() throws {
        viewModel.selectSafeCategories()
        XCTAssertEqual(viewModel.selectedDestructiveCategories.count, 0)

        viewModel.enableCategory(.iosBackups)
        viewModel.enableCategory(.largeFiles)
        XCTAssertEqual(viewModel.selectedDestructiveCategories.count, 2)
    }

    // MARK: - Sort Order

    func testSortOrderChange() throws {
        XCTAssertEqual(viewModel.sortOrder, .sizeDescending)

        viewModel.sortOrder = .nameAscending
        XCTAssertEqual(viewModel.sortOrder, .nameAscending)

        viewModel.sortOrder = .dateNewest
        XCTAssertEqual(viewModel.sortOrder, .dateNewest)
    }

    // MARK: - Reset

    func testResetToDefaults() throws {
        // Modify everything
        viewModel.skipHiddenFiles = false
        viewModel.confirmBeforeDelete = false
        viewModel.deselectAllCategories()
        viewModel.sortOrder = .nameDescending
        viewModel.minimumFileSize = 1000
        viewModel.oldDownloadsDays = 60

        // Reset
        viewModel.resetToDefaults()

        // Verify defaults
        XCTAssertTrue(viewModel.skipHiddenFiles)
        XCTAssertTrue(viewModel.confirmBeforeDelete)
        XCTAssertEqual(viewModel.selectedCategories.count, CleanCategory.allCases.count)
        XCTAssertEqual(viewModel.sortOrder, .sizeDescending)
        XCTAssertEqual(viewModel.minimumFileSize, 0)
        XCTAssertEqual(viewModel.oldDownloadsDays, 30)
    }

    // MARK: - Category Binding

    func testCategoryBinding() throws {
        let binding = viewModel.binding(for: .docker)

        XCTAssertTrue(binding.wrappedValue)

        binding.wrappedValue = false
        XCTAssertFalse(viewModel.isCategorySelected(.docker))

        binding.wrappedValue = true
        XCTAssertTrue(viewModel.isCategorySelected(.docker))
    }

    // MARK: - Enabled Categories

    func testEnabledCategories() throws {
        viewModel.selectAllCategories()
        XCTAssertEqual(viewModel.enabledCategories.count, CleanCategory.allCases.count)

        viewModel.deselectAllCategories()
        XCTAssertEqual(viewModel.enabledCategories.count, 0)
    }
}

// MARK: - AppState Tests

@MainActor
final class AppStateTests: XCTestCase {

    var appState: AppState!

    override func setUp() async throws {
        appState = AppState()
        appState.reset()
    }

    override func tearDown() async throws {
        appState = nil
    }

    // MARK: - Initial State

    func testInitialState() throws {
        XCTAssertNil(appState.scanResult)
        XCTAssertNil(appState.cleaningResult)
        XCTAssertFalse(appState.isScanning)
        XCTAssertFalse(appState.isCleaning)
        XCTAssertEqual(appState.scanProgress, 0.0)
        XCTAssertFalse(appState.showingConfirmation)
        XCTAssertEqual(appState.statusMessage, "Ready to scan")
    }

    // MARK: - Computed Properties

    func testHasSelectedItemsWithNoResults() throws {
        XCTAssertFalse(appState.hasSelectedItems)
        XCTAssertEqual(appState.selectedItemsCount, 0)
        XCTAssertEqual(appState.selectedSize, 0)
    }

    func testHasSelectedItemsWithResults() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        appState.scanResult = ScanResult(items: items)

        XCTAssertTrue(appState.hasSelectedItems)
        XCTAssertEqual(appState.selectedItemsCount, 2)
        XCTAssertEqual(appState.selectedSize, 3000)
    }

    func testCanStartScan() throws {
        XCTAssertTrue(appState.canStartScan)

        appState.isScanning = true
        XCTAssertFalse(appState.canStartScan)

        appState.isScanning = false
        appState.isCleaning = true
        XCTAssertFalse(appState.canStartScan)
    }

    func testCanClean() throws {
        // No items - can't clean
        XCTAssertFalse(appState.canClean)

        // Add items
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash)
        ]
        appState.scanResult = ScanResult(items: items)
        XCTAssertTrue(appState.canClean)

        // Scanning - can't clean
        appState.isScanning = true
        XCTAssertFalse(appState.canClean)
        appState.isScanning = false

        // Cleaning - can't start another clean
        appState.isCleaning = true
        XCTAssertFalse(appState.canClean)
    }

    // MARK: - Selection Management

    func testSelectAll() throws {
        var items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        items[0].isSelected = false
        items[1].isSelected = false

        appState.scanResult = ScanResult(items: items)
        XCTAssertEqual(appState.selectedItemsCount, 0)

        appState.selectAll()
        XCTAssertEqual(appState.selectedItemsCount, 2)
    }

    func testDeselectAll() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        appState.scanResult = ScanResult(items: items)
        XCTAssertEqual(appState.selectedItemsCount, 2)

        appState.deselectAll()
        XCTAssertEqual(appState.selectedItemsCount, 0)
    }

    func testToggleCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        appState.scanResult = ScanResult(items: items)

        appState.toggleCategory(.systemCaches)

        let cacheItems = appState.scanResult?.items.filter { $0.category == .systemCaches } ?? []
        XCTAssertTrue(cacheItems.allSatisfy { !$0.isSelected })

        let trashItems = appState.scanResult?.items.filter { $0.category == .trash } ?? []
        XCTAssertTrue(trashItems.allSatisfy { $0.isSelected })
    }

    func testToggleItemAtIndex() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash)
        ]
        appState.scanResult = ScanResult(items: items)
        XCTAssertTrue(appState.scanResult?.items[0].isSelected ?? false)

        appState.toggleItem(at: 0)
        XCTAssertFalse(appState.scanResult?.items[0].isSelected ?? true)

        appState.toggleItem(at: 0)
        XCTAssertTrue(appState.scanResult?.items[0].isSelected ?? false)
    }

    func testToggleItemByObject() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash)
        ]
        appState.scanResult = ScanResult(items: items)
        let item = appState.scanResult!.items[0]

        appState.toggleItem(item)
        XCTAssertFalse(appState.scanResult?.items[0].isSelected ?? true)
    }

    // MARK: - Reset

    func testReset() throws {
        // Set up some state
        appState.scanResult = ScanResult(items: [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash)
        ])
        appState.isScanning = true
        appState.isCleaning = true
        appState.scanProgress = 0.5
        appState.showingConfirmation = true
        appState.currentScanFile = "/some/file"
        appState.itemsFoundCount = 10

        // Reset
        appState.reset()

        // Verify reset
        XCTAssertNil(appState.scanResult)
        XCTAssertNil(appState.cleaningResult)
        XCTAssertFalse(appState.isScanning)
        XCTAssertFalse(appState.isCleaning)
        XCTAssertEqual(appState.scanProgress, 0.0)
        XCTAssertFalse(appState.showingConfirmation)
        XCTAssertEqual(appState.statusMessage, "Ready to scan")
        XCTAssertEqual(appState.currentScanFile, "")
        XCTAssertEqual(appState.itemsFoundCount, 0)
    }

    // MARK: - Confirmation Dialog

    func testCancelCleaning() throws {
        appState.showingConfirmation = true
        appState.cancelCleaning()
        XCTAssertFalse(appState.showingConfirmation)
    }

    // MARK: - Formatted Size

    func testFormattedSelectedSize() throws {
        XCTAssertEqual(appState.formattedSelectedSize, "0 bytes")

        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1024 * 1024, category: .trash) // 1 MB
        ]
        appState.scanResult = ScanResult(items: items)

        XCTAssertTrue(appState.formattedSelectedSize.contains("MB") || appState.formattedSelectedSize.contains("1"))
    }
}

// MARK: - ScanViewModel Tests

@MainActor
final class ScanViewModelTests: XCTestCase {

    var viewModel: ScanViewModel!

    override func setUp() async throws {
        viewModel = ScanViewModel()
        viewModel.reset()
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    func testInitialState() throws {
        XCTAssertFalse(viewModel.isScanning)
        XCTAssertEqual(viewModel.progress, 0.0)
        XCTAssertNil(viewModel.currentCategory)
        XCTAssertNil(viewModel.scanResult)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.hasResults)
    }

    func testComputedProperties() throws {
        XCTAssertEqual(viewModel.totalItemsFound, 0)
        XCTAssertEqual(viewModel.totalSize, 0)
        XCTAssertEqual(viewModel.progressPercentage, 0)

        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches)
        ]
        viewModel.scanResult = ScanResult(items: items)

        XCTAssertTrue(viewModel.hasResults)
        XCTAssertEqual(viewModel.totalItemsFound, 2)
        XCTAssertEqual(viewModel.totalSize, 3000)
    }

    func testItemsByCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/c"), size: 3000, category: .systemCaches)
        ]
        viewModel.scanResult = ScanResult(items: items)

        let byCategory = viewModel.itemsByCategory
        XCTAssertEqual(byCategory[.trash]?.count, 2)
        XCTAssertEqual(byCategory[.systemCaches]?.count, 1)
    }

    func testSizeByCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        viewModel.scanResult = ScanResult(items: items)

        let sizeByCategory = viewModel.sizeByCategory
        XCTAssertEqual(sizeByCategory[.trash], 3000)
    }

    func testSelectAllInCategory() throws {
        var items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        items[0].isSelected = false
        items[1].isSelected = false
        viewModel.scanResult = ScanResult(items: items)

        viewModel.selectAllInCategory(.trash)

        let trashItems = viewModel.itemsForCategory(.trash)
        XCTAssertTrue(trashItems.allSatisfy { $0.isSelected })
    }

    func testDeselectAllInCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        viewModel.scanResult = ScanResult(items: items)

        viewModel.deselectAllInCategory(.trash)

        let trashItems = viewModel.itemsForCategory(.trash)
        XCTAssertTrue(trashItems.allSatisfy { !$0.isSelected })
    }

    func testToggleItemSelection() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash)
        ]
        viewModel.scanResult = ScanResult(items: items)
        let item = viewModel.scanResult!.items[0]

        viewModel.toggleItemSelection(item)
        XCTAssertFalse(viewModel.scanResult!.items[0].isSelected)

        viewModel.toggleItemSelection(item)
        XCTAssertTrue(viewModel.scanResult!.items[0].isSelected)
    }

    func testItemsForCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches)
        ]
        viewModel.scanResult = ScanResult(items: items)

        let trashItems = viewModel.itemsForCategory(.trash)
        XCTAssertEqual(trashItems.count, 1)
        XCTAssertEqual(trashItems[0].size, 1000)
    }

    func testSizeForCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        viewModel.scanResult = ScanResult(items: items)

        XCTAssertEqual(viewModel.sizeForCategory(.trash), 3000)
        XCTAssertEqual(viewModel.sizeForCategory(.docker), 0)
    }

    func testFormattedSizeForCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1024 * 1024, category: .trash) // 1 MB
        ]
        viewModel.scanResult = ScanResult(items: items)

        let formatted = viewModel.formattedSizeForCategory(.trash)
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("1"))
    }

    func testSelectedItemsInCategory() throws {
        var items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        items[1].isSelected = false
        viewModel.scanResult = ScanResult(items: items)

        let selected = viewModel.selectedItemsInCategory(.trash)
        XCTAssertEqual(selected.count, 1)
    }

    func testSelectedSizeInCategory() throws {
        var items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]
        items[1].isSelected = false
        viewModel.scanResult = ScanResult(items: items)

        XCTAssertEqual(viewModel.selectedSizeInCategory(.trash), 1000)
    }

    func testReset() throws {
        viewModel.scanResult = ScanResult(items: [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash)
        ])
        viewModel.progress = 0.5
        viewModel.errorMessage = "Test error"

        viewModel.reset()

        XCTAssertNil(viewModel.scanResult)
        XCTAssertEqual(viewModel.progress, 0.0)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isScanning)
    }

    func testClearCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches)
        ]
        viewModel.scanResult = ScanResult(items: items)

        viewModel.clearCategory(.trash)

        XCTAssertEqual(viewModel.itemsForCategory(.trash).count, 0)
        XCTAssertEqual(viewModel.itemsForCategory(.systemCaches).count, 1)
    }
}
