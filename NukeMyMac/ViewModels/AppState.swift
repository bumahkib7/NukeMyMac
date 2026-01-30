import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published var diskUsage: DiskUsage?
    @Published var scanResult: ScanResult?
    @Published var isScanning: Bool = false
    @Published var isCleaning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var statusMessage: String = "Ready to scan"
    @Published var showingConfirmation: Bool = false
    @Published var cleaningResult: CleaningResult?

    // Cancellation support
    @Published var isCancelled: Bool = false
    private var currentScanTask: Task<Void, Never>?

    // MARK: - Real-time Scan Progress Properties

    @Published var currentScanFile: String = ""
    @Published var currentScanCategory: CleanCategory?
    @Published var scanLog: [(path: String, size: Int64, category: CleanCategory)] = []
    @Published var itemsFoundCount: Int = 0
    @Published var totalSizeFound: Int64 = 0
    
    // MARK: - RAM Monitor Properties
    @Published var runningProcesses: [ScannedProcess] = []
    @Published var memoryPressureHistory: [Double] = []
    
    // MARK: - CPU Monitor Properties
    @Published var cpuPressureHistory: [Double] = []
    @Published var currentCpuLoad: Double = 0

    // MARK: - Services

    private let diskScanner = DiskScanner.shared
    private let cleaningService = CleaningService.shared
    private let diskUsageService = DiskUsageService.shared
    private let permissionManager = PermissionManager.shared
    private let processManager = ProcessManager.shared

    // MARK: - Settings Reference

    private let settings = SettingsViewModel.shared

    // MARK: - Computed Properties

    var hasSelectedItems: Bool {
        guard let result = scanResult else { return false }
        return !result.selectedItems.isEmpty
    }

    var selectedItemsCount: Int {
        scanResult?.selectedItems.count ?? 0
    }

    var selectedSize: Int64 {
        scanResult?.selectedSize ?? 0
    }

    var formattedSelectedSize: String {
        scanResult?.formattedSelectedSize ?? "0 bytes"
    }

    var canStartScan: Bool {
        !isScanning && !isCleaning
    }

    var canClean: Bool {
        !isScanning && !isCleaning && hasSelectedItems
    }

    // MARK: - Initialization

    init() {
        Task {
            await loadDiskUsage()
        }
        
        // Subscribe to ProcessManager
        processManager.$processes
            .assign(to: &$runningProcesses)
        
        processManager.$memoryHistory
            .assign(to: &$memoryPressureHistory)
            
        processManager.$cpuHistory
            .assign(to: &$cpuPressureHistory)
            
        processManager.$totalCpuUsage
            .assign(to: &$currentCpuLoad)
    }

    // MARK: - Disk Usage

    func loadDiskUsage() async {
        do {
            let usage = try await diskUsageService.getDiskUsage()
            diskUsage = usage
        } catch {
            statusMessage = "Failed to load disk usage: \(error.localizedDescription)"
        }
    }

    // MARK: - Scanning

    func startScan() async {
        guard canStartScan else { return }

        isScanning = true
        scanProgress = 0.0
        statusMessage = "Starting scan..."
        scanResult = nil
        cleaningResult = nil

        // Reset real-time tracking
        scanLog = []
        itemsFoundCount = 0
        totalSizeFound = 0
        currentScanFile = ""
        currentScanCategory = nil

        let categoriesToScan = settings.enabledCategories

        guard !categoriesToScan.isEmpty else {
            statusMessage = "No categories selected for scanning"
            isScanning = false
            return
        }

        let result = await diskScanner.scan(categories: categoriesToScan, progress: { [weak self] progress, message in
            Task { @MainActor in
                self?.scanProgress = progress
                self?.statusMessage = message
            }
        }) { [weak self] path, size, category in
            Task { @MainActor in
                self?.currentScanFile = path
                self?.currentScanCategory = category
                self?.itemsFoundCount += 1
                self?.totalSizeFound += size

                // Keep log trimmed to last 50
                if (self?.scanLog.count ?? 0) >= 50 {
                    self?.scanLog.removeFirst()
                }
                self?.scanLog.append((path: path, size: size, category: category))
            }
        }

        scanResult = result
        isScanning = false
        scanProgress = 1.0

        if result.items.isEmpty {
            statusMessage = "No items found to clean"
        } else {
            statusMessage = "Found \(result.items.count) items (\(result.formattedTotalSize))"
        }

        // Refresh disk usage after scan
        await loadDiskUsage()
    }

    func scanCategory(_ category: CleanCategory) async {
        guard canStartScan else { return }

        isScanning = true
        scanProgress = 0.0
        statusMessage = "Scanning \(category.rawValue)..."

        // Reset real-time tracking
        scanLog = []
        itemsFoundCount = 0
        totalSizeFound = 0
        currentScanFile = ""
        currentScanCategory = nil

        let result = await diskScanner.scan(categories: [category], progress: { [weak self] progress, message in
            Task { @MainActor in
                self?.scanProgress = progress
                self?.statusMessage = message
            }
        }) { [weak self] path, size, category in
            Task { @MainActor in
                self?.currentScanFile = path
                self?.currentScanCategory = category
                self?.itemsFoundCount += 1
                self?.totalSizeFound += size

                // Keep log trimmed to last 50
                if (self?.scanLog.count ?? 0) >= 50 {
                    self?.scanLog.removeFirst()
                }
                self?.scanLog.append((path: path, size: size, category: category))
            }
        }

        // Merge with existing results or set new
        if var existingResult = scanResult {
            // Remove old items from this category and add new ones
            existingResult.items.removeAll { $0.category == category }
            existingResult.items.append(contentsOf: result.items)
            existingResult = ScanResult(
                items: existingResult.items,
                scanDuration: existingResult.scanDuration + result.scanDuration,
                errorMessages: existingResult.errorMessages + result.errorMessages
            )
            scanResult = existingResult
        } else {
            scanResult = result
        }

        isScanning = false
        scanProgress = 1.0
        statusMessage = "Scan complete"
    }

    // MARK: - Cleaning

    func cleanSelected() async {
        guard canClean else { return }
        guard let result = scanResult else { return }

        let itemsToClean = result.selectedItems
        guard !itemsToClean.isEmpty else {
            statusMessage = "No items selected for cleaning"
            return
        }

        // Check if confirmation is required
        if settings.confirmBeforeDelete {
            showingConfirmation = true
            return
        }

        await performCleaning(items: itemsToClean)
    }

    func confirmAndClean() async {
        showingConfirmation = false
        guard let result = scanResult else { return }
        await performCleaning(items: result.selectedItems)
    }

    func cancelCleaning() {
        showingConfirmation = false
    }

    func cancelScan() {
        isCancelled = true
        currentScanTask?.cancel()
        isScanning = false
        isCleaning = false
        statusMessage = "Scan cancelled"
        scanProgress = 0.0
    }

    private func performCleaning(items: [ScannedItem]) async {
        isCleaning = true
        scanProgress = 0.0
        statusMessage = "Cleaning..."

        let result = await cleaningService.deleteItems(items) { [weak self] progress, message in
            Task { @MainActor in
                self?.scanProgress = progress
                self?.statusMessage = message
            }
        }

        cleaningResult = result
        isCleaning = false
        scanProgress = 1.0

        // Remove deleted items from scan result
        if var currentScanResult = scanResult {
            let deletedURLs = Set(result.deletedItems.map { $0.url })
            currentScanResult.items.removeAll { deletedURLs.contains($0.url) }
            scanResult = currentScanResult
        }

        if result.hasFailures {
            statusMessage = "Cleaned \(result.successCount) items, \(result.failureCount) failed. Freed \(result.formattedTotalFreed)"
        } else {
            statusMessage = "Successfully freed \(result.formattedTotalFreed)"
        }

        // Refresh disk usage after cleaning
        await loadDiskUsage()
    }

    // MARK: - Selection Management

    func selectAll() {
        scanResult?.selectAll()
        objectWillChange.send()
    }

    func deselectAll() {
        scanResult?.deselectAll()
        objectWillChange.send()
    }

    func toggleCategory(_ category: CleanCategory) {
        scanResult?.toggleCategory(category)
        objectWillChange.send()
    }

    func toggleItem(at index: Int) {
        guard var result = scanResult, index < result.items.count else { return }
        result.items[index].isSelected.toggle()
        scanResult = result
    }

    func toggleItem(_ item: ScannedItem) {
        guard var result = scanResult,
              let index = result.items.firstIndex(where: { $0.id == item.id }) else { return }
        result.items[index].isSelected.toggle()
        scanResult = result
    }

    // MARK: - Permission Checks

    func checkPermissions() async -> Bool {
        await permissionManager.hasFullDiskAccess()
    }

    func openPermissionSettings() async {
        await permissionManager.openSystemPreferences()
    }

    // MARK: - Reset

    func reset() {
        scanResult = nil
        cleaningResult = nil
        scanProgress = 0.0
        statusMessage = "Ready to scan"
        isScanning = false
        isCleaning = false
        showingConfirmation = false

        // Reset real-time tracking
        currentScanFile = ""
        currentScanCategory = nil
        scanLog = []
        itemsFoundCount = 0
        totalSizeFound = 0
    }

    // MARK: - Process Monitoring
    
    func startRamMonitoring() {
        processManager.startMonitoring()
        Task { await loadDiskUsage() }
    }
    
    func stopRamMonitoring() {
        processManager.stopMonitoring()
    }
    
    func cleanMemory() async {
        await MemoryService.shared.cleanMemory()
    }
    
    func killProcess(_ process: ScannedProcess) {
        processManager.killProcess(process)
    }
}
