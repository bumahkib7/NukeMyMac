import Foundation
import AppKit
import Combine
import SwiftUI

struct ScannedProcess: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let memoryUsage: Int64
    let cpuUsage: Double // 0.0 to 100.0 (percentage)

    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory)
    }

    var formattedCpu: String {
        String(format: "%.1f%%", cpuUsage)
    }
}

@MainActor
class ProcessManager: ObservableObject {
    static let shared = ProcessManager()

    @Published var processes: [ScannedProcess] = []

    // Memory
    @Published var totalMemoryUsage: Double = 0 // 0.0 to 1.0
    @Published var memoryHistory: [Double] = Array(repeating: 0.0, count: 30)

    // CPU
    @Published var totalCpuUsage: Double = 0 // 0.0 to 1.0
    @Published var cpuHistory: [Double] = Array(repeating: 0.0, count: 30)

    @Published var isMonitoring = false

    private var monitorTimer: Timer?
    private var previousCpuInfo: (user: Double, system: Double, idle: Double, nice: Double)?
    private var previousProcessCpuTimes: [pid_t: (user: UInt64, system: UInt64, timestamp: Date)] = [:]

    private init() {}

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshData()
            }
        }
        refreshData()
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    func refreshData() {
        refreshProcesses()
        refreshCpuUsage()
    }

    private func refreshProcesses() {
        // Get ALL running applications (not just dock apps)
        let allApps = NSWorkspace.shared.runningApplications

        var newProcessList: [ScannedProcess] = []
        var currentTotalMem: Int64 = 0
        let now = Date()
        var seenPids = Set<pid_t>()

        // First, get GUI apps (have icons)
        for app in allApps {
            let pid = app.processIdentifier
            guard !seenPids.contains(pid) else { continue }
            seenPids.insert(pid)

            let mem = getMemoryUsage(for: pid)
            let cpu = getCpuUsage(for: pid, at: now)

            // Include if we can get memory info OR it's a regular app
            if mem > 0 || app.activationPolicy == .regular {
                currentTotalMem += mem
                newProcessList.append(ScannedProcess(
                    id: pid,
                    name: app.localizedName ?? app.bundleIdentifier ?? "Unknown",
                    icon: app.icon,
                    memoryUsage: max(mem, 0),
                    cpuUsage: cpu
                ))
            }
        }

        // Also get top processes from ps command for processes we might miss
        if let psProcesses = getTopProcessesFromPS() {
            for psProc in psProcesses {
                guard !seenPids.contains(psProc.pid) else { continue }
                seenPids.insert(psProc.pid)

                // Try to get app icon if it's an app
                var icon: NSImage? = nil
                if let app = allApps.first(where: { $0.processIdentifier == psProc.pid }) {
                    icon = app.icon
                }

                currentTotalMem += psProc.memory
                newProcessList.append(ScannedProcess(
                    id: psProc.pid,
                    name: psProc.name,
                    icon: icon,
                    memoryUsage: psProc.memory,
                    cpuUsage: psProc.cpu
                ))
            }
        }

        self.processes = newProcessList.sorted { $0.memoryUsage > $1.memoryUsage }

        // Memory Pressure Logic
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let pressure = Double(currentTotalMem) / Double(physicalMemory) * 4.0 // Scale factor
        self.totalMemoryUsage = min(pressure, 1.0)

        if self.memoryHistory.count >= 30 { self.memoryHistory.removeFirst() }
        self.memoryHistory.append(self.totalMemoryUsage)

        // Clean up old CPU tracking entries
        previousProcessCpuTimes = previousProcessCpuTimes.filter { seenPids.contains($0.key) }
    }

    private struct PSProcess {
        let pid: pid_t
        let name: String
        let cpu: Double
        let memory: Int64
    }

    private func getTopProcessesFromPS() -> [PSProcess]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // Get top processes by memory: pid, %cpu, rss (memory in KB), command name
        process.arguments = ["-arcwwxo", "pid,%cpu,rss,comm", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            var results: [PSProcess] = []
            let lines = output.components(separatedBy: "\n").dropFirst() // Skip header

            for line in lines.prefix(50) { // Top 50 processes
                let parts = line.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }

                guard parts.count >= 4,
                      let pid = Int32(parts[0]),
                      let cpu = Double(parts[1]),
                      let rssKB = Int64(parts[2]) else { continue }

                // Get process name (last part, may have spaces)
                let name = parts.dropFirst(3).joined(separator: " ")
                    .components(separatedBy: "/").last ?? parts[3]

                // Skip kernel processes and very small processes
                guard rssKB > 1000 else { continue } // > 1MB

                results.append(PSProcess(
                    pid: pid,
                    name: name,
                    cpu: cpu,
                    memory: rssKB * 1024 // Convert KB to bytes
                ))
            }

            return results
        } catch {
            return nil
        }
    }

    private func refreshCpuUsage() {
        let load = getSystemCPULoad()
        self.totalCpuUsage = load

        if self.cpuHistory.count >= 30 { self.cpuHistory.removeFirst() }
        self.cpuHistory.append(load)
    }

    func killProcess(_ process: ScannedProcess) {
        if let app = NSRunningApplication(processIdentifier: process.id) {
            app.forceTerminate()
            withAnimation {
                processes.removeAll { $0.id == process.id }
            }
        }
    }

    // MARK: - Mach Kernel Queries

    private func getMemoryUsage(for pid: pid_t) -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        var task: mach_port_t = 0
        let result = task_for_pid(mach_task_self_, pid, &task)

        if result == KERN_SUCCESS {
            let infoResult = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }
            if infoResult == KERN_SUCCESS {
                return Int64(info.resident_size)
            }
        }
        return 0
    }

    private func getCpuUsage(for pid: pid_t, at now: Date) -> Double {
        var task: mach_port_t = 0
        let result = task_for_pid(mach_task_self_, pid, &task)

        guard result == KERN_SUCCESS else { return 0 }

        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let threadsResult = task_threads(task, &threadList, &threadCount)
        guard threadsResult == KERN_SUCCESS, let threads = threadList else { return 0 }

        var totalUserTime: UInt64 = 0
        var totalSystemTime: UInt64 = 0

        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)

            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }

            if infoResult == KERN_SUCCESS {
                totalUserTime += UInt64(threadInfo.user_time.seconds) * 1_000_000 + UInt64(threadInfo.user_time.microseconds)
                totalSystemTime += UInt64(threadInfo.system_time.seconds) * 1_000_000 + UInt64(threadInfo.system_time.microseconds)
            }
        }

        // Deallocate thread list
        let _ = vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size))

        // Calculate CPU percentage based on delta
        var cpuPercentage: Double = 0

        if let previous = previousProcessCpuTimes[pid] {
            let timeDelta = now.timeIntervalSince(previous.timestamp)
            if timeDelta > 0 {
                let userDelta = totalUserTime > previous.user ? totalUserTime - previous.user : 0
                let systemDelta = totalSystemTime > previous.system ? totalSystemTime - previous.system : 0
                let totalDelta = Double(userDelta + systemDelta) / 1_000_000.0 // Convert to seconds

                // CPU percentage = (CPU time used / wall clock time) * 100
                // Divide by number of CPUs for normalized percentage
                let cpuCount = Double(ProcessInfo.processInfo.processorCount)
                cpuPercentage = (totalDelta / timeDelta) * 100.0 / cpuCount * cpuCount // Per-process, not normalized
                cpuPercentage = min(cpuPercentage, 100.0 * cpuCount) // Cap at max possible
            }
        }

        previousProcessCpuTimes[pid] = (totalUserTime, totalSystemTime, now)
        return cpuPercentage
    }

    private func getSystemCPULoad() -> Double {
        var cpuLoad: host_cpu_load_info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size) / 4
        let result = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { $0 }
        }, &count)

        if result != KERN_SUCCESS { return 0 }

        let user = Double(cpuLoad.cpu_ticks.0)
        let system = Double(cpuLoad.cpu_ticks.1)
        let idle = Double(cpuLoad.cpu_ticks.2)
        let nice = Double(cpuLoad.cpu_ticks.3)

        var load: Double = 0

        if let prev = previousCpuInfo {
            let userDiff = user - prev.user
            let systemDiff = system - prev.system
            let idleDiff = idle - prev.idle
            let niceDiff = nice - prev.nice

            let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
            if totalTicks > 0 {
                load = (userDiff + systemDiff + niceDiff) / totalTicks
            }
        }

        previousCpuInfo = (user, system, idle, nice)
        return load
    }
}
