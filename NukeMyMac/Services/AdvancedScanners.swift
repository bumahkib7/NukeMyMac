import Foundation
import CryptoKit
import AppKit

// MARK: - Concurrency Configuration

/// Global concurrency limits to prevent system overload
private enum ConcurrencyLimits {
    static let maxParallelTasks = 4  // Max concurrent heavy operations
    static let maxFileTasks = 8      // Max concurrent file operations
    static let progressUpdateInterval = 50  // Update progress every N items
}

// MARK: - Shared Utilities

/// High-performance parallel directory size calculator
enum DirectorySizeCalculator {
    /// Calculate directory size using optimized file enumeration
    /// Uses totalFileAllocatedSizeKey for accurate disk usage
    nonisolated static func calculateSize(at url: URL, skipHidden: Bool = true) -> Int64 {
        let fm = FileManager.default
        var size: Int64 = 0

        var options: FileManager.DirectoryEnumerationOptions = []
        if skipHidden {
            options.insert(.skipsHiddenFiles)
        }

        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]

        autoreleasepool {
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: options) {
                for case let fileURL as URL in enumerator {
                    autoreleasepool {
                        if let values = try? fileURL.resourceValues(forKeys: keys),
                           values.isRegularFile == true {
                            size += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                        }
                    }
                }
            }
        }

        return size
    }

    /// Calculate app bundle size (includes all contents, doesn't skip hidden files)
    nonisolated static func calculateAppBundleSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var size: Int64 = 0

        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]

        autoreleasepool {
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: []) {
                for case let fileURL as URL in enumerator {
                    autoreleasepool {
                        if let values = try? fileURL.resourceValues(forKeys: keys),
                           values.isRegularFile == true {
                            size += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                        }
                    }
                }
            }
        }

        return size
    }

    /// Calculate sizes of multiple directories in parallel with concurrency limit
    static func calculateSizes(at urls: [URL], skipHidden: Bool = true) async -> [URL: Int64] {
        await withTaskGroup(of: (URL, Int64).self, returning: [URL: Int64].self) { group in
            var pending = urls[...]
            var activeCount = 0

            // Start initial batch
            while activeCount < ConcurrencyLimits.maxParallelTasks, let url = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    let size = calculateSize(at: url, skipHidden: skipHidden)
                    return (url, size)
                }
            }

            var results: [URL: Int64] = [:]
            for await (url, size) in group {
                results[url] = size
                activeCount -= 1

                // Add next task if available
                if let nextURL = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        let size = calculateSize(at: nextURL, skipHidden: skipHidden)
                        return (nextURL, size)
                    }
                }
            }
            return results
        }
    }
}

// MARK: - Treemap Scanner

