import Foundation

actor CleaningService {
    static let shared = CleaningService()

    private let fileManager = FileManager.default
    private let batchSize = 10 // Process in batches to prevent freezing

    // SECURITY: Paths that should NEVER be deleted - even if somehow scanned
    private let forbiddenPaths: Set<String> = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var",
        "/private/etc",
        "/Library/Apple",
        "/Library/Preferences/SystemConfiguration",
        "/Applications",
        "/Users/Shared"
    ]

    // SECURITY: Patterns that indicate system-critical files
    private let forbiddenPatterns: [String] = [
        ".Spotlight",
        ".fseventsd",
        ".DocumentRevisions",
        "com.apple.LaunchServices",
        "Keychains",
        "Safari/LocalStorage",
        "CoreServices",
        "SystemConfiguration",
        ".vol/",
        "/.Trashes",
        "/.MobileBackups"
    ]

    private init() {}

    func deleteItems(_ items: [ScannedItem], progress: @escaping (Double, String) -> Void) async -> CleaningResult {
        let totalItems = items.count
        guard totalItems > 0 else {
            return CleaningResult(deletedItems: [], failedItems: [], totalFreed: 0)
        }

        // Use concurrent processing with controlled parallelism
        let maxConcurrency = min(8, ProcessInfo.processInfo.activeProcessorCount)

        // Process items in parallel batches
        let results = await withTaskGroup(of: (ScannedItem, Result<Void, Error>).self, returning: (deleted: [ScannedItem], failed: [(ScannedItem, String)], freed: Int64).self) { group in
            var deletedItems: [ScannedItem] = []
            var failedItems: [(ScannedItem, String)] = []
            var totalFreed: Int64 = 0
            var processedCount = 0
            var activeTaskCount = 0

            for item in items {
                // Limit concurrent tasks
                if activeTaskCount >= maxConcurrency {
                    // Wait for one to complete before adding more
                    if let result = await group.next() {
                        processedCount += 1
                        activeTaskCount -= 1

                        switch result.1 {
                        case .success:
                            deletedItems.append(result.0)
                            totalFreed += result.0.size
                        case .failure(let error):
                            failedItems.append((result.0, error.localizedDescription))
                        }

                        // Update progress
                        if processedCount % 5 == 0 || processedCount == totalItems {
                            let progressValue = Double(processedCount) / Double(totalItems)
                            await MainActor.run { progress(progressValue, "Deleting files: \(processedCount)/\(totalItems)") }
                        }
                    }
                }

                // Add new task
                group.addTask { [self] in
                    do {
                        try await self.deleteItemSafely(item)
                        return (item, .success(()))
                    } catch {
                        return (item, .failure(error))
                    }
                }
                activeTaskCount += 1
            }

            // Collect remaining results
            for await result in group {
                processedCount += 1

                switch result.1 {
                case .success:
                    deletedItems.append(result.0)
                    totalFreed += result.0.size
                case .failure(let error):
                    failedItems.append((result.0, error.localizedDescription))
                }

                // Update progress
                if processedCount % 5 == 0 || processedCount == totalItems {
                    let progressValue = Double(processedCount) / Double(totalItems)
                    await MainActor.run { progress(progressValue, "Deleting files: \(processedCount)/\(totalItems)") }
                }
            }

            return (deletedItems, failedItems, totalFreed)
        }

        await MainActor.run {
            progress(1.0, "Cleaning complete")
        }

        return CleaningResult(
            deletedItems: results.deleted,
            failedItems: results.failed,
            totalFreed: results.freed
        )
    }

    private func deleteItemSafely(_ item: ScannedItem) async throws {
        // SECURITY: Resolve symlinks and canonicalize path FIRST
        let canonicalPath = resolveAndCanonicalize(item.url)

        // SECURITY: Validate against blocklist BEFORE any deletion
        guard isPathSafeToDelete(canonicalPath) else {
            throw CleaningError.forbiddenPath(canonicalPath)
        }

        // Check if file still exists (at resolved path)
        guard fileManager.fileExists(atPath: canonicalPath) else {
            return // Already deleted, not an error
        }

        let resolvedURL = URL(fileURLWithPath: canonicalPath)

        // Check if we have permission
        guard fileManager.isDeletableFile(atPath: canonicalPath) else {
            throw CleaningError.permissionDenied(canonicalPath)
        }

        // SECURITY: Final safety check - ensure we're in user space
        let home = fileManager.homeDirectoryForCurrentUser.path
        let isInUserSpace = canonicalPath.hasPrefix(home) ||
                            canonicalPath.hasPrefix("/opt/homebrew") ||
                            canonicalPath.hasPrefix("/usr/local")

        guard isInUserSpace || item.category == .trash else {
            throw CleaningError.forbiddenPath(canonicalPath)
        }

        // Try to delete
        do {
            if item.category == .trash {
                // For trash items, permanently delete
                try fileManager.removeItem(at: resolvedURL)
            } else {
                // For other items, move to trash (safer)
                try fileManager.trashItem(at: resolvedURL, resultingItemURL: nil)
            }
        } catch let error as NSError {
            // Handle specific errors gracefully
            if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case NSFileNoSuchFileError, 4: // File doesn't exist
                    return // File already gone, that's fine
                case NSFileWriteNoPermissionError, 513: // Permission denied
                    throw CleaningError.permissionDenied(canonicalPath)
                case 16: // Resource busy
                    throw CleaningError.fileBusy(canonicalPath)
                default:
                    throw CleaningError.deletionFailed(canonicalPath, error.localizedDescription)
                }
            }
            throw error
        }
    }

    // MARK: - Security Helpers

    /// Resolves symlinks and canonicalizes the path
    private func resolveAndCanonicalize(_ url: URL) -> String {
        // Resolve symlinks
        let resolved = url.resolvingSymlinksInPath()

        // Standardize the path (removes .., ., trailing slashes)
        return resolved.standardized.path
    }

    /// Checks if a path is safe to delete (not in forbidden list)
    private func isPathSafeToDelete(_ path: String) -> Bool {
        // Check against forbidden absolute paths
        for forbidden in forbiddenPaths {
            if path == forbidden || path.hasPrefix(forbidden + "/") {
                return false
            }
        }

        // Check against forbidden patterns
        for pattern in forbiddenPatterns {
            if path.contains(pattern) {
                return false
            }
        }

        // Reject paths outside of expected locations
        let home = fileManager.homeDirectoryForCurrentUser.path
        let allowedPrefixes = [
            home,
            "/opt/homebrew",
            "/usr/local/Caches",
            "/usr/local/var"
        ]

        let isAllowed = allowedPrefixes.contains { path.hasPrefix($0) }
        return isAllowed
    }

    func emptyTrash() async -> (success: Int, failed: Int) {
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")

        guard let contents = try? fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil) else {
            return (0, 0)
        }

        // Delete trash items in parallel
        let results = await withTaskGroup(of: Bool.self, returning: (success: Int, failed: Int).self) { group in
            for item in contents {
                group.addTask {
                    do {
                        try FileManager.default.removeItem(at: item)
                        return true
                    } catch {
                        return false
                    }
                }
            }

            var success = 0
            var failed = 0
            for await result in group {
                if result {
                    success += 1
                } else {
                    failed += 1
                }
            }
            return (success, failed)
        }

        return results
    }
}

// MARK: - Cleaning Errors

enum CleaningError: LocalizedError {
    case permissionDenied(String)
    case fileBusy(String)
    case deletionFailed(String, String)
    case forbiddenPath(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .fileBusy(let path):
            return "File in use: \(path)"
        case .deletionFailed(let path, let reason):
            return "Failed to delete \(path): \(reason)"
        case .forbiddenPath(let path):
            return "Protected system path: \(path)"
        }
    }
}

// MARK: - Cleaning Result

struct CleaningResult {
    let deletedItems: [ScannedItem]
    let failedItems: [(ScannedItem, String)]
    let totalFreed: Int64

    var formattedTotalFreed: String {
        ByteCountFormatter.string(fromByteCount: totalFreed, countStyle: .file)
    }

    var successCount: Int { deletedItems.count }
    var failureCount: Int { failedItems.count }
    var hasFailures: Bool { !failedItems.isEmpty }
}
