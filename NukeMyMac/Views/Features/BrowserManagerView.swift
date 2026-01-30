import SwiftUI

/// Browser data manager - clear caches, history, cookies
struct BrowserManagerView: View {
    @State private var profiles: [BrowserProfile] = []
    @State private var isScanning = false
    @State private var selectedProfiles: Set<UUID> = []
    @State private var showingClearConfirmation = false
    @State private var clearOptions: ClearOptions = ClearOptions()

    struct ClearOptions {
        var clearCache = true
        var clearHistory = false
        var clearCookies = false
        var clearDownloads = false
    }

    private var totalCacheSize: Int64 {
        profiles.reduce(0) { $0 + $1.cacheSize }
    }

    private var selectedCacheSize: Int64 {
        profiles.filter { selectedProfiles.contains($0.id) }.reduce(0) { $0 + $1.cacheSize }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            if isScanning {
                scanningView
            } else if profiles.isEmpty {
                emptyStateView
            } else {
                HStack(spacing: 0) {
                    // Browser list
                    browserListView
                        .frame(maxWidth: .infinity)

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // Clear options sidebar
                    clearOptionsSidebar
                        .frame(width: 300)
                }
            }
        }
        .background(Color.nukeBackground)
        .task {
            await scanBrowsers()
        }
        .confirmationDialog("Clear Browser Data", isPresented: $showingClearConfirmation) {
            Button("Clear Data", role: .destructive) {
                clearSelectedData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear selected data from \(selectedProfiles.count) browser(s).")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.nukeCyan)

                Text("BROWSER MANAGER")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextPrimary)
            }

            if !profiles.isEmpty {
                // Stats
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("\(profiles.count)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.nukeCyan)
                        Text("browsers")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.nukeTextSecondary)
                    }

                    Text("•")
                        .foregroundStyle(Color.nukeTextTertiary)