actor TreemapScanner {
    static let shared = TreemapScanner()

    func scanDirectory(_ url: URL, maxDepth: Int = 3, progress: ((String) -> Void)? = nil) async throws -> TreemapNode {
        // Reduced default maxDepth to 3 for performance
        try await buildNode(at: url, currentDepth: 0, maxDepth: maxDepth, progress: progress)
    }

    private func buildNode(at url: URL, currentDepth: Int, maxDepth: Int, progress: ((String) -> Void)? = nil) async throws -> TreemapNode {
        let fm = FileManager.default

        // Report progress for top-level directories
        if currentDepth <= 1 {
            progress?(url.lastPathComponent)
        }

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw NSError(domain: "TreemapScanner", code: 404, userInfo: [NSLocalizedDescriptionKey: "Path not found"])
        }

        if !isDirectory.boolValue {
            let attrs = try fm.attributesOfItem(atPath: url.path)
            let size = (attrs[.size] as? Int64) ?? 0
            return TreemapNode(name: url.lastPathComponent, path: url, size: size, children: [], isDirectory: false)
        }

        // Directory - scan children with limited concurrency
        var children: [TreemapNode] = []
        var totalSize: Int64 = 0

        if currentDepth < maxDepth {
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles])

            // Limit to top-level directories only for parallel scanning
            // Deeper levels scan sequentially to prevent task explosion
            if currentDepth == 0 {
                children = await withTaskGroup(of: TreemapNode?.self, returning: [TreemapNode].self) { group in
                    var pending = contents[...]
                    var activeCount = 0

                    // Start limited batch
                    while await activeCount < ConcurrencyLimits.maxParallelTasks, let itemURL = pending.popFirst() {
                        activeCount += 1
                        group.addTask {
                            try? await self.buildNode(at: itemURL, currentDepth: currentDepth + 1, maxDepth: maxDepth, progress: progress)
                        }
                    }

                    var results: [TreemapNode] = []
                    for await result in group {
                        if let node = result {
                            results.append(node)
                        }
                        activeCount -= 1

                        if let nextURL = pending.popFirst() {
                            activeCount += 1
                            group.addTask {
                                try? await self.buildNode(at: nextURL, currentDepth: currentDepth + 1, maxDepth: maxDepth, progress: progress)
                            }
                        }
                    }
                    return results
                }
            } else {
                // Sequential scanning for deeper levels to prevent task explosion
                for itemURL in contents {
                    if let node = try? await buildNode(at: itemURL, currentDepth: currentDepth + 1, maxDepth: maxDepth, progress: progress) {
                        children.append(node)
                    }
                }
            }

            totalSize = children.reduce(0) { $0 + $1.size }
        } else {
            totalSize = DirectorySizeCalculator.calculateSize(at: url)
        }

        // Sort children by size (largest first), limit to top 50 for performance
        children.sort { $0.size > $1.size }
        if children.count > 50 {
            let others = children.dropFirst(49)
            let othersSize = others.reduce(0) { $0 + $1.size }
            children = Array(children.prefix(49))
            children.append(TreemapNode(name: "Other (\(others.count) items)", path: url, size: othersSize, children: [], isDirectory: true))
        }

        return TreemapNode(name: url.lastPathComponent, path: url, size: totalSize, children: children, isDirectory: true)
    }
}

// MARK: - Duplicate File Scanner

