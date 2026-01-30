import SwiftUI
import StoreKit
import AppKit

struct PaywallView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var isStartingTrial = false
    @State private var showLicenseKeyInput = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            ScrollView {
                VStack(spacing: 24) {
                    // Trial banner (if available or active)
                    if licenseManager.canStartTrial || licenseManager.currentTier == .trial {
                        trialSection
                    }

                    // Features comparison
                    featuresSection

                    // Pricing options
                    pricingSection

                    // Purchase button
                    purchaseButton

                    // Restore & Terms
                    footerSection
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 700)
        .background(Color.nukeBackground)
        .onAppear {
            // Select yearly by default (best value)
            selectedProduct = licenseManager.products.first { $0.id == ProductID.proYearly }
        }
        .sheet(isPresented: $showLicenseKeyInput) {
            LicenseKeyInputView()
                .environmentObject(licenseManager)
        }
    }

    // MARK: - Trial Section

    private var trialSection: some View {
        VStack(spacing: 12) {
            if licenseManager.canStartTrial {
                // Offer to start trial
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.nukeToxicGreen)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Try Pro Free for \(TrialConfig.durationDays) Days")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.nukeTextPrimary)

                            Text("Full access to all Pro features, no commitment")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.nukeTextSecondary)
                        }

                        Spacer()
                    }

                    Button {
                        startTrial()
                    } label: {
                        HStack {
                            if isStartingTrial {
                                NukeSpinner(size: 14, color: .white)
                            } else {
                                Text("START FREE TRIAL")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.nukeToxicGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStartingTrial)
                }
                .padding(16)
                .background(Color.nukeToxicGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.nukeToxicGreen.opacity(0.3), lineWidth: 1)
                )

            } else if licenseManager.currentTier == .trial {
                // Show active trial status
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(licenseManager.trialDaysRemaining <= 2 ? Color.nukeNeonRed : Color.nukeNeonOrange)

                        Text("Trial Active")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.nukeTextPrimary)

                        Spacer()

                        Text("\(licenseManager.trialTimeRemaining) remaining")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(licenseManager.trialDaysRemaining <= 2 ? Color.nukeNeonRed : Color.nukeNeonOrange)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.nukeSurface)
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(licenseManager.trialDaysRemaining <= 2 ? Color.nukeNeonRed : Color.nukeNeonOrange)
                                .frame(width: geo.size.width * licenseManager.trialProgress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("Subscribe now to keep Pro features after trial ends")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .padding(12)
                .background(Color.nukeNeonOrange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func startTrial() {
        isStartingTrial = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = licenseManager.startTrial()
            isStartingTrial = false
            if success {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Logo/Icon
            ZStack {
                Circle()
                    .fill(Color.nukePrimaryGradient)
                    .frame(width: 80, height: 80)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("UPGRADE TO PRO")
                    .font(.system(size: 24, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Unlock the full power of NukeMyMac")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.nukeTextSecondary)
            }
        }
        .padding(.bottom, 8)
        .background(Color.nukeSurface)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRO FEATURES")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nukeTextTertiary)

            VStack(spacing: 8) {
                FeatureRow(icon: "doc.on.doc.fill", title: "Duplicate Finder", description: "Find and remove duplicate files")
                FeatureRow(icon: "trash.fill", title: "App Uninstaller", description: "Completely remove apps and leftovers")
                FeatureRow(icon: "square.grid.3x3.topleft.filled", title: "Space Treemap", description: "Visual disk space analysis")
                FeatureRow(icon: "wrench.and.screwdriver.fill", title: "Developer Tools", description: "Clean Xcode, npm, Docker caches")
                FeatureRow(icon: "safari.fill", title: "Browser Cleaner", description: "Clear browser caches and data")
                FeatureRow(icon: "gearshape.fill", title: "Startup Manager", description: "Control app launch at startup")
            }
        }
        .padding(16)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 12) {
            Text("CHOOSE YOUR PLAN")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nukeTextTertiary)

            VStack(spacing: 8) {
                ForEach(licenseManager.products, id: \.id) { product in
                    PricingOption(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        badge: product.id == ProductID.proYearly ? "BEST VALUE" : nil
                    ) {
                        selectedProduct = product
                    }
                }
            }
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchase() }
            } label: {
                HStack {
                    if isPurchasing {
                        NukeSpinner(size: 16, color: .white)
                    } else {
                        Text("UPGRADE NOW")
                            .font(.system(size: 14, weight: .black))
                            .tracking(1)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.nukePrimaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(selectedProduct == nil || isPurchasing)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.nukeNeonRed)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 12) {
            // License key and restore options
            HStack(spacing: 16) {
                Button {
                    showLicenseKeyInput = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 10))
                        Text("Enter License Key")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.nukeCyan)
                }
                .buttonStyle(.plain)

                Text("•")
                    .foregroundStyle(Color.nukeTextTertiary)

                Button {
                    Task { await licenseManager.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.nukeCyan)
                }
                .buttonStyle(.plain)
            }

            // Buy on website option
            Button {
                NSWorkspace.shared.open(LicenseKeyValidator.purchaseURL)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 10))
                    Text("Buy on Website")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.nukeTextSecondary)
            }
            .buttonStyle(.plain)

            Text("Subscriptions auto-renew unless cancelled 24h before the end of the current period. Manage subscriptions in System Settings.")
                .font(.system(size: 10))
                .foregroundStyle(Color.nukeTextTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        errorMessage = nil

        do {
            let success = try await licenseManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }

        isPurchasing = false
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.nukeNeonOrange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.nukeTextPrimary)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nukeTextTertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.nukeToxicGreen)
        }
    }
}

