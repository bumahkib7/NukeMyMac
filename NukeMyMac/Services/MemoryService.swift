import Foundation
import Combine
import UserNotifications

struct MemoryUsage {
    let total: UInt64
    let used: UInt64
    let free: UInt64
    let wired: UInt64
    let compressed: UInt64
    let appMemory: UInt64

    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    var freePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(free) / Double(total)
    }

    var formattedTotal: String { ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory) }
    var formattedUsed: String { ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory) }
    var formattedFree: String { ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .memory) }

    var pressureLevel: MemoryPressure {
        if usedPercentage > 0.9 { return .critical }
        if usedPercentage > 0.75 { return .warning }
        return .normal
    }
}

enum MemoryPressure: String {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"

    var color: String {
        switch self {
        case .normal: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

@MainActor
class MemoryService: ObservableObject {
    static let shared = MemoryService()

    @Published var currentUsage: MemoryUsage?
    @Published var isMonitoring = false
    @Published var isCleaning = false
    @Published var showLowMemoryAlert = false
    @Published var enableNotifications = true

    private var monitorTask: Task<Void, Never>?
    private var lowMemoryAlertShown = false
    private var lastNotificationTime: Date?
    private let notificationCooldown: TimeInterval = 300 // 5 minutes between notifications

    private init() {
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.enableNotifications = granted
            }
        }
    }

    func startMonitoring(interval: TimeInterval = 2.0) {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitorTask = Task {
            while !Task.isCancelled {
                await updateMemoryUsage()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }

    func updateMemoryUsage() async {
        currentUsage = getMemoryUsage()

        // Check for low memory alert
        if let usage = currentUsage {
            if usage.pressureLevel == .critical && !lowMemoryAlertShown {
                lowMemoryAlertShown = true
                showLowMemoryAlert = true
                sendLowMemoryNotification(usage: usage)
            } else if usage.pressureLevel == .warning && !lowMemoryAlertShown {
                // Warning level - just show in-app alert, no push notification
                showLowMemoryAlert = true
                lowMemoryAlertShown = true
            } else if usage.pressureLevel == .normal {
                lowMemoryAlertShown = false
                showLowMemoryAlert = false
            }
        }
    }

    private func sendLowMemoryNotification(usage: MemoryUsage) {
        guard enableNotifications else { return }

        // Check cooldown to avoid spam
        if let lastTime = lastNotificationTime,
           Date().timeIntervalSince(lastTime) < notificationCooldown {
            return
        }

        lastNotificationTime = Date()

        let content = UNMutableNotificationContent()
        content.title = "⚠️ Low Memory Warning"
        content.body = "RAM usage at \(Int(usage.usedPercentage * 100))%. Only \(usage.formattedFree) free. Tap to clean."
        content.sound = .default
        content.categoryIdentifier = "LOW_MEMORY"

        // Add action to clean memory
        let cleanAction = UNNotificationAction(identifier: "CLEAN_MEMORY", title: "Clean Now", options: .foreground)
        let category = UNNotificationCategory(identifier: "LOW_MEMORY", actions: [cleanAction], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func dismissLowMemoryAlert() {
        showLowMemoryAlert = false
    }

    func cleanMemory() async {
        guard !isCleaning else { return } // Prevent double-clicks
        isCleaning = true

        // Run purge in background - don't wait, it's slow
        Task.detached(priority: .background) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                // Don't wait - let it run in background
            } catch {
                // purge not available or failed, that's ok
            }
        }

        // Small delay then refresh stats
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        await updateMemoryUsage()

        isCleaning = false
    }

    private func getMemoryUsage() -> MemoryUsage {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryUsage(total: 0, used: 0, free: 0, wired: 0, compressed: 0, appMemory: 0)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let total = ProcessInfo.processInfo.physicalMemory

        let free = UInt64(stats.free_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize

        let used = wired + compressed + active
        let appMemory = active + inactive

        return MemoryUsage(
            total: total,
            used: used,
            free: free,
            wired: wired,
            compressed: compressed,
            appMemory: appMemory
        )
    }
}
