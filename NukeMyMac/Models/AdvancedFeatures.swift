import Foundation
import AppKit

// MARK: - Treemap Models

struct TreemapNode: Identifiable {
    let id = UUID()
    let name: String
    let path: URL
    let size: Int64
    var children: [TreemapNode]
    let isDirectory: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var depth: Int {
        if children.isEmpty { return 0 }
        return 1 + (children.map { $0.depth }.max() ?? 0)
    }
}

// MARK: - Similar Photos Models

struct SimilarPhotoGroup: Identifiable {
    let id = UUID()
    var photos: [SimilarPhoto]
    let similarity: Double // 0.0 - 1.0

    var totalSize: Int64 {
        photos.reduce(0) { $0 + $1.size }
    }

    var potentialSavings: Int64 {
        let selected = photos.filter { $0.isSelected }
        return selected.reduce(0) { $0 + $1.size }
    }
}

struct SimilarPhoto: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let dimensions: CGSize
    let creationDate: Date?
    var isSelected: Bool = false
    var isBest: Bool = false // Highest resolution is marked as best

    var name: String { url.lastPathComponent }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDimensions: String {
        "\(Int(dimensions.width))×\(Int(dimensions.height))"
    }
}

// MARK: - App Uninstaller Models

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let url: URL
    let icon: NSImage?
    let size: Int64
    var relatedFiles: [RelatedFile]
    let lastUsed: Date?
    let version: String?

    var totalSize: Int64 {
        size + relatedFiles.reduce(0) { $0 + $1.size }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

struct RelatedFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let type: RelatedFileType
    var isSelected: Bool = true

    var name: String { url.lastPathComponent }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum RelatedFileType: String, CaseIterable {
    case preferences = "Preferences"
    case cache = "Cache"
    case applicationSupport = "App Support"
    case containers = "Containers"
    case logs = "Logs"
    case crashReports = "Crash Reports"

    var icon: String {
        switch self {
        case .preferences: return "slider.horizontal.3"
        case .cache: return "internaldrive"
        case .applicationSupport: return "folder.fill"
        case .containers: return "shippingbox.fill"
        case .logs: return "doc.text.fill"
        case .crashReports: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Startup Items Models

struct StartupItem: Identifiable {
    let id = UUID()
    let name: String
    let path: URL
    let type: StartupItemType
    var isEnabled: Bool
    let publisher: String?

    var icon: String {
        type.icon
    }
}

enum StartupItemType: String, CaseIterable {
    case loginItem = "Login Item"
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"

    var icon: String {
        switch self {
        case .loginItem: return "person.crop.circle"
        case .launchAgent: return "gearshape.2.fill"
        case .launchDaemon: return "server.rack"
        }
    }
}

// MARK: - Browser Data Models

struct BrowserProfile: Identifiable {
    let id = UUID()
    let browser: BrowserType
    let profileName: String
    var cacheSize: Int64
    var historyCount: Int
    var cookiesCount: Int
    var downloadHistoryCount: Int

    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }
}

enum BrowserType: String, CaseIterable {
    case safari = "Safari"
    case chrome = "Chrome"
    case firefox = "Firefox"
    case edge = "Edge"
    case brave = "Brave"
    case arc = "Arc"

    var icon: String {
        switch self {
        case .safari: return "safari"
        case .chrome: return "globe"
        case .firefox: return "flame.fill"
        case .edge: return "globe"
        case .brave: return "shield.fill"
        case .arc: return "circle.hexagongrid.fill"
        }
    }

    var cachePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .safari:
            return ["\(home)/Library/Caches/com.apple.Safari"]
        case .chrome:
            return ["\(home)/Library/Caches/Google/Chrome"]
        case .firefox:
            return ["\(home)/Library/Caches/Firefox"]
        case .edge:
            return ["\(home)/Library/Caches/Microsoft Edge"]
        case .brave:
            return ["\(home)/Library/Caches/BraveSoftware"]
        case .arc:
            return ["\(home)/Library/Caches/company.thebrowser.Browser"]
        }
    }
}

// MARK: - Disk Health Models

struct DiskHealthInfo: Identifiable {
    let id = UUID()
    let deviceName: String
    let model: String
    let serialNumber: String
    let capacity: Int64
    let healthStatus: DiskHealthStatus
    let temperature: Int?
    let powerOnHours: Int?
    let reallocatedSectors: Int?
    let pendingSectors: Int?
    let smartAttributes: [SMARTAttribute]

    var formattedCapacity: String {
        ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file)
    }
}

enum DiskHealthStatus: String {
    case healthy = "Healthy"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"

