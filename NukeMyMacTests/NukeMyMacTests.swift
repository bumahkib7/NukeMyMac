//
//  NukeMyMacTests.swift
//  NukeMyMacTests
//
//  Comprehensive Test Suite for NukeMyMac
//

import XCTest
@testable import NukeMyMac

// MARK: - Model Tests

final class ScannedItemTests: XCTestCase {

    func testScannedItemInitialization() throws {
        let url = URL(fileURLWithPath: "/Users/test/Library/Caches/TestApp")
        let item = ScannedItem(url: url, size: 1024 * 1024, category: .systemCaches)

        XCTAssertEqual(item.name, "TestApp")
        XCTAssertEqual(item.size, 1024 * 1024)
        XCTAssertEqual(item.category, .systemCaches)
        XCTAssertTrue(item.isSelected) // Default is selected
        XCTAssertNil(item.modificationDate)
    }

    func testScannedItemWithModificationDate() throws {
        let url = URL(fileURLWithPath: "/Users/test/Downloads/OldFile.zip")
        let date = Date()
        let item = ScannedItem(url: url, size: 500, category: .oldDownloads, modificationDate: date)

        XCTAssertEqual(item.modificationDate, date)
        XCTAssertEqual(item.category, .oldDownloads)
    }

    func testFormattedSize() throws {
        let url = URL(fileURLWithPath: "/test/file")

        // 1 MB
        let item1MB = ScannedItem(url: url, size: 1024 * 1024, category: .systemCaches)
        XCTAssertTrue(item1MB.formattedSize.contains("MB") || item1MB.formattedSize.contains("1"))

        // 1 GB
        let item1GB = ScannedItem(url: url, size: 1024 * 1024 * 1024, category: .largeFiles)
        XCTAssertTrue(item1GB.formattedSize.contains("GB") || item1GB.formattedSize.contains("1"))

        // Small file
        let itemSmall = ScannedItem(url: url, size: 100, category: .logFiles)
        XCTAssertTrue(itemSmall.formattedSize.contains("bytes") || itemSmall.formattedSize.contains("100"))
    }

    func testScannedItemEquality() throws {
        let url = URL(fileURLWithPath: "/test/same")
        let item1 = ScannedItem(url: url, size: 100, category: .trash)
        let item2 = ScannedItem(url: url, size: 100, category: .trash)

        // Same URL but different UUIDs - should NOT be equal
        XCTAssertNotEqual(item1, item2)
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func testScannedItemHashable() throws {
        let url = URL(fileURLWithPath: "/test/file")
        let item = ScannedItem(url: url, size: 100, category: .trash)

        var set = Set<ScannedItem>()
        set.insert(item)

        XCTAssertTrue(set.contains(item))
        XCTAssertEqual(set.count, 1)
    }
}

// MARK: - ScanResult Tests

final class ScanResultTests: XCTestCase {

    func testEmptyScanResult() throws {
        let result = ScanResult()

        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.totalSize, 0)
        XCTAssertEqual(result.scanDuration, 0)
        XCTAssertTrue(result.errorMessages.isEmpty)
        XCTAssertEqual(result.formattedTotalSize, "Zero KB")
    }

