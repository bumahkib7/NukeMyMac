import Foundation
import SwiftUI
import Combine

actor SpaceAnalyzer {
    static let shared = SpaceAnalyzer()
    
    @MainActor
    class AnalysisState: ObservableObject {
        @Published var rootNode: FileNode?
        @Published var isunScanning = false
        @Published var scannedCount = 0
        @Published var currentPath = ""
    }
    
    private init() {}
    
    /// Scans a directory and returns a specialized FileNode tree for visualization
    func analyze(url: URL, progress: ((Int, String) -> Void)? = nil) async -> FileNode {
        // Offload to a detached task to ensure we don't block the actor or main thread.
        // We use a detached task to avoid inheriting the actor's context for the recursion.
        return await Task.detached(priority: .userInitiated) {
            let root = FileNode(url: url, isDirectory: true)
            var count = 0
            var lastUpdate = Date()
            
            // Define recursion inside so it captures context but runs synchronously on this Thread
            func scan(node: FileNode) {
                guard node.isDirectory else { return }
                
                do {
                    // pre-fetch necessary keys
                    let resourceKeys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isDirectoryKey, .isPackageKey]
                    let contents = try FileManager.default.contentsOfDirectory(at: node.url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
                    
                    var children: [FileNode] = []
                    var totalSize: Int64 = 0
                    
                    for url in contents {
                        if Task.isCancelled { return }
                        
                        let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys))
                        let isDirectory = resourceValues?.isDirectory ?? false
                        let isPackage = resourceValues?.isPackage ?? false
                        let fileSize = Int64(resourceValues?.totalFileAllocatedSize ?? 0)
                        
                        let treatAsFile = !isDirectory || isPackage
                        
                        // Create node
                        let child = FileNode(url: url, isDirectory: !treatAsFile, size: treatAsFile ? fileSize : 0, parent: node)
                        
                        // Recurse if directory
                        if !treatAsFile {
                            scan(node: child)
                        }
                        
                        totalSize += child.size
                        children.append(child)
                        
                        count += 1
                        
                        // Throttle progress updates to ~10fps
                        if count % 100 == 0 {
                            let now = Date()
                            if now.timeIntervalSince(lastUpdate) > 0.1 {
                                lastUpdate = now
                                Task { @MainActor in
                                    progress?(count, url.lastPathComponent)
                                }
                            }
                        }
                    }
                    
                    if !children.isEmpty {
                        node.children = children
                        node.size = totalSize
                        node.sortChildren()
                    }
                    
                    // If node is empty (0 size), we might want to check if it's actually empty or just failed to size.
                    // But FileManager size for folders is usually 0 or metadata size. We rely on sum of children.
                    
                } catch {
                    // print("Scan error: \(error)")
                }
            }
            
            scan(node: root)
            return root
        }.value
    }
}
