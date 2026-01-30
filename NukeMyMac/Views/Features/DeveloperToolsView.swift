import SwiftUI

/// Developer tools cleanup - package managers, simulators, git repos
struct DeveloperToolsView: View {
    @State private var selectedTab: DevToolsTab = .packageManagers
    @State private var packageCaches: [PackageManagerCache] = []
    @State private var simulators: [SimulatorDevice] = []
    @State private var gitRepos: [GitRepository] = []

    // Per-tab loading states for better UX
    @State private var isLoadingPackages = false
    @State private var isLoadingSimulators = false
    @State private var isLoadingRepos = false

    // Search
    @State private var searchText = ""

    // Progress
    @State private var scanProgress: String = ""

    enum DevToolsTab: String, CaseIterable {
        case packageManagers = "Package Managers"
        case simulators = "Simulators"
        case gitRepos = "Git Repos"

        var icon: String {
            switch self {
            case .packageManagers: return "shippingbox.fill"
            case .simulators: return "iphone"
            case .gitRepos: return "arrow.triangle.branch"
            }
        }

        var color: Color {
            switch self {
            case .packageManagers: return .nukeNeonOrange
            case .simulators: return .nukeCyan
            case .gitRepos: return .nukeToxicGreen
            }
        }
    }

    private var isCurrentTabLoading: Bool {
        switch selectedTab {
        case .packageManagers: return isLoadingPackages
        case .simulators: return isLoadingSimulators
        case .gitRepos: return isLoadingRepos
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            // Tab bar
            tabBar

            Divider().overlay(Color.nukeSurfaceHighlight)

            // Content
            if isCurrentTabLoading {
                loadingView
            } else {
                switch selectedTab {
                case .packageManagers:
                    packageManagersView
                case .simulators:
                    simulatorsView
                case .gitRepos:
                    gitReposView
                }
            }
        }
        .background(Color.nukeBackground)
        .task {
            await scanCurrentTab()
        }
        .onChange(of: selectedTab) { _ in
            Task { await scanCurrentTab() }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.nukeToxicGreen.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "hammer.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.nukeToxicGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("DEVELOPER TOOLS")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Clean package caches, simulators, and git repos")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            Spacer()

            // Quick stats
            HStack(spacing: 12) {
                quickStat(
                    icon: "shippingbox.fill",
                    value: ByteCountFormatter.string(fromByteCount: packageCaches.reduce(0) { $0 + $1.size }, countStyle: .file),
                    color: .nukeNeonOrange
                )
                quickStat(
                    icon: "iphone",
                    value: "\(simulators.count)",
                    color: .nukeCyan
                )
                quickStat(
                    icon: "arrow.triangle.branch",
                    value: "\(gitRepos.count)",
                    color: .nukeToxicGreen
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.nukeSurface)
    }

    private func quickStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.nukeTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DevToolsTab.allCases, id: \.self) { tab in
                tabButton(tab)

                if tab != DevToolsTab.allCases.last {
                    Divider()
                        .frame(height: 24)
                        .overlay(Color.nukeSurfaceHighlight)
                }
            }

