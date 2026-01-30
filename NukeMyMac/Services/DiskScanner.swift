import Foundation

/// Concurrency limits for DiskScanner
private enum ScannerLimits {
    static let maxParallelTasks = 4
    static let progressUpdateInterval = 20
}

actor DiskScanner {
    static let shared = DiskScanner()

    private let fileManager = FileManager.default
    private let minFileSize: Int64 = 1024 * 1024 // 1MB minimum - skip tiny files
    private let largeFileThreshold: Int64 = 500 * 1024 * 1024 // 500MB

    // Paths to NEVER touch - system critical (expanded blocklist)
    private let systemPaths: Set<String> = [
        // Absolute system paths
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var",
        "/private/etc",
        "/Library/Apple",
        "/Library/Preferences/SystemConfiguration",
        "/Applications",

        // Patterns that indicate system files
        ".Spotlight",
        ".fseventsd",
        ".DocumentRevisions",
        ".MobileBackups",
        ".vol/",
        "com.apple.",
        "CloudKit",
        "Keychains",
        "Safari/LocalStorage",
        "Safari/Databases",
        "CoreServices",
        "SystemConfiguration",
        "LaunchServices",
        "loginwindow",
        "SystemAppearance",
        "FontCollections",
        "com.apple.icloud",
        "com.apple.Safari",
        "com.apple.Mail",
        "com.apple.finder",
        "NetworkInterfaces",
        "Bluetooth",
        "WiFi",
        "cups",
        "sshd"
    ]

    private init() {}

    // MARK: - Main Scan (Limited Parallel)

    func scan(
        categories: [CleanCategory],
        progress: @escaping (Double, String) -> Void,
        fileFound: @escaping (String, Int64, CleanCategory) -> Void  // path, size, category
    ) async -> ScanResult {
        let startTime = Date()

        // Scan categories with limited concurrency to prevent system overload
        let results = await withTaskGroup(of: (CleanCategory, [ScannedItem], String?).self) { group in
            var pending = categories[...]
            var activeCount = 0

            // Start limited batch
            while activeCount < ScannerLimits.maxParallelTasks, let category = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    do {
                        let items = try await self.scanCategory(category, fileFound: fileFound)
                        return (category, items, nil)
                    } catch {
                        return (category, [], error.localizedDescription)
                    }
                }
            }

            var allItems: [ScannedItem] = []
            var errors: [String] = []
            var completed = 0
            let totalCategories = categories.count

            for await (category, items, error) in group {
                completed += 1
                activeCount -= 1
                allItems.append(contentsOf: items)
                if let error = error {
                    errors.append("\(category.rawValue): \(error)")
                }

                // Add next task if available
                if let nextCategory = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        do {
                            let items = try await self.scanCategory(nextCategory, fileFound: fileFound)
                            return (nextCategory, items, nil)
                        } catch {
                            return (nextCategory, [], error.localizedDescription)
                        }
                    }
                }

                await MainActor.run {
                    progress(Double(completed) / Double(totalCategories), "Scanned \(category.rawValue)")
                }
            }

            return (allItems, errors)
        }

        await MainActor.run {
            progress(1.0, "Scan complete")
        }

        let duration = Date().timeIntervalSince(startTime)
        return ScanResult(items: results.0, scanDuration: duration, errorMessages: results.1)
    }

    // MARK: - Category Router

    private func scanCategory(_ category: CleanCategory, fileFound: @escaping (String, Int64, CleanCategory) -> Void) async throws -> [ScannedItem] {
        switch category {
        case .systemCaches:
            return await scanCaches(fileFound: fileFound)
        case .xcodeDerivedData:
            return await scanXcode(fileFound: fileFound)
        case .iosBackups:
            return await scanIOSBackups(fileFound: fileFound)
        case .homebrewCache:
            return await scanHomebrew(fileFound: fileFound)
        case .npmCache:
            return await scanNpm(fileFound: fileFound)
        case .docker:
            return await scanDocker(fileFound: fileFound)
        case .oldDownloads:
            return await scanOldDownloads(fileFound: fileFound)
        case .trash:
            return await scanTrash(fileFound: fileFound)
        case .largeFiles:
            return await scanLargeFiles(fileFound: fileFound)
        case .logFiles:
            return await scanLogs(fileFound: fileFound)
        }
    }

    // MARK: - Fast Category Scanners

    private func scanCaches(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let cachePath = "\(home)/Library/Caches"
        let minSize = self.minFileSize

        guard let contents = try? fileManager.contentsOfDirectory(atPath: cachePath) else { return [] }

        // Filter out system caches and build URLs
        let cacheURLs = contents
            .filter { !isSystemPath($0) }
            .map { URL(fileURLWithPath: "\(cachePath)/\($0)") }

        // Calculate sizes with limited concurrency
        return await withTaskGroup(of: ScannedItem?.self, returning: [ScannedItem].self) { group in
            var pending = cacheURLs[...]
            var activeCount = 0

            while activeCount < ScannerLimits.maxParallelTasks, let url = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    let size = Self.fastDirectorySizeStatic(url)
                    guard size > minSize else { return nil }
                    await MainActor.run { fileFound(url.path, size, .systemCaches) }
                    return ScannedItem(url: url, size: size, category: .systemCaches)
                }
            }

            var results: [ScannedItem] = []
            for await item in group {
                activeCount -= 1
                if let item = item {
                    results.append(item)
                }
                if let nextURL = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        let size = Self.fastDirectorySizeStatic(nextURL)
                        guard size > minSize else { return nil }
                        await MainActor.run { fileFound(nextURL.path, size, .systemCaches) }
                        return ScannedItem(url: nextURL, size: size, category: .systemCaches)
                    }
                }
            }
            return results
        }
    }

    private func scanXcode(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let minSize = self.minFileSize

        // Collect all URLs to scan
        var urlsToScan: [URL] = []

        // DerivedData - biggest target
        let derivedData = "\(home)/Library/Developer/Xcode/DerivedData"
        if let contents = try? fileManager.contentsOfDirectory(atPath: derivedData) {
            for folder in contents where !folder.hasPrefix("ModuleCache") {
                urlsToScan.append(URL(fileURLWithPath: "\(derivedData)/\(folder)"))
            }
        }

        // Archives
        let archives = "\(home)/Library/Developer/Xcode/Archives"
        if let years = try? fileManager.contentsOfDirectory(atPath: archives) {
            for year in years {
                urlsToScan.append(URL(fileURLWithPath: "\(archives)/\(year)"))
            }
        }

        // iOS DeviceSupport
        let deviceSupport = "\(home)/Library/Developer/Xcode/iOS DeviceSupport"
        if let versions = try? fileManager.contentsOfDirectory(atPath: deviceSupport) {
            for version in versions {
                urlsToScan.append(URL(fileURLWithPath: "\(deviceSupport)/\(version)"))
            }
        }

        // Simulator caches
        let simulators = "\(home)/Library/Developer/CoreSimulator/Caches"
        if fileManager.fileExists(atPath: simulators) {
            urlsToScan.append(URL(fileURLWithPath: simulators))
        }

        // Scan with limited concurrency
        return await withTaskGroup(of: ScannedItem?.self, returning: [ScannedItem].self) { group in
            var pending = urlsToScan[...]
            var activeCount = 0

            while activeCount < ScannerLimits.maxParallelTasks, let url = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    let size = Self.fastDirectorySizeStatic(url)
                    guard size > minSize else { return nil }
                    await MainActor.run { fileFound(url.path, size, .xcodeDerivedData) }
                    return ScannedItem(url: url, size: size, category: .xcodeDerivedData)
                }
            }

            var results: [ScannedItem] = []
            for await item in group {
                activeCount -= 1
                if let item = item {
                    results.append(item)
                }
                if let nextURL = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        let size = Self.fastDirectorySizeStatic(nextURL)
                        guard size > minSize else { return nil }
                        await MainActor.run { fileFound(nextURL.path, size, .xcodeDerivedData) }
                        return ScannedItem(url: nextURL, size: size, category: .xcodeDerivedData)
                    }
                }
            }
            return results
        }
    }

    private func scanIOSBackups(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let backupPath = "\(home)/Library/Application Support/MobileSync/Backup"
        var items: [ScannedItem] = []

        guard let backups = try? fileManager.contentsOfDirectory(atPath: backupPath) else { return items }

        for backup in backups {
            let url = URL(fileURLWithPath: "\(backupPath)/\(backup)")
            let size = fastDirectorySize(url)
            if size > minFileSize {
                // Report file found in real-time
                await MainActor.run {
                    fileFound(url.path, size, .iosBackups)
                }
                items.append(ScannedItem(url: url, size: size, category: .iosBackups))
            }
        }

        return items
    }

    private func scanHomebrew(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var items: [ScannedItem] = []

        let paths = [
            "\(home)/Library/Caches/Homebrew",
            "/opt/homebrew/Caches"
        ]

        for path in paths {
            guard fileManager.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            let size = fastDirectorySize(url)
            if size > minFileSize {
                // Report file found in real-time
                await MainActor.run {
                    fileFound(url.path, size, .homebrewCache)
                }
                items.append(ScannedItem(url: url, size: size, category: .homebrewCache))
            }
        }

        return items
    }

    private func scanNpm(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var items: [ScannedItem] = []

        let paths = [
            "\(home)/.npm/_cacache",
            "\(home)/.npm/_logs",
            "\(home)/.yarn/cache",
            "\(home)/.pnpm-store",
            "\(home)/.bun/install/cache"
        ]

        for path in paths {
            guard fileManager.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            let size = fastDirectorySize(url)
            if size > minFileSize {
                // Report file found in real-time
                await MainActor.run {
                    fileFound(url.path, size, .npmCache)
                }
                items.append(ScannedItem(url: url, size: size, category: .npmCache))
            }
        }

        return items
    }

    private func scanDocker(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var items: [ScannedItem] = []

        let dockerPath = "\(home)/Library/Containers/com.docker.docker/Data"
        if fileManager.fileExists(atPath: dockerPath) {
            let url = URL(fileURLWithPath: dockerPath)
            let size = fastDirectorySize(url)
            if size > minFileSize {
                // Report file found in real-time
                await MainActor.run {
                    fileFound(url.path, size, .docker)
                }
                items.append(ScannedItem(url: url, size: size, category: .docker))
            }
        }

        return items
    }

    private func scanOldDownloads(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let downloadsPath = "\(home)/Downloads"
        var items: [ScannedItem] = []

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: downloadsPath),
            includingPropertiesForKeys: [.contentModificationDateKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return items }

        for itemURL in contents {
            guard let rv = try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = rv.contentModificationDate,
                  modDate < thirtyDaysAgo else { continue }

            let size = fastSize(itemURL)
            if size > minFileSize {
                // Report file found in real-time
                await MainActor.run {
                    fileFound(itemURL.path, size, .oldDownloads)
                }
                items.append(ScannedItem(url: itemURL, size: size, category: .oldDownloads, modificationDate: modDate))
            }
        }

        return items
    }

    private func scanTrash(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let trashPath = "\(home)/.Trash"
        var items: [ScannedItem] = []

        guard let contents = try? fileManager.contentsOfDirectory(atPath: trashPath) else { return items }

        for item in contents {
            let url = URL(fileURLWithPath: "\(trashPath)/\(item)")
            let size = fastSize(url)
            if size > 0 { // Include all trash
                // Report file found in real-time
                await MainActor.run {
                    fileFound(url.path, size, .trash)
                }
                items.append(ScannedItem(url: url, size: size, category: .trash))
            }
        }

        return items
    }

    private func scanLargeFiles(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var items: [ScannedItem] = []

        // Only scan safe user directories
        let scanDirs = [
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Movies",
            "\(home)/Music"
        ]

        for dir in scanDirs {
            guard fileManager.fileExists(atPath: dir) else { continue }

            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            while let url = enumerator?.nextObject() as? URL {
                guard let rv = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      rv.isRegularFile == true,
                      let size = rv.fileSize,
                      size > largeFileThreshold else { continue }

                // Report file found in real-time
                await MainActor.run {
                    fileFound(url.path, Int64(size), .largeFiles)
                }
                items.append(ScannedItem(url: url, size: Int64(size), category: .largeFiles))
            }
        }

        return items
    }

    private func scanLogs(fileFound: @escaping (String, Int64, CleanCategory) -> Void) async -> [ScannedItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let logPath = "\(home)/Library/Logs"
        let minSize = self.minFileSize

        guard let contents = try? fileManager.contentsOfDirectory(atPath: logPath) else { return [] }

        // Filter system logs and build URLs
        let logURLs = contents
            .filter { !isSystemPath($0) }
            .map { URL(fileURLWithPath: "\(logPath)/\($0)") }

        // Scan with limited concurrency
        return await withTaskGroup(of: ScannedItem?.self, returning: [ScannedItem].self) { group in
            var pending = logURLs[...]
            var activeCount = 0

            while activeCount < ScannerLimits.maxParallelTasks, let url = pending.popFirst() {
                activeCount += 1
                group.addTask {
                    let size = Self.fastDirectorySizeStatic(url)
                    guard size > minSize else { return nil }
                    await MainActor.run { fileFound(url.path, size, .logFiles) }
                    return ScannedItem(url: url, size: size, category: .logFiles)
                }
            }

            var results: [ScannedItem] = []
            for await item in group {
                activeCount -= 1
                if let item = item {
                    results.append(item)
                }
                if let nextURL = pending.popFirst() {
                    activeCount += 1
                    group.addTask {
                        let size = Self.fastDirectorySizeStatic(nextURL)
                        guard size > minSize else { return nil }
                        await MainActor.run { fileFound(nextURL.path, size, .logFiles) }
                        return ScannedItem(url: nextURL, size: size, category: .logFiles)
                    }
                }
            }
            return results
        }
    }

    // MARK: - Fast Size Calculation (using allocatedSize)

    private func fastSize(_ url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if isDir.boolValue {
            return fastDirectorySize(url)
        } else {
            let rv = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            return Int64(rv?.totalFileAllocatedSize ?? rv?.fileSize ?? 0)
        }
    }

    private nonisolated func fastDirectorySize(_ url: URL) -> Int64 {
        Self.fastDirectorySizeStatic(url)
    }

    /// Static version for use in parallel tasks - with memory management
    private static func fastDirectorySizeStatic(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0

        // Use autoreleasepool to prevent memory accumulation during enumeration
        autoreleasepool {
            for case let fileURL as URL in enumerator {
                autoreleasepool {
                    let rv = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                    total += Int64(rv?.totalFileAllocatedSize ?? 0)
                }
            }
        }

        return total
    }

    // MARK: - Safety Check

    private func isSystemPath(_ path: String) -> Bool {
        for p in systemPaths {
            if path.contains(p) { return true }
        }
        return false
    }

    /// SECURITY: Resolves symlinks and checks if the real path is safe
    private func resolveAndValidatePath(_ url: URL) -> URL? {
        // Resolve symlinks to get the real destination
        let resolved = url.resolvingSymlinksInPath().standardized

        // Check if the resolved path is a system path
        if isSystemPath(resolved.path) {
            return nil
        }

        // Verify it's in user space
        let home = fileManager.homeDirectoryForCurrentUser.path
        let allowedPrefixes = [home, "/opt/homebrew", "/usr/local"]

        let isAllowed = allowedPrefixes.contains { resolved.path.hasPrefix($0) }
        return isAllowed ? resolved : nil
    }
}
