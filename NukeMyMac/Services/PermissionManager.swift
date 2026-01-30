import Foundation
import AppKit

actor PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    func hasFullDiskAccess() -> Bool {
        let testPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")

        return FileManager.default.isReadableFile(atPath: testPath.path)
    }

    func canAccessPath(_ path: String) -> Bool {
        FileManager.default.isReadableFile(atPath: path)
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccess(for path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            _ = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return true
        } catch {
            return false
        }
    }
}
