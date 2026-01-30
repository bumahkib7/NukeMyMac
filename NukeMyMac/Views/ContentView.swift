import SwiftUI

/// Main container view with NavigationSplitView - the command center for NUKING
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var settings = SettingsViewModel.shared

    @State private var selectedNavItem: NavigationItem = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // Toast notification state
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastType: ToastType = .success

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar
            SidebarView(selectedItem: $selectedNavItem)
                .navigationSplitViewColumnWidth(min: 220, ideal: Theme.sidebarWidth, max: 300)
                .background(Color.nukeBlack)
        } detail: {
            // MARK: - Detail View
            ZStack {
                // Background
                Color.nukeBackground.ignoresSafeArea()

                DetailView(selectedItem: selectedNavItem)
                    .frame(minWidth: 600, minHeight: 500)
            }
        }
        .environmentObject(appState)
        .overlay {
            // Progress overlay for scanning/cleaning with real-time file feed
            ProgressOverlay(
                progress: appState.scanProgress,
                message: appState.statusMessage,
                isVisible: appState.isScanning || appState.isCleaning,
                currentFile: appState.currentScanFile,
                currentCategory: appState.currentScanCategory,
                itemsFound: appState.itemsFoundCount,
                sizeFound: appState.totalSizeFound,
                scanLog: appState.scanLog.map { ScanLogEntry(path: $0.path, size: $0.size, category: $0.category) },
                onCancel: {
                    appState.cancelScan()
                    showToastNotification("Scan cancelled", type: .warning)
                }
            )
        }
        .overlay(alignment: .bottom) {
            // Toast notification
            if showToast {
                ToastView(message: toastMessage, type: toastType)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .confirmationDialog(
            "CONFIRM DESTRUCTION",
            isPresented: $appState.showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("NUKE \(appState.selectedItemsCount) ITEMS", role: .destructive) {
                Task {
                    await appState.confirmAndClean()
                    showToastNotification("Successfully deleted \(appState.formattedSelectedSize)", type: .success)
                }
            }
            Button("Cancel", role: .cancel) {
                appState.cancelCleaning()
            }
        } message: {
            Text("You are about to permanently delete \(appState.formattedSelectedSize) of data. This action cannot be undone.")
        }
        .modifier(DialogSuppressionModifier(isSuppressed: $settings.suppressDeleteConfirmation))
        // Force dark mode for the Nuke aesthetic
        .preferredColorScheme(.dark)
        // Keyboard navigation
        .focusable()
        .accessibilityLabel("NukeMyMac main window")
        // Trial expiration handler - shows paywall when trial expires
        .handleTrialExpiration()
        // Observe scan completion (using macOS 13 compatible onChange)
        .onChange(of: appState.isScanning) { isScanning in
            if !isScanning && !appState.isCancelled {
                if let result = appState.scanResult {
                    if result.items.isEmpty {
                        showToastNotification("Scan complete - no items found", type: .warning)
                    } else {
                        showToastNotification("Found \(result.items.count) items (\(result.formattedTotalSize))", type: .success)
                    }
                }
            }
        }
        // Observe cleaning completion
        .onChange(of: appState.isCleaning) { isCleaning in
            if !isCleaning {
                if let result = appState.cleaningResult {
                    if result.hasFailures {
                        showToastNotification("Cleaned with \(result.failureCount) errors", type: .warning)
                    }
                }
            }
        }
    }

    // MARK: - Toast Helper

    private func showToastNotification(_ message: String, type: ToastType) {
        toastMessage = message
        toastType = type
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// MARK: - Toast Types

enum ToastType {
    case success
    case error
    case warning

    var color: Color {
        switch self {
        case .success: return .nukeToxicGreen
        case .error: return .nukeNeonRed
        case .warning: return .nukeNeonOrange
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let type: ToastType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
                .font(.title3)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.nukeSurface)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: type.color.opacity(0.3), radius: 10)
        .accessibilityLabel(message)
    }
}

// MARK: - Navigation Item Enum

enum NavigationItem: String, CaseIterable, Identifiable {
    // Core
    case dashboard = "Dashboard"
    case scanResults = "Scan Results"

    // Disk Analysis
    case diskAnalysis = "Disk Analysis"
    case spaceTreemap = "Space Treemap"
    case duplicateFinder = "Duplicates"

    // Cleanup Tools
    case appUninstaller = "App Uninstaller"
    case startupManager = "Startup Manager"
    case browserManager = "Browser Manager"

    // System Tools
    case systemMaintenance = "Maintenance"
    case developerTools = "Developer Tools"

    // Automation
    case scheduledScans = "Scheduled Scans"
    case whitelist = "Whitelist"

    // Settings
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .scanResults: return "doc.text.magnifyingglass"
        case .diskAnalysis: return "chart.pie.fill"
        case .spaceTreemap: return "square.grid.3x3.topleft.filled"
        case .duplicateFinder: return "doc.on.doc.fill"
        case .appUninstaller: return "app.badge.checkmark"
        case .startupManager: return "power.circle.fill"
        case .browserManager: return "globe"
        case .systemMaintenance: return "gearshape.2.fill"
        case .developerTools: return "hammer.fill"
        case .scheduledScans: return "clock.badge.checkmark.fill"
        case .whitelist: return "shield.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var description: String {
        switch self {
        case .dashboard: return "System Status"
        case .scanResults: return "Target Analysis"
        case .diskAnalysis: return "Sunburst View"
        case .spaceTreemap: return "Treemap View"
        case .duplicateFinder: return "Find Duplicates"
        case .appUninstaller: return "Remove Apps"
        case .startupManager: return "Login Items"
        case .browserManager: return "Clear Browser Data"
        case .systemMaintenance: return "System Tasks"
        case .developerTools: return "Dev Caches"
        case .scheduledScans: return "Automation"
        case .whitelist: return "Exclusions"
        case .settings: return "Configuration"
        }
    }

    var section: NavigationSection {
        switch self {
        case .dashboard, .scanResults:
            return .core
        case .diskAnalysis, .spaceTreemap, .duplicateFinder:
            return .analysis
        case .appUninstaller, .startupManager, .browserManager:
            return .cleanup
        case .systemMaintenance, .developerTools:
            return .system
        case .scheduledScans, .whitelist:
            return .automation
        case .settings:
            return .settings
        }
    }

    /// Whether this feature requires Pro
    var isPro: Bool {
        switch self {
        case .diskAnalysis, .spaceTreemap, .duplicateFinder,
             .appUninstaller, .startupManager, .browserManager,
             .developerTools:
            return true
        default:
            return false
        }
    }
}