    var color: String {
        switch self {
        case .healthy: return "nukeToxicGreen"
        case .warning: return "nukeNeonOrange"
        case .critical: return "nukeNeonRed"
        case .unknown: return "nukeTextSecondary"
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        case .critical: return "xmark.shield.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

struct SMARTAttribute: Identifiable {
    let id = UUID()
    let name: String
    let value: Int
    let threshold: Int
    let worst: Int
    let status: DiskHealthStatus
}

// MARK: - Scheduled Scan Models

struct ScheduledScan: Identifiable, Codable {
    let id: UUID
    var name: String
    var frequency: ScanFrequency
    var categories: [String] // CleanCategory rawValues
    var isEnabled: Bool
    var lastRun: Date?
    var nextRun: Date?
    var autoClean: Bool

    init(id: UUID = UUID(), name: String, frequency: ScanFrequency, categories: [String], isEnabled: Bool = true, autoClean: Bool = false) {
        self.id = id
        self.name = name
        self.frequency = frequency
        self.categories = categories
        self.isEnabled = isEnabled
        self.autoClean = autoClean
    }
}

enum ScanFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var calendarComponent: Calendar.Component {
        switch self {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        }
    }
}

// MARK: - Whitelist Models

struct WhitelistEntry: Identifiable, Codable {
    let id: UUID
    let path: String
    let name: String
    let dateAdded: Date
    let reason: String?

    init(id: UUID = UUID(), path: String, name: String, reason: String? = nil) {
        self.id = id
        self.path = path
        self.name = name
        self.dateAdded = Date()
        self.reason = reason
    }
}

// MARK: - Undo/Restore Models

struct DeletedItemRecord: Identifiable, Codable {
    let id: UUID
    let originalPath: String
    let backupPath: String
    let name: String
    let size: Int64
    let deletionDate: Date
    let category: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var canRestore: Bool {
        FileManager.default.fileExists(atPath: backupPath)
    }
}

// MARK: - Developer Tools Models

struct PackageManagerCache: Identifiable {
    let id = UUID()
    let manager: PackageManager
    let path: URL
    let size: Int64
    var isSelected: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum PackageManager: String, CaseIterable {
    case cocoapods = "CocoaPods"
    case carthage = "Carthage"
    case spm = "Swift Package Manager"
    case npm = "npm"
    case yarn = "Yarn"
    case pnpm = "pnpm"
    case homebrew = "Homebrew"
    case pip = "pip"
    case gem = "RubyGems"
    case gradle = "Gradle"
    case maven = "Maven"

    var icon: String {
        switch self {
        case .cocoapods: return "cube.fill"
        case .carthage: return "cart.fill"
        case .spm: return "swift"
        case .npm, .yarn, .pnpm: return "shippingbox.fill"
        case .homebrew: return "mug.fill"
        case .pip: return "cube.transparent.fill"
        case .gem: return "diamond.fill"
        case .gradle, .maven: return "hammer.fill"
        }
    }

    var cachePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .cocoapods:
            return ["\(home)/Library/Caches/CocoaPods"]
        case .carthage:
            return ["\(home)/Library/Caches/org.carthage.CarthageKit"]
        case .spm:
            return ["\(home)/Library/Caches/org.swift.swiftpm"]
        case .npm:
            return ["\(home)/.npm/_cacache"]
        case .yarn:
            return ["\(home)/Library/Caches/Yarn"]
        case .pnpm:
            return ["\(home)/Library/pnpm/store"]
        case .homebrew:
            return ["\(home)/Library/Caches/Homebrew"]
        case .pip:
            return ["\(home)/Library/Caches/pip"]
        case .gem:
            return ["\(home)/.gem"]
        case .gradle:
            return ["\(home)/.gradle/caches"]
        case .maven:
            return ["\(home)/.m2/repository"]
        }
    }
}

struct SimulatorDevice: Identifiable {
    let id: String // UDID
    let name: String
    let runtime: String
    let state: SimulatorState
    let dataSize: Int64
    var isSelected: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: dataSize, countStyle: .file)
    }
}

enum SimulatorState: String {
    case booted = "Booted"
    case shutdown = "Shutdown"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .booted: return "power.circle.fill"
        case .shutdown: return "power.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct GitRepository: Identifiable {
    let id = UUID()
    let path: URL
    let name: String
    var objectsSize: Int64
    var canPrune: Bool
    var lastCommitDate: Date?
    var isSelected: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: objectsSize, countStyle: .file)
    }
}

// MARK: - Mail Attachments Models

struct MailAttachment: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let messageSubject: String?
    let date: Date?
    var isSelected: Bool = false

    var name: String { url.lastPathComponent }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
