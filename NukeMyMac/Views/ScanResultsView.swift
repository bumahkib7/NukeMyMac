import SwiftUI

/// Scan results view - review and select items for DESTRUCTION
struct ScanResultsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var settings = SettingsViewModel.shared
    
    @State private var expandedCategories: Set<CleanCategory> = Set(CleanCategory.allCases)
    @State private var searchText: String = ""
    @State private var isNukeButtonHovered = false

    // File preview inspector
    @State private var showInspector: Bool = false
    @State private var selectedPreviewItem: ScannedItem?
    
    private var filteredItemsByCategory: [CleanCategory: [ScannedItem]] {
        guard let scanResult = appState.scanResult else { return [:] }
        
        var grouped = scanResult.itemsByCategory()
        
        // Apply search filter
        if !searchText.isEmpty {
            for (category, items) in grouped {
                grouped[category] = items.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.url.path.localizedCaseInsensitiveContains(searchText)
                }
            }
            // Remove empty categories after filtering
            grouped = grouped.filter { !$0.value.isEmpty }
        }
        
        // Sort items within each category
        for (category, items) in grouped {
            grouped[category] = settings.sortOrder.sort(items)
        }
        
        return grouped
    }
    
    private var sortedCategories: [CleanCategory] {
        filteredItemsByCategory.keys.sorted { lhs, rhs in
            let lhsSize = filteredItemsByCategory[lhs]?.reduce(0) { $0 + $1.size } ?? 0
            let rhsSize = filteredItemsByCategory[rhs]?.reduce(0) { $0 + $1.size } ?? 0
            return lhsSize > rhsSize
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            VStack(spacing: 0) {
                if appState.scanResult == nil {
                    emptyStateView
                } else if filteredItemsByCategory.isEmpty {
                    noResultsView
                } else {
                    // MARK: - Toolbar
                    resultsToolbar

                    Divider()
                        .overlay(Color.nukeSurfaceHighlight)

                    // MARK: - Results List
                    resultsList

                    Divider()
                        .overlay(Color.nukeSurfaceHighlight)

                    // MARK: - Bottom Action Bar
                    bottomActionBar
                }
            }

            // Preview sidebar (always visible when item selected)
            if showInspector {
                Divider()
                    .overlay(Color.nukeSurfaceHighlight)

                FilePreviewInspector(item: selectedPreviewItem)
                    .frame(width: 280)
            }
        }
        .background(Color.nukeBackground)
        .navigationTitle("Scan Results")
        .searchable(text: $searchText, prompt: "Search files...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Select All
                Button {
                    appState.selectAll()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .help("Select All (⌘A)")
                .keyboardShortcut("a", modifiers: .command)

                // Deselect All
                Button {
                    appState.deselectAll()
                } label: {
                    Image(systemName: "circle")
                }
                .help("Deselect All (⌘⇧D)")
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                // Preview toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInspector.toggle()
                    }
                } label: {
                    Image(systemName: showInspector ? "sidebar.right" : "sidebar.right")
                        .foregroundStyle(showInspector ? Color.nukeNeonRed : Color.nukeTextSecondary)
                }
                .help("Toggle preview (⌘I)")
                .keyboardShortcut("i", modifiers: .command)
            }
        }
        .onAppear {
            // Auto-show preview panel if there's a scan result
            if appState.scanResult != nil {
                showInspector = true
            }
        }
    }

    // MARK: - Select item for preview

    func selectItemForPreview(_ item: ScannedItem) {
        selectedPreviewItem = item
        if !showInspector {
            showInspector = true
        }
    }
    
    // MARK: - Empty State (using ContentUnavailableView)

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.nukeNeonRed.opacity(0.6))

            Text("NO TARGETS IDENTIFIED")
                .font(.system(size: 20, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)

            Text("Initialize scan sequence from the Dashboard to find files that can be cleaned.")
                .foregroundStyle(Color.nukeTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await appState.startScan()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("INITIATE SCAN")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.nukeNeonRed)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(!appState.canStartScan)
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.spacing32)
        .accessibilityLabel("No scan results. Press Command Shift S to start a scan.")
    }

    // MARK: - No Results View (after search filter)

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.nukeTextTertiary)

            Text("No Results for \"\(searchText)\"")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)

            Text("Check the spelling or try a different search term.")
                .font(.system(size: 13))
                .foregroundStyle(Color.nukeTextSecondary)

            Button("Reset Search") {
                searchText = ""
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results Toolbar
    
    private var resultsToolbar: some View {
        HStack(spacing: Theme.spacing16) {
            // Selection info
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.nukeToxicGreen)
                Text("\(appState.selectedItemsCount) TARGETS SELECTED")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.white)
            }
            
            Spacer()
            
            // Selection buttons
            Button("Select All") {
                appState.selectAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut("a", modifiers: .command)
            .accessibilityLabel("Select all items")

            Button("Deselect All") {
                appState.deselectAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .accessibilityLabel("Deselect all items")
            
            Divider()
                .frame(height: 20)
                .overlay(Color.nukeSurfaceHighlight)
            
            // Sort picker
            Picker("Sort", selection: $settings.sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .controlSize(.small)
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
        .background(Color.nukeSurface.opacity(0.8))
    }
    
    // MARK: - Results List
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing16, pinnedViews: [.sectionHeaders]) {
                ForEach(sortedCategories, id: \.self) { category in
                    if let items = filteredItemsByCategory[category], !items.isEmpty {
                        categorySection(category: category, items: items)
                    }
                }
            }
            .padding(Theme.spacing16)
        }
    }
    
    // MARK: - Category Section
    
    private func categorySection(category: CleanCategory, items: [ScannedItem]) -> some View {
        let isExpanded = expandedCategories.contains(category)
        let categorySize = items.reduce(0) { $0 + $1.size }
        let selectedCount = items.filter { $0.isSelected }.count
        let allSelected = items.allSatisfy { $0.isSelected }
        
        return VStack(spacing: 0) {
            // Category Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack(spacing: Theme.spacing12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .frame(width: 16)
                    
                    CategoryCard(
                        category: category,
                        size: categorySize,
                        itemCount: items.count,
                        isSelected: allSelected,
                        onToggle: {
                            appState.toggleCategory(category)
                        }
                    )
                }
            }
            .buttonStyle(.plain)
            
            // Expanded items
            if isExpanded {
                VStack(spacing: 1) { // 1px spacing for sleek look
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        FileRowWrapper(
                            item: item,
                            appState: appState,
                            onPreview: { selectItemForPreview(item) }
                        )
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .padding(.leading, 28) // Indent items
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack(spacing: Theme.spacing16) {
            // Summary
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.nukeNeonRed)
                        .frame(width: 8, height: 8)
                        .shadow(color: .nukeNeonRed, radius: 5)
                    
                    Text("PAYLOAD SIZE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.nukeTextSecondary)
                }
                
                Text(appState.formattedSelectedSize)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.nukeNeonRed)
                    .shadow(color: .nukeNeonRed.opacity(0.4), radius: 10)
                    .animation(.easeInOut, value: appState.selectedItemsCount)
            }
            
            Spacer()
            
            // Keyboard shortcuts hints
            VStack(alignment: .leading, spacing: 4) {
                shortcutHint("⌘A", "Select All")
                shortcutHint("⌘⇧D", "Deselect")
                shortcutHint("⌘⌫", "Delete")
                shortcutHint("⌘I", "Preview")
            }
            .padding(12)
            .background(Color.nukeSurface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Warning if destructive categories selected
            if appState.scanResult?.selectedItems.contains(where: { $0.category.isDestructive }) == true {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("USER DATA INCLUDED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
            }
            
            // NUKE button
            Button {
                Task {
                    await appState.cleanSelected()
                }
            } label: {
                HStack(spacing: 12) {
                    if isNukeButtonHovered {
                        Image(systemName: "flame.fill")
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "trash.fill")
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Text("NUKE SELECTED")
                        .font(.system(size: 16, weight: .black))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 48)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: appState.canClean ? [Color.nukeNeonRed, Color(red: 0.8, green: 0.1, blue: 0.0)] : [Color.nukeSurface, Color.nukeSurface],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: appState.canClean ? .nukeNeonRed.opacity(isNukeButtonHovered ? 0.6 : 0.3) : .clear, radius: isNukeButtonHovered ? 15 : 8, x: 0, y: 4)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                // Add Shimmer Effect when enabled!
                .opacity(appState.canClean ? 1 : 0.5)
                .overlay(
                    // Conditional overlay modifier isn't native, so we use logic here
                    Group {
                        if appState.canClean {
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .fill(Color.clear) // Placeholder for shape
                                .nukeShimmer(duration: 2.0)
                                .allowsHitTesting(false)
                        }
                    }
                )
                .scaleEffect(isNukeButtonHovered && appState.canClean ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(!appState.canClean)
            .keyboardShortcut(.delete, modifiers: .command)
            .accessibilityLabel("Delete \(appState.selectedItemsCount) selected items, \(appState.formattedSelectedSize)")
            .accessibilityHint("Double-tap to permanently delete selected files")
            .onHover { hovering in
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isNukeButtonHovered = hovering
                    }
                }
            }
        }
        .padding(.horizontal, Theme.spacing24)
        .padding(.vertical, Theme.spacing24)
        .background(Color.nukeDarkGray)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.nukeSurfaceHighlight)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Action bar")
    }

    private func shortcutHint(_ shortcut: String, _ action: String) -> some View {
        HStack(spacing: 6) {
            Text(shortcut)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.nukeNeonOrange)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.nukeSurfaceHighlight)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(action)
                .font(.system(size: 9))
                .foregroundStyle(Color.nukeTextTertiary)
        }
    }
}

