import SwiftUI
import Combine

/// Represents a file or directory in the space analysis tree
class FileNode: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    
    @Published var size: Int64 = 0
    @Published var children: [FileNode]? = nil
    
    // Weak parent reference to avoid retain cycles
    weak var parent: FileNode?
    
    // Cached color for visualization consistency
    var color: Color = .gray
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    init(url: URL, isDirectory: Bool, size: Int64 = 0, parent: FileNode? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.size = size
        self.parent = parent
        
        // Root or unknown items might get assigned color later
    }
    
    func sortChildren() {
        children?.sort { $0.size > $1.size }
    }
}

extension FileNode: Equatable, Hashable {
    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