                    HStack(spacing: 4) {
                        Text(ByteCountFormatter.string(fromByteCount: totalCacheSize, countStyle: .file))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.nukeNeonOrange)
                        Text("cached")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.nukeTextSecondary)
                    }
                }
            }

            Spacer()

            Button {
                Task { await scanBrowsers() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("REFRESH")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.nukeNeonOrange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.nukeNeonOrange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(isScanning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.nukeSurface)
    }

    // MARK: - Browser List

    private var browserListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Select all bar
                HStack {
                    Button {
                        if selectedProfiles.count == profiles.count {
                            selectedProfiles.removeAll()
                        } else {
                            selectedProfiles = Set(profiles.map { $0.id })
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedProfiles.count == profiles.count ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14))
                            Text(selectedProfiles.count == profiles.count ? "Deselect All" : "Select All")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.nukeTextSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if !selectedProfiles.isEmpty {
                        Text("\(selectedProfiles.count) selected")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.nukeNeonOrange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.nukeSurfaceHighlight.opacity(0.3))

                // Browser cards
                LazyVStack(spacing: 12) {
                    ForEach(profiles) { profile in
                        browserCard(profile)
                    }
                }
                .padding(16)
            }
        }
    }

    private func browserCard(_ profile: BrowserProfile) -> some View {
        let isSelected = selectedProfiles.contains(profile.id)

        return Button {
            if isSelected {
                selectedProfiles.remove(profile.id)
            } else {
                selectedProfiles.insert(profile.id)
            }
        } label: {
            HStack(spacing: 16) {
                // Selection checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.nukeNeonRed : Color.nukeTextTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.nukeNeonRed)
                    }
                }

                // Browser icon
                ZStack {
                    Circle()
                        .fill(browserColor(profile.browser).opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: profile.browser.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(browserColor(profile.browser))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.browser.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.nukeTextPrimary)

                    // Data breakdown
                    HStack(spacing: 16) {
                        dataLabel(icon: "internaldrive.fill", value: profile.formattedCacheSize, label: "Cache", color: .nukeNeonOrange)
                    }
                }

                Spacer()

                // Cache size badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(profile.formattedCacheSize)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(sizeColor(profile.cacheSize))

                    Text("CACHE SIZE")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.nukeTextTertiary)

                    // Size bar
                    GeometryReader { geo in
                        let percentage = min(Double(profile.cacheSize) / 1_000_000_000, 1.0)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.nukeSurfaceHighlight)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(sizeColor(profile.cacheSize))
                                .frame(width: geo.size.width * percentage)
                        }
                    }
                    .frame(width: 70, height: 4)
                }
            }
            .padding(16)
            .background(isSelected ? Color.nukeNeonRed.opacity(0.05) : Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.nukeNeonRed.opacity(0.4) : Color.nukeSurfaceHighlight, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dataLabel(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.nukeTextPrimary)

                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(Color.nukeTextTertiary)
            }
        }
    }

    private func sizeColor(_ size: Int64) -> Color {
        if size > 1_000_000_000 { return .nukeNeonRed }
        if size > 500_000_000 { return .nukeNeonOrange }
        return .nukeCyan
    }

    private func browserColor(_ browser: BrowserType) -> Color {
        switch browser {
        case .safari: return .nukeCyan
        case .chrome: return .nukeNeonOrange
        case .firefox: return .nukeNeonRed
        case .edge: return .nukeBlue
        case .brave: return .nukeNeonOrange
        case .arc: return .nukeToxicGreen
        }
    }

    // MARK: - Clear Options Sidebar

    private var clearOptionsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("CLEAR OPTIONS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextTertiary)

                Spacer()

                if hasSelectedOptions {
                    Circle()
                        .fill(Color.nukeToxicGreen)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.nukeSurfaceHighlight.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Options
                    VStack(spacing: 10) {
                        clearOptionToggle(
                            title: "Cache",
                            subtitle: "Temporary files and cached data",
                            icon: "internaldrive.fill",
                            color: .nukeNeonOrange,
                            isOn: $clearOptions.clearCache
                        )

                        clearOptionToggle(
                            title: "History",
                            subtitle: "Browsing history",
                            icon: "clock.fill",
                            color: .nukeCyan,
                            isOn: $clearOptions.clearHistory
                        )

                        clearOptionToggle(
                            title: "Cookies",
                            subtitle: "Site cookies and sessions",
                            icon: "circle.hexagongrid.fill",
                            color: .nukeToxicGreen,
                            isOn: $clearOptions.clearCookies
                        )

                        clearOptionToggle(
                            title: "Download History",
                            subtitle: "List of downloaded files",
                            icon: "arrow.down.circle.fill",
                            color: .nukeBlue,
                            isOn: $clearOptions.clearDownloads
                        )
                    }

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // Summary
                    if !selectedProfiles.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUMMARY")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color.nukeTextTertiary)

                            // Selected browsers
                            HStack(spacing: 8) {
                                ForEach(profiles.filter { selectedProfiles.contains($0.id) }) { profile in
                                    ZStack {
                                        Circle()
                                            .fill(browserColor(profile.browser).opacity(0.2))
                                            .frame(width: 32, height: 32)

                                        Image(systemName: profile.browser.icon)
                                            .font(.system(size: 14))
                                            .foregroundStyle(browserColor(profile.browser))
                                    }
                                }
                            }

                            // Size to clear
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Data to clear")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.nukeTextTertiary)

                                Text(ByteCountFormatter.string(fromByteCount: selectedCacheSize, countStyle: .file))
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.nukeNeonRed)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.nukeNeonRed.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else {
                        // No selection
                        VStack(spacing: 8) {
                            Image(systemName: "hand.point.left")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.nukeTextTertiary)

                            Text("Select browsers to clear")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.nukeTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }

                    Spacer(minLength: 16)

                    // Action button
                    Button {
                        showingClearConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("CLEAR SELECTED DATA")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Group {
                                if selectedProfiles.isEmpty || !hasSelectedOptions {
                                    Color.nukeTextTertiary
                                } else {
                                    LinearGradient(
                                        colors: [.nukeNeonRed, .nukeNeonOrange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: (selectedProfiles.isEmpty || !hasSelectedOptions) ? .clear : .nukeNeonRed.opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedProfiles.isEmpty || !hasSelectedOptions)
                }
                .padding(16)
            }
        }
        .background(Color.nukeSurface.opacity(0.5))
    }

    private var hasSelectedOptions: Bool {
        clearOptions.clearCache || clearOptions.clearHistory || clearOptions.clearCookies || clearOptions.clearDownloads
    }

    private func clearOptionToggle(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isOn.wrappedValue ? color : Color.nukeTextTertiary, lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if isOn.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(color)
                    }
                }

                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(isOn.wrappedValue ? 0.15 : 0.05))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(isOn.wrappedValue ? color : Color.nukeTextTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isOn.wrappedValue ? Color.nukeTextPrimary : Color.nukeTextSecondary)

                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nukeTextTertiary)
                }

                Spacer()
            }
            .padding(10)
            .background(isOn.wrappedValue ? color.opacity(0.05) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn.wrappedValue ? color.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.nukeCyan.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i * 25), height: 100 + CGFloat(i * 25))
                }

                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.nukeCyan, .nukeBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("BROWSER MANAGER")
                    .font(.system(size: 18, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Clear browser caches and protect your privacy")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            // Features list
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "internaldrive", text: "Clear browser caches")
                featureRow(icon: "clock", text: "Remove browsing history")
                featureRow(icon: "shield.checkered", text: "Delete cookies & sessions")
                featureRow(icon: "arrow.down.circle", text: "Clean download history")
            }
            .padding(20)
            .background(Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Supported browsers
            VStack(spacing: 8) {
                Text("Supported Browsers")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.nukeTextTertiary)

                HStack(spacing: 12) {
                    ForEach(BrowserType.allCases, id: \.self) { browser in
                        ZStack {
                            Circle()
                                .fill(browserColor(browser).opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: browser.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(browserColor(browser))
                        }
                    }
                }
            }

            Button {
                Task { await scanBrowsers() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("SCAN BROWSERS")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.nukeCyan, .nukeBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .nukeCyan.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeCyan)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeTextSecondary)
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 24) {
            ReactorLoader(size: 80, color: .nukeCyan)

            VStack(spacing: 8) {
                Text("SCANNING BROWSERS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Finding installed browsers and cache data...")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeTextTertiary)
            }

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color.nukeCyan)
                        .frame(width: 6, height: 6)
                        .opacity(0.3 + Double((i + 1)) * 0.14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func scanBrowsers() async {
        isScanning = true

        let browserProfiles = await BrowserScanner.shared.scanBrowserProfiles()

        await MainActor.run {
            profiles = browserProfiles
            isScanning = false
        }
    }

    private func clearSelectedData() {
        Task {
            for profile in profiles where selectedProfiles.contains(profile.id) {
                if clearOptions.clearCache {
                    try? await BrowserScanner.shared.clearBrowserCache(profile.browser)
                }
                // Note: History, cookies, and download history clearing would require
                // browser-specific implementations and potentially admin access
            }

            // Rescan
            await scanBrowsers()
            selectedProfiles.removeAll()
        }
    }
}

#Preview("Browser Manager") {
    BrowserManagerView()
        .frame(width: 900, height: 600)
}
