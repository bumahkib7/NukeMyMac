import SwiftUI

/// Central hub for all advanced features
struct FeaturesHubView: View {
    @State private var selectedFeature: FeatureCategory?

    var body: some View {
        if let feature = selectedFeature {
            // Show selected feature view
            featureView(for: feature)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFeature = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Features")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.nukeNeonOrange)
                        }
                        .buttonStyle(.plain)
                    }
                }
        } else {
            // Show features grid
            featuresGridView
        }
    }

    // MARK: - Features Grid

    private var featuresGridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADVANCED TOOLS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.nukeTextTertiary)

                    Text("Power Tools for Your Mac")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.nukeTextPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Feature sections
                ForEach(FeatureSection.allSections) { section in
                    featureSectionView(section)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.nukeBackground)
    }

    private func featureSectionView(_ section: FeatureSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(section.color)

                Text(section.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextSecondary)
            }
            .padding(.horizontal, 24)

            // Feature cards grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(section.features) { feature in
                    featureCard(feature)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func featureCard(_ feature: FeatureCategory) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFeature = feature
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(feature.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: feature.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(feature.color)
                }

                // Title and description
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.nukeTextPrimary)

                    Text(feature.description)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nukeTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Arrow indicator
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(feature.color)
                }
            }
            .padding(16)
            .frame(height: 160)
            .background(Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.nukeSurfaceHighlight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            DispatchQueue.main.async {
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }

    // MARK: - Feature View Router

    @ViewBuilder
    private func featureView(for feature: FeatureCategory) -> some View {
        switch feature {
        case .spaceTreemap:
            SpaceTreemapView()
        case .duplicateFinder:
            DuplicateFinderView()
        case .appUninstaller:
            AppUninstallerView()
        case .startupManager:
            StartupManagerView()
        case .browserManager:
            BrowserManagerView()
        case .systemMaintenance:
            SystemMaintenanceView()
        case .developerTools:
            DeveloperToolsView()
        case .scheduledScans:
            ScheduledScansView()
        case .whitelist:
            WhitelistView()
        }
    }
}

// MARK: - Feature Models

enum FeatureCategory: String, Identifiable, CaseIterable {
    case spaceTreemap
    case duplicateFinder
    case appUninstaller
    case startupManager
    case browserManager
    case systemMaintenance
    case developerTools
    case scheduledScans
    case whitelist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spaceTreemap: return "Space Treemap"
        case .duplicateFinder: return "Duplicate Finder"
        case .appUninstaller: return "App Uninstaller"
        case .startupManager: return "Startup Manager"
        case .browserManager: return "Browser Manager"
        case .systemMaintenance: return "System Maintenance"
        case .developerTools: return "Developer Tools"
        case .scheduledScans: return "Scheduled Scans"
        case .whitelist: return "Whitelist"
        }
    }

    var description: String {
        switch self {
        case .spaceTreemap: return "Visualize disk usage with an interactive treemap"
        case .duplicateFinder: return "Find and remove duplicate files"
        case .appUninstaller: return "Completely remove apps and leftovers"
        case .startupManager: return "Control login items and launch agents"
        case .browserManager: return "Clear browser caches and data"
        case .systemMaintenance: return "Run system maintenance tasks"
        case .developerTools: return "Clean dev caches and simulators"
        case .scheduledScans: return "Automate scans and cleanup"
        case .whitelist: return "Protect files from cleanup"
        }
    }

    var icon: String {
        switch self {
        case .spaceTreemap: return "square.grid.3x3.topleft.filled"
        case .duplicateFinder: return "doc.on.doc.fill"
        case .appUninstaller: return "app.badge.checkmark"
        case .startupManager: return "power.circle.fill"
        case .browserManager: return "globe"
        case .systemMaintenance: return "gearshape.2.fill"
        case .developerTools: return "hammer.fill"
        case .scheduledScans: return "clock.badge.checkmark.fill"
        case .whitelist: return "shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .spaceTreemap: return .nukeCyan
        case .duplicateFinder: return .nukeNeonOrange
        case .appUninstaller: return .nukeNeonRed
        case .startupManager: return .nukeToxicGreen
        case .browserManager: return .nukeBlue
        case .systemMaintenance: return .nukeNeonOrange
        case .developerTools: return .nukeCyan
        case .scheduledScans: return .nukeToxicGreen
        case .whitelist: return .nukeToxicGreen
        }
    }
}

struct FeatureSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let features: [FeatureCategory]

    static var allSections: [FeatureSection] {
        [
            FeatureSection(
                title: "Disk Analysis",
                icon: "chart.pie.fill",
                color: .nukeCyan,
                features: [.spaceTreemap, .duplicateFinder]
            ),
            FeatureSection(
                title: "App & System Cleanup",
                icon: "trash.fill",
                color: .nukeNeonRed,
                features: [.appUninstaller, .startupManager, .browserManager]
            ),
            FeatureSection(
                title: "System Tools",
                icon: "gearshape.fill",
                color: .nukeNeonOrange,
                features: [.systemMaintenance, .developerTools]
            ),
            FeatureSection(
                title: "Automation",
                icon: "clock.fill",
                color: .nukeToxicGreen,
                features: [.scheduledScans, .whitelist]
            )
        ]
    }
}

#Preview("Features Hub") {
    FeaturesHubView()
        .frame(width: 900, height: 700)
}