    func testScanResultWithItems() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/c"), size: 3000, category: .xcodeDerivedData)
        ]

        let result = ScanResult(items: items, scanDuration: 1.5, errorMessages: ["Test error"])

        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.totalSize, 6000)
        XCTAssertEqual(result.scanDuration, 1.5)
        XCTAssertEqual(result.errorMessages.count, 1)
    }

    func testSelectedItems() throws {
        var items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches),
        ]
        items[1].isSelected = false

        let result = ScanResult(items: items)

        XCTAssertEqual(result.selectedItems.count, 1)
        XCTAssertEqual(result.selectedSize, 1000)
    }

    func testItemsByCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/c"), size: 3000, category: .xcodeDerivedData),
            ScannedItem(url: URL(fileURLWithPath: "/d"), size: 4000, category: .trash)
        ]

        let result = ScanResult(items: items)
        let byCategory = result.itemsByCategory()

        XCTAssertEqual(byCategory[.systemCaches]?.count, 2)
        XCTAssertEqual(byCategory[.xcodeDerivedData]?.count, 1)
        XCTAssertEqual(byCategory[.trash]?.count, 1)
        XCTAssertNil(byCategory[.docker])
    }

    func testSizeByCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/c"), size: 5000, category: .xcodeDerivedData)
        ]

        let result = ScanResult(items: items)
        let sizeByCategory = result.sizeByCategory()

        XCTAssertEqual(sizeByCategory[.systemCaches], 3000)
        XCTAssertEqual(sizeByCategory[.xcodeDerivedData], 5000)
    }

    func testSelectAll() throws {
        var items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches),
        ]
        items[0].isSelected = false
        items[1].isSelected = false

        var result = ScanResult(items: items)
        XCTAssertEqual(result.selectedItems.count, 0)

        result.selectAll()
        XCTAssertEqual(result.selectedItems.count, 2)
    }

    func testDeselectAll() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches),
        ]

        var result = ScanResult(items: items)
        XCTAssertEqual(result.selectedItems.count, 2)

        result.deselectAll()
        XCTAssertEqual(result.selectedItems.count, 0)
    }

    func testToggleCategory() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .systemCaches),
            ScannedItem(url: URL(fileURLWithPath: "/c"), size: 3000, category: .xcodeDerivedData)
        ]

        var result = ScanResult(items: items)

        // All selected initially
        XCTAssertEqual(result.selectedItems.count, 3)

        // Toggle system caches off
        result.toggleCategory(.systemCaches)
        let cacheItems = result.items.filter { $0.category == .systemCaches }
        XCTAssertTrue(cacheItems.allSatisfy { !$0.isSelected })

        // Xcode should still be selected
        let xcodeItems = result.items.filter { $0.category == .xcodeDerivedData }
        XCTAssertTrue(xcodeItems.allSatisfy { $0.isSelected })

        // Toggle system caches back on
        result.toggleCategory(.systemCaches)
        let cacheItems2 = result.items.filter { $0.category == .systemCaches }
        XCTAssertTrue(cacheItems2.allSatisfy { $0.isSelected })
    }
}

// MARK: - CleanCategory Tests

final class CleanCategoryTests: XCTestCase {

    func testAllCategoriesExist() throws {
        XCTAssertEqual(CleanCategory.allCases.count, 10)
    }

    func testCategoryIcons() throws {
        for category in CleanCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "Category \(category.rawValue) should have an icon")
        }
    }

    func testCategoryDescriptions() throws {
        for category in CleanCategory.allCases {
            XCTAssertFalse(category.description.isEmpty, "Category \(category.rawValue) should have a description")
        }
    }

    func testCategoryPaths() throws {
        for category in CleanCategory.allCases {
            XCTAssertFalse(category.paths.isEmpty, "Category \(category.rawValue) should have at least one path")
        }
    }

    func testDestructiveCategories() throws {
        // These should be destructive
        XCTAssertTrue(CleanCategory.iosBackups.isDestructive)
        XCTAssertTrue(CleanCategory.largeFiles.isDestructive)
        XCTAssertTrue(CleanCategory.oldDownloads.isDestructive)

        // These should NOT be destructive
        XCTAssertFalse(CleanCategory.systemCaches.isDestructive)
        XCTAssertFalse(CleanCategory.xcodeDerivedData.isDestructive)
        XCTAssertFalse(CleanCategory.trash.isDestructive)
        XCTAssertFalse(CleanCategory.logFiles.isDestructive)
    }

    func testCategoryIdentifiable() throws {
        for category in CleanCategory.allCases {
            XCTAssertEqual(category.id, category.rawValue)
        }
    }
}

// MARK: - SortOrder Tests

final class SortOrderTests: XCTestCase {