actor DuplicateScanner {
    static let shared = DuplicateScanner()

    /// Directories most likely to contain duplicate files
    private static let defaultScanDirectories: [String] = [
        "Downloads",
        "Documents",
        "Desktop",
        "Pictures"
    ]

    /// Max file size to fully hash (larger files use partial hash)
    private static let maxFullHashSize: Int64 = 50_000_000 // 50MB

    func scanForDuplicates(
        in directories: [URL],
        minSize: Int64 = 10_000, // 10KB minimum (skip tiny files)
        progress: @escaping (Double, String) -> Void
    ) async -> [DuplicateGroup] {
        var filesBySize: [Int64: [URL]] = [:]
        let fm = FileManager.default

        // Phase 1: Group files by size
        await MainActor.run { progress(0.0, "Indexing files...") }

        // If scanning home directory, limit to specific subdirectories for efficiency
        var effectiveDirectories: [URL] = []
        let home = fm.homeDirectoryForCurrentUser

        for directory in directories {
            if directory.path == home.path {
                // Expand home to specific directories
                for subdir in Self.defaultScanDirectories {
                    let subdirURL = home.appendingPathComponent(subdir)
                    if fm.fileExists(atPath: subdirURL.path) {
                        effectiveDirectories.append(subdirURL)
                    }
                }
            } else {
                effectiveDirectories.append(directory)
            }
        }

        var fileCount = 0
        for directory in effectiveDirectories {
            await MainActor.run { progress(0.05, "Scanning \(directory.lastPathComponent)...") }

            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            autoreleasepool {
                for case let fileURL as URL in enumerator {
                    autoreleasepool {
                        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                        guard values?.isRegularFile == true,
                              let size = values?.fileSize,
                              size >= minSize else { return }

                        let size64 = Int64(size)
                        filesBySize[size64, default: []].append(fileURL)
                        fileCount += 1
                    }
                }
            }

            // Update progress after each directory
            await MainActor.run { progress(0.1, "Indexed \(fileCount) files...") }
        }

        // Filter to only sizes with multiple files
        let potentialDuplicates = filesBySize.filter { $0.value.count > 1 }
        let potentialCount = potentialDuplicates.values.reduce(0) { $0 + $1.count }

        await MainActor.run { progress(0.2, "Found \(potentialCount) files to compare...") }

        // Phase 2: Hash files with same size (limited parallel processing)
        await MainActor.run { progress(0.25, "Comparing files by content...") }

        var hashGroups: [String: [URL]] = [:]

        let allFilesToHash = potentialDuplicates.flatMap { size, urls in
            urls.map { (size: size, url: $0) }
        }
        let totalToHash = allFilesToHash.count

        // Process files with limited concurrency to prevent memory issues
        let hashResults = await withTaskGroup(of: (key: String, url: URL)?.self, returning: [(key: String, url: URL)].self) { group in
            var pending = allFilesToHash[...]
            var activeCount = 0

            // Start limited batch
            while activeCount < ConcurrencyLimits.maxFileTasks, let item = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    guard let hash = Self.hashFileStreaming(item.url, fileSize: item.size) else { return nil }
                    return (key: "\(item.size)_\(hash)", url: item.url)
                }
            }

            var results: [(key: String, url: URL)] = []
            var processedCount = 0
            for await result in group {
                processedCount += 1
                activeCount -= 1

                if let result = result {
                    results.append(result)
                }

                // Add next task
                if let nextItem = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        guard let hash = Self.hashFileStreaming(nextItem.url, fileSize: nextItem.size) else { return nil }
                        return (key: "\(nextItem.size)_\(hash)", url: nextItem.url)
                    }
                }

                // Update progress periodically
                if processedCount % ConcurrencyLimits.progressUpdateInterval == 0 || processedCount == totalToHash {
                    let hashProgress = 0.25 + (Double(processedCount) / Double(totalToHash)) * 0.65
                    await MainActor.run { progress(hashProgress, "Comparing: \(processedCount)/\(totalToHash)") }
                }
            }
            return results
        }

        // Build hash groups from parallel results
        for (key, url) in hashResults {
            hashGroups[key, default: []].append(url)
        }

        // Phase 3: Build duplicate groups
        await MainActor.run { progress(0.9, "Building results...") }

        var duplicateGroups: [DuplicateGroup] = []

        for (key, urls) in hashGroups where urls.count > 1 {
            let sizeStr = key.split(separator: "_").first ?? "0"
            let size = Int64(sizeStr) ?? 0
            let hash = String(key.split(separator: "_").last ?? "")

            var files = urls.map { url -> DuplicateFile in
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let modDate = attrs?[.modificationDate] as? Date
                return DuplicateFile(url: url, modificationDate: modDate)
            }

            // Mark oldest as original
            files.sort { ($0.modificationDate ?? .distantFuture) < ($1.modificationDate ?? .distantFuture) }
            if !files.isEmpty {
                files[0].isOriginal = true
            }

            duplicateGroups.append(DuplicateGroup(hash: hash, size: size, files: files))
        }

        // Sort by wasted space, limit results for performance
        duplicateGroups.sort { $0.wastedSpace > $1.wastedSpace }

        await MainActor.run { progress(1.0, "Found \(duplicateGroups.count) duplicate groups") }

        return Array(duplicateGroups.prefix(500)) // Limit to top 500 for UI performance
    }

    /// Stream-based file hashing to avoid loading entire file into memory
    private nonisolated static func hashFileStreaming(_ url: URL, fileSize: Int64) -> String? {
        // Check if file is readable first
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return nil
        }

        // For large files, hash first + last chunks only (fast comparison)
        if fileSize > maxFullHashSize {
            return hashFilePartial(url, fileSize: fileSize)
        }

        // For smaller files, use memory-mapped full hash
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Hash first and last 1MB of large files for quick comparison
    private nonisolated static func hashFilePartial(_ url: URL, fileSize: Int64) -> String? {
        // Check readability
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return nil
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let chunkSize = 1_048_576 // 1MB
        var hasher = SHA256()

        // Hash first chunk - use do-catch to handle read errors gracefully
        do {
            if let firstChunk = try handle.read(upToCount: chunkSize) {
                hasher.update(data: firstChunk)
            }
        } catch {
            return nil
        }

        // Hash last chunk (if file is larger than 2 chunks)
        if fileSize > Int64(chunkSize * 2) {
            do {
                try handle.seek(toOffset: UInt64(fileSize) - UInt64(chunkSize))
                if let lastChunk = try handle.read(upToCount: chunkSize) {
                    hasher.update(data: lastChunk)
                }
            } catch {
                // If we can't read the last chunk, still return the hash of the first chunk
                // This is still useful for comparison
            }
        }

        let hash = hasher.finalize()
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - App Scanner

actor AppScanner {
    static let shared = AppScanner()

    func scanInstalledApps(progress: ((Double, String) -> Void)? = nil) async -> [InstalledApp] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let appDirectories = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications")
        ]

        // Collect all app URLs first
        var allAppURLs: [URL] = []
        for appDir in appDirectories {
            if let contents = try? fm.contentsOfDirectory(at: appDir, includingPropertiesForKeys: nil) {
                allAppURLs.append(contentsOf: contents.filter { $0.pathExtension == "app" })
            }
        }

        let totalApps = allAppURLs.count
        await MainActor.run { progress?(0.0, "Scanning \(totalApps) applications...") }

        // Scan apps with limited concurrency to prevent system overload
        let apps = await withTaskGroup(of: InstalledApp?.self, returning: [InstalledApp].self) { group in
            var pending = allAppURLs[...]
            var activeCount = 0

            // Start limited batch
            while await activeCount < ConcurrencyLimits.maxParallelTasks, let url = pending.popFirst() {
                activeCount += 1
                group.addTask { [self] in
                    await self.scanApp(at: url)
                }
            }

            var results: [InstalledApp] = []
            var processed = 0
            for await result in group {
                processed += 1
                activeCount -= 1

                if let app = result {
                    results.append(app)
                }

                // Add next task
                if let nextURL = pending.popFirst() {
                    activeCount += 1
                    group.addTask { [self] in
                        await self.scanApp(at: nextURL)
                    }
                }

                // Update progress periodically
                if processed % 10 == 0 || processed == totalApps {
                    let progressValue = Double(processed) / Double(totalApps)
                    await MainActor.run { progress?(progressValue, "Scanned \(processed)/\(totalApps) apps") }
                }
            }
            return results
        }

        return apps.sorted { $0.totalSize > $1.totalSize }
    }

    private func scanApp(at url: URL) async -> InstalledApp? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        let bundleId = plist["CFBundleIdentifier"] as? String ?? ""
        let name = plist["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
        let version = plist["CFBundleShortVersionString"] as? String

        // Get app icon (must be on main thread for NSWorkspace)
        let icon = await MainActor.run { NSWorkspace.shared.icon(forFile: url.path) }

        // Build list of paths to check for related files
        var pathsToCheck: [(URL, RelatedFileType)] = []

        // Preferences
        let prefsPath = home.appendingPathComponent("Library/Preferences/\(bundleId).plist")
        pathsToCheck.append((prefsPath, .preferences))

        // Application Support (by bundle ID and name)
        let appSupportPath = home.appendingPathComponent("Library/Application Support/\(bundleId)")
        pathsToCheck.append((appSupportPath, .applicationSupport))
        let appSupportByName = home.appendingPathComponent("Library/Application Support/\(name)")
        if appSupportByName != appSupportPath {
            pathsToCheck.append((appSupportByName, .applicationSupport))
        }

        // Caches
        let cachePath = home.appendingPathComponent("Library/Caches/\(bundleId)")
        pathsToCheck.append((cachePath, .cache))

        // Containers
        let containerPath = home.appendingPathComponent("Library/Containers/\(bundleId)")
        pathsToCheck.append((containerPath, .containers))

        // Logs
        let logsPath = home.appendingPathComponent("Library/Logs/\(bundleId)")
        pathsToCheck.append((logsPath, .logs))

        // Calculate app bundle size (don't skip hidden files for accurate size)
        async let appSizeTask = DirectorySizeCalculator.calculateAppBundleSize(at: url)

        // Check related files in parallel
        let relatedFiles = await withTaskGroup(of: RelatedFile?.self, returning: [RelatedFile].self) { group in
            for (path, type) in pathsToCheck {
                group.addTask {
                    guard fm.fileExists(atPath: path.path) else { return nil }
                    let size: Int64
                    if type == .preferences {
                        // Preferences is a single file
                        size = (try? fm.attributesOfItem(atPath: path.path)[.size] as? Int64) ?? 0
                    } else {
                        // Don't skip hidden files for accurate related file sizes
                        size = DirectorySizeCalculator.calculateSize(at: path, skipHidden: false)
                    }
                    guard size > 0 else { return nil }
                    return RelatedFile(url: path, size: size, type: type)
                }
            }

            var results: [RelatedFile] = []
            for await result in group {
                if let file = result {
                    results.append(file)
                }
            }
            return results
        }

        let appSize = await appSizeTask

        // Get last used date
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let lastUsed = attrs?[.modificationDate] as? Date

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleId,
            url: url,
            icon: icon,
            size: appSize,
            relatedFiles: relatedFiles,
            lastUsed: lastUsed,
            version: version
        )
    }
}

