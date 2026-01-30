import SwiftUI

/// Duplicate file finder with side-by-side comparison
struct DuplicateFinderView: View {
    @State private var duplicateGroups: [DuplicateGroup] = []
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var statusMessage = ""
    @State private var selectedGroup: DuplicateGroup?
    @State private var showingDeleteConfirmation = false

    // Stats
    private var totalWastedSpace: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
    }

    private var selectedForDeletion: Int64 {
        var total: Int64 = 0
        for group in duplicateGroups {
            for file in group.files where file.isSelected {
                total += group.size
            }
        }
        return total
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            if isScanning {
                scanningView
            } else if duplicateGroups.isEmpty {
                emptyStateView
            } else {
                // Main content
                HStack(spacing: 0) {
                    // Groups list
                    groupsListView
                        .frame(width: 350)

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // Comparison view
                    comparisonView
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.nukeBackground)
        .confirmationDialog("Delete Selected Duplicates", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedDuplicates()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the selected duplicate files.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DUPLICATE FINDER")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextPrimary)

                if !duplicateGroups.isEmpty {
                    Text("\(duplicateGroups.count) groups • \(ByteCountFormatter.string(fromByteCount: totalWastedSpace, countStyle: .file)) wasted")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nukeTextSecondary)
                }
            }

            Spacer()

            // Action buttons
            if !duplicateGroups.isEmpty {
                Button {
                    autoSelectDuplicates()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                        Text("Auto-Select")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.nukeCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.nukeCyan.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Select all duplicates, keeping the oldest file")

                Button {
                    showingDeleteConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Delete Selected")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.nukeNeonRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.nukeNeonRed.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(selectedForDeletion == 0)
            }

            Button {
                Task { await startScan() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                    Text("SCAN")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.nukeNeonOrange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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

    // MARK: - Groups List

    private var groupsListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(Array(duplicateGroups.enumerated()), id: \.element.id) { index, group in
                    groupRow(group, index: index)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.nukeSurface)
    }

    private func groupRow(_ group: DuplicateGroup, index: Int) -> some View {
        let isSelected = selectedGroup?.id == group.id

        return Button {
            selectedGroup = group
        } label: {
            HStack(spacing: 12) {
                // Index badge
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.nukeNeonRed : Color.nukeTextTertiary)
                    .frame(width: 24)

                // File icon
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.nukeNeonRed : Color.nukeTextSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(group.files.count) copies")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.nukeTextPrimary : Color.nukeTextSecondary)

                    Text(group.files.first?.name ?? "")
                        .font(.custom("Menlo", size: 10))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Size and wasted
                VStack(alignment: .trailing, spacing: 2) {
                    Text(group.formattedSize)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeTextPrimary)

                    Text("-\(group.formattedWastedSpace)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.nukeNeonRed)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.nukeSurfaceHighlight : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comparison View

    private var comparisonView: some View {
        Group {
            if let group = selectedGroup {
                VStack(spacing: 0) {
                    // Group header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("COMPARING \(group.files.count) FILES")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Color.nukeTextTertiary)

                            Text(group.files.first?.name ?? "")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.nukeTextPrimary)
                        }

                        Spacer()

                        Text("Each file: \(group.formattedSize)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.nukeNeonOrange)
                    }
                    .padding(16)
                    .background(Color.nukeSurface)

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // Files comparison
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(group.files.enumerated()), id: \.element.id) { fileIndex, file in
                                fileComparisonCard(file, groupIndex: duplicateGroups.firstIndex(where: { $0.id == group.id }) ?? 0, fileIndex: fileIndex)
                            }
                        }
                        .padding(16)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.nukeTextTertiary)

                    Text("Select a duplicate group to compare files")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.nukeTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func fileComparisonCard(_ file: DuplicateFile, groupIndex: Int, fileIndex: Int) -> some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button {
                toggleFileSelection(groupIndex: groupIndex, fileIndex: fileIndex)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(file.isSelected ? Color.nukeNeonRed : Color.nukeTextTertiary, lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if file.isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.nukeNeonRed)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(file.isOriginal)

            // Original badge
            if file.isOriginal {
                Text("ORIGINAL")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeToxicGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.nukeToxicGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(file.isSelected ? Color.nukeNeonRed.opacity(0.7) : Color.nukeTextPrimary)
                    .strikethrough(file.isSelected)

                Text(file.path)
                    .font(.custom("Menlo", size: 9))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Date
            if let date = file.modificationDate {
                Text(date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nukeTextTertiary)
            }

            // Actions
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.nukeCyan)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(12)
        .background(file.isSelected ? Color.nukeNeonRed.opacity(0.05) : Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(file.isSelected ? Color.nukeNeonRed.opacity(0.3) : Color.nukeSurfaceHighlight, lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundStyle(Color.nukeTextTertiary)

            Text("Find Duplicate Files")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.nukeTextPrimary)

            Text("Scan your system to find duplicate files\nand free up wasted disk space.")
                .font(.system(size: 13))
                .foregroundStyle(Color.nukeTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await startScan() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("FIND DUPLICATES")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.nukePrimaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 20) {
            ReactorLoader(size: 80, color: .nukeNeonOrange)

            Text(statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.nukeTextSecondary)

            ProgressView(value: scanProgress)
                .progressViewStyle(.linear)
                .tint(Color.nukeNeonOrange)
                .frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func startScan() async {
        isScanning = true
        scanProgress = 0
        statusMessage = "Starting scan..."

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let groups = await DuplicateScanner.shared.scanForDuplicates(
            in: [homeDir],
            minSize: 1024 * 1024 // 1MB minimum
        ) { progress, message in
            Task { @MainActor in
                self.scanProgress = progress
                self.statusMessage = message
            }
        }

        await MainActor.run {
            duplicateGroups = groups
            selectedGroup = groups.first
            isScanning = false
        }
    }

    private func toggleFileSelection(groupIndex: Int, fileIndex: Int) {
        guard groupIndex < duplicateGroups.count,
              fileIndex < duplicateGroups[groupIndex].files.count else { return }

        duplicateGroups[groupIndex].files[fileIndex].isSelected.toggle()

        // Update selected group if viewing it
        if selectedGroup?.id == duplicateGroups[groupIndex].id {
            selectedGroup = duplicateGroups[groupIndex]
        }
    }

    private func autoSelectDuplicates() {
        for i in duplicateGroups.indices {
            for j in duplicateGroups[i].files.indices {
                // Select all except the original (oldest)
                duplicateGroups[i].files[j].isSelected = !duplicateGroups[i].files[j].isOriginal
            }
        }

        // Refresh selected group
        if let current = selectedGroup,
           let index = duplicateGroups.firstIndex(where: { $0.id == current.id }) {
            selectedGroup = duplicateGroups[index]
        }
    }

    private func deleteSelectedDuplicates() {
        let fm = FileManager.default

        for i in duplicateGroups.indices {
            duplicateGroups[i].files.removeAll { file in
                if file.isSelected {
                    try? fm.removeItem(at: file.url)
                    return true
                }
                return false
            }
        }

        // Remove empty groups
        duplicateGroups.removeAll { $0.files.count <= 1 }

        // Update selection
        if let current = selectedGroup {
            if !duplicateGroups.contains(where: { $0.id == current.id }) {
                selectedGroup = duplicateGroups.first
            }
        }
    }
}

#Preview("Duplicate Finder") {
    DuplicateFinderView()
        .frame(width: 900, height: 600)
}
