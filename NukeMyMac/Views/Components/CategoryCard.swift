import SwiftUI

/// Card component for scan categories with aggressive NUKE styling
struct CategoryCard: View {
    let category: CleanCategory
    let size: Int64
    let itemCount: Int
    let isSelected: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private var sizeColor: Color {
        if size > 1_000_000_000 { // > 1GB
            return .nukeNeonRed
        } else if size > 100_000_000 { // > 100MB
            return .nukeNeonOrange
        } else {
            return .nukeToxicGreen
        }
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.nukeNeonRed : Color.nukeTextTertiary, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.nukeNeonRed)
                            .frame(width: 14, height: 14)
                            .shadow(color: .nukeNeonRed.opacity(0.8), radius: 4)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)
                
                // Category icon
                ZStack {
                    Circle()
                        .fill(Color.nukeBlack)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(sizeColor.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(sizeColor)
                        .shadow(color: sizeColor.opacity(0.5), radius: 5)
                }
                
                // Category info
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.nukeTextPrimary)
                    
                    Text("\(itemCount) TARGETS MATCHED")
                        .font(.custom("Menlo", size: 10))
                        .foregroundStyle(Color.nukeTextSecondary)
                }
                
                Spacer()
                
                // Size
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedSize)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(sizeColor)
                        .shadow(color: sizeColor.opacity(0.3), radius: 8)
                    
                    // Destructive warning
                    if category.isDestructive {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("USER DATA")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.yellow)
                    }
                }
            }
            .padding(16)
            .background(Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(isSelected ? sizeColor.opacity(0.3) : Color.nukeSurfaceHighlight, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Category Card - Dark Nuke") {
    VStack(spacing: 16) {
        CategoryCard(
            category: .xcodeDerivedData,
            size: 15_000_000_000,
            itemCount: 42,
            isSelected: true,
            onToggle: {}
        )
        
        CategoryCard(
            category: .systemCaches,
            size: 500_000_000,
            itemCount: 156,
            isSelected: false,
            onToggle: {}
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color.nukeBackground)
}