enum NavigationSection: String, CaseIterable {
    case core = "CORE"
    case analysis = "DISK ANALYSIS"
    case cleanup = "CLEANUP TOOLS"
    case system = "SYSTEM"
    case automation = "AUTOMATION"
    case settings = "SETTINGS"

    var items: [NavigationItem] {
        NavigationItem.allCases.filter { $0.section == self }
    }

    var showHeader: Bool {
        switch self {
        case .core, .settings:
            return false
        default:
            return true
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem
    @EnvironmentObject var appState: AppState
    @ObservedObject private var taskManager = BackgroundTaskManager.shared
    @Namespace private var animation
    @State private var showTasksPopover = false
    @State private var logoRotation: Double = 0
    @State private var logoPulse: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced App Header
            sidebarHeader

            // Navigation items grouped by section
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(NavigationSection.allCases, id: \.self) { section in
                        if !section.items.isEmpty {
                            sectionView(section)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }

            Spacer(minLength: 0)

            // Enhanced Status Footer
            sidebarFooter
        }
        .background(
            LinearGradient(
                colors: [Color.nukeBlack, Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Animated Logo
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(Color.nukeNeonRed.opacity(0.3), lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .scaleEffect(logoPulse ? 1.1 : 1.0)

                    // Inner circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.nukeNeonRed.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 24
                            )
                        )
                        .frame(width: 44, height: 44)

                    // Icon
                    Image(systemName: "atom")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.nukeNeonRed, Color.nukeNeonOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(logoRotation))
                        .shadow(color: .nukeNeonRed.opacity(0.8), radius: 8)
                }
                .onAppear {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        logoRotation = 360
                    }
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        logoPulse = true
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("NUKE")
                        .font(.system(size: 20, weight: .black))
                        .tracking(3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("MY MAC")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(5)
                        .foregroundStyle(Color.nukeNeonOrange)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(
                ZStack {
                    // Gradient background
                    LinearGradient(
                        colors: [Color.nukeNeonRed.opacity(0.08), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Subtle pattern overlay
                    GeometryReader { geo in
                        Path { path in
                            let gridSize: CGFloat = 20
                            for x in stride(from: 0, to: geo.size.width, by: gridSize) {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: geo.size.height))
                            }
                        }
                        .stroke(Color.white.opacity(0.02), lineWidth: 0.5)
                    }
                }
            )

            // Gradient divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.nukeNeonRed.opacity(0.5), Color.nukeNeonOrange.opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
    }

    // MARK: - Section View

    private func sectionView(_ section: NavigationSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section header
            if section.showHeader {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(section.color.opacity(0.5))
                        .frame(width: 3, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 1))

                    Text(section.rawValue)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Color.nukeTextTertiary)

                    Rectangle()
                        .fill(Color.nukeSurfaceHighlight.opacity(0.5))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8)
                .padding(.top, 16)
                .padding(.bottom, 6)
            }