// MARK: - Startup Items Scanner

actor StartupItemsScanner {
    static let shared = StartupItemsScanner()

    func scanStartupItems() async -> [StartupItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // Define all directories to scan
        let directoriesToScan: [(URL, StartupItemType)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), .launchAgent),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .launchAgent),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .launchDaemon)
        ]

        // Scan all directories in parallel
        let allItems = await withTaskGroup(of: [StartupItem].self, returning: [StartupItem].self) { group in
            for (directory, type) in directoriesToScan {
                group.addTask { [self] in
                    await self.scanLaunchDirectory(directory, type: type)
                }
            }

            var results: [StartupItem] = []
            for await items in group {
                results.append(contentsOf: items)
            }
            return results
        }

        return allItems
    }

    private func scanLaunchDirectory(_ directory: URL, type: StartupItemType) async -> [StartupItem] {
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        let plistURLs = contents.filter { $0.pathExtension == "plist" }

        // Parse all plists in parallel
        return await withTaskGroup(of: StartupItem?.self, returning: [StartupItem].self) { group in
            for url in plistURLs {
                group.addTask {
                    guard let plistData = try? Data(contentsOf: url),
                          let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
                        return nil
                    }

                    let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
                    let disabled = plist["Disabled"] as? Bool ?? false

                    return StartupItem(
                        name: label,
                        path: url,
                        type: type,
                        isEnabled: !disabled,
                        publisher: nil
                    )
                }
            }

            var results: [StartupItem] = []
            for await item in group {
                if let item = item {
                    results.append(item)
                }
            }
            return results
        }
    }

    func toggleStartupItem(_ item: StartupItem, enabled: Bool) async throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: item.path.path) else {
            throw NSError(domain: "StartupItems", code: 404, userInfo: [NSLocalizedDescriptionKey: "Plist not found"])
        }

        guard var plistData = try? Data(contentsOf: item.path),
              var plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw NSError(domain: "StartupItems", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to read plist"])
        }

        plist["Disabled"] = !enabled

        let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try newData.write(to: item.path)
    }
}

