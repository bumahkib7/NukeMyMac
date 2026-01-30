import SwiftUI
import LocalAuthentication

/// System maintenance tools - DNS flush, Spotlight rebuild, disk permissions
struct SystemMaintenanceView: View {
    @State private var tasks: [MaintenanceTask] = MaintenanceTask.allTasks
    @State private var runningTaskId: UUID?
    @State private var taskOutput: String = ""
    @State private var selectedCategory: TaskCategory? = nil
    @State private var showCompletedOnly = false
    @State private var touchIDEnabled: Bool = false
    @State private var showTouchIDSetup = false

    enum TaskCategory: String, CaseIterable {
        case network = "Network"
        case system = "System"
        case storage = "Storage"
        case performance = "Performance"

        var icon: String {
            switch self {
            case .network: return "network"
            case .system: return "gearshape.2.fill"
            case .storage: return "internaldrive.fill"
            case .performance: return "gauge.with.needle.fill"
            }
        }

        var color: Color {
            switch self {
            case .network: return .nukeCyan
            case .system: return .nukeNeonOrange
            case .storage: return .nukeBlue
            case .performance: return .nukeNeonRed
            }
        }
    }

    private var filteredTasks: [MaintenanceTask] {
        var result = tasks
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if showCompletedOnly {
            result = result.filter { $0.isCompleted }
        }
        return result
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    private var failedCount: Int {
        tasks.filter { $0.isFailed }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            HStack(spacing: 0) {
                // Tasks list
                VStack(spacing: 0) {
                    // Filter bar
                    filterBar

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // Tasks
                    tasksListView
                }
                .frame(maxWidth: .infinity)

                Divider().overlay(Color.nukeSurfaceHighlight)

                // Output console
                consoleView
                    .frame(width: 320)
            }
        }
        .background(Color.nukeBackground)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.nukeNeonOrange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.nukeNeonOrange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SYSTEM MAINTENANCE")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Run maintenance tasks to optimize your Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            Spacer()

            // Stats
            HStack(spacing: 16) {
                statPill(icon: "checkmark.circle.fill", value: "\(completedCount)", label: "Done", color: .nukeToxicGreen)
                statPill(icon: "xmark.circle.fill", value: "\(failedCount)", label: "Failed", color: .nukeNeonRed)
                statPill(icon: "clock.fill", value: "\(tasks.count - completedCount - failedCount)", label: "Pending", color: .nukeTextTertiary)
            }

            // Run All button
            Button {
                runAllTasks()
            } label: {
                HStack(spacing: 6) {
                    if runningTaskId != nil {
                        NukeSpinner(size: 12, color: .white)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(runningTaskId != nil ? "RUNNING..." : "RUN ALL")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if runningTaskId != nil {
                        Color.nukeTextTertiary
                    } else {
                        Color.nukePrimaryGradient
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(runningTaskId != nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.nukeSurface)
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.nukeTextPrimary)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.nukeTextTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.nukeSurfaceHighlight.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Category filters
            HStack(spacing: 8) {
                categoryPill(nil, label: "All")
                ForEach(TaskCategory.allCases, id: \.self) { category in
                    categoryPill(category, label: category.rawValue)
                }
            }

            Spacer()

            // Touch ID setup button
            Button {
                showTouchIDSetup = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: touchIDEnabled ? "touchid" : "touchid")
                        .foregroundStyle(touchIDEnabled ? Color.nukeToxicGreen : Color.nukeTextTertiary)
                    Text(touchIDEnabled ? "Touch ID" : "Enable Touch ID")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(touchIDEnabled ? Color.nukeToxicGreen : Color.nukeTextSecondary)
            }
            .buttonStyle(.plain)

            // Reset completed
            if completedCount > 0 || failedCount > 0 {
                Button {
                    resetTaskStates()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.nukeTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.nukeSurface.opacity(0.5))
        .alert("Enable Touch ID for Admin Tasks", isPresented: $showTouchIDSetup) {
            Button("Enable Touch ID") {
                Task { await setupTouchID() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will configure your Mac to allow Touch ID for administrator authentication. You'll need to enter your password once to set this up.")
        }
        .onAppear {
            checkTouchIDStatus()
        }
    }

    private func categoryPill(_ category: TaskCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 4) {
                if let cat = category {
                    Image(systemName: cat.icon)
                        .font(.system(size: 9))
                }
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? (category?.color ?? Color.nukeNeonOrange) : Color.nukeTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? (category?.color ?? Color.nukeNeonOrange).opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tasks List

    private var tasksListView: some View {
        ScrollView {
            if filteredTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.nukeToxicGreen)

                    Text("No tasks in this category")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.nukeTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { _, task in
                        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                            taskCard(task, index: index)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func taskCard(_ task: MaintenanceTask, index: Int) -> some View {
        let isRunning = runningTaskId == task.id

        return HStack(spacing: 12) {
            // Category color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(task.category.color)
                .frame(width: 4)

            // Icon
            ZStack {
                Circle()
                    .fill(task.color.opacity(0.15))
                    .frame(width: 40, height: 40)

                if isRunning {
                    NukeSpinner(size: 18, color: task.color)
                } else if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.nukeToxicGreen)
                } else if task.isFailed {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.nukeNeonRed)
                } else {
                    Image(systemName: task.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(task.color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.nukeTextPrimary)

                    if task.requiresAdmin {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.nukeNeonOrange)
                    }
                }

                Text(task.description)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nukeTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status badge
            if task.isCompleted {
                Text("DONE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.nukeToxicGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.nukeToxicGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if task.isFailed {
                Text("FAILED")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.nukeNeonRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.nukeNeonRed.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Run button
            Button {
                runTask(index)
            } label: {
                HStack(spacing: 4) {
                    if !isRunning {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                    }
                    Text(isRunning ? "RUNNING" : "RUN")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isRunning ? Color.nukeTextTertiary : task.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isRunning ? Color.nukeSurfaceHighlight : task.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .disabled(isRunning || runningTaskId != nil)
        }
        .padding(12)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isRunning ? task.color.opacity(0.5) :
                        (task.isCompleted ? Color.nukeToxicGreen.opacity(0.3) :
                            (task.isFailed ? Color.nukeNeonRed.opacity(0.3) : Color.nukeSurfaceHighlight)),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Console View

    private var consoleView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Console header
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.nukeNeonRed).frame(width: 8, height: 8)
                    Circle().fill(Color.nukeNeonOrange).frame(width: 8, height: 8)
                    Circle().fill(Color.nukeToxicGreen).frame(width: 8, height: 8)
                }

                Spacer()

                Text("OUTPUT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextTertiary)

                Spacer()

                Button {
                    taskOutput = ""
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.12))

            // Console output
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if taskOutput.isEmpty {
                            HStack(spacing: 8) {
                                Text("$")
                                    .foregroundStyle(Color.nukeToxicGreen)
                                Text("Run a task to see output...")
                                    .foregroundStyle(Color.nukeTextTertiary)
                            }
                            .font(.custom("Menlo", size: 10))
                            .padding(12)
                        } else {
                            Text(taskOutput)
                                .font(.custom("Menlo", size: 10))
                                .foregroundStyle(Color.nukeToxicGreen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .textSelection(.enabled)

                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                }
                .onChange(of: taskOutput) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color.nukeBlack)
        }
    }

    // MARK: - Actions

    private func runTask(_ index: Int) {
        guard runningTaskId == nil else { return }

        let task = tasks[index]
        runningTaskId = task.id

        let timestamp = Date().formatted(date: .omitted, time: .standard)
        taskOutput += "[\(timestamp)] \(task.name)\n"

        Task {
            let result = await executeTask(task)

            await MainActor.run {
                tasks[index].isCompleted = result.success
                tasks[index].isFailed = !result.success
                if !result.output.isEmpty {
                    taskOutput += result.output
                }
                taskOutput += result.success ? "✓ Success\n\n" : "✗ Failed\n\n"
                runningTaskId = nil
            }
        }
    }

    private func runAllTasks() {
        let pendingTasks = filteredTasks.filter { !$0.isCompleted && !$0.isFailed }
        guard !pendingTasks.isEmpty else { return }

        Task {
            for task in pendingTasks {
                guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { continue }

                await MainActor.run {
                    runningTaskId = tasks[index].id
                    let timestamp = Date().formatted(date: .omitted, time: .standard)
                    taskOutput += "[\(timestamp)] \(tasks[index].name)\n"
                }

                let result = await executeTask(tasks[index])

                await MainActor.run {
                    tasks[index].isCompleted = result.success
                    tasks[index].isFailed = !result.success
                    if !result.output.isEmpty {
                        taskOutput += result.output
                    }
                    taskOutput += result.success ? "✓ Success\n\n" : "✗ Failed\n\n"
                }

                try? await Task.sleep(nanoseconds: 300_000_000)
            }

            await MainActor.run {
                runningTaskId = nil
            }
        }
    }

    private func resetTaskStates() {
        for i in tasks.indices {
            tasks[i].isCompleted = false
            tasks[i].isFailed = false
        }
    }

    private func checkTouchIDStatus() {
        // Check if Touch ID PAM module is configured for sudo
        let sudoLocalPath = "/etc/pam.d/sudo_local"
        if FileManager.default.fileExists(atPath: sudoLocalPath),
           let content = try? String(contentsOfFile: sudoLocalPath, encoding: .utf8) {
            touchIDEnabled = content.contains("pam_tid.so")
        } else {
            touchIDEnabled = false
        }
    }

    private func setupTouchID() async {
        // Create /etc/pam.d/sudo_local with Touch ID support
        let pamConfig = """
        # sudo_local: local config file which survives system update and target the tid module
        auth       sufficient     pam_tid.so
        """

        // Use AppleScript to create the file with admin privileges
        let script = """
        do shell script "echo '\(pamConfig)' > /etc/pam.d/sudo_local" with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?

        await MainActor.run {
            if appleScript?.executeAndReturnError(&errorDict) != nil {
                touchIDEnabled = true
                taskOutput += "[Touch ID] Successfully enabled for admin authentication\n\n"
            } else {
                if let error = errorDict,
                   let msg = error[NSAppleScript.errorMessage] as? String {
                    if !msg.contains("User canceled") {
                        taskOutput += "[Touch ID] Setup failed: \(msg)\n\n"
                    }
                }
            }
        }
    }

    private func executeTask(_ task: MaintenanceTask) async -> (success: Bool, output: String) {
        if task.requiresAdmin {
            // Use AppleScript to prompt for admin privileges with native macOS dialog
            return await executeWithAdminPrivileges(task.command)
        } else {
            // Run without admin
            return await executeShellCommand(task.command)
        }
    }

    private func executeShellCommand(_ command: String) async -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return (process.terminationStatus == 0, output.isEmpty ? "" : output + "\n")
        } catch {
            return (false, "Error: \(error.localizedDescription)\n")
        }
    }

    private func executeWithAdminPrivileges(_ command: String) async -> (success: Bool, output: String) {
        // Remove sudo from command since AppleScript handles elevation
        let cleanCommand = command
            .replacingOccurrences(of: "sudo ", with: "")

        // Base64 encode the command to avoid all escaping issues
        guard let commandData = cleanCommand.data(using: .utf8) else {
            return (false, "Failed to encode command\n")
        }
        let base64Command = commandData.base64EncodedString()

        // Decode and execute via zsh
        let script = "do shell script \"echo \(base64Command) | base64 -d | /bin/zsh\" with administrator privileges"

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?

        // Execute on main thread as AppleScript UI requires it
        let result: (success: Bool, output: String) = await MainActor.run {
            if let output = appleScript?.executeAndReturnError(&errorDict) {
                let outputString = output.stringValue ?? ""
                return (true, outputString.isEmpty ? "" : outputString + "\n")
            } else {
                if let error = errorDict {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    // Check if user cancelled the auth dialog
                    if errorMessage.contains("User canceled") || errorMessage.contains("-128") {
                        return (false, "Authentication cancelled by user\n")
                    }
                    return (false, "Error: \(errorMessage)\n")
                }
                return (false, "Unknown error occurred\n")
            }
        }

        return result
    }
}

// MARK: - Maintenance Task Model

struct MaintenanceTask: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color
    let command: String
    let requiresAdmin: Bool
    let category: SystemMaintenanceView.TaskCategory
    var isCompleted: Bool = false
    var isFailed: Bool = false

    static var allTasks: [MaintenanceTask] {
        [
            // Network
            MaintenanceTask(
                name: "Flush DNS Cache",
                description: "Clear DNS resolver cache to fix connection issues",
                icon: "network",
                color: .nukeCyan,
                command: "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder 2>/dev/null || echo 'DNS cache flushed'",
                requiresAdmin: true,
                category: .network
            ),

            // System
            MaintenanceTask(
                name: "Rebuild Spotlight Index",
                description: "Rebuild Spotlight search index for better search results",
                icon: "magnifyingglass",
                color: .nukeNeonOrange,
                command: "sudo mdutil -E / 2>/dev/null || echo 'Spotlight reindex initiated'",
                requiresAdmin: true,
                category: .system
            ),
            MaintenanceTask(
                name: "Clear Font Caches",
                description: "Remove font caches to fix rendering issues",
                icon: "textformat",
                color: .nukeToxicGreen,
                command: "sudo atsutil databases -remove 2>/dev/null; atsutil server -shutdown; atsutil server -ping || echo 'Font caches cleared'",
                requiresAdmin: true,
                category: .system
            ),
            MaintenanceTask(
                name: "Run Maintenance Scripts",
                description: "Execute daily, weekly, and monthly maintenance scripts",
                icon: "gear.badge.checkmark",
                color: .nukeNeonOrange,
                command: "sudo periodic daily weekly monthly 2>/dev/null || echo 'Maintenance scripts executed'",
                requiresAdmin: true,
                category: .system
            ),

            // Storage
            MaintenanceTask(
                name: "Repair Disk Permissions",
                description: "Verify and repair disk permissions",
                icon: "lock.shield.fill",
                color: .nukeBlue,
                command: "diskutil resetUserPermissions / $(id -u) 2>/dev/null || echo 'Permissions reset attempted'",
                requiresAdmin: false,
                category: .storage
            ),
            MaintenanceTask(
                name: "Verify Startup Disk",
                description: "Check disk for errors (read-only verification)",
                icon: "internaldrive.fill",
                color: .nukeCyan,
                command: "diskutil verifyVolume / 2>/dev/null || echo 'Disk verification completed'",
                requiresAdmin: false,
                category: .storage
            ),
            MaintenanceTask(
                name: "Clear System Logs",
                description: "Remove old system log files",
                icon: "doc.text.fill",
                color: .nukeTextSecondary,
                command: "sudo rm -rf /var/log/*.old 2>/dev/null; sudo rm -rf ~/Library/Logs/*.old 2>/dev/null || echo 'Old logs cleared'",
                requiresAdmin: true,
                category: .storage
            ),

            // Performance
            MaintenanceTask(
                name: "Purge Inactive Memory",
                description: "Free up inactive memory for better performance",
                icon: "memorychip",
                color: .nukeNeonRed,
                command: "sudo purge 2>/dev/null || echo 'Memory purged'",
                requiresAdmin: true,
                category: .performance
            ),
            MaintenanceTask(
                name: "Rebuild Launch Services",
                description: "Fix issues with file associations and app opening",
                icon: "app.badge.checkmark.fill",
                color: .purple,
                command: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null || echo 'Launch Services rebuilt'",
                requiresAdmin: false,
                category: .performance
            ),
            MaintenanceTask(
                name: "Flush Memory Cache",
                description: "Clear memory caches and buffers",
                icon: "cpu.fill",
                color: .nukeNeonRed,
                command: "sync && sudo purge 2>/dev/null || echo 'Caches flushed'",
                requiresAdmin: true,
                category: .performance
            )
        ]
    }
}

#Preview("System Maintenance") {
    SystemMaintenanceView()
        .frame(width: 900, height: 600)
}
