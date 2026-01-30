import Foundation

enum CleanCategory: String, CaseIterable, Identifiable {
    case systemCaches = "System Caches"
    case xcodeDerivedData = "Xcode Derived Data"
    case iosBackups = "iOS Backups"
    case homebrewCache = "Homebrew Cache"
    case npmCache = "npm Cache"
    case docker = "Docker"
    case oldDownloads = "Old Downloads"
    case trash = "Trash"
    case largeFiles = "Large Files"
    case logFiles = "Log Files"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemCaches: return "folder.badge.gearshape"
        case .xcodeDerivedData: return "hammer.fill"
        case .iosBackups: return "iphone"
        case .homebrewCache: return "mug.fill"
        case .npmCache: return "shippingbox.fill"
        case .docker: return "cube.box.fill"
        case .oldDownloads: return "arrow.down.circle.fill"
        case .trash: return "trash.fill"
        case .largeFiles: return "doc.fill"
        case .logFiles: return "doc.text.fill"
        }
    }

    var description: String {
        switch self {
        case .systemCaches: return "Temporary files from apps and system"
        case .xcodeDerivedData: return "Build artifacts from Xcode projects"
        case .iosBackups: return "Old iPhone/iPad backups"
        case .homebrewCache: return "Downloaded packages from Homebrew"
        case .npmCache: return "Cached npm packages"
        case .docker: return "Docker images, volumes, and build cache"
        case .oldDownloads: return "Downloads older than 30 days"
        case .trash: return "Files in your Trash"
        case .largeFiles: return "Files larger than 500MB"
        case .logFiles: return "System and application logs"
        }
    }

    var paths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .systemCaches:
            return [
                "\(home)/Library/Caches",
                "/Library/Caches"
            ]
        case .xcodeDerivedData:
            return ["\(home)/Library/Developer/Xcode/DerivedData"]
        case .iosBackups:
            return ["\(home)/Library/Application Support/MobileSync/Backup"]
        case .homebrewCache:
            return ["\(home)/Library/Caches/Homebrew"]
        case .npmCache:
            return ["\(home)/.npm/_cacache"]
        case .docker:
            return [
                "\(home)/Library/Containers/com.docker.docker",
                "\(home)/.docker"
            ]
        case .oldDownloads:
            return ["\(home)/Downloads"]
        case .trash:
            return ["\(home)/.Trash"]
        case .largeFiles:
            return [home]
        case .logFiles:
            return [
                "\(home)/Library/Logs",
                "/var/log"
            ]
        }
    }

    var isDestructive: Bool {
        switch self {
        case .iosBackups, .largeFiles, .oldDownloads:
            return true
        default:
            return false
        }
    }
}
