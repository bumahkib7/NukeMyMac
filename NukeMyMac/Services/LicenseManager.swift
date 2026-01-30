import Foundation
import StoreKit
import Combine
import CryptoKit

// MARK: - Trial Configuration

enum TrialConfig {
    static let durationDays = 7
    static let duration: TimeInterval = TimeInterval(durationDays * 24 * 60 * 60)
}

// MARK: - Pro Features

enum ProFeature: String, CaseIterable {
    // Free features
    case basicScan = "basic_scan"
    case trashCleaning = "trash_cleaning"
    case cacheCleaning = "cache_cleaning"

    // Pro features
    case duplicateFinder = "duplicate_finder"
    case appUninstaller = "app_uninstaller"
    case spaceTreemap = "space_treemap"
    case sunburstAnalysis = "sunburst_analysis"
    case developerTools = "developer_tools"
    case mailAttachments = "mail_attachments"
    case startupManager = "startup_manager"
    case browserCleaner = "browser_cleaner"
    case advancedScanning = "advanced_scanning"
    case unlimitedCleaning = "unlimited_cleaning"

    var isPro: Bool {
        switch self {
        case .basicScan, .trashCleaning, .cacheCleaning:
            return false
        default:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .basicScan: return "Basic Scan"
        case .trashCleaning: return "Trash Cleaning"
        case .cacheCleaning: return "Cache Cleaning"
        case .duplicateFinder: return "Duplicate Finder"
        case .appUninstaller: return "App Uninstaller"
        case .spaceTreemap: return "Space Treemap"
        case .sunburstAnalysis: return "Disk Analysis"
        case .developerTools: return "Developer Tools"
        case .mailAttachments: return "Mail Attachments"
        case .startupManager: return "Startup Manager"
        case .browserCleaner: return "Browser Cleaner"
        case .advancedScanning: return "Advanced Scanning"
        case .unlimitedCleaning: return "Unlimited Cleaning"
        }
    }
}

// MARK: - License Tier

enum LicenseTier: String, Codable {
    case free = "free"
    case trial = "trial"
    case proMonthly = "pro_monthly"
    case proYearly = "pro_yearly"
    case proLifetime = "pro_lifetime"
    case developer = "developer"  // Secret tier for you

    var isPro: Bool {
        switch self {
        case .free:
            return false
        case .trial, .proMonthly, .proYearly, .proLifetime, .developer:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .trial: return "Trial"
        case .proMonthly: return "Pro Monthly"
        case .proYearly: return "Pro Yearly"
        case .proLifetime: return "Pro Lifetime"
        case .developer: return "Developer"
        }
    }
}

// MARK: - Product IDs (Configure in App Store Connect)

enum ProductID {
    static let proMonthly = "com.nukemymac.pro.monthly"    // $3.99/month
    static let proYearly = "com.nukemymac.pro.yearly"      // $29.99/year
    static let proLifetime = "com.nukemymac.pro.lifetime"  // $49.99 one-time

    static let allSubscriptions = [proMonthly, proYearly]
    static let allProducts = [proMonthly, proYearly, proLifetime]
}

// MARK: - License Key Result

enum LicenseKeyResult {
    case success(tier: LicenseTier)
    case invalidFormat
    case invalidKey
    case networkError
    case alreadyActivated
}

// MARK: - License Key Validation

struct LicenseKeyValidator {
    /// Validate license key format: NUKE-XXXX-XXXX-XXXX-XXXX
    /// Second segment starts with Y (yearly) or L (lifetime)
    static func validateFormat(_ key: String) -> (valid: Bool, tier: LicenseTier?) {
        let normalized = key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check format: NUKE-XXXX-YXXX-XXXX-XXXX or NUKE-XXXX-LXXX-XXXX-XXXX
        let pattern = "^NUKE-[A-Z0-9]{4}-[YL][A-Z0-9]{3}-[A-Z0-9]{4}-[A-Z0-9]{4}$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil else {
            return (false, nil)
        }

        // Extract tier from second segment's first character
        let segments = normalized.split(separator: "-")
        guard segments.count == 5 else { return (false, nil) }

        let tierChar = segments[2].first
        let tier: LicenseTier = tierChar == "Y" ? .proYearly : .proLifetime

        return (true, tier)
    }

    /// Website URL for purchasing
    static let purchaseURL = URL(string: "https://nukemymac-website.vercel.app/#pricing")!
}

// MARK: - License Manager

