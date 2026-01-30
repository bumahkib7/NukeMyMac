import SwiftUI
import AppKit

struct LicenseKeyInputView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @Environment(\.dismiss) private var dismiss

    @State private var licenseKey: String = ""
    @State private var isActivating = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var activatedTier: LicenseTier?

    private let keyFormat = "NUKE-XXXX-XXXX-XXXX-XXXX"

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Enter License Key")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Paste your license key from your purchase confirmation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            if showSuccess, let tier = activatedTier {
                // Success state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("License Activated!")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("You now have access to \(tier.displayName) features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                // Input form
                VStack(spacing: 16) {
                    // License key input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField(keyFormat, text: $licenseKey)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .padding(12)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(errorMessage != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                                .onChange(of: licenseKey) { _, newValue in
                                    errorMessage = nil
                                    licenseKey = formatLicenseKey(newValue)
                                }

                            Button(action: pasteFromClipboard) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.bordered)
                            .help("Paste from clipboard")
                        }

                        if let error = errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // Activate button
                    Button(action: activateLicense) {
                        HStack(spacing: 8) {
                            if isActivating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(.circular)
                            }
                            Text(isActivating ? "Activating..." : "Activate License")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(licenseKey.isEmpty || isActivating)
                }

                Divider()
                    .padding(.vertical, 8)

                // Purchase link
                VStack(spacing: 12) {
                    Text("Don't have a license key?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: openPurchasePage) {
                        HStack(spacing: 6) {
                            Image(systemName: "cart.fill")
                            Text("Buy on Website")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            licenseKey = formatLicenseKey(clipboardString)
        }
    }

    private func formatLicenseKey(_ input: String) -> String {
        // Remove any existing dashes and whitespace, uppercase
        let cleaned = input
            .uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }

        // If it starts with "NUKE", keep it; otherwise just format as is
        var result = ""
        let chars = Array(cleaned)

        for (index, char) in chars.enumerated() {
            if index == 4 || index == 8 || index == 12 || index == 16 {
                result += "-"
            }
            if result.count < 24 { // NUKE-XXXX-XXXX-XXXX-XXXX = 24 chars
                result += String(char)
            }
        }

        return result
    }

    private func activateLicense() {
        guard !licenseKey.isEmpty else { return }

        isActivating = true
        errorMessage = nil

        Task {
            let result = await licenseManager.activateLicenseKey(licenseKey)

            await MainActor.run {
                isActivating = false

                switch result {
                case .success(let tier):
                    activatedTier = tier
                    withAnimation {
                        showSuccess = true
                    }

                case .invalidFormat:
                    errorMessage = "Invalid license key format. Expected: \(keyFormat)"

                case .invalidKey:
                    errorMessage = "This license key is not valid"

                case .networkError:
                    errorMessage = "Network error. Please check your connection."

                case .alreadyActivated:
                    errorMessage = "This license key is already activated"
                }
            }
        }
    }

    private func openPurchasePage() {
        NSWorkspace.shared.open(LicenseKeyValidator.purchaseURL)
    }
}

// MARK: - Preview

#Preview {
    LicenseKeyInputView()
        .environmentObject(LicenseManager.shared)
}
