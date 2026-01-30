import SwiftUI
import Charts

/// Dashboard view - the NUKE command center showing disk usage and scan controls
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var isButtonHovered = false
    @State private var pulseAnimation = false
    @State private var rotationAnimation = false
    
    var body: some View {
        ZStack {
            // Animated Background
            AnimatedMeshBackground()
            
            ScrollView {
                VStack(spacing: Theme.spacing32) {
                    // MARK: - Header Status
                    headerStatus
                    
                    // MARK: - Main Reactor Section
                    HStack(spacing: Theme.spacing32) {
                        // Left Column - Stats with Donut Chart
                        VStack(spacing: Theme.spacing16) {
                            if let diskUsage = appState.diskUsage {
                                // Donut Chart visualization
                                VStack(spacing: 12) {
                                    Text("STORAGE OVERVIEW")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(2)
                                        .foregroundStyle(Color.nukeTextTertiary)

                                    StorageDonutChart(diskUsage: diskUsage)
                                }
                                .padding(16)
                                .background(Color.nukeSurface.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))

                                DiskStatCard(
                                    title: "SYSTEM CAPACITY",
                                    value: diskUsage.formattedTotal,
                                    subValue: "TOTAL STORAGE",
                                    color: .nukeTextPrimary
                                )
                            } else {
                                // Loading placeholder
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .fill(Color.nukeSurface)
                                    .frame(height: 300)
                                    .overlay(
                                        ReactorLoader(size: 40, color: .nukeNeonRed)
                                    )
                            }
                        }
                        .frame(width: 240)
                        
                        // Center - Reactor Core
                        reactorCoreSection
                            .frame(maxWidth: .infinity)
                        
                        // Right Column - Quick Actions / Scan Results Chart
                        VStack(spacing: Theme.spacing16) {
                            if let scanResult = appState.scanResult {
                                ScanResultCard(scanResult: scanResult)

                                // Category breakdown chart
                                if !scanResult.items.isEmpty {
                                    ScanResultsChart(scanResult: scanResult)
                                }
                            } else {
                                // Placeholder or tip
                                VStack(spacing: 12) {
                                    Image(systemName: "terminal.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color.nukeTextTertiary)

                                    Text("AWAITING COMMAND")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.nukeTextSecondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .stroke(Color.nukeSurfaceHighlight, lineWidth: 2)
                                        .background(Color.nukeSurface.opacity(0.5))
                                )
                            }
                        }
                        .frame(width: 280)
                    }
                    .frame(height: 320)
                    
                    // MARK: - Categories Grid
                    VStack(alignment: .leading, spacing: Theme.spacing16) {
                        HStack {
                            Rectangle()
                                .fill(Color.nukeNeonOrange)
                                .frame(width: 4, height: 16)
                            
                            Text("TARGET PROTOCOLS")
                                .font(.system(size: 12, weight: .black))
                                .tracking(2)
                                .foregroundStyle(Color.nukeTextSecondary)
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Theme.spacing16) {
                            ForEach(CleanCategory.allCases) { category in
                                CategoryPreviewCard(category: category)
                            }
                        }
                    }
                    
                    Spacer(minLength: Theme.spacing32)
                }
                .padding(Theme.spacing32)
            }
        }
        .background(Color.nukeBackground)
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Start Scan
                Button {
                    Task { await appState.startScan() }
                } label: {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color.nukeNeonOrange)
                }
                .help("Start Scan (⌘⇧S)")
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!appState.canStartScan)

                // Refresh
                Button {
                    Task { await appState.loadDiskUsage() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.nukeNeonRed)
                }
                .help("Refresh (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .task {
            await appState.loadDiskUsage()
        }
    }
    
    // MARK: - Header Status
    
    private var headerStatus: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DASHBOARD")
                    .font(.system(size: 32, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .nukeGlitchReveal()
                
                Text("SYSTEM OVERVIEW UNIT // ONLINE")
                    .font(.custom("Menlo", size: 12))
                    .foregroundStyle(Color.nukeToxicGreen)
                    .nukeGlitchReveal()
            }
            
            Spacer()
            
            if appState.isScanning {
                HStack(spacing: 8) {
                    ReactorLoader(size: 16, color: .nukeNeonRed)
                    
                    Text("SCANNING...")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.nukeNeonRed)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.nukeNeonRed.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.nukeNeonRed.opacity(0.3), lineWidth: 1))
            }
        }
    }
    
    // MARK: - Reactor Core (Scan Button)
    
    private var reactorCoreSection: some View {
        ZStack {
            // "Plasma" Plasma Rings
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.clear, .nukeNeonRed.opacity(0.5), .clear],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 220 + CGFloat(i * 30), height: 220 + CGFloat(i * 30))
                    .rotationEffect(.degrees(rotationAnimation ? 360 : 0))
                    .animation(
                        .linear(duration: 10 + Double(i * 8)).repeatForever(autoreverses: false),
                        value: rotationAnimation
                    )
            }
            
            // The Button
            Button {
                Task {
                    await appState.startScan()
                }
            } label: {
                ZStack {
                    // Glow Layer
                    Circle()
                        .fill(Color.nukeNeonRed.opacity(isButtonHovered ? 0.3 : 0.05))
                        .frame(width: 190, height: 190)
                        .blur(radius: isButtonHovered ? 40 : 20)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    
                    // Core Visual
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.nukeNeonRed.opacity(0.2), Color.nukeBlack],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 170, height: 170)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.nukeNeonRed, .nukeNeonOrange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .nukeGlow(color: .nukeNeonRed, radius: 15, opacity: 0.6)
                    
                    // Button Content
                    VStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.nukeNeonRed)
                            .shadow(color: .nukeNeonRed, radius: 10)
                        
                        Text("INITIATE")
                            .font(.system(size: 14, weight: .black))
                            .tracking(2)
                            .foregroundStyle(.white)
                        
                        Text("SCAN")
                            .font(.system(size: 14, weight: .black))
                            .tracking(2)
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!appState.canStartScan)
            .scaleEffect(isButtonHovered ? 1.05 : 1.0)
            .onHover { hovering in
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isButtonHovered = hovering
                    }
                }
            }
            .onAppear {
                rotationAnimation = true
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }
}

