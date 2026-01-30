import SwiftUI

/// Startup items manager - control what launches at login
struct StartupManagerView: View {
    @State private var startupItems: [StartupItem] = []
    @State private var isScanning = false
    @State private var selectedType: StartupItemType? = nil
    @State private var searchText = ""
    @State private var showDisabledOnly = false

    private var filteredItems: [StartupItem] {
        var items = startupItems

        // Type filter
        if let type = selectedType {
            items = items.filter { $0.type == type }
        }

        // Search filter
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Disabled only filter
        if showDisabledOnly {
            items = items.filter { !$0.isEnabled }
        }

        return items
    }

    private var enabledCount: Int {
        startupItems.filter { $0.isEnabled }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            if isScanning {
                scanningView
            } else if startupItems.isEmpty {
                emptyStateView
            } else {
                // Stats bar
                statsBar

                // Type filter tabs
                typeFilterBar

                Divider().overlay(Color.nukeSurfaceHighlight)

                // Items list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            startupItemRow(item, index: startupItems.firstIndex(where: { $0.id == item.id }) ?? index)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.nukeBackground)
        .task {
            await scanStartupItems()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.nukeToxicGreen)

                Text("STARTUP MANAGER")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextPrimary)
            }

            Spacer()

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.nukeTextTertiary)

                TextField("Search...", text: $searchText)
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
            .frame(width: 200)

            Button {
                Task { await scanStartupItems() }
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

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 20) {
            // Total items
            statBadge(
                icon: "list.bullet",
                value: "\(startupItems.count)",
                label: "Total Items",
                color: .nukeTextSecondary
            )

            // Enabled count
            statBadge(
                icon: "checkmark.circle.fill",
                value: "\(enabledCount)",
                label: "Enabled",
                color: .nukeToxicGreen
            )

            // Disabled count
            statBadge(
                icon: "xmark.circle.fill",
                value: "\(startupItems.count - enabledCount)",
                label: "Disabled",
                color: .nukeTextTertiary
            )

            Spacer()

            // Quick actions
            if enabledCount > 0 {
                Button {
                    disableAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.circle")
                        Text("Disable All")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.nukeNeonRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.nukeNeonRed.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.nukeSurfaceHighlight.opacity(0.3))
    }

    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.nukeTextPrimary)

                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.nukeTextTertiary)
            }
        }
    }

    // MARK: - Type Filter Bar

    private var typeFilterBar: some View {
        HStack(spacing: 8) {
            // All filter
            filterPill(
                title: "All",
                count: startupItems.count,
                icon: "square.stack.3d.up",
                isSelected: selectedType == nil,
                color: .nukeTextSecondary
            ) {
                selectedType = nil
            }

            ForEach(StartupItemType.allCases, id: \.self) { type in
                filterPill(
                    title: type.rawValue,
                    count: startupItems.filter { $0.type == type }.count,
                    icon: type.icon,
                    isSelected: selectedType == type,
                    color: typeColor(type)
                ) {
                    selectedType = selectedType == type ? nil : type
                }
            }

            Spacer()

            // Show disabled toggle
            Button {
                showDisabledOnly.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showDisabledOnly ? "eye.fill" : "eye.slash")
                        .font(.system(size: 10))
                    Text(showDisabledOnly ? "Show All" : "Disabled Only")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(showDisabledOnly ? Color.nukeNeonOrange : Color.nukeTextTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(showDisabledOnly ? Color.nukeNeonOrange.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.nukeSurface.opacity(0.5))
    }

    private func filterPill(title: String, count: Int, icon: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))

                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(isSelected ? color : Color.nukeSurfaceHighlight)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .foregroundStyle(isSelected ? color : Color.nukeTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.1) : Color.nukeSurfaceHighlight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Item Row

    private func startupItemRow(_ item: StartupItem, index: Int) -> some View {
        HStack(spacing: 14) {
            // Enable/Disable toggle
            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { newValue in
                    Task {
                        await toggleItem(index, enabled: newValue)
                    }
                }
            ))
            .toggleStyle(NukeToggleStyle())
            .frame(width: 44)

            // Type icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor(item.type).opacity(item.isEnabled ? 0.15 : 0.05))
                    .frame(width: 36, height: 36)

                Image(systemName: item.type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(item.isEnabled ? typeColor(item.type) : Color.nukeTextTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(item.isEnabled ? Color.nukeTextPrimary : Color.nukeTextSecondary)

                    // Type badge
                    Text(item.type.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(typeColor(item.type))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor(item.type).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    // Status badge
                    HStack(spacing: 3) {
                        Circle()
                            .fill(item.isEnabled ? Color.nukeToxicGreen : Color.nukeTextTertiary)
                            .frame(width: 6, height: 6)

                        Text(item.isEnabled ? "ACTIVE" : "DISABLED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(item.isEnabled ? Color.nukeToxicGreen : Color.nukeTextTertiary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((item.isEnabled ? Color.nukeToxicGreen : Color.nukeTextTertiary).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Text(item.path.path)
                    .font(.custom("Menlo", size: 9))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.path])
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.nukeCyan)
                        .frame(width: 32, height: 32)
                        .background(Color.nukeCyan.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(item.path.path, forType: .string)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.nukeTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.nukeSurfaceHighlight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Copy Path")
            }
        }
        .padding(14)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isEnabled ? typeColor(item.type).opacity(0.2) : Color.nukeSurfaceHighlight, lineWidth: 1)
        )
    }

    private func typeColor(_ type: StartupItemType) -> Color {
        switch type {
        case .loginItem: return .nukeCyan
        case .launchAgent: return .nukeNeonOrange
        case .launchDaemon: return .nukeNeonRed
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.nukeToxicGreen.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i * 25), height: 100 + CGFloat(i * 25))
                }

                Image(systemName: "power.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.nukeToxicGreen, .nukeCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("STARTUP MANAGER")
                    .font(.system(size: 18, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Control what runs when your Mac starts")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            // Features list
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "list.bullet.rectangle", text: "View all startup items")
                featureRow(icon: "power", text: "Enable or disable with one click")
                featureRow(icon: "speedometer", text: "Speed up your Mac's boot time")
                featureRow(icon: "shield.checkered", text: "Identify unwanted launch agents")
            }
            .padding(20)
            .background(Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await scanStartupItems() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("SCAN STARTUP ITEMS")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.nukeToxicGreen, .nukeCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .nukeToxicGreen.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeToxicGreen)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeTextSecondary)
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 24) {
            ReactorLoader(size: 80, color: .nukeToxicGreen)

            VStack(spacing: 8) {
                Text("SCANNING STARTUP ITEMS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Finding login items, launch agents, and daemons...")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeTextTertiary)
            }

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color.nukeToxicGreen)
                        .frame(width: 6, height: 6)
                        .opacity(0.3 + Double((i + 1)) * 0.14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func scanStartupItems() async {
        isScanning = true

        let items = await StartupItemsScanner.shared.scanStartupItems()

        await MainActor.run {
            startupItems = items
            isScanning = false
        }
    }

    private func toggleItem(_ index: Int, enabled: Bool) async {
        guard index < startupItems.count else { return }

        do {
            try await StartupItemsScanner.shared.toggleStartupItem(startupItems[index], enabled: enabled)
            await MainActor.run {
                startupItems[index].isEnabled = enabled
            }
        } catch {
            // Handle error - item might be protected
        }
    }

    private func disableAll() {
        Task {
            for i in 0..<startupItems.count where startupItems[i].isEnabled {
                await toggleItem(i, enabled: false)
            }
        }
    }
}

// MARK: - Custom Toggle Style

struct NukeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.nukeToxicGreen : Color.nukeSurfaceHighlight)
                    .frame(width: 44, height: 26)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .frame(width: 22, height: 22)
                    .offset(x: configuration.isOn ? 9 : -9)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Startup Manager") {
    StartupManagerView()
        .frame(width: 800, height: 600)
}
