import SwiftUI

struct MenuBarView: View {
    @ObservedObject var memoryService = MemoryService.shared
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "rays")
                    .foregroundStyle(Color.nukeNeonRed)
                Text("NUKE")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                Spacer()
                if let usage = memoryService.currentUsage {
                    Text(usage.pressureLevel.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(pressureColor(usage.pressureLevel).opacity(0.2))
                        .foregroundStyle(pressureColor(usage.pressureLevel))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.nukeDarkGray)

            Divider()

            // Memory Stats
            if let usage = memoryService.currentUsage {
                VStack(spacing: 12) {
                    // Memory bar
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("MEMORY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(usage.usedPercentage * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.3))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [pressureColor(usage.pressureLevel), pressureColor(usage.pressureLevel).opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * usage.usedPercentage)
                            }
                        }
                        .frame(height: 6)
                    }

                    // Stats grid
                    HStack(spacing: 16) {
                        StatBox(title: "USED", value: usage.formattedUsed)
                        StatBox(title: "FREE", value: usage.formattedFree)
                        StatBox(title: "TOTAL", value: usage.formattedTotal)
                    }
                }
                .padding(16)
            }

            Divider()

            // Actions
            VStack(spacing: 4) {
                Button {
                    Task {
                        await memoryService.cleanMemory()
                    }
                } label: {
                    HStack {
                        Image(systemName: memoryService.isCleaning ? "arrow.triangle.2.circlepath" : "memorychip")
                        Text(memoryService.isCleaning ? "Cleaning..." : "Clean Memory")
                        Spacer()
                        Text("⌘M")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(memoryService.isCleaning)

                Divider()
                    .padding(.horizontal, 12)

                Button {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = NSApplication.shared.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    HStack {
                        Image(systemName: "macwindow")
                        Text("Open NukeMyMac")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.horizontal, 12)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                        Spacer()
                        Text("⌘Q")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
        .frame(width: 280)
        .background(Color.nukeBlack)
    }

    private func pressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .nukeToxicGreen
        case .warning: return .nukeNeonOrange
        case .critical: return .nukeNeonRed
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
    }
}
