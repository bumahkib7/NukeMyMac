import SwiftUI

/// Entry in the scan log showing a discovered file
struct ScanLogEntry: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let size: Int64
    let category: CleanCategory
    let timestamp: Date = Date()
}

/// Modal overlay shown during scan/clean operations with aggressive NUKE styling
/// Now featuring real-time file scanning display with hacker/matrix aesthetic
struct ProgressOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double
    let message: String
    let isVisible: Bool

    // Real-time scanning properties
    let currentFile: String
    let currentCategory: CleanCategory?
    let itemsFound: Int
    let sizeFound: Int64
    let scanLog: [ScanLogEntry]

    // Optional callbacks
    var onCancel: (() -> Void)?

    @State private var pulseAnimation = false
    @State private var rotationAngle = 0.0
    @State private var glitchOffset: CGFloat = 0
    @State private var scanLineOffset: CGFloat = 0

    // Time tracking
    @State private var startTime: Date = Date()
    @State private var estimatedTimeRemaining: String = "Calculating..."
    @State private var lastProgressUpdate: Double = 0

    // Backwards compatible initializer
    init(
        progress: Double,
        message: String,
        isVisible: Bool,
        currentFile: String = "",
        currentCategory: CleanCategory? = nil,
        itemsFound: Int = 0,
        sizeFound: Int64 = 0,
        scanLog: [ScanLogEntry] = [],
        onCancel: (() -> Void)? = nil
    ) {
        self.progress = progress
        self.message = message
        self.isVisible = isVisible
        self.currentFile = currentFile
        self.currentCategory = currentCategory
        self.itemsFound = itemsFound
        self.sizeFound = sizeFound
        self.scanLog = scanLog
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            if isVisible {
                // Dimmed background with scan lines effect
                ZStack {
                    Color.black.opacity(0.85)

                    // Animated scan line effect
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .nukeToxicGreen.opacity(0.03), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 100)
                        .offset(y: scanLineOffset)
                }
                .ignoresSafeArea()
                .transition(.opacity)

                // Main content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Header with spinning radiation icon
                        headerSection

                        // Stats row
                        statsRow

                        // Current file being scanned
                        currentFileSection

                        // Progress bar
                        progressBarSection

                        // Live scan log (terminal style)
                        scanLogSection

                        // Warning footer
                        warningSection
                    }
                    .padding(32)
                }
                .frame(width: 520)
                .frame(maxHeight: 550)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.nukeBlack.opacity(0.95))
                        .overlay {
                            // Glowing border
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .nukeNeonRed.opacity(0.8),
                                            .nukeNeonOrange.opacity(0.5),
                                            .nukeNeonRed.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        }
                        .shadow(color: .nukeNeonRed.opacity(0.4), radius: 30, x: 0, y: 10)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            startAnimations()
        }
        .onChange(of: progress) { newProgress in
            // Only update when progress changes by at least 1% to avoid rapid updates
            if abs(newProgress - lastProgressUpdate) >= 0.01 {
                lastProgressUpdate = newProgress
                updateTimeEstimate()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Scan progress: \(Int(progress * 100)) percent complete")
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Animated radiation icon
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.nukeNeonRed, .nukeNeonOrange, .nukeNeonRed],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(rotationAngle))
                    .blur(radius: 1)

                // Pulse circle
                Circle()
                    .fill(Color.nukeNeonRed.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .scaleEffect(pulseAnimation ? 1.15 : 0.95)

                // Icon
                Image(systemName: "rays")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.nukeNeonOrange, .nukeNeonRed],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(-rotationAngle / 2))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SYSTEM SCAN ACTIVE")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.nukeNeonOrange)
                    .nukeGlitchReveal()

                Text(message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.nukeTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            StatDisplay(
                icon: "target",
                label: "TARGETS",
                value: "\(itemsFound)",
                color: .nukeToxicGreen
            )

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.1))

            StatDisplay(
                icon: "internaldrive",
                label: "SIZE FOUND",
                value: ByteCountFormatter.string(fromByteCount: sizeFound, countStyle: .file),
                color: .nukeNeonOrange
            )

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.1))

            StatDisplay(
                icon: "percent",
                label: "PROGRESS",
                value: "\(Int(progress * 100))%",
                color: .nukeCyan
            )
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.nukeSurface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    // MARK: - Current File Section

    private var currentFileSection: some View {
        HStack(spacing: 10) {
            // Category icon
            if let category = currentCategory {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.nukeNeonOrange)
                    .frame(width: 20)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .frame(width: 20)
            }

            // Blinking cursor
            Text(">")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.nukeToxicGreen)
                .opacity(pulseAnimation ? 1 : 0.3)

            // Current file path (truncated from left)
            Text(truncatePath(currentFile, maxLength: 55))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.nukeToxicGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Progress Bar Section

    private var progressBarSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.nukeSurface)
                        .frame(height: 8)

                    // Progress fill with glow
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.nukeNeonRed, .nukeNeonOrange, .nukeToxicGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * progress), height: 8)
                        .shadow(color: .nukeNeonOrange.opacity(0.6), radius: 6, x: 0, y: 0)

                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 40, height: 8)
                        .offset(x: pulseAnimation ? geometry.size.width : -40)
                        .mask {
                            RoundedRectangle(cornerRadius: 4)
                                .frame(width: geometry.size.width * progress, height: 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Scan Log Section (Terminal Style)

    private var scanLogSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Terminal header
            HStack {
                Circle().fill(Color.nukeNeonRed).frame(width: 8, height: 8)
                Circle().fill(Color.nukeNeonOrange).frame(width: 8, height: 8)
                Circle().fill(Color.nukeToxicGreen).frame(width: 8, height: 8)

                Spacer()

                Text("SCAN LOG")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .tracking(1)

                Spacer()

                Text("\(scanLog.count) entries")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.nukeTextTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.nukeSurface.opacity(0.8))

            // Log entries
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(scanLog.suffix(15).enumerated()), id: \.element.id) { index, entry in
                            ScanLogRow(entry: entry, index: index)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .onChange(of: scanLog.count) { _ in
                    // Defer scroll to avoid layout recursion
                    DispatchQueue.main.async {
                        if let lastEntry = scanLog.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(lastEntry.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(height: 120)
            .background(Color.black.opacity(0.8))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.nukeToxicGreen.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Warning Section with Time Estimate and Cancel

    private var warningSection: some View {
        VStack(spacing: 12) {
            // Time estimate row
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nukeCyan)

                    Text("EST. REMAINING:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeTextTertiary)

                    Text(estimatedTimeRemaining)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeCyan)
                }

                Spacer()

                // Cancel button
                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                            Text("CANCEL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Color.nukeNeonRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.nukeNeonRed.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.nukeNeonRed.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityLabel("Cancel scan")
                }
            }

            // Warning text
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeNeonOrange)

                Text("DO NOT QUIT APPLICATION DURING SCAN")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .tracking(0.5)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helper Functions

    private func truncatePath(_ path: String, maxLength: Int = 50) -> String {
        guard !path.isEmpty else { return "Initializing..." }
        if path.count <= maxLength { return path }
        return "..." + path.suffix(maxLength - 3)
    }

    private func startAnimations() {
        startTime = Date()

        guard !reduceMotion else {
            pulseAnimation = true
            return
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }

        // Rotation animation
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Scan line animation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            scanLineOffset = 800
        }
    }

    private func updateTimeEstimate() {
        guard progress > 0.05 else {
            estimatedTimeRemaining = "Calculating..."
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTotal = elapsed / progress
        let remaining = estimatedTotal - elapsed

        if remaining < 5 {
            estimatedTimeRemaining = "Almost done..."
        } else if remaining < 60 {
            estimatedTimeRemaining = "\(Int(remaining)) seconds"
        } else {
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining) % 60
            estimatedTimeRemaining = "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Stat Display Component

private struct StatDisplay: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color.opacity(0.8))

                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .tracking(0.5)
            }

            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scan Log Row Component

private struct ScanLogRow: View {
    let entry: ScanLogEntry
    let index: Int

    private var sizeColor: Color {
        if entry.size > 100_000_000 { // > 100MB
            return .nukeNeonRed
        } else if entry.size > 10_000_000 { // > 10MB
            return .nukeNeonOrange
        } else {
            return .nukeToxicGreen
        }
    }

    private var truncatedPath: String {
        let path = entry.path
        if path.count <= 45 { return path }
        return "..." + path.suffix(42)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Category icon (small)
            Image(systemName: entry.category.icon)
                .font(.system(size: 8))
                .foregroundStyle(sizeColor.opacity(0.6))
                .frame(width: 12)

            // File path
            Text(truncatedPath)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(sizeColor.opacity(0.85))
                .lineLimit(1)

            Spacer()

            // Size
            Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(sizeColor)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            index % 2 == 0
                ? Color.white.opacity(0.02)
                : Color.clear
        )
    }
}

// MARK: - Indeterminate Progress Overlay

struct IndeterminateProgressOverlay: View {
    let message: String
    let isVisible: Bool

    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            if isVisible {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
                    // Custom spinning indicator
                    ReactorLoader(size: 80, color: .nukeNeonRed)
                        .frame(width: 80, height: 80)

                    Text("SCANNING...")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Color.nukeNeonOrange)
                        .nukeGlitchReveal()

                    Text(message)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.nukeTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .frame(width: 320)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.nukeBlack.opacity(0.95))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.nukeNeonRed.opacity(0.4), lineWidth: 2)
                        }
                        .shadow(color: .nukeNeonRed.opacity(0.3), radius: 20, x: 0, y: 5)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Preview

