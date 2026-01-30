import SwiftUI

/// Settings view - configure NUKE preferences
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var settings = SettingsViewModel.shared
    
    @State private var permissionStatus: PermissionStatus = .unknown
    @State private var isCheckingPermissions = false
    @State private var isAnimated = false
    
    enum PermissionStatus {
        case unknown
        case granted
        case denied
    }
    
    var body: some View {
        ZStack {
            // Animated Background
            AnimatedMeshBackground()
                .opacity(0.6) // Slightly subtler than Dashboard
            
            ScrollView {
                VStack(spacing: Theme.spacing32) {
                    // MARK: - Scan Categories Section
                    categoriesSection
                        .offset(y: isAnimated ? 0 : 50)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAnimated)
                    
                    // MARK: - Behavior Settings Section
                    behaviorSection
                        .offset(y: isAnimated ? 0 : 50)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimated)
                    
                    // MARK: - Permissions Section
                    permissionsSection
                        .offset(y: isAnimated ? 0 : 50)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: isAnimated)
                    
                    // MARK: - App Info Section
                    appInfoSection
                        .offset(y: isAnimated ? 0 : 50)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: isAnimated)
                    
                    Spacer(minLength: Theme.spacing32)
                }
                .padding(Theme.spacing32)
            }
        }
        .background(Color.nukeBackground)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reset to Defaults") {
                    withAnimation {
                        settings.resetToDefaults()
                    }
                }
                .foregroundStyle(Color.nukeNeonRed)
            }
        }
        .task {
            await checkPermissions()
            isAnimated = true
        }
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        SettingsSection(
            title: "SCAN CATEGORIES",
            subtitle: "Select which categories to include when scanning",
            icon: "folder.badge.gearshape"
        ) {
            VStack(spacing: 0) {
                ForEach(CleanCategory.allCases) { category in
                    categoryToggleRow(category)
                    
                    if category != CleanCategory.allCases.last {
                        Divider()
                            .overlay(Color.nukeSurfaceHighlight)
                    }
                }
            }
            .glassCardStyle()
            
            // Quick selection buttons
            HStack(spacing: Theme.spacing12) {
                GlitchButton(title: "Select All", action: { settings.selectAllCategories() })
                GlitchButton(title: "Select Safe Only", action: { settings.selectSafeCategories() })
                GlitchButton(title: "Deselect All", action: { settings.deselectAllCategories() })
            }
            .padding(.top, Theme.spacing8)
        }
    }
    
    private func categoryToggleRow(_ category: CleanCategory) -> some View {
        StartScanToggle(isOn: settings.binding(for: category)) {
            HStack(spacing: Theme.spacing12) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(settings.isCategorySelected(category) ? Color.nukeNeonRed : Color.nukeTextTertiary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(category.rawValue)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.nukeTextPrimary)
                        
                        if category.isDestructive {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("CAUTION")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(Color.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(Color.nukeTextTertiary)
                }
            }
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
    }
    
    // MARK: - Behavior Section
    
    private var behaviorSection: some View {
        SettingsSection(
            title: "BEHAVIOR",
            subtitle: "Configure how NUKE operates",
            icon: "gearshape.2.fill"
        ) {
            VStack(spacing: 0) {
                settingsToggle(
                    title: "Confirm Before Delete",
                    subtitle: "Show confirmation dialog before deleting files",
                    icon: "exclamationmark.bubble.fill",
                    isOn: $settings.confirmBeforeDelete
                )
                
                Divider().overlay(Color.nukeSurfaceHighlight)
                
                settingsToggle(
                    title: "Skip Hidden Files",
                    subtitle: "Ignore files starting with a dot (.)",
                    icon: "eye.slash.fill",
                    isOn: $settings.skipHiddenFiles
                )
                
                Divider().overlay(Color.nukeSurfaceHighlight)
                
                settingsToggle(
                    title: "Show Destructive Warnings",
                    subtitle: "Highlight potentially risky categories",
                    icon: "exclamationmark.triangle.fill",
                    isOn: $settings.showDestructiveWarnings
                )
                
                Divider().overlay(Color.nukeSurfaceHighlight)
                
                settingsToggle(
                    title: "Auto-Refresh Disk Usage",
                    subtitle: "Update disk stats after operations",
                    icon: "arrow.clockwise",
                    isOn: $settings.autoRefreshDiskUsage
                )
                
                Divider().overlay(Color.nukeSurfaceHighlight)
                
                settingsToggle(
                    title: "Group by Category",
                    subtitle: "Organize results by file category",
                    icon: "rectangle.3.group.fill",
                    isOn: $settings.groupByCategory
                )

                Divider().overlay(Color.nukeSurfaceHighlight)

                settingsToggle(
                    title: "Remember Delete Choice",
                    subtitle: "Don't ask for confirmation again",
                    icon: "checkmark.seal.fill",
                    isOn: $settings.suppressDeleteConfirmation
                )

                Divider().overlay(Color.nukeSurfaceHighlight)

                settingsToggle(
                    title: "Reduce Animations",
                    subtitle: "Minimize motion effects for accessibility",
                    icon: "figure.walk.motion",
                    isOn: $settings.reduceAnimations
                )
            }
            .glassCardStyle()
            
            // Old downloads threshold
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.nukeNeonOrange)
                    Text("Old Downloads Threshold")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nukeTextPrimary)
                    
                    Spacer()
                    
                    Text("\(settings.oldDownloadsDays) days")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.nukeNeonRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.nukeNeonRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                Slider(value: Binding(
                    get: { Double(settings.oldDownloadsDays) },
                    set: { settings.oldDownloadsDays = Int($0) }
                ), in: 7...90, step: 1)
                .tint(Color.nukeNeonRed)
                .padding(.vertical, 8)
                
                Text("Files in Downloads older than this will be flagged for cleaning")
                    .font(.caption)
                    .foregroundStyle(Color.nukeTextTertiary)
            }
            .padding(Theme.spacing16)
            .glassCardStyle()
        }
    }
    
    private func settingsToggle(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        StartScanToggle(isOn: isOn) {
            HStack(spacing: Theme.spacing12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isOn.wrappedValue ? Color.nukeNeonRed : Color.nukeTextTertiary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nukeTextPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.nukeTextTertiary)
                }
            }
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing12)
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        SettingsSection(
            title: "PERMISSIONS",
            subtitle: "System access required for full functionality",
            icon: "lock.shield.fill"
        ) {
            VStack(spacing: Theme.spacing12) {
                // Full Disk Access status
                HStack(spacing: Theme.spacing12) {
                    Image(systemName: permissionStatusIcon)
                        .font(.title2)
                        .foregroundStyle(permissionStatusColor)
                        .frame(width: 32)
                        .shadow(color: permissionStatusColor.opacity(0.5), radius: 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full Disk Access")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.nukeTextPrimary)
                        
                        Text(permissionStatusText)
                            .font(.caption)
                            .foregroundStyle(Color.nukeTextSecondary)
                    }
                    
                    Spacer()
                    
                    if isCheckingPermissions {
                        NukeSpinner(size: 16, color: .nukeNeonOrange)
                    } else {
                        Button("Check Permissions") {
                            Task {
                                await checkPermissions()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(Theme.spacing16)
                .glassCardStyle()
                
                // Open System Preferences button
                if permissionStatus == .denied {
                    Button {
                        Task {
                            await appState.openPermissionSettings()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open System Preferences")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.nukeNeonOrange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                        .nukeGlow(color: .nukeNeonOrange, radius: 10, opacity: 0.5)
                    }
                    .buttonStyle(.plain)
                }
                
                // Info text
                Text("Full Disk Access is required to scan system caches and other protected locations. Without it, some categories may return incomplete results.")
                    .font(.caption)
                    .foregroundStyle(Color.nukeTextTertiary)
                    .padding(.horizontal, Theme.spacing4)
            }
        }
    }
    
    private var permissionStatusIcon: String {
        switch permissionStatus {
        case .unknown: return "questionmark.circle.fill"
        case .granted: return "checkmark.shield.fill"
        case .denied: return "xmark.shield.fill"
        }
    }
    
    private var permissionStatusColor: Color {
        switch permissionStatus {
        case .unknown: return Color.gray
        case .granted: return Color.nukeToxicGreen
        case .denied: return Color.nukeNeonRed
        }
    }
    
    private var permissionStatusText: String {
        switch permissionStatus {
        case .unknown: return "Status unknown - click Check Permissions"
        case .granted: return "Full Disk Access is enabled"
        case .denied: return "Full Disk Access not granted - some features may be limited"
        }
    }
    
    private func checkPermissions() async {
        isCheckingPermissions = true
        let hasAccess = await appState.checkPermissions()
        permissionStatus = hasAccess ? .granted : .denied
        isCheckingPermissions = false
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        SettingsSection(
            title: "ABOUT",
            subtitle: "Application information",
            icon: "info.circle.fill"
        ) {
            VStack(spacing: Theme.spacing16) {
                // App logo and name
                HStack(spacing: Theme.spacing16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.nukeNeonRed.opacity(0.3), Color.nukeNeonOrange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .blur(radius: 5)
                        
                        Image(systemName: "rays")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.nukeNeonRed, Color.nukeNeonOrange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .nukeNeonRed, radius: 10)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NukeMyMac")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(Color.nukeTextPrimary)
                        
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.caption)
                            .foregroundStyle(Color.nukeTextSecondary)
                    }
                    
                    Spacer()
                }
                
                Divider().overlay(Color.nukeSurfaceHighlight)
                
                // App details
                VStack(spacing: Theme.spacing8) {
                    infoRow(label: "Target OS", value: "macOS 14.0+")
                    infoRow(label: "Architecture", value: "Universal (Apple Silicon & Intel)")
                    infoRow(label: "Framework", value: "SwiftUI")
                }
                
                Divider().overlay(Color.nukeSurfaceHighlight)
                
                // Copyright
                Text("Built with aggressive intent to destroy disk clutter.")
                    .font(.caption)
                    .foregroundStyle(Color.nukeTextTertiary)
                    .italic()
                
                Text("Copyright 2024. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(Color.nukeTextTertiary)
            }
            .padding(Theme.spacing16)
            .glassCardStyle()
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.nukeTextSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.nukeTextPrimary)
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Settings Section Container

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing16) {
            // Header
            HStack(spacing: Theme.spacing8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.nukeNeonRed)
                    .shadow(color: .nukeNeonRed.opacity(0.6), radius: 5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.black)
                        .tracking(1)
                        .foregroundStyle(Color.nukeTextPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.nukeTextSecondary)
                }
            }
            .padding(.leading, 4)
            
            content
        }
    }
}

// MARK: - Custom Styles

struct StartScanToggle<Content: View>: View {
    @Binding var isOn: Bool
    let label: () -> Content
    
    var body: some View {
        Toggle(isOn: $isOn) {
            label()
        }
        .toggleStyle(.switch)
        .tint(Color.nukeNeonRed)
    }
}



extension View {
    func glassCardStyle() -> some View {
        self
            .background(Color.nukeSurface.opacity(0.7))
            .background(.ultraThinMaterial) // Glassmorphism!
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Preview

#Preview("Settings - Dark Nuke") {
    SettingsView()
        .environmentObject(AppState())
        .frame(width: 800, height: 800)
        .preferredColorScheme(.dark)
}
