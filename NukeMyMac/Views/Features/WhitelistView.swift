import SwiftUI

/// Whitelist/Exclusions manager - protect files from cleanup
struct WhitelistView: View {
    @State private var entries: [WhitelistEntry] = []
    @State private var showingAddSheet = false
    @State private var newEntryPath = ""
    @State private var newEntryReason = ""
    @State private var searchText = ""

    private var filteredEntries: [WhitelistEntry] {
        if searchText.isEmpty {
            return entries
        }
        return entries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            if entries.isEmpty {
                emptyStateView
            } else {
                // Search bar
                searchBar

                // Entries list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredEntries) { entry in
                            entryRow(entry)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.nukeBackground)
        .onAppear {
            loadEntries()
        }
        .sheet(isPresented: $showingAddSheet) {
            addEntrySheet
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WHITELIST")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("\(entries.count) protected paths")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            Spacer()

            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("ADD PATH")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.nukeToxicGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.nukeToxicGreen.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.nukeSurface)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.nukeTextTertiary)

            TextField("Search whitelist...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.nukeSurfaceHighlight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: WhitelistEntry) -> some View {
        HStack(spacing: 12) {
            // Shield icon
            Image(systemName: "shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.nukeToxicGreen)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.nukeTextPrimary)

                Text(entry.path)
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .lineLimit(1)

                if let reason = entry.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.nukeCyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.nukeCyan.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            Spacer()

            // Date added
            VStack(alignment: .trailing, spacing: 2) {
                Text("Added")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.nukeTextTertiary)

                Text(entry.dateAdded, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            // Actions
            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.nukeCyan)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button {
                    removeEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.nukeNeonRed)
                }
                .buttonStyle(.plain)
                .help("Remove from whitelist")
            }
        }
        .padding(12)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.nukeToxicGreen.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48))
                .foregroundStyle(Color.nukeTextTertiary)

            Text("Whitelist")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.nukeTextPrimary)

            Text("Add files and folders to protect them\nfrom being cleaned during scans.")
                .font(.system(size: 13))
                .foregroundStyle(Color.nukeTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("ADD FIRST PATH")
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

    // MARK: - Add Entry Sheet

    private var addEntrySheet: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add to Whitelist")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.nukeTextPrimary)

                Spacer()

                Button {
                    showingAddSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Color.nukeSurfaceHighlight)

            // Path input
            VStack(alignment: .leading, spacing: 8) {
                Text("PATH")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextTertiary)

                HStack {
                    TextField("Enter path or drag file here...", text: $newEntryPath)
                        .textFieldStyle(.plain)
                        .font(.custom("Menlo", size: 12))
                        .padding(10)
                        .background(Color.nukeSurfaceHighlight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button {
                        selectPath()
                    } label: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.nukeCyan)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Reason input
            VStack(alignment: .leading, spacing: 8) {
                Text("REASON (OPTIONAL)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextTertiary)

                TextField("Why is this protected?", text: $newEntryReason)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(10)
                    .background(Color.nukeSurfaceHighlight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button {
                    showingAddSheet = false
                    newEntryPath = ""
                    newEntryReason = ""
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.nukeTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.nukeSurfaceHighlight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    addEntry()
                } label: {
                    HStack {
                        Image(systemName: "shield.fill")
                        Text("Protect")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.nukeToxicGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(newEntryPath.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 450, height: 350)
        .background(Color.nukeSurface)
    }

    // MARK: - Actions

    private func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: "whitelist_entries"),
           let decoded = try? JSONDecoder().decode([WhitelistEntry].self, from: data) {
            entries = decoded
        }
    }

    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "whitelist_entries")
        }
    }

    private func addEntry() {
        let url = URL(fileURLWithPath: newEntryPath)
        let entry = WhitelistEntry(
            path: newEntryPath,
            name: url.lastPathComponent,
            reason: newEntryReason.isEmpty ? nil : newEntryReason
        )

        entries.append(entry)
        saveEntries()

        newEntryPath = ""
        newEntryReason = ""
        showingAddSheet = false
    }

    private func removeEntry(_ entry: WhitelistEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    private func selectPath() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            newEntryPath = url.path
        }
    }
}

#Preview("Whitelist") {
    WhitelistView()
        .frame(width: 700, height: 500)
}
