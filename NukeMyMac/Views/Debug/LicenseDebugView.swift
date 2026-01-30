import SwiftUI

#if DEBUG
/// Debug view for testing license and trial states
/// Access via Settings or Option+Click on logo
struct LicenseDebugView: View {
    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LICENSE DEBUG")
                    .font(.system(size: 12, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.nukeNeonRed)

                Spacer()

                Text("DEBUG BUILD ONLY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.nukeNeonRed)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding()
            .background(Color.nukeSurface)

            ScrollView {
                VStack(spacing: 20) {
                    // Current Status
                    statusSection

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // Trial Controls
                    trialControlsSection

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
        .background(Color.nukeBackground)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT STATUS")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nukeTextTertiary)

            VStack(spacing: 8) {
                StatusRow(label: "License Tier", value: licenseManager.currentTier.displayName, color: tierColor)
                StatusRow(label: "Is Pro", value: licenseManager.currentTier.isPro ? "Yes" : "No", color: licenseManager.currentTier.isPro ? .nukeToxicGreen : .nukeTextSecondary)
                StatusRow(label: "Is Developer", value: licenseManager.isDeveloperMode ? "Yes" : "No", color: licenseManager.isDeveloperMode ? .nukeCyan : .nukeTextSecondary)

                Divider().overlay(Color.nukeSurfaceHighlight)

                StatusRow(label: "Trial Used", value: licenseManager.hasUsedTrial ? "Yes" : "No")
                StatusRow(label: "Trial Expired", value: licenseManager.isTrialExpired ? "Yes" : "No", color: licenseManager.isTrialExpired ? .nukeNeonRed : .nukeTextSecondary)
                StatusRow(label: "Can Start Trial", value: licenseManager.canStartTrial ? "Yes" : "No", color: licenseManager.canStartTrial ? .nukeToxicGreen : .nukeTextSecondary)

                if licenseManager.currentTier == .trial {
                    Divider().overlay(Color.nukeSurfaceHighlight)
                    StatusRow(label: "Days Remaining", value: "\(licenseManager.trialDaysRemaining)", color: .nukeNeonOrange)
                    StatusRow(label: "Hours Remaining", value: "\(licenseManager.trialHoursRemaining)", color: .nukeNeonOrange)
                    StatusRow(label: "Progress", value: String(format: "%.1f%%", licenseManager.trialProgress * 100))

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.nukeSurface)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.nukeNeonOrange)
                                .frame(width: geo.size.width * licenseManager.trialProgress)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
            .background(Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var tierColor: Color {
        switch licenseManager.currentTier {
        case .free: return .nukeTextSecondary
        case .trial: return .nukeNeonOrange
        case .proMonthly, .proYearly, .proLifetime: return .nukeToxicGreen
        case .developer: return .nukeCyan
        }
    }

    // MARK: - Trial Controls

    private var trialControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRIAL SIMULATION")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nukeTextTertiary)

            VStack(spacing: 8) {
                DebugButton(title: "Start Fresh Trial", icon: "play.fill", color: .nukeToxicGreen) {
                    licenseManager.debugResetTrial()
                    _ = licenseManager.startTrial()
                }

                DebugButton(title: "Set Trial: 7 Days Left", icon: "7.circle.fill", color: .nukeNeonOrange) {
                    licenseManager.debugSetTrialDays(7)
                }

                DebugButton(title: "Set Trial: 2 Days Left", icon: "2.circle.fill", color: .nukeNeonOrange) {
                    licenseManager.debugSetTrialDays(2)
                }

                DebugButton(title: "Set Trial: 1 Day Left", icon: "1.circle.fill", color: .nukeNeonRed) {
                    licenseManager.debugSetTrialDays(1)
                }

                DebugButton(title: "Expire Trial Now", icon: "xmark.circle.fill", color: .nukeNeonRed) {
                    licenseManager.debugExpireTrial()
                }

                DebugButton(title: "Reset Trial (Start Over)", icon: "arrow.counterclockwise", color: .nukeTextSecondary) {
                    licenseManager.debugResetTrial()
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK ACTIONS")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nukeTextTertiary)

            VStack(spacing: 8) {
                DebugButton(title: "Show Paywall", icon: "creditcard.fill", color: .nukeCyan) {
                    showPaywall = true
                }

                DebugButton(title: "Disable Dev Mode (Test as User)", icon: "person.fill", color: .nukeNeonOrange) {
                    licenseManager.debugDisableDeveloperMode()
                }

                DebugButton(title: "Re-enable Dev Mode", icon: "hammer.fill", color: .nukeCyan) {
                    licenseManager.debugEnableDeveloperMode()
                }

                DebugButton(title: "Post Trial Expired Notification", icon: "bell.fill", color: .nukeNeonRed) {
                    NotificationCenter.default.post(name: .trialExpired, object: nil)
                }
            }
        }
    }
}

// MARK: - Helper Views

private struct StatusRow: View {
    let label: String
    let value: String
    var color: Color = .nukeTextPrimary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.nukeTextSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

private struct DebugButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

#Preview("License Debug") {
    LicenseDebugView()
}
#endif