    let testItems: [ScannedItem] = [
        ScannedItem(url: URL(fileURLWithPath: "/Zebra"), size: 100, category: .systemCaches, modificationDate: Date(timeIntervalSince1970: 1000)),
        ScannedItem(url: URL(fileURLWithPath: "/Apple"), size: 500, category: .xcodeDerivedData, modificationDate: Date(timeIntervalSince1970: 3000)),
        ScannedItem(url: URL(fileURLWithPath: "/Mango"), size: 300, category: .trash, modificationDate: Date(timeIntervalSince1970: 2000))
    ]

    func testSortBySizeDescending() throws {
        let sorted = SortOrder.sizeDescending.sort(testItems)

        XCTAssertEqual(sorted[0].size, 500)
        XCTAssertEqual(sorted[1].size, 300)
        XCTAssertEqual(sorted[2].size, 100)
    }

    func testSortBySizeAscending() throws {
        let sorted = SortOrder.sizeAscending.sort(testItems)

        XCTAssertEqual(sorted[0].size, 100)
        XCTAssertEqual(sorted[1].size, 300)
        XCTAssertEqual(sorted[2].size, 500)
    }

    func testSortByNameAscending() throws {
        let sorted = SortOrder.nameAscending.sort(testItems)

        XCTAssertEqual(sorted[0].name, "Apple")
        XCTAssertEqual(sorted[1].name, "Mango")
        XCTAssertEqual(sorted[2].name, "Zebra")
    }

    func testSortByNameDescending() throws {
        let sorted = SortOrder.nameDescending.sort(testItems)

        XCTAssertEqual(sorted[0].name, "Zebra")
        XCTAssertEqual(sorted[1].name, "Mango")
        XCTAssertEqual(sorted[2].name, "Apple")
    }

    func testSortByDateNewest() throws {
        let sorted = SortOrder.dateNewest.sort(testItems)

        XCTAssertEqual(sorted[0].modificationDate?.timeIntervalSince1970, 3000)
        XCTAssertEqual(sorted[1].modificationDate?.timeIntervalSince1970, 2000)
        XCTAssertEqual(sorted[2].modificationDate?.timeIntervalSince1970, 1000)
    }

    func testSortByDateOldest() throws {
        let sorted = SortOrder.dateOldest.sort(testItems)

        XCTAssertEqual(sorted[0].modificationDate?.timeIntervalSince1970, 1000)
        XCTAssertEqual(sorted[1].modificationDate?.timeIntervalSince1970, 2000)
        XCTAssertEqual(sorted[2].modificationDate?.timeIntervalSince1970, 3000)
    }

    func testSortByCategory() throws {
        let sorted = SortOrder.category.sort(testItems)

        // Sorted alphabetically by category raw value
        XCTAssertEqual(sorted[0].category, .systemCaches)
        XCTAssertEqual(sorted[1].category, .trash)
        XCTAssertEqual(sorted[2].category, .xcodeDerivedData)
    }

    func testAllSortOrdersExist() throws {
        XCTAssertEqual(SortOrder.allCases.count, 7)
    }
}

// MARK: - CleaningResult Tests

final class CleaningResultTests: XCTestCase {

    func testEmptyCleaningResult() throws {
        let result = CleaningResult(deletedItems: [], failedItems: [], totalFreed: 0)

        XCTAssertEqual(result.successCount, 0)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertFalse(result.hasFailures)
        XCTAssertEqual(result.formattedTotalFreed, "Zero KB")
    }

    func testCleaningResultWithSuccess() throws {
        let items = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash),
            ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)
        ]

        let result = CleaningResult(deletedItems: items, failedItems: [], totalFreed: 3000)

        XCTAssertEqual(result.successCount, 2)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertFalse(result.hasFailures)
    }

    func testCleaningResultWithFailures() throws {
        let successItems = [
            ScannedItem(url: URL(fileURLWithPath: "/a"), size: 1000, category: .trash)
        ]
        let failedItem = ScannedItem(url: URL(fileURLWithPath: "/b"), size: 2000, category: .trash)

        let result = CleaningResult(
            deletedItems: successItems,
            failedItems: [(failedItem, "Permission denied")],
            totalFreed: 1000
        )

        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.failureCount, 1)
        XCTAssertTrue(result.hasFailures)
    }
}
