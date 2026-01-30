import SwiftUI

/// Row component for individual scanned files with aggressive NUKE styling
struct FileRow: View {
    let item: ScannedItem
    @Binding var isSelected: Bool
    let onToggle: () -> Void
    var onPreview: (() -> Void)? = nil

    @State private var isHovered = false
    
    private var sizeColor: Color {
        if item.size > 500_000_000 { // > 500MB
            return .nukeNeonRed
        } else if item.size > 100_000_000 { // > 100MB
            return .nukeNeonOrange
        } else {
            return .nukeTextPrimary
        }
    }
    
    private var fileIcon: String {
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "app": return "app.fill"
        case "dmg": return "opticaldisc.fill"
        case "zip", "tar", "gz", "rar": return "doc.zipper"
        case "log": return "doc.text.fill"
        case "plist": return "doc.badge.gearshape.fill"
        default: return "doc.fill"
        }
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSelected ? Color.nukeNeonRed : Color.nukeTextTertiary, lineWidth: 1)
                        .frame(width: 14, height: 14)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.nukeNeonRed)
                            .frame(width: 10, height: 10)
                    }
                }
                .animation(.easeInOut(duration: 0.1), value: isSelected)
                
                // File icon
                Image(systemName: fileIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.nukeTextSecondary)
                    .frame(width: 20)
                
                // File info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.custom("Menlo", size: 12))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.nukeTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text(item.url.deletingLastPathComponent().path)
                        .font(.custom("Menlo", size: 9))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                
                Spacer()
                
                // Modification date
                if let date = item.modificationDate {
                    Text(date, style: .date)
                        .font(.custom("Menlo", size: 9))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .padding(.horizontal, 8)
                }
                
                // Size badge
                Text(item.formattedSize)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(sizeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(sizeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Quick action: Preview
                if let onPreview = onPreview {
                    Button {
                        onPreview()
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(isHovered ? Color.nukeCyan : Color.nukeTextTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Preview file (⌘I)")
                    .frame(width: 20)
                }

                // Quick action: Reveal in Finder
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? Color.nukeNeonOrange : Color.nukeTextTertiary)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
                .frame(width: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.nukeSurfaceHighlight : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            DispatchQueue.main.async {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

struct FileRowPreviewWrapper: View {
    @State private var selections: [Bool] = [true, false, true]
    
    var body: some View {
        VStack(spacing: 0) {
            FileRow(
                item: ScannedItem(
                    url: URL(fileURLWithPath: "/Users/dev/Library/Developer/Xcode/DerivedData/MyApp-abc123"),
                    size: 2_500_000_000,
                    category: .xcodeDerivedData,
                    modificationDate: Date().addingTimeInterval(-86400 * 7)
                ),
                isSelected: $selections[0],
                onToggle: { selections[0].toggle() }
            )
            
            FileRow(
                item: ScannedItem(
                    url: URL(fileURLWithPath: "/Users/dev/Library/Caches/com.apple.Safari"),
                    size: 150_000_000,
                    category: .systemCaches,
                    modificationDate: Date().addingTimeInterval(-86400 * 2)
                ),
                isSelected: $selections[1],
                onToggle: { selections[1].toggle() }
            )
        }
        .padding()
        .frame(width: 600)
        .background(Color.nukeBackground)
    }
}

#Preview("File Rows - Dark Nuke") {
    FileRowPreviewWrapper()
}
