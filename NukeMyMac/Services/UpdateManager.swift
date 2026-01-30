import Foundation
import SwiftUI
import Combine

// MARK: - Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

struct AppUpdate {
    let version: String
    let currentVersion: String
    let changelog: String
    let downloadUrl: URL
    let releaseUrl: URL
    let isNewer: Bool
}

// MARK: - Update Manager

@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private let githubRepo = "bumahkib7/NukeMyMac"
    private let checkIntervalHours: Double = 24
    private let lastCheckKey = "lastUpdateCheck"
    private let lastSeenVersionKey = "lastSeenVersion"
    private let justUpdatedKey = "justUpdated"

    @Published var updateAvailable: AppUpdate?
    @Published var isChecking = false
    @Published var showUpdateAlert = false
    @Published var showChangelogSheet = false
    @Published var justUpdatedChangelog: String?

    private init() {}

    // MARK: - Public Methods

    /// Check for updates on app launch
    func checkOnLaunch() {
        // Check if we just updated
        if UserDefaults.standard.bool(forKey: justUpdatedKey) {
            UserDefaults.standard.set(false, forKey: justUpdatedKey)
            showJustUpdatedChangelog()
            return
        }

        // Check if enough time has passed since last check
        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        let hoursSinceLastCheck = (Date().timeIntervalSince1970 - lastCheck) / 3600

        if hoursSinceLastCheck >= checkIntervalHours {
            Task {
                await checkForUpdates(silent: true)
            }
        }
    }

    /// Manual check for updates
    func checkForUpdates(silent: Bool = false) async {
        guard !isChecking else { return }

        isChecking = true
        defer { isChecking = false }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

        do {
            let release = try await fetchLatestRelease()
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            let isNewer = compareVersions(latestVersion, isNewerThan: currentVersion)

            guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
                  let downloadUrl = URL(string: dmgAsset.browserDownloadUrl),
                  let releaseUrl = URL(string: release.htmlUrl) else {
                return
            }

            let update = AppUpdate(
                version: latestVersion,
                currentVersion: currentVersion,
                changelog: release.body,
                downloadUrl: downloadUrl,
                releaseUrl: releaseUrl,
                isNewer: isNewer
            )

            if isNewer {
                self.updateAvailable = update
                if !silent {
                    self.showUpdateAlert = true
                } else {
                    // Show alert for silent checks too if update is available
                    let lastSeen = UserDefaults.standard.string(forKey: lastSeenVersionKey) ?? ""
                    if lastSeen != latestVersion {
                        self.showUpdateAlert = true
                    }
                }
            } else if !silent {
                // No update available, but user manually checked
                self.updateAvailable = update
            }

        } catch {
            print("Update check failed: \(error)")
        }
    }

    /// Mark that we're about to update (to show changelog after restart)
    func markUpdating() {
        if let update = updateAvailable {
            UserDefaults.standard.set(update.version, forKey: lastSeenVersionKey)
            UserDefaults.standard.set(true, forKey: justUpdatedKey)
            UserDefaults.standard.set(update.changelog, forKey: "pendingChangelog")
        }
    }

    /// Open download page
    func downloadUpdate() {
        guard let update = updateAvailable else { return }
        markUpdating()
        NSWorkspace.shared.open(update.releaseUrl)
    }

    /// Dismiss update alert
    func dismissUpdate() {
        if let update = updateAvailable {
            UserDefaults.standard.set(update.version, forKey: lastSeenVersionKey)
        }
        showUpdateAlert = false
    }

    // MARK: - Private Methods

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("NukeMyMac-App", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    private func compareVersions(_ v1: String, isNewerThan v2: String) -> Bool {
        let v1Parts = v1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Parts.count, v2Parts.count)

        for i in 0..<maxLength {
            let v1Part = i < v1Parts.count ? v1Parts[i] : 0
            let v2Part = i < v2Parts.count ? v2Parts[i] : 0

            if v1Part > v2Part { return true }
            if v1Part < v2Part { return false }
        }

        return false
    }

    private func showJustUpdatedChangelog() {
        if let changelog = UserDefaults.standard.string(forKey: "pendingChangelog") {
            self.justUpdatedChangelog = changelog
            self.showChangelogSheet = true
            UserDefaults.standard.removeObject(forKey: "pendingChangelog")
        }
    }

    enum UpdateError: Error {
        case networkError
        case parseError
    }
}

// MARK: - Update Alert View

struct UpdateAlertView: View {
    @ObservedObject var updateManager = UpdateManager.shared

    var body: some View {
        if let update = updateManager.updateAvailable, updateManager.showUpdateAlert {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.linearGradient(
                            colors: [Color(hex: "ff6b35"), Color(hex: "ff8f5a")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text("Update Available")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("NukeMyMac \(update.version) is now available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("You have version \(update.currentVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)

                Divider()

                // Changelog
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's New:")
                            .font(.headline)
                            .padding(.bottom, 4)

                        Text(update.changelog)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .frame(maxHeight: 200)

                Divider()

                // Buttons
                HStack(spacing: 12) {
                    Button("Later") {
                        updateManager.dismissUpdate()
                    }
                    .buttonStyle(.bordered)

                    Button("Download Update") {
                        updateManager.downloadUpdate()
                        updateManager.showUpdateAlert = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "ff6b35"))
                }
                .padding()
            }
            .frame(width: 400)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }
}

// MARK: - Just Updated Sheet

struct JustUpdatedSheet: View {
    @ObservedObject var updateManager = UpdateManager.shared
    let version: String

    init() {
        self.version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("Updated to v\(version)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("NukeMyMac has been updated successfully")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Changelog
            if let changelog = updateManager.justUpdatedChangelog {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's New in this version:")
                            .font(.headline)
                            .padding(.bottom, 4)

                        Text(changelog)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .frame(maxHeight: 250)

                Divider()
            }

            // Button
            Button("Got it!") {
                updateManager.showChangelogSheet = false
                updateManager.justUpdatedChangelog = nil
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "ff6b35"))
            .padding()
        }
        .frame(width: 400)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
