import SwiftUI

/// Complete app uninstaller with related files detection - AppCleaner style
struct AppUninstallerView: View {
    @State private var apps: [InstalledApp] = []
    @State private var filteredApps: [InstalledApp] = []
    @State private var isScanning = false
    @State private var searchText = ""
    @State private var selectedApp: InstalledApp?
    @State private var showingDeleteConfirmation = false
    @State private var sortOrder: SortOrder = .size
    @State private var scanProgress: String = ""

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case lastUsed = "Last Used"

        var icon: String {
            switch self {
            case .name: return "textformat"
            case .size: return "arrow.up.arrow.down"
            case .lastUsed: return "clock"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            if isScanning {
                scanningView
            } else if apps.isEmpty {
                emptyStateView
            } else {
                // Main content
                HStack(spacing: 0) {
                    // Apps list
                    appsListView
                        .frame(width: 340)

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // App details
                    appDetailsView
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.nukeBackground)
        .onChange(of: searchText) { _ in filterApps() }
        .onChange(of: sortOrder) { _ in filterApps() }
        .confirmationDialog("Uninstall Application", isPresented: $showingDeleteConfirmation) {
            Button("Uninstall", role: .destructive) {
                uninstallSelectedApp()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let app = selectedApp {
                Text("This will remove \(app.name) and all selected related files (\(app.formattedTotalSize)).")
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Title with stats
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.square.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.nukeNeonRed)

                    Text("APP UNINSTALLER")
                        .font(.system(size: 14, weight: .black))
                        .tracking(1)
                        .foregroundStyle(Color.nukeTextPrimary)
                }

                if !apps.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(apps.count) apps")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.nukeTextSecondary)

                        let totalSize = apps.reduce(0) { $0 + $1.totalSize }
                        Text("•")
                            .foregroundStyle(Color.nukeTextTertiary)
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.nukeNeonOrange)
                    }
                }
            }