// MARK: - File Row Wrapper

struct FileRowWrapper: View {
    let item: ScannedItem
    let appState: AppState
    var onPreview: (() -> Void)? = nil

    @State private var isSelected: Bool

    init(item: ScannedItem, appState: AppState, onPreview: (() -> Void)? = nil) {
        self.item = item
        self.appState = appState
        self.onPreview = onPreview
        self._isSelected = State(initialValue: item.isSelected)
    }

    var body: some View {
        FileRow(
            item: item,
            isSelected: $isSelected,
            onToggle: {
                appState.toggleItem(item)
                isSelected.toggle()
            },
            onPreview: onPreview
        )
        .onChange(of: item.isSelected) { newValue in
            isSelected = newValue
        }
    }
}

// MARK: - Inspector Modifier (macOS 14+ only)

struct InspectorModifier: ViewModifier {
    @Binding var isPresented: Bool
    let item: ScannedItem?

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .inspector(isPresented: $isPresented) {
                    FilePreviewInspector(item: item)
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
                }
        } else {
            // Fallback for macOS 13: use sheet instead
            content
                .sheet(isPresented: $isPresented) {
                    FilePreviewInspector(item: item)
                        .frame(width: 300, height: 500)
                }
        }
    }
}

// MARK: - File Preview Inspector