// MARK: - Browser Data Scanner

actor BrowserScanner {
    static let shared = BrowserScanner()

    func scanBrowserProfiles() async -> [BrowserProfile] {
        // Scan all browsers in parallel
        return await withTaskGroup(of: BrowserProfile?.self, returning: [BrowserProfile].self) { group in
            for browser in BrowserType.allCases {
                group.addTask { [self] in
                    await self.scanBrowser(browser)
                }
            }

            var results: [BrowserProfile] = []
            for await profile in group {
                if let profile = profile {
                    results.append(profile)
                }
            }
            return results.sorted { $0.cacheSize > $1.cacheSize }
        }
    }

    private func scanBrowser(_ browser: BrowserType) async -> BrowserProfile? {
        let fm = FileManager.default

        // Collect existing cache paths
        let existingPaths = browser.cachePaths
            .map { URL(fileURLWithPath: $0) }
            .filter { fm.fileExists(atPath: $0.path) }

        guard !existingPaths.isEmpty else { return nil }

        // Calculate sizes in parallel
        let sizes = await DirectorySizeCalculator.calculateSizes(at: existingPaths)
        let cacheSize = sizes.values.reduce(0, +)

        guard cacheSize > 0 else { return nil }

        return BrowserProfile(
            browser: browser,
            profileName: "Default",
            cacheSize: cacheSize,
            historyCount: 0,
            cookiesCount: 0,
            downloadHistoryCount: 0
        )
    }

    func clearBrowserCache(_ browser: BrowserType) async throws {
        let fm = FileManager.default

        // Delete cache directories in parallel
        try await withThrowingTaskGroup(of: Void.self) { group in
            for path in browser.cachePaths {
                let url = URL(fileURLWithPath: path)
                if fm.fileExists(atPath: path) {
                    group.addTask {
                        try fm.removeItem(at: url)
                    }
                }
            }
            try await group.waitForAll()
        }
    }
}

