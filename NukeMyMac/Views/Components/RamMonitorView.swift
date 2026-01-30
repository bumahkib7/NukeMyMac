import SwiftUI
import Charts
import AppKit

struct RamMonitorView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHoveringClean = false
    @State private var isHoveringScan = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView

            Divider().overlay(Color.nukeNeonRed.opacity(0.3))

            // MARK: - System Stats
            HStack(spacing: 0) {
                // CPU Graph
                EnhancedGraphCard(
                    title: "CPU",
                    icon: "cpu.fill",
                    value: appState.currentCpuLoad,
                    history: appState.cpuPressureHistory,
                    color: .nukeCyan,
                    accentColor: .nukeBlue
                )

                Divider().overlay(Color.white.opacity(0.05))

                // RAM Graph
                EnhancedGraphCard(
                    title: "RAM",
                    icon: "memorychip.fill",
                    value: appState.memoryPressureHistory.last ?? 0,
                    history: appState.memoryPressureHistory,
                    color: .nukeToxicGreen,
                    accentColor: .nukeNeonOrange,
                    showAction: true,
                    action: { Task { await appState.cleanMemory() } }
                )

                Divider().overlay(Color.white.opacity(0.05))

                // Disk
                EnhancedDiskCard(diskUsage: appState.diskUsage)
            }
            .frame(height: 110)

            Divider().overlay(Color.white.opacity(0.05))

            // MARK: - Quick Actions
            quickActionsBar

            Divider().overlay(Color.white.opacity(0.05))

            // MARK: - Process List
            processListView
        }
        .frame(width: 460, height: 380)
        .background(Color.nukeBlack)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.nukeNeonRed.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            appState.startRamMonitoring()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("NUKE MY MAC")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.nukeNeonRed, .nukeNeonOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("System Monitor")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.nukeTextTertiary)
            }

            Spacer()

            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.nukeToxicGreen)
                    .frame(width: 6, height: 6)
                    .shadow(color: .nukeToxicGreen, radius: 3)

                Text("ONLINE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.nukeToxicGreen)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.nukeToxicGreen.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.nukeSurface.opacity(0.5))
    }

    // MARK: - Quick Actions
    private var quickActionsBar: some View {
        HStack(spacing: 8) {
            QuickActionButton(
                icon: "trash.fill",
                label: "Clean Memory",
                color: .nukeNeonRed,
                isHovering: $isHoveringClean
            ) {
                Task { await appState.cleanMemory() }
            }

            QuickActionButton(
                icon: "magnifyingglass",
                label: "Quick Scan",
                color: .nukeCyan,
                isHovering: $isHoveringScan
            ) {
                Task { await appState.startScan() }
            }

            Spacer()

            // Open main app
            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("Nuke") || $0.isKeyWindow == false }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Open App")
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 9))
                }
                .foregroundStyle(Color.nukeTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.nukeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.nukeBlack.opacity(0.5))
    }

    // MARK: - Process List
    private var processListView: some View {
        ProcessListSection(
            processes: appState.runningProcesses,
            onKill: { process in
                withAnimation(.spring(response: 0.3)) {
                    appState.killProcess(process)
                }
            }
        )
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Process List Section

struct ProcessListSection: View {
    let processes: [ScannedProcess]
    let onKill: (ScannedProcess) -> Void

    @State private var sortBy: ProcessSortOption = .memory
    @State private var searchText = ""

    enum ProcessSortOption: String, CaseIterable {
        case memory = "Memory"
        case cpu = "CPU"
        case name = "Name"

        var icon: String {
            switch self {
            case .memory: return "memorychip"
            case .cpu: return "cpu"
            case .name: return "textformat"
            }
        }
    }

    private var sortedProcesses: [ScannedProcess] {
        var filtered = processes
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortBy {
        case .memory:
            return filtered.sorted { $0.memoryUsage > $1.memoryUsage }
        case .cpu:
            return filtered.sorted { $0.cpuUsage > $1.cpuUsage }
        case .name:
            return filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with sort options
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.nukeNeonOrange)

                Text("PROCESSES")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.nukeTextSecondary)
                    .tracking(1)

                Text("\(processes.count)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.nukeNeonOrange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.nukeNeonOrange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Spacer()

                // Sort buttons
                HStack(spacing: 4) {
                    ForEach(ProcessSortOption.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                sortBy = option
                            }
                        } label: {
                            Image(systemName: option.icon)
                                .font(.system(size: 9, weight: sortBy == option ? .bold : .regular))
                                .foregroundStyle(sortBy == option ? Color.nukeNeonOrange : Color.nukeTextTertiary)
                                .frame(width: 22, height: 18)
                                .background(sortBy == option ? Color.nukeNeonOrange.opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .help("Sort by \(option.rawValue)")
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if processes.isEmpty {
                VStack(spacing: 8) {
                    NukeSpinner(size: 20, color: .nukeTextTertiary)
                    Text("Scanning processes...")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Column headers inline with scroll content
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        // Header row
                        HStack(spacing: 6) {
                            Text("APP")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("CPU")
                                .frame(width: 45, alignment: .trailing)
                            Text("MEM")
                                .frame(width: 55, alignment: .trailing)
                            Color.clear.frame(width: 14)
                        }
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)

                        // Process rows
                        ForEach(sortedProcesses, id: \.id) { process in
                            EnhancedProcessRow(process: process) {
                                onKill(process)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                }
            }
        }
    }
}

// MARK: - Enhanced Graph Card

struct EnhancedGraphCard: View {
    let title: String
    let icon: String
    let value: Double
    let history: [Double]
    let color: Color
    let accentColor: Color
    var showAction: Bool = false
    var action: (() -> Void)? = nil

    @State private var isHovering = false

    private var percentage: Int {
        Int(value * 100)
    }

    private var statusColor: Color {
        if value > 0.8 { return .nukeNeonRed }
        if value > 0.6 { return .nukeNeonOrange }
        return color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.nukeTextSecondary)

                Spacer()

                if showAction, let action = action {
                    Button(action: action) {
                        Image(systemName: "arrow.circlepath")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isHovering ? .white : color)
                            .frame(width: 22, height: 22)
                            .background(isHovering ? color : color.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isHovering = hovering
                            }
                        }
                    }
                    .help("Clean Memory")
                }
            }

            // Percentage display
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(percentage)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(statusColor)

                Text("%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(statusColor.opacity(0.7))
            }

            // Graph
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Background grid
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Divider().background(Color.white.opacity(0.05))
                            Spacer()
                        }
                    }

                    if history.count > 1 {
                        // Area fill
                        AreaGraph(data: history, color: color)

                        // Line
                        LineGraph(data: history, color: color, accentColor: accentColor)
                    }
                }
            }
            .frame(height: 35)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Line Graph

