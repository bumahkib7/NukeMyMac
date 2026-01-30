import Foundation
import CryptoKit
import Combine

actor DuplicateScannerLegacy {
    static let shared = DuplicateScannerLegacy()
    
    @MainActor
    class ScanState: ObservableObject {
        @Published var foundGroups: [DuplicateGroup] = []
        @Published var isScanning = false
        @Published var progress: Double = 0.0
        @Published var status: String = "Idle"
        @Published var scannedCount = 0
    }
    
    private init() {}
    
    func scan(directories: [URL], fastMode: Bool = true, progressHelper: ScanState) async {
        await MainActor.run {
            progressHelper.isScanning = true
            progressHelper.foundGroups = []
            progressHelper.progress = 0
            progressHelper.scannedCount = 0
            progressHelper.status = "Scanning file hierarchy..."
        }
        
        let groups = await Task.detached(priority: .userInitiated) { () -> [DuplicateGroup] in
            // 1. Gather all files
            var allFiles: [URL] = []
            let fileManager = FileManager.default
            
            for dir in directories {
                if let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                    for case let fileURL as URL in enumerator {
                        if Task.isCancelled { return [] }
                        
                        // optimization: skip small files < 1KB (usually not worth deleting)
                        // skip system files check
                        
                        allFiles.append(fileURL)
                        
                        if allFiles.count % 1000 == 0 {
                            Task { @MainActor in progressHelper.scannedCount = allFiles.count }
                        }
                    }
                }
            }
            
            Task { @MainActor in progressHelper.status = "Grouping by size..." }
            
            // 2. Group by Size (Stage 1)
            var bySize: [Int64: [URL]] = [:]
            for file in allFiles {
                if Task.isCancelled { return [] }
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    let size64 = Int64(size)
                    if size64 > 1024 { // Min 1KB
                        bySize[size64, default: []].append(file)
                    }
                }
            }
            
            // Filter out unique sizes
            let potentialDuplicates = bySize.filter { $0.value.count > 1 }
            var candidates = potentialDuplicates.values.flatMap { $0 }
            let totalCandidates = candidates.count
            
            Task { @MainActor in
                progressHelper.status = "Analyzing content..."
                progressHelper.progress = 0.1
            }
            
            // 3. Group by Hash (Stage 2 & 3 combined for simplicity, or split)
            // We'll create a dictionary of Hash -> [DuplicateFile]
            var byHash: [String: [DuplicateFile]] = [:]
            
            var processed = 0
            
            for (size, files) in potentialDuplicates {
                if Task.isCancelled { return [] }
                
                // For files with same size, compute hash
                // Optimization: Maybe compute partial hash first?
                // For now, let's implement robust chunked hashing or just full SHA256 for safety.
                // To be crash-proof, we do this serially or in limited concurrency groups.
                
                for file in files {
                    if let hash = self.computeHash(for: file) {
                        let resourceValues = try? file.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                        let dupFile = DuplicateFile(
                            url: file,
                            creationDate: resourceValues?.creationDate,
                            modificationDate: resourceValues?.contentModificationDate
                        )
                        byHash[hash, default: []].append(dupFile)
                    }
                    
                    processed += 1
                    if processed % 10 == 0 {
                        let p = 0.1 + (0.9 * Double(processed) / Double(totalCandidates))
                        Task { @MainActor in progressHelper.progress = p }
                    }
                }
            }
            
            // 4. Final filter
            let finalGroups = byHash.compactMap { (hash, files) -> DuplicateGroup? in
                guard files.count > 1 else { return nil }
                // Calculate size from first file
                let size = (try? files.first?.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
                return DuplicateGroup(hash: hash, size: size, files: files)
            }.sorted { $0.totalWastedSize > $1.totalWastedSize }
            
            return finalGroups
        }.value
        
        await MainActor.run {
            progressHelper.foundGroups = groups
            progressHelper.isScanning = false
            progressHelper.status = "Complete"
            progressHelper.progress = 1.0
        }
    }
    
    private nonisolated func computeHash(for url: URL) -> String? {
        // Check if file is readable first
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return nil
        }

        // Skip files that are too large (> 500MB) to avoid timeouts
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64,
           size > 500_000_000 {
            // For very large files, just use size + name as pseudo-hash
            return "large_\(size)_\(url.lastPathComponent.hashValue)"
        }

        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            var hasher = SHA256()
            let chunkSize = 1024 * 1024 // 1MB chunks

            // Use the throwing version of read which is safer
            while true {
                let data: Data?
                do {
                    data = try fileHandle.read(upToCount: chunkSize)
                } catch {
                    // File read error (timeout, permission, etc.) - skip this file
                    return nil
                }

                guard let readData = data, !readData.isEmpty else {
                    break
                }
                hasher.update(data: readData)
            }

            let digest = hasher.finalize()
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
}