// MARK: - Developer Tools Scanner

actor DeveloperToolsScanner {
    static let shared = DeveloperToolsScanner()

    func scanPackageManagerCaches() async -> [PackageManagerCache] {
        let fm = FileManager.default

        // Collect all existing cache paths with their managers
        var pathsToScan: [(PackageManager, URL)] = []
        for manager in PackageManager.allCases {
            for path in manager.cachePaths {
                let url = URL(fileURLWithPath: path)
                if fm.fileExists(atPath: path) {
                    pathsToScan.append((manager, url))
                }
            }
        }

        // Scan caches with limited concurrency
        let caches = await withTaskGroup(of: PackageManagerCache?.self, returning: [PackageManagerCache].self) { group in
            var pending = pathsToScan[...]
            var activeCount = 0

            while activeCount < ConcurrencyLimits.maxParallelTasks, let item = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    let size = DirectorySizeCalculator.calculateSize(at: item.1)
                    guard size > 0 else { return nil }
                    return PackageManagerCache(manager: item.0, path: item.1, size: size)
                }
            }

            var results: [PackageManagerCache] = []
            for await cache in group {
                activeCount -= 1
                if let cache = cache {
                    results.append(cache)
                }
                if let nextItem = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        let size = DirectorySizeCalculator.calculateSize(at: nextItem.1)
                        guard size > 0 else { return nil }
                        return PackageManagerCache(manager: nextItem.0, path: nextItem.1, size: size)
                    }
                }
            }
            return results
        }

        return caches.sorted { $0.size > $1.size }
    }

    func scanSimulators() async -> [SimulatorDevice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "-j"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let devicesDict = json["devices"] as? [String: [[String: Any]]] else {
                return []
            }

            // Collect all device info first
            var deviceInfos: [(udid: String, name: String, state: SimulatorState, runtime: String)] = []
            for (runtime, deviceList) in devicesDict {
                for device in deviceList {
                    guard let udid = device["udid"] as? String,
                          let name = device["name"] as? String,
                          let stateStr = device["state"] as? String else { continue }

                    let state: SimulatorState = stateStr == "Booted" ? .booted : .shutdown
                    let runtimeName = runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
                        .replacingOccurrences(of: "-", with: " ")

                    deviceInfos.append((udid, name, state, runtimeName))
                }
            }

            // Calculate data sizes with limited concurrency
            let devices = await withTaskGroup(of: SimulatorDevice.self, returning: [SimulatorDevice].self) { group in
                let home = FileManager.default.homeDirectoryForCurrentUser
                var pending = deviceInfos[...]
                var activeCount = 0

                while activeCount < ConcurrencyLimits.maxParallelTasks, let info = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        let dataPath = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices/\(info.udid)")
                        let dataSize = DirectorySizeCalculator.calculateSize(at: dataPath, skipHidden: false)
                        return SimulatorDevice(
                            id: info.udid,
                            name: info.name,
                            runtime: info.runtime,
                            state: info.state,
                            dataSize: dataSize
                        )
                    }
                }

                var results: [SimulatorDevice] = []
                for await device in group {
                    results.append(device)
                    activeCount -= 1
                    if let nextInfo = pending.popFirst() {
                        activeCount += 1
                        group.addTask {
                            let dataPath = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices/\(nextInfo.udid)")
                            let dataSize = DirectorySizeCalculator.calculateSize(at: dataPath, skipHidden: false)
                            return SimulatorDevice(
                                id: nextInfo.udid,
                                name: nextInfo.name,
                                runtime: nextInfo.runtime,
                                state: nextInfo.state,
                                dataSize: dataSize
                            )
                        }
                    }
                }
                return results
            }

            return devices.sorted { $0.dataSize > $1.dataSize }
        } catch {
            return []
        }
    }

    func scanGitRepositories(in directory: URL) async -> [GitRepository] {
        let fm = FileManager.default

        // Find git repos - limit depth to prevent scanning too deep
        var repoURLs: [URL] = []
        var depth = 0
        let maxDepth = 3

        autoreleasepool {
            if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for case let url as URL in enumerator {
                    // Limit depth
                    let relPath = url.path.replacingOccurrences(of: directory.path, with: "")
                    depth = relPath.components(separatedBy: "/").count - 1
                    if depth > maxDepth {
                        enumerator.skipDescendants()
                        continue
                    }

                    let gitDir = url.appendingPathComponent(".git")
                    if fm.fileExists(atPath: gitDir.path) {
                        enumerator.skipDescendants()
                        repoURLs.append(url)
                    }

                    // Limit total repos found
                    if repoURLs.count >= 100 {
                        break
                    }
                }
            }
        }

        // Calculate git objects sizes with limited concurrency
        let repos = await withTaskGroup(of: GitRepository.self, returning: [GitRepository].self) { group in
            var pending = repoURLs[...]
            var activeCount = 0

            while activeCount < ConcurrencyLimits.maxParallelTasks, let url = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    let objectsDir = url.appendingPathComponent(".git/objects")
                    let objectsSize = DirectorySizeCalculator.calculateSize(at: objectsDir, skipHidden: false)
                    return GitRepository(
                        path: url,
                        name: url.lastPathComponent,
                        objectsSize: objectsSize,
                        canPrune: objectsSize > 10_000_000,
                        lastCommitDate: nil
                    )
                }
            }

            var results: [GitRepository] = []
            for await repo in group {
                results.append(repo)
                activeCount -= 1
                if let nextURL = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        let objectsDir = nextURL.appendingPathComponent(".git/objects")
                        let objectsSize = DirectorySizeCalculator.calculateSize(at: objectsDir, skipHidden: false)
                        return GitRepository(
                            path: nextURL,
                            name: nextURL.lastPathComponent,
                            objectsSize: objectsSize,
                            canPrune: objectsSize > 10_000_000,
                            lastCommitDate: nil
                        )
                    }
                }
            }
            return results
        }

        return repos.sorted { $0.objectsSize > $1.objectsSize }
    }

    func deleteSimulator(udid: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "delete", udid]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "Simulator", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to delete simulator"])
        }
    }

    func pruneGitRepository(_ repo: GitRepository) async throws {
        let process = Process()
        process.currentDirectoryURL = repo.path
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["gc", "--aggressive", "--prune=now"]

        try process.run()
        process.waitUntilExit()
    }

    /// Fast git repository scanner - only scans common developer directories
    func scanGitRepositoriesFast(progress: ((String) -> Void)?) async -> [GitRepository] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // Common developer directories to scan
        let developerDirs = [
            "Projects",
            "Developer",
            "Development",
            "Code",
            "code",
            "repos",
            "Repos",
            "src",
            "Source",
            "workspace",
            "Workspace",
            "git",
            "GitHub",
            "GitLab",
            "Bitbucket",
            "IdeaProjects",      // JetBrains
            "AndroidStudioProjects",
            "XcodeProjects",
            "Documents/Projects",
            "Documents/Developer",
            "Documents/Code",
            "Desktop/Projects",
            "Desktop/Code"
        ]

        // Directories to skip entirely
        let skipDirs = Set([
            "Library",
            "Applications",
            ".Trash",
            "Movies",
            "Music",
            "Pictures",
            "Photos Library.photoslibrary",
            "node_modules",
            ".npm",
            ".cargo",
            ".rustup",
            "Pods",
            ".cocoapods",
            "DerivedData",
            ".gradle",
            ".m2",
            "venv",
            ".venv",
            "__pycache__",
            ".git"
        ])

        var repoURLs: [URL] = []
        let maxRepos = 100
        let maxDepth = 4

        // First scan specific developer directories
        for dir in developerDirs {
            guard repoURLs.count < maxRepos else { break }

            let dirURL = home.appendingPathComponent(dir)
            guard fm.fileExists(atPath: dirURL.path) else { continue }

            progress?("Scanning ~/\(dir)...")

            autoreleasepool {
                if let enumerator = fm.enumerator(
                    at: dirURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for case let url as URL in enumerator {
                        let fileName = url.lastPathComponent

                        // Skip known non-developer directories
                        if skipDirs.contains(fileName) {
                            enumerator.skipDescendants()
                            continue
                        }

                        // Limit depth
                        let relPath = url.path.replacingOccurrences(of: dirURL.path, with: "")
                        let depth = relPath.components(separatedBy: "/").count - 1
                        if depth > maxDepth {
                            enumerator.skipDescendants()
                            continue
                        }

                        // Check for .git directory
                        let gitDir = url.appendingPathComponent(".git")
                        if fm.fileExists(atPath: gitDir.path) {
                            enumerator.skipDescendants()
                            repoURLs.append(url)

                            if repoURLs.count >= maxRepos {
                                break
                            }
                        }
                    }
                }
            }
        }

        progress?("Calculating repository sizes...")

        // Calculate git objects sizes with limited concurrency
        let repos = await withTaskGroup(of: GitRepository.self, returning: [GitRepository].self) { group in
            var pending = repoURLs[...]
            var activeCount = 0

            while activeCount < ConcurrencyLimits.maxParallelTasks, let url = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    let objectsDir = url.appendingPathComponent(".git/objects")
                    let objectsSize = DirectorySizeCalculator.calculateSize(at: objectsDir, skipHidden: false)
                    return GitRepository(
                        path: url,
                        name: url.lastPathComponent,
                        objectsSize: objectsSize,
                        canPrune: objectsSize > 10_000_000,
                        lastCommitDate: nil
                    )
                }
            }

            var results: [GitRepository] = []
            for await repo in group {
                results.append(repo)
                activeCount -= 1
                if let nextURL = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        let objectsDir = nextURL.appendingPathComponent(".git/objects")
                        let objectsSize = DirectorySizeCalculator.calculateSize(at: objectsDir, skipHidden: false)
                        return GitRepository(
                            path: nextURL,
                            name: nextURL.lastPathComponent,
                            objectsSize: objectsSize,
                            canPrune: objectsSize > 10_000_000,
                            lastCommitDate: nil
                        )
                    }
                }
            }
            return results
        }

        return repos.sorted { $0.objectsSize > $1.objectsSize }
    }
}

