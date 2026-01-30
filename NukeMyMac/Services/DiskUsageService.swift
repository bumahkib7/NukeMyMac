import Foundation

struct DiskUsage {
    let totalSpace: Int64
    let usedSpace: Int64
    let freeSpace: Int64

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }

    var freePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(freeSpace) / Double(totalSpace)
    }

    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }

    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }

    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }
}

actor DiskUsageService {
    static let shared = DiskUsageService()

    private init() {}

    func getDiskUsage() async throws -> DiskUsage {
        let fileURL = URL(fileURLWithPath: "/")
        let values = try fileURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])

        guard let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage else {
            throw DiskUsageError.unableToGetDiskSpace
        }

        let totalBytes = Int64(total)
        let freeBytes = available
        let usedBytes = totalBytes - freeBytes

        return DiskUsage(
            totalSpace: totalBytes,
            usedSpace: usedBytes,
            freeSpace: freeBytes
        )
    }
}

enum DiskUsageError: LocalizedError {
    case unableToGetDiskSpace

    var errorDescription: String? {
        switch self {
        case .unableToGetDiskSpace:
            return "Unable to retrieve disk space information"
        }
    }
}