// MARK: - Pricing Option

struct PricingOption: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.nukeNeonOrange : Color.nukeTextTertiary, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(Color.nukeNeonOrange)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.nukeTextPrimary)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.nukeToxicGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    if product.id == ProductID.proYearly {
                        Text("Save 37% vs monthly")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.nukeToxicGreen)
                    } else if product.id == ProductID.proLifetime {
                        Text("One-time purchase, forever yours")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeTextPrimary)

                    if product.id != ProductID.proLifetime {
                        Text(product.id == ProductID.proMonthly ? "/month" : "/year")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                }
            }
            .padding(12)
            .background(isSelected ? Color.nukeNeonOrange.opacity(0.1) : Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.nukeNeonOrange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pro Gate View

struct ProGateView<Content: View>: View {
    let feature: ProFeature
    @ViewBuilder let content: () -> Content

    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var showPaywall = false

    var body: some View {
        if licenseManager.canAccess(feature) {
            VStack(spacing: 0) {
                // Show trial banner if on trial
                if licenseManager.currentTier == .trial {
                    TrialBanner(showPaywall: $showPaywall)
                }
                content()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        } else {
            lockedView
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
        }
    }

    private var lockedView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.nukeSurface)
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.nukeTextTertiary)
            }

            VStack(spacing: 8) {
                if licenseManager.isTrialExpired {
                    Text("TRIAL EXPIRED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.nukeNeonRed)
                } else {
                    Text("PRO FEATURE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.nukeNeonOrange)
                }

                Text(feature.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.nukeTextPrimary)

                if licenseManager.canStartTrial {
                    Text("Start a free \(TrialConfig.durationDays)-day trial or upgrade to Pro")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.nukeTextSecondary)
                } else if licenseManager.isTrialExpired {
                    Text("Your trial has ended. Subscribe to continue using Pro features.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.nukeTextSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Upgrade to Pro to unlock this feature")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.nukeTextSecondary)
                }
            }

            VStack(spacing: 12) {
                // Trial button if available
                if licenseManager.canStartTrial {
                    Button {
                        _ = licenseManager.startTrial()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gift.fill")
                            Text("START FREE TRIAL")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.nukeToxicGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                // Upgrade button
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text(licenseManager.canStartTrial ? "OR UPGRADE NOW" : "UPGRADE TO PRO")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(licenseManager.canStartTrial ? Color.nukeNeonOrange : .white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background {
                        if licenseManager.canStartTrial {
                            Color.nukeNeonOrange.opacity(0.15)
                        } else {
                            Color.nukePrimaryGradient
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nukeBackground)
    }
}

// MARK: - Trial Banner (shown at top of Pro features during trial)

struct TrialBanner: View {
    @ObservedObject private var licenseManager = LicenseManager.shared
    @Binding var showPaywall: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundStyle(urgencyColor)

            Text("Trial: \(licenseManager.trialTimeRemaining) remaining")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.nukeTextPrimary)

            Spacer()

            Button {
                showPaywall = true
            } label: {
                Text("Subscribe")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(urgencyColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(urgencyColor.opacity(0.15))
    }

    private var urgencyColor: Color {
        licenseManager.trialDaysRemaining <= 2 ? .nukeNeonRed : .nukeNeonOrange
    }
}

// MARK: - Trial Expired Alert Modifier

struct TrialExpiredAlert: ViewModifier {
    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .trialExpired)) { _ in
                showPaywall = true
            }
    }
}

extension View {
    func handleTrialExpiration() -> some View {
        modifier(TrialExpiredAlert())
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
}

#Preview("Pro Gate - Locked") {
    ProGateView(feature: .duplicateFinder) {
        Text("Duplicate Finder Content")
    }
    .frame(width: 600, height: 400)
}