// MARK: - Mail Attachments Scanner

actor MailAttachmentsScanner {
    static let shared = MailAttachmentsScanner()

    private static let attachmentExtensions = Set([
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "zip", "rar", "dmg", "pkg", "mp3", "mp4", "mov",
        "jpg", "jpeg", "png", "gif", "heic", "webp"
    ])

    func scanMailAttachments(progress: ((Double, String) -> Void)? = nil) async -> [MailAttachment] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // Mail attachments location
        let mailDir = home.appendingPathComponent("Library/Mail")

        await MainActor.run { progress?(0.0, "Scanning mail directory...") }

        guard let enumerator = fm.enumerator(
            at: mailDir,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .isRegularFileKey],
            options: []
        ) else {
            return []
        }

        // Collect potential attachments first (batched for progress reporting)
        var potentialAttachments: [(URL, Int64, Date?)] = []

        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            guard Self.attachmentExtensions.contains(ext) else { continue }

            if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .isRegularFileKey]),
               values.isRegularFile == true {
                let size = Int64(values.fileSize ?? 0)
                guard size > 100_000 else { continue } // > 100KB
                potentialAttachments.append((url, size, values.creationDate))
            }
        }

        await MainActor.run { progress?(0.8, "Found \(potentialAttachments.count) attachments") }

        // Convert to MailAttachment objects
        let attachments = potentialAttachments.map { url, size, date in
            MailAttachment(url: url, size: size, messageSubject: nil, date: date)
        }

        await MainActor.run { progress?(1.0, "Scan complete") }

        return attachments.sorted { $0.size > $1.size }
    }
}