struct FilePreviewInspector: View {
    let item: ScannedItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(Color.nukeNeonRed)
                Text("FILE PREVIEW")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.nukeSurface)

            Divider().overlay(Color.nukeSurfaceHighlight)

            if let item = item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // File icon and name
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: item.category.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(Color.nukeNeonRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.nukeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(item.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }

                        Divider().overlay(Color.nukeSurfaceHighlight)

                        // File details
                        VStack(alignment: .leading, spacing: 12) {
                            previewRow(label: "SIZE", value: item.formattedSize, color: .nukeNeonOrange)
                            previewRow(label: "CATEGORY", value: item.category.rawValue, color: .nukeCyan)
                            previewRow(label: "TYPE", value: item.url.pathExtension.uppercased().isEmpty ? "FOLDER" : item.url.pathExtension.uppercased(), color: .nukeToxicGreen)

                            if let modDate = item.modificationDate {
                                previewRow(label: "MODIFIED", value: modDate.formatted(date: .abbreviated, time: .shortened), color: .nukeTextSecondary)
                            }
                        }

                        Divider().overlay(Color.nukeSurfaceHighlight)

                        // Full path
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FULL PATH")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.nukeTextTertiary)

                            Text(item.url.path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.nukeTextSecondary)
                                .textSelection(.enabled)
                        }

                        // Actions
                        VStack(spacing: 8) {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("Show in Finder")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.nukeSurface)
                                .foregroundStyle(Color.nukeCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.nukeCyan.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Show \(item.name) in Finder")

                            if item.category.isDestructive {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text("This file may contain user data")
                                        .font(.caption)
                                }
                                .foregroundStyle(.yellow)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.yellow.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
            } else {
                // No item selected
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.nukeTextTertiary)

                    Text("Select a file to preview")
                        .font(.caption)
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.nukeBackground)
    }

    private func previewRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.nukeTextTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Preview

#Preview("Scan Results - Dark Nuke") {
    ScanResultsView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