@MainActor
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var currentTier: LicenseTier = .free
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var products: [Product] = []

    // Trial state
    @Published private(set) var trialStartDate: Date?
    @Published private(set) var trialEndDate: Date?
    @Published private(set) var isTrialExpired = false
    @Published private(set) var hasUsedTrial = false

    private var updateListenerTask: Task<Void, Error>?
    private var trialCheckTimer: Timer?

    // Storage keys (obfuscated to prevent easy tampering)
    private let trialStartKey = "nk_ts_\(String("trial_start".utf8.md5))"
    private let trialUsedKey = "nk_tu_\(String("trial_used".utf8.md5))"
    private let installDateKey = "nk_id_\(String("install_date".utf8.md5))"
    private let licenseKeyStorageKey = "nk_lk_\(String("license_key".utf8.md5))"

    // License key state
    @Published private(set) var activatedLicenseKey: String?
    @Published private(set) var licenseKeyError: String?

    // MARK: - Developer Backdoor Keys
    private let devMachineIDs: Set<String> = [
        "F8341A7C-D805-541B-8C61-C160922EEC5A"  // Your Mac
    ]

    private let devSecretFile = ".nuke_dev_license"  // Hidden file in home directory
    private let devEnvKey = "NUKE_DEV_MODE"          // Environment variable
    private let devSecretCode = "NUKE_2024_DEV"      // Secret code in the file

    private init() {
        // Record install date if first launch
        recordInstallDateIfNeeded()

        // Check developer status first
        if checkDeveloperBackdoor() {
            currentTier = .developer
            return
        }

        // Load saved license, trial state, and license key
        loadSavedLicense()
        loadTrialState()
        loadLicenseKey()

        // Start listening for StoreKit transactions
        updateListenerTask = listenForTransactions()

        // Start trial expiration checker
        startTrialChecker()

        // Fetch products
        Task {
            await fetchProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
        trialCheckTimer?.invalidate()
    }

    // MARK: - Feature Access

    func canAccess(_ feature: ProFeature) -> Bool {
        if !feature.isPro { return true }

        // Check if trial is active (not expired)
        if currentTier == .trial && !isTrialExpired {
            return true
        }

        return currentTier.isPro && currentTier != .trial
    }

    func requirePro(for feature: ProFeature) -> Bool {
        feature.isPro && !canAccess(feature)
    }

    // MARK: - Trial Management

    /// Start a free trial (can only be used once per device)
    func startTrial() -> Bool {
        guard !hasUsedTrial else {
            print("❌ Trial already used")
            return false
        }

        guard currentTier == .free else {
            print("❌ Already has a license")
            return false
        }

        let now = Date()
        trialStartDate = now
        trialEndDate = now.addingTimeInterval(TrialConfig.duration)
        hasUsedTrial = true
        isTrialExpired = false
        currentTier = .trial

        saveTrialState()
        saveLicense()

        print("✅ Trial started, expires: \(trialEndDate!)")
        return true
    }

    /// Check if trial can be started
    var canStartTrial: Bool {
        !hasUsedTrial && currentTier == .free
    }

    /// Days remaining in trial
    var trialDaysRemaining: Int {
        guard let endDate = trialEndDate else { return 0 }
        let remaining = endDate.timeIntervalSince(Date())
        return max(0, Int(ceil(remaining / 86400)))
    }

    /// Hours remaining in trial (for last day)
    var trialHoursRemaining: Int {
        guard let endDate = trialEndDate else { return 0 }
        let remaining = endDate.timeIntervalSince(Date())
        return max(0, Int(ceil(remaining / 3600)))
    }

    /// Formatted trial time remaining
    var trialTimeRemaining: String {
        let days = trialDaysRemaining
        if days > 1 {
            return "\(days) days"
        } else if days == 1 {
            let hours = trialHoursRemaining
            return hours > 1 ? "\(hours) hours" : "< 1 hour"
        } else {
            return "Expired"
        }
    }

    /// Progress of trial (0.0 to 1.0)
    var trialProgress: Double {
        guard let startDate = trialStartDate, let endDate = trialEndDate else { return 0 }
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        return min(1.0, max(0.0, elapsed / total))
    }

    private func loadTrialState() {
        // Load trial start date
        if let startTimestamp = UserDefaults.standard.object(forKey: trialStartKey) as? TimeInterval {
            trialStartDate = Date(timeIntervalSince1970: startTimestamp)
            trialEndDate = trialStartDate?.addingTimeInterval(TrialConfig.duration)

            // Check if expired
            if let endDate = trialEndDate, Date() > endDate {
                isTrialExpired = true
                if currentTier == .trial {
                    currentTier = .free
                }
            } else if currentTier == .trial {
                isTrialExpired = false
            }
        }

        // Load if trial was used
        hasUsedTrial = UserDefaults.standard.bool(forKey: trialUsedKey)
    }

    private func saveTrialState() {
        if let startDate = trialStartDate {
            UserDefaults.standard.set(startDate.timeIntervalSince1970, forKey: trialStartKey)
        }
        UserDefaults.standard.set(hasUsedTrial, forKey: trialUsedKey)
    }

    private func startTrialChecker() {
        // Check trial status every minute
        trialCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTrialExpiration()
            }
        }
    }

    private func checkTrialExpiration() {
        guard currentTier == .trial, let endDate = trialEndDate else { return }

        if Date() > endDate {
            isTrialExpired = true
            currentTier = .free
            saveLicense()

            // Post notification for UI to show paywall
            NotificationCenter.default.post(name: .trialExpired, object: nil)
        }
    }

    // MARK: - License Key Activation

    /// Activate a license key purchased from the website
    /// - Parameter key: The license key in format NUKE-XXXX-XXXX-XXXX-XXXX
    /// - Returns: Result of the activation attempt
    func activateLicenseKey(_ key: String) async -> LicenseKeyResult {
        licenseKeyError = nil
        let normalizedKey = key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate format offline first
        let (valid, tier) = LicenseKeyValidator.validateFormat(normalizedKey)

        guard valid, let licenseTier = tier else {
            licenseKeyError = "Invalid license key format"
            return .invalidFormat
        }

        // Check if already activated with this key
        if activatedLicenseKey == normalizedKey {
            return .alreadyActivated
        }

        // Optionally validate with server (if online validation is desired)
        // For now, we do offline validation only based on key format
        // In production, you might want to call the /api/validate endpoint

        // Activate the license
        activatedLicenseKey = normalizedKey
        currentTier = licenseTier
        saveLicenseKey()
        saveLicense()

        // Clear trial if active
        if isTrialExpired == false && trialEndDate != nil {
            isTrialExpired = true
        }

        print("✅ License key activated: \(normalizedKey) -> \(licenseTier.displayName)")
        NotificationCenter.default.post(name: .licenseUpdated, object: nil)

        return .success(tier: licenseTier)
    }

    /// Validate license key with the server (optional online validation)
    func validateLicenseKeyOnline(_ key: String) async -> LicenseKeyResult {
        let normalizedKey = key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // First validate format
        let (valid, _) = LicenseKeyValidator.validateFormat(normalizedKey)
        guard valid else {
            return .invalidFormat
        }

        // Call validation API
        guard let url = URL(string: "https://nukemymac-website.vercel.app/api/validate") else {
            return .networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["key": normalizedKey, "activate": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .networkError
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isValid = json["valid"] as? Bool,
               isValid,
               let tierString = json["tier"] as? String {
                let tier: LicenseTier = tierString == "yearly" ? .proYearly : .proLifetime
                return .success(tier: tier)
            } else {
                return .invalidKey
            }
        } catch {
            return .networkError
        }
    }

    /// Deactivate the current license key
    func deactivateLicenseKey() {
        activatedLicenseKey = nil
        currentTier = hasUsedTrial ? .free : .free
        UserDefaults.standard.removeObject(forKey: licenseKeyStorageKey)
        saveLicense()
        NotificationCenter.default.post(name: .licenseUpdated, object: nil)
    }

    /// Check if a license key is currently active
    var hasActiveLicenseKey: Bool {
        activatedLicenseKey != nil && (currentTier == .proYearly || currentTier == .proLifetime)
    }

    private func saveLicenseKey() {
        if let key = activatedLicenseKey {
            UserDefaults.standard.set(key, forKey: licenseKeyStorageKey)
        }
    }

    private func loadLicenseKey() {
        if let savedKey = UserDefaults.standard.string(forKey: licenseKeyStorageKey) {
            activatedLicenseKey = savedKey
        }
    }

    private func recordInstallDateIfNeeded() {
        if UserDefaults.standard.object(forKey: installDateKey) == nil {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: installDateKey)
        }
    }

    // MARK: - Developer Backdoor

    private func checkDeveloperBackdoor() -> Bool {
        // Method 1: Environment variable (for debugging)
        if ProcessInfo.processInfo.environment[devEnvKey] == devSecretCode {
            print("🔓 Developer mode: Environment variable")
            return true
        }

        // Method 2: Secret file in home directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let secretFile = homeDir.appendingPathComponent(devSecretFile)
        if let content = try? String(contentsOf: secretFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           content == devSecretCode {
            print("🔓 Developer mode: Secret file")
            return true
        }

        // Method 3: Machine UUID check
        if let machineID = getMachineUUID(), devMachineIDs.contains(machineID) {
            print("🔓 Developer mode: Machine ID")
            return true
        }

        // Method 4: Debug build check (only works in Xcode)
        #if DEBUG
        // Uncomment this line if you want all debug builds to be pro
        // return true
        #endif

        return false
    }

    private func getMachineUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }

        guard service != 0,
              let uuidData = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String else {
            return nil
        }

        return uuidData
    }

    /// Call this to enable developer mode manually (for testing)
    func enableDeveloperMode() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let secretFile = homeDir.appendingPathComponent(devSecretFile)
        try? devSecretCode.write(to: secretFile, atomically: true, encoding: .utf8)
        currentTier = .developer
    }

    /// Check if running in developer mode
    var isDeveloperMode: Bool {
        currentTier == .developer
    }

    // MARK: - Debug/Testing (Remove in production or guard with #if DEBUG)

    #if DEBUG
    /// Reset trial for testing purposes
    func debugResetTrial() {
        UserDefaults.standard.removeObject(forKey: trialStartKey)
        UserDefaults.standard.removeObject(forKey: trialUsedKey)
        trialStartDate = nil
        trialEndDate = nil
        hasUsedTrial = false
        isTrialExpired = false
        if currentTier == .trial || currentTier == .developer {
            currentTier = .free
        }
        saveLicense()
        print("🔄 Trial reset for testing")
    }

    /// Simulate trial with custom days remaining
    func debugSetTrialDays(_ days: Int) {
        let now = Date()
        trialStartDate = now.addingTimeInterval(-TrialConfig.duration + TimeInterval(days * 86400))
        trialEndDate = trialStartDate?.addingTimeInterval(TrialConfig.duration)
        hasUsedTrial = true
        isTrialExpired = false
        currentTier = .trial
        saveTrialState()
        saveLicense()
        print("🔄 Trial set to \(days) days remaining")
    }

    /// Simulate expired trial
    func debugExpireTrial() {
        let now = Date()
        trialStartDate = now.addingTimeInterval(-TrialConfig.duration - 86400) // 1 day past
        trialEndDate = trialStartDate?.addingTimeInterval(TrialConfig.duration)
        hasUsedTrial = true
        isTrialExpired = true
        currentTier = .free
        saveTrialState()
        saveLicense()
        print("🔄 Trial expired for testing")
    }

    /// Temporarily disable developer mode for testing
    func debugDisableDeveloperMode() {
        if currentTier == .developer {
            currentTier = .free
            print("🔄 Developer mode disabled for testing")
        }
    }

    /// Re-enable developer mode
    func debugEnableDeveloperMode() {
        currentTier = .developer
        print("🔄 Developer mode re-enabled")
    }
    #endif

    // MARK: - StoreKit

    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: ProductID.allProducts)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateTierFromTransaction(transaction)
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        // Sync with App Store
        try? await AppStore.sync()
        await checkSubscriptionStatus()
    }

    private func checkSubscriptionStatus() async {
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                await updateTierFromTransaction(transaction)
                return
            }
        }

        // No active subscription found
        if currentTier != .developer {
            currentTier = .free
            expirationDate = nil
            saveLicense()
        }
    }

    private func updateTierFromTransaction(_ transaction: Transaction) async {
        switch transaction.productID {
        case ProductID.proMonthly:
            currentTier = .proMonthly
            expirationDate = transaction.expirationDate
        case ProductID.proYearly:
            currentTier = .proYearly
            expirationDate = transaction.expirationDate
        case ProductID.proLifetime:
            currentTier = .proLifetime
            expirationDate = nil
        default:
            break
        }
        saveLicense()
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updateTierFromTransaction(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Persistence

    private func saveLicense() {
        UserDefaults.standard.set(currentTier.rawValue, forKey: "license_tier")
        if let date = expirationDate {
            UserDefaults.standard.set(date, forKey: "license_expiration")
        }
    }

    private func loadSavedLicense() {
        if let tierString = UserDefaults.standard.string(forKey: "license_tier"),
           let tier = LicenseTier(rawValue: tierString) {
            currentTier = tier
            expirationDate = UserDefaults.standard.object(forKey: "license_expiration") as? Date

            // Check if subscription expired
            if let expDate = expirationDate, expDate < Date() {
                currentTier = .free
                expirationDate = nil
            }
        }
    }
}

// MARK: - Errors

enum StoreError: Error {
    case verificationFailed
    case purchaseFailed
    case productNotFound
}

// MARK: - Pricing Display Helper

extension LicenseManager {
    var monthlyPrice: String {
        products.first { $0.id == ProductID.proMonthly }?.displayPrice ?? "$3.99"
    }

    var yearlyPrice: String {
        products.first { $0.id == ProductID.proYearly }?.displayPrice ?? "$29.99"
    }

    var lifetimePrice: String {
        products.first { $0.id == ProductID.proLifetime }?.displayPrice ?? "$49.99"
    }

    var yearlySavings: String {
        // Monthly * 12 = $47.88, Yearly = $29.99, saves ~37%
        "Save 37%"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let trialExpired = Notification.Name("com.nukemymac.trialExpired")
    static let trialStarted = Notification.Name("com.nukemymac.trialStarted")
    static let licenseUpdated = Notification.Name("com.nukemymac.licenseUpdated")
}

// MARK: - String MD5 Helper (for key obfuscation)

extension String.UTF8View {
    var md5: String {
        let data = Data(self)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined().prefix(8).description
    }
}