            // Section items
            ForEach(section.items) { item in
                NavigationItemRow(item: item, isSelected: selectedItem == item, namespace: animation)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedItem = item
                        }
                    }
            }
        }
    }

    // MARK: - Footer

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            // Gradient divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.nukeSurfaceHighlight.opacity(0.5), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            VStack(spacing: 12) {
                // Running tasks indicator
                if taskManager.hasRunningTasks {
                    Button {
                        showTasksPopover.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.nukeNeonOrange.opacity(0.2))
                                    .frame(width: 28, height: 28)

                                NukeSpinner(size: 14, color: .nukeNeonOrange)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(taskManager.runningCount) TASK\(taskManager.runningCount == 1 ? "" : "S")")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.nukeNeonOrange)

                                Text("Running in background")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.nukeTextTertiary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.nukeTextTertiary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.nukeNeonOrange.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.nukeNeonOrange.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTasksPopover, arrowEdge: .top) {
                        RunningTasksPanel()
                    }
                }

                // System status
                HStack(spacing: 10) {
                    // Status indicator
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.2))
                            .frame(width: 8, height: 8)

                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: statusColor.opacity(0.8), radius: 4)
                    }

                    Text(statusText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeTextSecondary)

                    Spacer()

                    // Memory indicator
                    if let memPressure = appState.memoryPressureHistory.last {
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.nukeTextTertiary)

                            Text("\(Int(memPressure * 100))%")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(memPressure > 0.7 ? Color.nukeNeonOrange : Color.nukeTextSecondary)
                        }
                    }
                }

                // Disk usage
                if let diskUsage = appState.diskUsage {
                    VStack(spacing: 6) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "internaldrive.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.nukeTextTertiary)

                                Text("STORAGE")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(Color.nukeTextTertiary)
                            }

                            Spacer()

                            Text("\(diskUsage.formattedFree) free")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(diskUsage.usedPercentage > 0.9 ? Color.nukeNeonRed : Color.nukeTextPrimary)
                        }

                        // Enhanced progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.nukeSurfaceHighlight)

                                // Used portion with gradient
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: diskUsage.usedPercentage > 0.9
                                                ? [Color.nukeNeonRed, Color.nukeNeonOrange]
                                                : [Color.nukeToxicGreen, Color.nukeCyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * diskUsage.usedPercentage)
                                    .shadow(color: (diskUsage.usedPercentage > 0.9 ? Color.nukeNeonRed : Color.nukeToxicGreen).opacity(0.5), radius: 4)
                            }
                        }
                        .frame(height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                        // Usage text
                        HStack {
                            Text("\(Int(diskUsage.usedPercentage * 100))% used")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.nukeTextTertiary)

                            Spacer()

                            Text(diskUsage.formattedTotal)
                                .font(.system(size: 8))
                                .foregroundStyle(Color.nukeTextTertiary)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(white: 0.06))
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if appState.isScanning || appState.isCleaning {
            return .nukeNeonOrange
        } else if taskManager.hasRunningTasks {
            return .nukeCyan
        }
        return .nukeToxicGreen
    }

    private var statusText: String {
        if appState.isScanning {
            return "SCANNING..."
        } else if appState.isCleaning {
            return "CLEANING..."
        } else if taskManager.hasRunningTasks {
            return "PROCESSING"
        }
        return "READY"
    }
}

