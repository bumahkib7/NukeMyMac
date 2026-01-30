//
//  PerformanceTests.swift
//  NukeMyMacTests
//
//  Performance and stress tests
//

import XCTest
@testable import NukeMyMac

// MARK: - Performance Tests

final class PerformanceTests: XCTestCase {

    // MARK: - Model Performance

    func testScanResultCreationPerformance() throws {
        // Measure time to create a large scan result
        self.measure {
            var items: [ScannedItem] = []
            for i in 0..<1000 {
                let item = ScannedItem(
                    url: URL(fileURLWithPath: "/path/to/file\(i)"),
                    size: Int64(i * 1000),
                    category: CleanCategory.allCases[i % CleanCategory.allCases.count]
                )
                items.append(item)
            }
            let _ = ScanResult(items: items)
        }
    }

    func testScanResultGroupingPerformance() throws {
        // Create large result
        var items: [ScannedItem] = []
        for i in 0..<5000 {
            let item = ScannedItem(
                url: URL(fileURLWithPath: "/path/to/file\(i)"),
                size: Int64(i * 100),
                category: CleanCategory.allCases[i % CleanCategory.allCases.count]
            )
            items.append(item)
        }
        let result = ScanResult(items: items)

        // Measure grouping performance
        self.measure {
            let _ = result.itemsByCategory()
        }
    }

    func testSizeByCategoryPerformance() throws {
        var items: [ScannedItem] = []
        for i in 0..<5000 {
            let item = ScannedItem(
                url: URL(fileURLWithPath: "/path/to/file\(i)"),
                size: Int64(i * 100),
                category: CleanCategory.allCases[i % CleanCategory.allCases.count]
            )
            items.append(item)
        }
        let result = ScanResult(items: items)

        self.measure {
            let _ = result.sizeByCategory()
        }
    }

    // MARK: - Sorting Performance

    func testSortingPerformance() throws {
        var items: [ScannedItem] = []
        for i in 0..<10000 {
            let item = ScannedItem(
                url: URL(fileURLWithPath: "/path/to/file\(i)"),
                size: Int64.random(in: 0...1_000_000_000),
                category: CleanCategory.allCases.randomElement()!,
                modificationDate: Date(timeIntervalSince1970: Double.random(in: 0...1_700_000_000))
            )
            items.append(item)
        }

        self.measure {
            let _ = SortOrder.sizeDescending.sort(items)
            let _ = SortOrder.nameAscending.sort(items)
            let _ = SortOrder.dateNewest.sort(items)
        }
    }

    // MARK: - Selection Performance

    func testSelectAllPerformance() throws {
        var items: [ScannedItem] = []
        for i in 0..<10000 {
            var item = ScannedItem(
                url: URL(fileURLWithPath: "/path/to/file\(i)"),
                size: Int64(i * 100),
                category: .systemCaches
            )
            item.isSelected = false
            items.append(item)
        }
        var result = ScanResult(items: items)

        self.measure {
            result.selectAll()
            result.deselectAll()
        }
    }

    func testToggleCategoryPerformance() throws {
        var items: [ScannedItem] = []
        for i in 0..<10000 {
            let item = ScannedItem(
                url: URL(fileURLWithPath: "/path/to/file\(i)"),
                size: Int64(i * 100),
                category: CleanCategory.allCases[i % CleanCategory.allCases.count]
            )
            items.append(item)
        }
        var result = ScanResult(items: items)

        self.measure {
            for category in CleanCategory.allCases {
                result.toggleCategory(category)
            }
        }
    }

    // MARK: - Path Validation Performance

    func testPathValidationPerformance() throws {
        let paths = (0..<1000).map { "/Users/test/Library/Caches/App\($0)" }

        self.measure {
            for path in paths {
                let url = URL(fileURLWithPath: path)
                let _ = url.standardized.path
                let _ = url.resolvingSymlinksInPath()
            }
        }
    }

    // MARK: - Memory Allocation Tests

    func testLargeScanResultMemory() throws {
        // Create a very large scan result and measure memory impact
        self.measure {
            var items: [ScannedItem] = []
            items.reserveCapacity(50000)

            for i in 0..<50000 {
                let item = ScannedItem(
                    url: URL(fileURLWithPath: "/path/\(i)"),
                    size: Int64(i),
                    category: .trash
                )
                items.append(item)
            }

            let result = ScanResult(items: items)
            XCTAssertEqual(result.items.count, 50000)
        }
    }

    // MARK: - String Operations Performance

    func testPathContainsCheckPerformance() throws {
        let systemPaths: Set<String> = [
            "/System", "/usr", "/bin", "/sbin", "/private",
            ".Spotlight", ".fseventsd", "com.apple."
        ]

        let testPaths = (0..<1000).map { "/Users/test/path/\($0)" }

        self.measure {
            for path in testPaths {
                for systemPath in systemPaths {
                    let _ = path.contains(systemPath)
                }
            }
        }
    }

    // MARK: - UUID Generation Performance

    func testUUIDGenerationPerformance() throws {
        self.measure {
            for _ in 0..<10000 {
                let _ = UUID()
            }
        }
    }

    // MARK: - ByteCountFormatter Performance

    func testByteCountFormatterPerformance() throws {
        let sizes: [Int64] = (0..<1000).map { Int64($0 * 1024 * 1024) }

        self.measure {
            for size in sizes {
                let _ = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        }
    }
}

// MARK: - Stress Tests

final class StressTests: XCTestCase {