            Spacer()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nukeTextTertiary)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeTextPrimary)
                    .frame(width: 120)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.nukeSurfaceHighlight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.trailing, 12)

            // Refresh
            Button {
                Task { await scanCurrentTab(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCurrentTabLoading ? Color.nukeTextTertiary : Color.nukeTextSecondary)
                    .rotationEffect(.degrees(isCurrentTabLoading ? 360 : 0))
                    .animation(isCurrentTabLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isCurrentTabLoading)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentTabLoading)
            .padding(.trailing, 16)
        }
        .background(Color.nukeSurface)
    }

    private func tabButton(_ tab: DevToolsTab) -> some View {
        let isSelected = selectedTab == tab
        let count: Int = {
            switch tab {
            case .packageManagers: return packageCaches.count
            case .simulators: return simulators.count
            case .gitRepos: return gitRepos.count
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))

                Text(tab.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? .white : tab.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? tab.color : tab.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .foregroundStyle(isSelected ? tab.color : Color.nukeTextSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? tab.color.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ReactorLoader(size: 60, color: selectedTab.color)

            Text("Scanning \(selectedTab.rawValue.lowercased())...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.nukeTextSecondary)

            if !scanProgress.isEmpty {
                Text(scanProgress)
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Package Managers View

    private var filteredPackageCaches: [PackageManagerCache] {
        guard !searchText.isEmpty else { return packageCaches }
        return packageCaches.filter {
            $0.manager.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.path.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var packageManagersView: some View {
        VStack(spacing: 0) {
            // Stats header
            statsHeader(
                items: filteredPackageCaches,
                totalSize: packageCaches.reduce(0) { $0 + $1.size },
                selectedSize: packageCaches.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
            )

            Divider().overlay(Color.nukeSurfaceHighlight)

            if filteredPackageCaches.isEmpty {
                emptyState(
                    icon: "shippingbox",
                    title: packageCaches.isEmpty ? "No Package Caches Found" : "No Results",
                    message: packageCaches.isEmpty ? "Install some packages with npm, pip, brew, etc." : "Try a different search term"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredPackageCaches.enumerated()), id: \.element.id) { _, cache in
                            if let index = packageCaches.firstIndex(where: { $0.id == cache.id }) {
                                packageCacheCard(cache, index: index)
                            }
                        }
                    }
                    .padding(16)
                }

                actionBar(
                    selectedCount: packageCaches.filter { $0.isSelected }.count,
                    onSelectAll: { for i in packageCaches.indices { packageCaches[i].isSelected = true } },
                    onDeselectAll: { for i in packageCaches.indices { packageCaches[i].isSelected = false } },
                    onClean: cleanSelectedCaches
                )
            }
        }
    }

    private func packageCacheCard(_ cache: PackageManagerCache, index: Int) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            checkboxButton(isSelected: cache.isSelected) {
                packageCaches[index].isSelected.toggle()
            }

            // Icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.nukeNeonOrange.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: cache.manager.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.nukeNeonOrange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(cache.manager.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.nukeTextPrimary)

                Text(cache.path.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.custom("Menlo", size: 9))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Size with bar
            VStack(alignment: .trailing, spacing: 4) {
                Text(cache.formattedSize)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(sizeColor(cache.size))

                // Size bar
                GeometryReader { geo in
                    let maxSize = packageCaches.map { $0.size }.max() ?? 1
                    let ratio = CGFloat(cache.size) / CGFloat(maxSize)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.nukeSurfaceHighlight)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(sizeColor(cache.size))
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(width: 60, height: 4)
            }

            // Reveal button
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([cache.path])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.nukeCyan)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(cache.isSelected ? Color.nukeNeonRed.opacity(0.05) : Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cache.isSelected ? Color.nukeNeonRed.opacity(0.3) : Color.nukeSurfaceHighlight, lineWidth: 1)
        )
    }

    // MARK: - Simulators View

    private var filteredSimulators: [SimulatorDevice] {
        guard !searchText.isEmpty else { return simulators }
        return simulators.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.runtime.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var simulatorsView: some View {
        VStack(spacing: 0) {
            statsHeader(
                items: filteredSimulators,
                totalSize: simulators.reduce(0) { $0 + $1.dataSize },
                selectedSize: simulators.filter { $0.isSelected }.reduce(0) { $0 + $1.dataSize }
            )

            Divider().overlay(Color.nukeSurfaceHighlight)

            if filteredSimulators.isEmpty {
                emptyState(
                    icon: "iphone.slash",
                    title: simulators.isEmpty ? "No Simulators Found" : "No Results",
                    message: simulators.isEmpty ? "Make sure Xcode is installed" : "Try a different search term"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredSimulators.enumerated()), id: \.element.id) { _, sim in
                            if let index = simulators.firstIndex(where: { $0.id == sim.id }) {
                                simulatorCard(sim, index: index)
                            }
                        }
                    }
                    .padding(16)
                }

                actionBar(
                    selectedCount: simulators.filter { $0.isSelected }.count,
                    onSelectAll: { for i in simulators.indices { simulators[i].isSelected = true } },
                    onDeselectAll: { for i in simulators.indices { simulators[i].isSelected = false } },
                    onClean: deleteSelectedSimulators,
                    actionLabel: "DELETE SELECTED"
                )
            }
        }
    }

    private func simulatorCard(_ sim: SimulatorDevice, index: Int) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            checkboxButton(isSelected: sim.isSelected) {
                simulators[index].isSelected.toggle()
            }

            // Device icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(sim.state == .booted ? Color.nukeToxicGreen.opacity(0.1) : Color.nukeSurfaceHighlight.opacity(0.5))
                    .frame(width: 40, height: 40)

                Image(systemName: sim.name.contains("iPad") ? "ipad" : "iphone")
                    .font(.system(size: 18))
                    .foregroundStyle(sim.state == .booted ? Color.nukeToxicGreen : Color.nukeTextSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(sim.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.nukeTextPrimary)

                    if sim.state == .booted {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.nukeToxicGreen)
                                .frame(width: 6, height: 6)

                            Text("RUNNING")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.nukeToxicGreen)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.nukeToxicGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(sim.runtime)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nukeTextTertiary)
            }

            Spacer()

            // Size
            VStack(alignment: .trailing, spacing: 4) {
                Text(sim.formattedSize)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(sizeColor(sim.dataSize, threshold: 5_000_000_000))

                GeometryReader { geo in
                    let maxSize = simulators.map { $0.dataSize }.max() ?? 1
                    let ratio = CGFloat(sim.dataSize) / CGFloat(maxSize)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.nukeSurfaceHighlight)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(sizeColor(sim.dataSize, threshold: 5_000_000_000))
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
        .padding(12)
        .background(sim.isSelected ? Color.nukeNeonRed.opacity(0.05) : Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(sim.isSelected ? Color.nukeNeonRed.opacity(0.3) : Color.nukeSurfaceHighlight, lineWidth: 1)
        )
    }

    // MARK: - Git Repos View

    private var filteredRepos: [GitRepository] {
        guard !searchText.isEmpty else { return gitRepos }
        return gitRepos.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var gitReposView: some View {
        VStack(spacing: 0) {
            statsHeader(
                items: filteredRepos,
                totalSize: gitRepos.reduce(0) { $0 + $1.objectsSize },
                selectedSize: gitRepos.filter { $0.isSelected }.reduce(0) { $0 + $1.objectsSize }
            )

            Divider().overlay(Color.nukeSurfaceHighlight)

            if filteredRepos.isEmpty {
                emptyState(
                    icon: "arrow.triangle.branch",
                    title: gitRepos.isEmpty ? "No Git Repositories Found" : "No Results",
                    message: gitRepos.isEmpty ? "Scanning common developer directories" : "Try a different search term"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredRepos.enumerated()), id: \.element.id) { _, repo in
                            if let index = gitRepos.firstIndex(where: { $0.id == repo.id }) {
                                gitRepoCard(repo, index: index)
                            }
                        }
                    }
                    .padding(16)
                }

                // Git-specific actions
                HStack(spacing: 12) {
                    Button {
                        for i in gitRepos.indices { gitRepos[i].isSelected = true }
                    } label: {
                        Text("Select All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.nukeCyan)
                    }
                    .buttonStyle(.plain)

                    Button {
                        for i in gitRepos.indices { gitRepos[i].isSelected = false }
                    } label: {
                        Text("Deselect All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.nukeTextSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    let selectedCount = gitRepos.filter { $0.isSelected }.count

                    Button {
                        Task { await pruneSelectedRepos() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "scissors")
                            Text("GIT GC (\(selectedCount))")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selectedCount > 0 ? .white : Color.nukeTextTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if selectedCount > 0 {
                                Color.nukePrimaryGradient
                            } else {
                                Color.nukeSurfaceHighlight
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedCount == 0)
                }
                .padding(16)
                .background(Color.nukeSurface)
            }
        }
    }

    private func gitRepoCard(_ repo: GitRepository, index: Int) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            checkboxButton(isSelected: repo.isSelected) {
                gitRepos[index].isSelected.toggle()
            }

            // Git icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.nukeToxicGreen.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.nukeToxicGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.nukeTextPrimary)

                    if repo.canPrune {
                        Text("CAN OPTIMIZE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.nukeToxicGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.nukeToxicGreen.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(repo.path.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.custom("Menlo", size: 9))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Size
            Text(repo.formattedSize)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.nukeTextPrimary)

            // Reveal button
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([repo.path])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.nukeCyan)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(repo.isSelected ? Color.nukeNeonRed.opacity(0.05) : Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(repo.isSelected ? Color.nukeNeonRed.opacity(0.3) : Color.nukeSurfaceHighlight, lineWidth: 1)
        )
    }

    // MARK: - Shared Components

    private func statsHeader<T>(items: [T], totalSize: Int64, selectedSize: Int64) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(items.count) ITEMS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextTertiary)

                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.nukeTextPrimary)
            }

            Spacer()

            if selectedSize > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SELECTED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.nukeTextTertiary)

                    Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeNeonRed)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.nukeSurface.opacity(0.5))
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.nukeSurfaceHighlight.opacity(0.5))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(Color.nukeTextTertiary)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.nukeTextSecondary)

                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func checkboxButton(isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.nukeNeonRed : Color.nukeTextTertiary, lineWidth: 1.5)
                    .frame(width: 18, height: 18)

                if isSelected {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.nukeNeonRed)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func actionBar(
        selectedCount: Int,
        onSelectAll: @escaping () -> Void,
        onDeselectAll: @escaping () -> Void,
        onClean: @escaping () -> Void,
        actionLabel: String = "CLEAN SELECTED"
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: onSelectAll) {
                Text("Select All")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.nukeCyan)
            }
            .buttonStyle(.plain)

            Button(action: onDeselectAll) {
                Text("Deselect All")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.nukeTextSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onClean) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("\(actionLabel) (\(selectedCount))")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(selectedCount > 0 ? .white : Color.nukeTextTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if selectedCount > 0 {
                        Color.nukePrimaryGradient
                    } else {
                        Color.nukeSurfaceHighlight
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)
        }
        .padding(16)
        .background(Color.nukeSurface)
    }

    private func sizeColor(_ size: Int64, threshold: Int64 = 1_000_000_000) -> Color {
        if size > threshold {
            return .nukeNeonRed
        } else if size > threshold / 2 {
            return .nukeNeonOrange
        }
        return .nukeTextPrimary
    }

    // MARK: - Actions

    private func scanCurrentTab(force: Bool = false) async {
        switch selectedTab {
        case .packageManagers:
            guard force || packageCaches.isEmpty else { return }
            isLoadingPackages = true
            let caches = await DeveloperToolsScanner.shared.scanPackageManagerCaches()
            await MainActor.run {
                packageCaches = caches
                isLoadingPackages = false
            }

        case .simulators:
            guard force || simulators.isEmpty else { return }
            isLoadingSimulators = true
            let sims = await DeveloperToolsScanner.shared.scanSimulators()
            await MainActor.run {
                simulators = sims
                isLoadingSimulators = false
            }

        case .gitRepos:
            guard force || gitRepos.isEmpty else { return }
            isLoadingRepos = true
            scanProgress = ""

            let repos = await DeveloperToolsScanner.shared.scanGitRepositoriesFast { progress in
                Task { @MainActor in
                    scanProgress = progress
                }
            }

            await MainActor.run {
                gitRepos = repos
                isLoadingRepos = false
                scanProgress = ""
            }
        }
    }

    private func cleanSelectedCaches() {
        let fm = FileManager.default

        for cache in packageCaches where cache.isSelected {
            try? fm.removeItem(at: cache.path)
        }

        packageCaches.removeAll { $0.isSelected }
    }

    private func deleteSelectedSimulators() {
        Task {
            for sim in simulators where sim.isSelected {
                try? await DeveloperToolsScanner.shared.deleteSimulator(udid: sim.id)
            }

            await MainActor.run {
                simulators.removeAll { $0.isSelected }
            }
        }
    }

    private func pruneSelectedRepos() async {
        for repo in gitRepos where repo.isSelected {
            try? await DeveloperToolsScanner.shared.pruneGitRepository(repo)
        }

        // Rescan
        let repos = await DeveloperToolsScanner.shared.scanGitRepositoriesFast(progress: nil)
        await MainActor.run {
            gitRepos = repos
        }
    }
}

#Preview("Developer Tools") {
    DeveloperToolsView()
        .frame(width: 900, height: 600)
}