struct LineGraph: View {
    let data: [Double]
    let color: Color
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let stepX = width / CGFloat(max(1, data.count - 1))
                let safeData = data.map { $0.isNaN || $0.isInfinite ? 0 : min(1, max(0, $0)) }

                guard !safeData.isEmpty else { return }

                path.move(to: CGPoint(x: 0, y: height * (1 - CGFloat(safeData[0]))))
                for i in 1..<safeData.count {
                    let x = CGFloat(i) * stepX
                    let y = height * (1 - CGFloat(safeData[i]))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(colors: [color, accentColor], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: color.opacity(0.5), radius: 4)
        }
    }
}

// MARK: - Area Graph

struct AreaGraph: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let stepX = width / CGFloat(max(1, data.count - 1))
                let safeData = data.map { $0.isNaN || $0.isInfinite ? 0 : min(1, max(0, $0)) }

                guard !safeData.isEmpty else { return }

                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: 0, y: height * (1 - CGFloat(safeData[0]))))
                for i in 1..<safeData.count {
                    let x = CGFloat(i) * stepX
                    let y = height * (1 - CGFloat(safeData[i]))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Enhanced Disk Card

struct EnhancedDiskCard: View {
    let diskUsage: DiskUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.nukeNeonOrange)

                Text("DISK")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.nukeTextSecondary)

                Spacer()
            }

            if let usage = diskUsage {
                // Free space
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(usage.formattedFree)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("FREE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.nukeToxicGreen)

                Spacer()

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))

                        // Used portion
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [.nukeToxicGreen, .nukeNeonOrange, .nukeNeonRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(usage.usedPercentage))
                    }
                }
                .frame(height: 6)

                Text("\(Int(usage.usedPercentage * 100))% used")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.nukeTextTertiary)
            } else {
                Spacer()
                NukeSpinner(size: 16, color: .nukeTextTertiary)
                Spacer()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    @Binding var isHovering: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isHovering ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovering ? color : color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
        }
    }
}

// MARK: - Enhanced Process Row

struct EnhancedProcessRow: View {
    let process: ScannedProcess
    let onKill: () -> Void

    @State private var isHovering = false

    private var memoryColor: Color {
        let mb = Double(process.memoryUsage) / 1_000_000
        if mb > 500 { return .nukeNeonRed }
        if mb > 200 { return .nukeNeonOrange }
        return .nukeTextPrimary
    }

    private var cpuColor: Color {
        if process.cpuUsage > 50 { return .nukeNeonRed }
        if process.cpuUsage > 20 { return .nukeNeonOrange }
        if process.cpuUsage > 5 { return .nukeToxicGreen }
        return .nukeTextTertiary
    }

    var body: some View {
        HStack(spacing: 6) {
            // App icon - clickable to open app
            Button {
                openApp()
            } label: {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .frame(width: 16, height: 16)
                }
            }
            .buttonStyle(.plain)
            .help("Open \(process.name)")

            // Name - clickable to open app
            Button {
                openApp()
            } label: {
                Text(process.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // CPU
            Text(process.formattedCpu)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(cpuColor)
                .frame(width: 45, alignment: .trailing)

            // Memory
            Text(process.formattedMemory)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(memoryColor)
                .frame(width: 55, alignment: .trailing)

            // Kill button
            Button(action: onKill) {
                Image(systemName: "xmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(isHovering ? Color.nukeNeonRed : Color.nukeNeonRed.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.6)
            .help("Quit \(process.name)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(isHovering ? 0.05 : 0.01))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .onHover { hovering in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovering = hovering
                }
            }
        }
    }

    private func openApp() {
        if let app = NSRunningApplication(processIdentifier: process.id) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}

// MARK: - Preview

#Preview("RAM Monitor - Menu Bar") {
    RamMonitorView()
        .environmentObject(AppState())
}
