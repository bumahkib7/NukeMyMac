import SwiftUI

/// Visual storage bar showing used vs free space with aggressive NUKE styling
struct StorageBar: View {
    let usedPercentage: Double
    let usedSpace: String
    let freeSpace: String

    @State private var animatedPercentage: Double = 0

    private var usedGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.red,
                Color.orange,
                Color.red.opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var freeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.5)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "internaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                Text("STORAGE STATUS")
                    .font(.headline)
                    .fontWeight(.black)
                    .tracking(2)

                Spacer()

                Text("\(Int(usedPercentage))% USED")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(usedPercentage > 80 ? .red : .orange)
            }

            // Storage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background (free space)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(freeGradient)
                        .frame(height: 32)

                    // Used space bar
                    RoundedRectangle(cornerRadius: 8)
                        .fill(usedGradient)
                        .frame(width: max(0, geometry.size.width * animatedPercentage / 100), height: 32)
                        .shadow(color: .red.opacity(0.5), radius: 4, x: 0, y: 2)

                    // Danger zone indicator
                    if usedPercentage > 80 {
                        HStack {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                                .padding(.trailing, 8)
                        }
                    }
                }
            }
            .frame(height: 32)

            // Labels
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(usedGradient)
                        .frame(width: 10, height: 10)
                    Text("Used: \(usedSpace)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(freeGradient)
                        .frame(width: 10, height: 10)
                    Text("Free: \(freeSpace)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedPercentage = usedPercentage
            }
        }
        .onChange(of: usedPercentage) { newValue in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.5)) {
                    animatedPercentage = newValue
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Storage Bar - Normal") {
    StorageBar(
        usedPercentage: 65,
        usedSpace: "325 GB",
        freeSpace: "175 GB"
    )
    .padding()
    .frame(width: 400)
}

#Preview("Storage Bar - Critical") {
    StorageBar(
        usedPercentage: 92,
        usedSpace: "460 GB",
        freeSpace: "40 GB"
    )
    .padding()
    .frame(width: 400)
}