    func testRapidSelectionToggle() throws {
        var items: [ScannedItem] = []
        for i in 0..<1000 {
            let item = ScannedItem(
                url: URL(fileURLWithPath: "/file\(i)"),
                size: 100,
                category: .trash
            )
            items.append(item)
        }
        var result = ScanResult(items: items)

        // Rapidly toggle selections
        for _ in 0..<100 {
            result.selectAll()
            result.deselectAll()
            result.toggleCategory(.trash)
        }

        // Should complete without crash
        XCTAssertTrue(true)
    }

    func testCategoryEnumIteration() throws {
        // Stress test category iteration
        for _ in 0..<10000 {
            for category in CleanCategory.allCases {
                let _ = category.icon
                let _ = category.description
                let _ = category.isDestructive
            }
        }

        XCTAssertTrue(true)
    }

    func testSortOrderStress() throws {
        var items: [ScannedItem] = []
        for i in 0..<1000 {
            let item = ScannedItem(
                url: URL(fileURLWithPath: "/file\(i)"),
                size: Int64.random(in: 0...10000),
                category: CleanCategory.allCases.randomElement()!
            )
            items.append(item)
        }

        // Sort with all sort orders repeatedly
        for _ in 0..<100 {
            for sortOrder in SortOrder.allCases {
                let _ = sortOrder.sort(items)
            }
        }

        XCTAssertTrue(true)
    }

    func testEmptyResultOperations() throws {
        var result = ScanResult()

        // Operations on empty result should not crash
        for _ in 0..<1000 {
            result.selectAll()
            result.deselectAll()
            let _ = result.itemsByCategory()
            let _ = result.sizeByCategory()
            let _ = result.selectedItems
            let _ = result.selectedSize

            for category in CleanCategory.allCases {
                result.toggleCategory(category)
            }
        }

        XCTAssertTrue(true)
    }
}

// MARK: - Edge Case Tests

final class EdgeCaseTests: XCTestCase {

    func testVeryLargeSizeValues() throws {
        let maxSize = Int64.max
        let url = URL(fileURLWithPath: "/huge")
        let item = ScannedItem(url: url, size: maxSize, category: .largeFiles)

        XCTAssertEqual(item.size, maxSize)
        // Formatted size should not crash
        let _ = item.formattedSize
    }

    func testZeroSizeFile() throws {
        let url = URL(fileURLWithPath: "/empty")
        let item = ScannedItem(url: url, size: 0, category: .trash)

        XCTAssertEqual(item.size, 0)
        XCTAssertEqual(item.formattedSize, "Zero KB")
    }

    func testNegativeSizeHandling() throws {
        // Negative sizes shouldn't happen but test behavior
        let url = URL(fileURLWithPath: "/negative")
        let item = ScannedItem(url: url, size: -1000, category: .trash)

        // Should handle gracefully
        XCTAssertEqual(item.size, -1000)
        let _ = item.formattedSize // Should not crash
    }

    func testVeryLongFilePath() throws {
        // Create a very long path
        var path = "/Users/test"
        for i in 0..<100 {
            path += "/very_long_directory_name_\(i)"
        }
        path += "/file.txt"

        let url = URL(fileURLWithPath: path)
        let item = ScannedItem(url: url, size: 100, category: .largeFiles)

        XCTAssertEqual(item.name, "file.txt")
        XCTAssertFalse(item.url.path.isEmpty)
    }

    func testSpecialCharactersInPath() throws {
        let specialPaths = [
            "/Users/test/file with spaces.txt",
            "/Users/test/file'with'quotes.txt",
            "/Users/test/file\"with\"doublequotes.txt",
            "/Users/test/file-with-dashes.txt",
            "/Users/test/file_with_underscores.txt",
            "/Users/test/file.multiple.dots.txt"
        ]

        for path in specialPaths {
            let url = URL(fileURLWithPath: path)
            let item = ScannedItem(url: url, size: 100, category: .trash)
            XCTAssertFalse(item.name.isEmpty, "Name should not be empty for path: \(path)")
        }
    }

    func testUnicodeInPath() throws {
        let unicodePaths = [
            "/Users/test/日本語ファイル.txt",
            "/Users/test/файл.txt",
            "/Users/test/αρχείο.txt",
            "/Users/test/🔥🚀.txt"
        ]

        for path in unicodePaths {
            let url = URL(fileURLWithPath: path)
            let item = ScannedItem(url: url, size: 100, category: .trash)
            XCTAssertFalse(item.name.isEmpty)
        }
    }

    func testVeryOldModificationDate() throws {
        let veryOldDate = Date(timeIntervalSince1970: 0) // 1970
        let url = URL(fileURLWithPath: "/old")
        let item = ScannedItem(url: url, size: 100, category: .oldDownloads, modificationDate: veryOldDate)

        XCTAssertEqual(item.modificationDate, veryOldDate)
    }

    func testFutureModificationDate() throws {
        let futureDate = Date().addingTimeInterval(86400 * 365 * 100) // 100 years in future
        let url = URL(fileURLWithPath: "/future")
        let item = ScannedItem(url: url, size: 100, category: .oldDownloads, modificationDate: futureDate)

        XCTAssertEqual(item.modificationDate, futureDate)
    }
}