            Spacer()

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.nukeTextTertiary)

                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.nukeSurfaceHighlight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(width: 220)

            // Sort picker with icon
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        Label(order.rawValue, systemImage: order.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: sortOrder.icon)
                    Text(sortOrder.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.nukeTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.nukeSurfaceHighlight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button {
                Task { await startScan() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isScanning ? "stop.fill" : "arrow.clockwise")
                    Text(isScanning ? "STOP" : "SCAN")
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

    // MARK: - Apps List

    private var appsListView: some View {
        VStack(spacing: 0) {
            // List header
            HStack {
                Text("\(filteredApps.count) apps")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.nukeTextTertiary)

                Spacer()

                if !searchText.isEmpty {
                    Text("filtered")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nukeNeonOrange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.nukeSurfaceHighlight.opacity(0.3))

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { app in
                        appRow(app)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color.nukeSurface)
    }

    private func appRow(_ app: InstalledApp) -> some View {
        let isSelected = selectedApp?.id == app.id

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedApp = app
            }
        } label: {
            HStack(spacing: 12) {
                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.nukeSurfaceHighlight)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "app.fill")
                                .foregroundStyle(Color.nukeTextTertiary)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.nukeTextPrimary : Color.nukeTextSecondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let version = app.version {
                            Text("v\(version)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.nukeTextTertiary)
                        }

                        if !app.relatedFiles.isEmpty {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.nukeTextTertiary)

                            HStack(spacing: 2) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 8))
                                Text("+\(app.relatedFiles.count)")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(Color.nukeNeonOrange)
                        }
                    }
                }

                Spacer()

                // Total size with color coding
                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedTotalSize)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(sizeColor(app.totalSize))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.nukeNeonRed.opacity(0.1) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color.nukeNeonRed : Color.clear)
                    .frame(width: 3),
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sizeColor(_ size: Int64) -> Color {
        if size > 1_000_000_000 { return .nukeNeonRed } // > 1GB
        if size > 500_000_000 { return .nukeNeonOrange } // > 500MB
        if size > 100_000_000 { return .nukeCyan } // > 100MB
        return .nukeTextPrimary
    }

    // MARK: - App Details

    private var appDetailsView: some View {
        Group {
            if let app = selectedApp {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // App header card
                        appHeaderCard(app)

                        // Size breakdown
                        sizeBreakdownCard(app)

                        // Actions
                        actionsCard(app)
                    }
                    .padding(20)
                }
            } else {
                noSelectionView
            }
        }
    }

    private func appHeaderCard(_ app: InstalledApp) -> some View {
        HStack(spacing: 20) {
            // Large app icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nukeSurfaceHighlight)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.nukeTextTertiary)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(app.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.nukeTextPrimary)

                if let version = app.version {
                    Text("Version \(version)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.nukeTextSecondary)
                }

                Text(app.bundleIdentifier)
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .lineLimit(1)

                if let lastUsed = app.lastUsed {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("Last used: \(lastUsed, style: .relative) ago")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.nukeTextTertiary)
                }
            }

            Spacer()

            // Total size badge
            VStack(spacing: 6) {
                Text(app.formattedTotalSize)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(sizeColor(app.totalSize))

                Text("TOTAL SIZE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextTertiary)

                // Size bar
                GeometryReader { geo in
                    let percentage = min(Double(app.totalSize) / 1_000_000_000, 1.0) // Relative to 1GB
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.nukeSurfaceHighlight)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(sizeColor(app.totalSize))
                            .frame(width: geo.size.width * percentage)
                    }
                }
                .frame(width: 80, height: 4)
            }
            .padding(16)
            .background(Color.nukeSurfaceHighlight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sizeBreakdownCard(_ app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SIZE BREAKDOWN")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextTertiary)

                Spacer()

                // Select/Deselect all related files
                if !app.relatedFiles.isEmpty {
                    Button {
                        toggleAllRelatedFiles()
                    } label: {
                        Text(allRelatedFilesSelected ? "Deselect All" : "Select All")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.nukeCyan)
                    }
                    .buttonStyle(.plain)
                }
            }

            // App bundle (always included)
            relatedFileRow(
                icon: "app.fill",
                name: "Application Bundle",
                path: app.url.path,
                size: app.size,
                color: .nukeNeonRed,
                isAlwaysSelected: true
            )

            // Related files
            if !app.relatedFiles.isEmpty {
                ForEach(Array(app.relatedFiles.enumerated()), id: \.element.id) { index, file in
                    relatedFileRow(
                        icon: file.type.icon,
                        name: file.type.rawValue,
                        path: file.url.path,
                        size: file.size,
                        color: colorForFileType(file.type),
                        isSelected: file.isSelected,
                        onToggle: {
                            toggleRelatedFile(index)
                        }
                    )
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.nukeToxicGreen)

                    Text("No leftover files found")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.nukeTextSecondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var allRelatedFilesSelected: Bool {
        guard let app = selectedApp else { return false }
        return app.relatedFiles.allSatisfy { $0.isSelected }
    }

    private func toggleAllRelatedFiles() {
        guard var app = selectedApp,
              let appIndex = apps.firstIndex(where: { $0.id == app.id }) else { return }

        let newValue = !allRelatedFilesSelected
        for i in 0..<apps[appIndex].relatedFiles.count {
            apps[appIndex].relatedFiles[i].isSelected = newValue
        }
        selectedApp = apps[appIndex]
    }

    private func colorForFileType(_ type: RelatedFileType) -> Color {
        switch type {
        case .preferences: return .nukeCyan
        case .applicationSupport: return .nukeNeonOrange
        case .cache: return .nukeToxicGreen
        case .containers: return .nukeBlue
        case .logs: return .purple
        case .crashReports: return .nukeNeonRed
        }
    }

    private func actionsCard(_ app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Reveal in Finder")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.nukeCyan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.nukeCyan.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("UNINSTALL COMPLETELY")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.nukeNeonRed, .nukeNeonOrange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .nukeNeonRed.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.nukeTextTertiary)

            Text("Select an application")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.nukeTextSecondary)

            Text("Choose an app from the list to view details\nand remove it completely")
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func relatedFileRow(icon: String, name: String, path: String, size: Int64, color: Color, isAlwaysSelected: Bool = false, isSelected: Bool = true, onToggle: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            if !isAlwaysSelected, let toggle = onToggle {
                Button(action: toggle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.nukeNeonRed : Color.nukeTextTertiary, lineWidth: 1.5)
                            .frame(width: 18, height: 18)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.nukeNeonRed)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.nukeToxicGreen)
            }

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color.nukeTextPrimary : Color.nukeTextTertiary)

                Text(path)
                    .font(.custom("Menlo", size: 9))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? color : Color.nukeTextTertiary)
        }
        .padding(12)
        .background(isSelected ? color.opacity(0.05) : Color.nukeSurfaceHighlight.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.nukeNeonRed.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i * 20), height: 100 + CGFloat(i * 20))
                        .rotationEffect(.degrees(Double(i) * 5))
                }

                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.nukeNeonRed, .nukeNeonOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("APP UNINSTALLER")
                    .font(.system(size: 18, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Remove applications completely with all their leftovers")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            // Features list
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "magnifyingglass", text: "Find all installed applications")
                featureRow(icon: "doc.on.doc", text: "Detect leftover files & preferences")
                featureRow(icon: "trash", text: "Complete removal in one click")
                featureRow(icon: "shield.checkered", text: "Safe uninstall with preview")
            }
            .padding(20)
            .background(Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await startScan() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("SCAN APPLICATIONS")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.nukeNeonRed, .nukeNeonOrange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .nukeNeonRed.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeNeonRed)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeTextSecondary)
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 24) {
            ReactorLoader(size: 80, color: .nukeNeonRed)

            VStack(spacing: 8) {
                Text("SCANNING APPLICATIONS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                if !scanProgress.isEmpty {
                    Text(scanProgress)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nukeTextSecondary)
                } else {
                    Text("Finding installed apps and related files...")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color.nukeNeonRed)
                        .frame(width: 6, height: 6)
                        .opacity(0.3 + Double((i + 1)) * 0.14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func startScan() async {
        isScanning = true
        scanProgress = ""

        let scannedApps = await AppScanner.shared.scanInstalledApps { progress, status in
            Task { @MainActor in
                self.scanProgress = status
            }
        }

        await MainActor.run {
            apps = scannedApps
            filterApps()
            selectedApp = filteredApps.first
            isScanning = false
        }
    }

    private func filterApps() {
        var result = apps

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort
        switch sortOrder {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            result.sort { $0.totalSize > $1.totalSize }
        case .lastUsed:
            result.sort { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }

        filteredApps = result
    }

    private func toggleRelatedFile(_ index: Int) {
        guard var app = selectedApp,
              let appIndex = apps.firstIndex(where: { $0.id == app.id }),
              index < app.relatedFiles.count else { return }

        apps[appIndex].relatedFiles[index].isSelected.toggle()
        selectedApp = apps[appIndex]
    }

    private func uninstallSelectedApp() {
        guard let app = selectedApp else { return }
        let fm = FileManager.default

        // Delete related files first
        for file in app.relatedFiles where file.isSelected {
            try? fm.removeItem(at: file.url)
        }

        // Move app to trash
        try? fm.trashItem(at: app.url, resultingItemURL: nil)

        // Remove from list
        apps.removeAll { $0.id == app.id }
        filterApps()
        selectedApp = filteredApps.first
    }
}

#Preview("App Uninstaller") {
    AppUninstallerView()
        .frame(width: 950, height: 650)
}