#Preview("Progress Overlay - Scanning") {
    ZStack {
        Color.nukeBlack
            .ignoresSafeArea()

        Text("Main App Content")
            .font(.largeTitle)
            .foregroundStyle(.white)

        ProgressOverlay(
            progress: 0.45,
            message: "Scanning Xcode Derived Data...",
            isVisible: true,
            currentFile: "/Users/developer/Library/Developer/Xcode/DerivedData/MyProject-abc123/Build/Products/Debug",
            currentCategory: .xcodeDerivedData,
            itemsFound: 1247,
            sizeFound: 8_547_321_856,
            scanLog: [
                ScanLogEntry(path: "/Users/dev/Library/Caches/com.apple.Safari", size: 234_567_890, category: .systemCaches),
                ScanLogEntry(path: "/Users/dev/Library/Caches/Homebrew/downloads", size: 567_890_123, category: .homebrewCache),
                ScanLogEntry(path: "/Users/dev/.npm/_cacache/content-v2", size: 123_456_789, category: .npmCache),
                ScanLogEntry(path: "/Users/dev/Library/Developer/Xcode/DerivedData/App1", size: 2_345_678_901, category: .xcodeDerivedData),
                ScanLogEntry(path: "/Users/dev/Library/Logs/DiagnosticReports", size: 45_678_901, category: .logFiles),
                ScanLogEntry(path: "/Users/dev/Downloads/old-installer.dmg", size: 1_234_567_890, category: .oldDownloads),
                ScanLogEntry(path: "/Users/dev/Library/Caches/Google/Chrome", size: 789_012_345, category: .systemCaches),
                ScanLogEntry(path: "/Users/dev/.Trash/deleted-project", size: 456_789_012, category: .trash)
            ]
        )
    }
    .frame(width: 700, height: 600)
}

