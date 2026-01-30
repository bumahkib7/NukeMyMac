import SwiftUI

// ⚠️ SET TO TRUE TO TEST TRIAL MODE (disables dev backdoor and starts trial)
private let kTestTrialMode = true

// ⚠️ SET TO TRUE TO ALWAYS SHOW ONBOARDING (for testing)
private let kAlwaysShowOnboarding = true

@main
struct NukeMyMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var settings = SettingsViewModel()
    @ObservedObject private var memoryService = MemoryService.shared
    @ObservedObject private var licenseManager = LicenseManager.shared
    @ObservedObject private var updateManager = UpdateManager.shared

    // For testing: kAlwaysShowOnboarding resets this on every launch
    @State private var hasCompletedOnboarding: Bool = {
        #if DEBUG
        if kAlwaysShowOnboarding {
            return false
        }
        #endif
        return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }()

    #if DEBUG
    @State private var showDebugPanel = false
    #endif

    init() {
        #if DEBUG
        // Reset onboarding for testing if flag is set (must happen before view renders)
        if kAlwaysShowOnboarding {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
        #endif

        // Start memory monitoring immediately
        Task { @MainActor in
            MemoryService.shared.startMonitoring()

            // Check for updates on launch
            UpdateManager.shared.checkOnLaunch()

            #if DEBUG
            // Auto-start trial for testing if flag is set
            if kTestTrialMode {
                let license = LicenseManager.shared
                license.debugDisableDeveloperMode()  // Disable dev backdoor
                license.debugResetTrial()            // Reset any existing trial
                _ = license.startTrial()             // Start fresh 7-day trial
                print("🧪 TEST MODE: Trial started - \(license.trialDaysRemaining) days remaining")
            }
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else {
                    mainContentView
                }
            }
            .frame(minWidth: 1100, idealWidth: 1200, minHeight: 750, idealHeight: 800)
            #if DEBUG
            .sheet(isPresented: $showDebugPanel) {
                LicenseDebugView()
            }
            #endif
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }

            // Check for Updates
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    Task {
                        await updateManager.checkForUpdates(silent: false)
                    }
                }
                .disabled(updateManager.isChecking)
            }

            // MARK: - Actions Menu
            CommandMenu("Actions") {
                Button("Start Scan") {
                    Task { await appState.startScan() }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!appState.canStartScan)

                Button("Delete Selected") {
                    Task { await appState.cleanSelected() }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!appState.canClean)

                Divider()

                Button("Clean Memory") {
                    Task { await memoryService.cleanMemory() }
                }
                .keyboardShortcut("m", modifiers: .command)

                Button("Refresh Disk Usage") {
                    Task { await appState.loadDiskUsage() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            // MARK: - Selection Menu
            CommandMenu("Selection") {
                Button("Select All") {
                    appState.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)

                Button("Deselect All") {
                    appState.deselectAll()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Toggle System Caches") {
                    appState.toggleCategory(.systemCaches)
                }

                Button("Toggle Xcode Derived Data") {
                    appState.toggleCategory(.xcodeDerivedData)
                }

                Button("Toggle Log Files") {
                    appState.toggleCategory(.logFiles)
                }
            }

            #if DEBUG
            // MARK: - Debug Menu (only in debug builds)
            CommandMenu("Debug") {
                Button("License Debug Panel") {
                    showDebugPanel = true
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Reset Trial") {
                    licenseManager.debugResetTrial()
                }

                Button("Start Trial") {
                    _ = licenseManager.startTrial()
                }

                Button("Expire Trial") {
                    licenseManager.debugExpireTrial()
                }

                Divider()

                Button("Disable Dev Mode") {
                    licenseManager.debugDisableDeveloperMode()
                }

                Button("Enable Dev Mode") {
                    licenseManager.debugEnableDeveloperMode()
                }

                Divider()

                Button("Reset Onboarding") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    hasCompletedOnboarding = false
                }
            }
            #endif
        }

        // Menu Bar Extra - shows RAM in menu bar
        MenuBarExtra("NukeMyMac", systemImage: "bolt.shield.fill") {
            RamMonitorView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(settings)
        }
    }

    // MARK: - Main Content View

    private var mainContentView: some View {
        ContentView()
            .environmentObject(appState)
            .environmentObject(settings)
            .overlay {
                // Update available alert
                if updateManager.showUpdateAlert {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    UpdateAlertView()
                }
            }
            .sheet(isPresented: $updateManager.showChangelogSheet) {
                JustUpdatedSheet()
            }
    }
}