// MARK: - Navigation Section Extension

extension NavigationSection {
    var color: Color {
        switch self {
        case .core: return .nukeNeonRed
        case .analysis: return .nukeCyan
        case .cleanup: return .nukeToxicGreen
        case .system: return .nukeNeonOrange
        case .automation: return .purple
        case .settings: return .nukeTextSecondary
        }
    }
}

// MARK: - Navigation Item Row

struct NavigationItemRow: View {
    let item: NavigationItem
    let isSelected: Bool
    var namespace: Namespace.ID

    @ObservedObject private var taskManager = BackgroundTaskManager.shared
    @State private var isHovered = false

    /// Check if this nav item has running tasks
    private var hasRunningTask: Bool {
        taskManager.tasks.contains { task in
            task.isRunning && taskMatchesItem(task)
        }
    }

    private func taskMatchesItem(_ task: BackgroundTask) -> Bool {
        switch item {
        case .diskAnalysis:
            return task.name.contains("Disk Analysis")
        case .duplicateFinder:
            return task.name.contains("Duplicate")
        case .spaceTreemap:
            return task.name.contains("Treemap")
        case .developerTools:
            return task.name.contains("Developer")
        case .appUninstaller:
            return task.name.contains("Uninstall")
        case .scanResults:
            return task.name.contains("Scan")
        default:
            return false
        }
    }

    private var itemColor: Color {
        item.section.color
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon container with running indicator
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? itemColor.opacity(0.15) : (isHovered ? Color.nukeSurfaceHighlight : Color.clear))
                    .frame(width: 32, height: 32)

                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? itemColor : (isHovered ? .white : Color.nukeTextSecondary))

                // Running task indicator
                if hasRunningTask {
                    Circle()
                        .fill(Color.nukeNeonOrange)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.nukeBlack, lineWidth: 2)
                        )
                        .offset(x: 10, y: -10)
                }
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : (isHovered ? .white : Color.nukeTextSecondary))

                    // PRO badge
                    if item.isPro && !LicenseManager.shared.currentTier.isPro {
                        Text("PRO")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [Color.nukeNeonOrange, Color.nukeNeonRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                if isSelected || isHovered {
                    Text(item.description)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            // Selection indicator / arrow
            if isSelected {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(itemColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.nukeSurfaceHighlight.opacity(0.8))
                        .matchedGeometryEffect(id: "nav_bg", in: namespace)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(itemColor.opacity(0.3), lineWidth: 1)
                        )
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.nukeSurfaceHighlight.opacity(0.4))
                }
            }
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    let selectedItem: NavigationItem

    var body: some View {
        switch selectedItem {
        // Free features
        case .dashboard:
            DashboardView()
        case .scanResults:
            ScanResultsView()
        case .systemMaintenance:
            SystemMaintenanceView()
        case .scheduledScans:
            ScheduledScansView()
        case .whitelist:
            WhitelistView()
        case .settings:
            SettingsView()

        // Pro features - gated with trial support
        case .diskAnalysis:
            ProGateView(feature: .sunburstAnalysis) {
                DiskAnalysisView()
            }
        case .spaceTreemap:
            ProGateView(feature: .spaceTreemap) {
                SpaceTreemapView()
            }
        case .duplicateFinder:
            ProGateView(feature: .duplicateFinder) {
                DuplicateResultsView()
            }
        case .appUninstaller:
            ProGateView(feature: .appUninstaller) {
                AppUninstallerView()
            }
        case .startupManager:
            ProGateView(feature: .startupManager) {
                StartupManagerView()
            }
        case .browserManager:
            ProGateView(feature: .browserCleaner) {
                BrowserManagerView()
            }
        case .developerTools:
            ProGateView(feature: .developerTools) {
                DeveloperToolsView()
            }
        }
    }
}

// MARK: - Dialog Suppression Modifier (macOS 14+ only)

struct DialogSuppressionModifier: ViewModifier {
    @Binding var isSuppressed: Bool

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .dialogSuppressionToggle(isSuppressed: $isSuppressed)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview("Content View") {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 960, height: 600)
}