// MARK: - Subcomponents

struct DiskStatCard: View {
    let title: String
    let value: String
    let subValue: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: 12)
                
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextSecondary)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            
            Text(subValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Color.nukeSurfaceHighlight, lineWidth: 1)
        )
    }
}

struct CategoryPreviewCard: View {
    let category: CleanCategory
    @ObservedObject var settings = SettingsViewModel.shared
    
    var body: some View {
        let isEnabled = settings.isCategorySelected(category)
        
        Button {
            settings.toggleCategory(category)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isEnabled ? Color.nukeNeonRed : Color.nukeTextTertiary)
                    
                    Spacer()
                    
                    Circle()
                        .fill(isEnabled ? Color.nukeToxicGreen : Color.nukeDarkGray)
                        .frame(width: 6, height: 6)
                        .shadow(color: isEnabled ? .nukeToxicGreen : .clear, radius: 4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isEnabled ? .white : Color.nukeTextSecondary)
                        .lineLimit(1)
                    
                    Text(isEnabled ? "ACTIVE" : "DISABLED")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(isEnabled ? Color.nukeTextSecondary : Color.nukeTextTertiary)
                }
            }
            .padding(16)
            .background(isEnabled ? Color.nukeSurface : Color.nukeBlack)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .stroke(isEnabled ? Color.nukeNeonRed.opacity(0.3) : Color.nukeSurfaceHighlight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScanResultCard: View {
    let scanResult: ScanResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.nukeNeonOrange)
                Text("SCAN REPORT")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
            }
            
            Divider().overlay(Color.nukeSurfaceHighlight)
            
            VStack(spacing: 12) {
                resultRow(label: "FOUND", value: "\(scanResult.items.count)", color: .white)
                resultRow(label: "SIZE", value: scanResult.formattedTotalSize, color: .nukeNeonRed)
                resultRow(label: "TIME", value: String(format: "%.2fs", scanResult.scanDuration), color: .nukeNeonOrange)
            }
            
            Spacer()
            
            Text("READY FOR DESTRUCTION")
                .font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.nukeNeonRed.opacity(0.2))
                .foregroundStyle(Color.nukeNeonRed)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Color.nukeNeonOrange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func resultRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.nukeTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Storage Donut Chart (Swift Charts)