#Preview("Progress Overlay - 85%") {
    ZStack {
        Color.nukeBlack
            .ignoresSafeArea()

        ProgressOverlay(
            progress: 0.85,
            message: "Scanning System Caches...",
            isVisible: true,
            currentFile: "/Library/Caches/com.apple.diagnostics",
            currentCategory: .systemCaches,
            itemsFound: 3892,
            sizeFound: 24_891_234_567,
            scanLog: [
                ScanLogEntry(path: "/Users/dev/Library/Caches/CloudKit", size: 12_345_678, category: .systemCaches),
                ScanLogEntry(path: "/Users/dev/Library/Caches/com.spotify.client", size: 234_567_890, category: .systemCaches),
                ScanLogEntry(path: "/Library/Caches/com.apple.appstore", size: 567_890, category: .systemCaches)
            ]
        )
    }
    .frame(width: 700, height: 600)
}

#Preview("Indeterminate Progress") {
    ZStack {
        Color.nukeBlack
            .ignoresSafeArea()

        IndeterminateProgressOverlay(
            message: "Analyzing disk contents...",
            isVisible: true
        )
    }
    .frame(width: 600, height: 500)
}

#Preview("Backward Compatible") {
    ZStack {
        Color.nukeBlack
            .ignoresSafeArea()

        ProgressOverlay(
            progress: 0.5,
            message: "Processing...",
            isVisible: true
        )
    }
    .frame(width: 600, height: 500)
}
