import SwiftUI

struct DuplicateResultsView: View {
    @StateObject private var scanState = DuplicateScannerLegacy.ScanState()
    @State private var expandedGroups: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("DUPLICATE FINDER")
                        .font(.system(size: 16, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Color.nukeTextPrimary)
                    
                    Spacer()
                    
                    if scanState.isScanning {
                        Text(scanState.status)
                            .font(.caption)
                            .foregroundStyle(Color.nukeNeonOrange)
                        
                        ProgressView(value: scanState.progress)
                            .progressViewStyle(.linear)
                            .tint(Color.nukeNeonOrange)
                            .frame(width: 100)
                    } else {
                        Button("Start Scan") {
                            startScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.nukeNeonRed)
                        .disabled(scanState.isScanning)
                    }
                }
                
                if !scanState.isScanning && !scanState.foundGroups.isEmpty {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(scanState.foundGroups.count) DUPLICATE SETS")
                                .font(.caption.bold())
                                .foregroundStyle(Color.nukeTextSecondary)
                            
                            let totalWasted = scanState.foundGroups.reduce(0) { $0 + $1.totalWastedSize }
                            Text("POTENTIAL SAVINGS: \(ByteCountFormatter.string(fromByteCount: totalWasted, countStyle: .file))")
                                .font(.caption)
                                .foregroundStyle(Color.nukeToxicGreen)
                        }
                        Spacer()
                    }
                }
            }
            .padding(Theme.spacing16)
            .background(Color.nukeSurface)
            
            Divider().overlay(Color.nukeSurfaceHighlight)
            
            // List
            if scanState.foundGroups.isEmpty && !scanState.isScanning {
                VStack(spacing: 20) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.nukeTextTertiary)
                    
                    Text("Scan a folder to find duplicates")
                        .font(.title3)
                        .foregroundStyle(Color.nukeTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach($scanState.foundGroups) { $group in
                            DuplicateGroupRow(group: $group, isExpanded: expandedGroups.contains(group.id)) {
                                if expandedGroups.contains(group.id) {
                                    expandedGroups.remove(group.id)
                                } else {
                                    expandedGroups.insert(group.id)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.nukeBackground)
    }
    
    private func startScan() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "Select folders to scan for duplicates"
        
        panel.begin { response in
            if response == .OK {
                Task {
                    await DuplicateScannerLegacy.shared.scan(directories: panel.urls, progressHelper: scanState)
                }
            }
        }
    }
}

struct DuplicateGroupRow: View {
    @Binding var group: DuplicateGroup
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onToggle) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading) {
                    Text(group.files.first?.name ?? "Unknown")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(group.files.count) copies • \(group.formattedSize) each")
                        .font(.caption)
                        .foregroundStyle(Color.nukeTextSecondary)
                }
                
                Spacer()
                
                Button("Auto Select") {
                    autoSelect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color.nukeSurface)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }
            
            // Expanded items
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach($group.files) { $file in
                        HStack {
                            Toggle("", isOn: $file.isSelected)
                                .toggleStyle(.checkbox)
                            
                            Image(systemName: "doc")
                                .foregroundStyle(Color.nukeCyan)
                            
                            VStack(alignment: .leading) {
                                Text(file.path)
                                    .font(.caption)
                                    .foregroundStyle(Color.nukeTextSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                if let date = file.modificationDate {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(Color.nukeTextTertiary)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([file.url])
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.nukeBackground.opacity(0.5))
                    }
                }
                .overlay(
                    Rectangle().stroke(Color.nukeSurface, lineWidth: 1)
                )
            }
        }
        .animation(.spring(response: 0.3), value: isExpanded)
    }
    
    func autoSelect() {
        // Keep the oldest one, select others
        if let keeper = group.files.sorted(by: { ($0.modificationDate ?? .distantFuture) < ($1.modificationDate ?? .distantFuture) }).first {
            for i in group.files.indices {
                group.files[i].isSelected = (group.files[i].id != keeper.id)
            }
        }
    }
}