struct StorageDonutChart: View {
    let diskUsage: DiskUsage

    private var chartData: [StorageChartData] {
        [
            StorageChartData(label: "Used", value: Double(diskUsage.usedSpace), color: .nukeNeonRed),
            StorageChartData(label: "Free", value: Double(diskUsage.freeSpace), color: .nukeToxicGreen)
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            if #available(macOS 14.0, *) {
                Chart(chartData) { item in
                    SectorMark(
                        angle: .value("Size", item.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(width: 120, height: 120)
                .chartBackground { proxy in
                    GeometryReader { geo in
                        if let frame = proxy.plotFrame {
                            let rect = geo[frame]
                            VStack(spacing: 2) {
                                Text("\(Int(diskUsage.usedPercentage * 100))%")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("USED")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color.nukeTextTertiary)
                            }
                            .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
            } else {
                // Fallback for macOS 13: simple progress ring
                ZStack {
                    Circle()
                        .stroke(Color.nukeSurfaceHighlight, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: diskUsage.usedPercentage)
                        .stroke(Color.nukeNeonRed, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(diskUsage.usedPercentage * 100))%")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("USED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                }
                .frame(width: 120, height: 120)
            }

            // Legend
            HStack(spacing: 16) {
                legendItem(color: .nukeNeonRed, label: "Used", value: diskUsage.formattedUsed)
                legendItem(color: .nukeToxicGreen, label: "Free", value: diskUsage.formattedFree)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Disk usage: \(Int(diskUsage.usedPercentage * 100)) percent used, \(diskUsage.formattedFree) free")
    }

    private func legendItem(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.nukeTextTertiary)
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct StorageChartData: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

// MARK: - Scan Results Chart

struct ScanResultsChart: View {
    let scanResult: ScanResult

    private var chartData: [CategoryChartData] {
        let sizeByCategory = scanResult.sizeByCategory()
        return sizeByCategory.map { category, size in
            CategoryChartData(category: category, size: size)
        }.sorted { $0.size > $1.size }
        .prefix(5) // Show top 5 categories only
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.nukeNeonOrange)
                Text("TOP CATEGORIES")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            // Custom list view instead of Chart for better readability
            VStack(spacing: 8) {
                ForEach(chartData) { item in
                    HStack(spacing: 12) {
                        // Category icon
                        Image(systemName: item.category.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(categoryColor(item.category))
                            .frame(width: 20)

                        // Category name
                        Text(item.category.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        // Size
                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.nukeNeonOrange)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.nukeSurfaceHighlight)
                                .frame(height: 4)

                            Rectangle()
                                .fill(categoryColor(item.category))
                                .frame(width: geo.size.width * barWidth(for: item), height: 4)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(16)
        .background(Color.nukeSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func barWidth(for item: CategoryChartData) -> Double {
        guard let maxSize = chartData.first?.size, maxSize > 0 else { return 0 }
        return Double(item.size) / Double(maxSize)
    }

    private func categoryColor(_ category: CleanCategory) -> Color {
        switch category {
        case .systemCaches, .homebrewCache, .npmCache:
            return .nukeCyan
        case .xcodeDerivedData:
            return .nukeNeonOrange
        case .trash, .oldDownloads:
            return .nukeNeonRed
        case .logFiles, .docker:
            return .nukeBlue
        default:
            return .nukeToxicGreen
        }
    }
}

struct CategoryChartData: Identifiable {
    let id = UUID()
    let category: CleanCategory
    let size: Int64

    var name: String { category.rawValue }
}

// MARK: - Preview

#Preview("Dashboard - Dark Nuke") {
    DashboardView()
        .environmentObject(AppState())
        .frame(width: 900, height: 700)
        .preferredColorScheme(.dark)
}
