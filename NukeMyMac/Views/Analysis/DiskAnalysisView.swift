import SwiftUI

struct DiskAnalysisView: View {
    @StateObject private var analyzerState = SpaceAnalyzer.AnalysisState()
    @State private var selectedNode: FileNode?
    @State private var hoveredNode: FileNode?
    @State private var isScanning = false
    @State private var currentRoot: FileNode?
    @State private var navigationPath: [FileNode] = []
    @State private var zoomTransition = false
    @State private var currentTaskId: UUID?

    var body: some View {
        HStack(spacing: 0) {
            // Main Visualization Area
            VStack(spacing: 0) {
                // Enhanced Header with breadcrumbs
                headerView

                Divider().overlay(Color.nukeSurfaceHighlight)

                // Main content
                ZStack {
                    if isScanning {
                        scanningView
                    } else if let root = currentRoot {
                        sunburstContainer(root: root)
                    } else {
                        emptyStateView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.nukeBackground)

            // Sidebar Details
            Divider().overlay(Color.nukeSurfaceHighlight)

            detailsSidebar
                .frame(width: 320)
                .background(Color.nukeSurface.opacity(0.5))
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Home button
            Button {
                drillToRoot()
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(navigationPath.count > 1 ? Color.nukeNeonOrange : Color.nukeTextTertiary)
                    .frame(width: 28, height: 28)
                    .background(navigationPath.count > 1 ? Color.nukeNeonOrange.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(navigationPath.count <= 1)

            // Back button
            Button {
                drillOut()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(navigationPath.count > 1 ? Color.nukeTextPrimary : Color.nukeTextTertiary)
                    .frame(width: 28, height: 28)
                    .background(navigationPath.count > 1 ? Color.nukeSurfaceHighlight : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(navigationPath.count <= 1)

            // Depth indicator
            if navigationPath.count > 1 {
                HStack(spacing: 3) {
                    ForEach(0..<min(navigationPath.count, 6), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(depthColor(for: i))
                            .frame(width: i == navigationPath.count - 1 ? 16 : 6, height: 6)
                    }
                    if navigationPath.count > 6 {
                        Text("+\(navigationPath.count - 6)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.nukeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Breadcrumb navigation
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    if navigationPath.isEmpty {
                        Text("DISK SPACE ANALYZER")
                            .font(.system(size: 12, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Color.nukeTextPrimary)
                    } else {
                        ForEach(Array(navigationPath.enumerated()), id: \.element.id) { index, node in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color.nukeTextTertiary.opacity(0.5))
                                    .padding(.horizontal, 2)
                            }

                            Button {
                                drillTo(index: index)
                            } label: {
                                HStack(spacing: 4) {
                                    if index == navigationPath.count - 1 {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(depthColor(for: index))
                                    }
                                    Text(node.name)
                                        .font(.system(size: 11, weight: index == navigationPath.count - 1 ? .bold : .medium))
                                        .foregroundStyle(index == navigationPath.count - 1 ? Color.nukeTextPrimary : Color.nukeTextSecondary)
                                }
                                .padding(.horizontal, index == navigationPath.count - 1 ? 8 : 4)
                                .padding(.vertical, 4)
                                .background(index == navigationPath.count - 1 ? depthColor(for: index).opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()

            // Current size indicator
            if let root = currentRoot {
                HStack(spacing: 6) {
                    Text(root.formattedSize)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeNeonOrange)

                    if navigationPath.count > 1, let parent = navigationPath.dropLast().last {
                        let percentage = Double(root.size) / Double(parent.size) * 100
                        Text("(\(Int(percentage))%)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.nukeNeonOrange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Scanning status
            if isScanning {
                HStack(spacing: 6) {
                    NukeSpinner(size: 12, color: .nukeNeonOrange)
                    Text("\(analyzerState.scannedCount)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeNeonOrange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.nukeNeonOrange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Select Folder button
            Button {
                selectFolder()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                    Text("SELECT")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.nukeCyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.nukeCyan.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(isScanning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.nukeSurface)
    }

    private func depthColor(for index: Int) -> Color {
        let colors: [Color] = [.nukeNeonOrange, .nukeCyan, .nukeToxicGreen, .nukeNeonRed, .nukeBlue, .purple]
        return colors[index % colors.count]
    }

    // MARK: - Sunburst Container

    private func sunburstContainer(root: FileNode) -> some View {
        ZStack {
            SunburstView(
                rootNode: root,
                selectedNode: $selectedNode,
                hoveredNode: $hoveredNode,
                onDrillDown: { node in
                    drillInto(node)
                }
            )
            .padding(40)
            .scaleEffect(zoomTransition ? 0.8 : 1.0)
            .opacity(zoomTransition ? 0 : 1)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.nukeNeonOrange.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: 120 + CGFloat(i * 30), height: 120 + CGFloat(i * 30))
                }

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.nukeNeonOrange, .nukeNeonRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("DISK SPACE ANALYZER")
                    .font(.system(size: 18, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Visualize disk usage with an interactive sunburst chart")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            // Features list
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "arrow.down.right.circle", text: "Drill down into folders")
                featureRow(icon: "chart.pie.fill", text: "Interactive sunburst visualization")
                featureRow(icon: "scope", text: "Identify space hogs instantly")
                featureRow(icon: "arrow.uturn.backward.circle", text: "Navigate with breadcrumbs")
            }
            .padding(20)
            .background(Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                selectFolder()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                    Text("SELECT FOLDER TO ANALYZE")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.nukeNeonOrange, .nukeNeonRed],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .nukeNeonOrange.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(.plain)

            // Quick scan buttons
            HStack(spacing: 12) {
                quickScanButton(name: "Home", path: FileManager.default.homeDirectoryForCurrentUser)
                quickScanButton(name: "Downloads", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
                quickScanButton(name: "Applications", path: URL(fileURLWithPath: "/Applications"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeNeonOrange)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.nukeTextSecondary)
        }
    }

    private func quickScanButton(name: String, path: URL) -> some View {
        Button {
            startAnalysis(url: path)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                Text(name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Color.nukeTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.nukeSurfaceHighlight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 24) {
            ReactorLoader(size: 80, color: .nukeNeonOrange)

            VStack(spacing: 8) {
                Text("ANALYZING DISK SPACE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("\(analyzerState.scannedCount) items scanned")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.nukeNeonOrange)

                if !analyzerState.currentPath.isEmpty {
                    Text(analyzerState.currentPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .lineLimit(1)
                        .frame(maxWidth: 400)
                }
            }

            // Animated dots
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color.nukeNeonOrange)
                        .frame(width: 6, height: 6)
                        .opacity(0.3 + Double((i + 1)) * 0.14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Details Sidebar

    private var detailsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("INSPECTOR")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextTertiary)

                Spacer()

                if selectedNode != nil || hoveredNode != nil {
                    Circle()
                        .fill(Color.nukeToxicGreen)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.nukeSurfaceHighlight.opacity(0.3))

            ScrollView {
                if let node = hoveredNode ?? selectedNode ?? currentRoot {
                    VStack(alignment: .leading, spacing: 16) {
                        // Icon and name
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(node.color.opacity(0.2))
                                    .frame(width: 50, height: 50)

                                Image(systemName: node.isDirectory ? "folder.fill" : iconForExtension(node.url.pathExtension))
                                    .font(.system(size: 22))
                                    .foregroundStyle(node.color)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(node.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.nukeTextPrimary)
                                    .lineLimit(2)

                                Text(node.formattedSize)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.nukeNeonOrange)
                            }
                        }

                        // Size relative to parent
                        if let parent = node.parent {
                            let percentage = Double(node.size) / Double(parent.size) * 100

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("SIZE IN PARENT")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.nukeTextTertiary)

                                    Spacer()

                                    Text("\(String(format: "%.1f", percentage))%")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(node.color)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.nukeSurfaceHighlight)

                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(
                                                LinearGradient(
                                                    colors: [node.color, node.color.opacity(0.7)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geo.size.width * min(percentage, 100) / 100)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(12)
                            .background(Color.nukeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Divider().overlay(Color.nukeSurfaceHighlight)

                        // Quick stats
                        if node.isDirectory, let children = node.children, !children.isEmpty {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                statCard(icon: "folder.fill", label: "TYPE", value: "Directory", color: .nukeBlue)
                                statCard(icon: "number", label: "ITEMS", value: "\(children.count)", color: .nukeCyan)

                                if let largest = children.max(by: { $0.size < $1.size }) {
                                    statCard(icon: "arrow.up.circle.fill", label: "LARGEST", value: largest.formattedSize, color: .nukeNeonOrange)
                                }

                                let dirCount = children.filter { $0.isDirectory }.count
                                statCard(icon: "folder.badge.gearshape", label: "FOLDERS", value: "\(dirCount)", color: .nukeToxicGreen)
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                let ext = node.url.pathExtension.isEmpty ? "—" : node.url.pathExtension.uppercased()
                                statCard(icon: "doc.fill", label: "TYPE", value: ext, color: node.color)
                                statCard(icon: "internaldrive.fill", label: "SIZE", value: node.formattedSize, color: .nukeNeonOrange)
                            }
                        }

                        // Path
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PATH")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.nukeTextTertiary)

                            Text(node.url.path)
                                .font(.custom("Menlo", size: 9))
                                .foregroundStyle(Color.nukeTextSecondary)
                                .lineLimit(4)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.nukeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        // Children preview
                        if node.isDirectory, let children = node.children, !children.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("TOP ITEMS")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.nukeTextTertiary)

                                    Spacer()

                                    if children.count > 5 {
                                        Text("+\(children.count - 5) more")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.nukeTextTertiary)
                                    }
                                }

                                ForEach(children.sorted(by: { $0.size > $1.size }).prefix(5)) { child in
                                    Button {
                                        selectedNode = child
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: child.isDirectory ? "folder.fill" : "doc.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(child.color)
                                                .frame(width: 16)

                                            Text(child.name)
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.nukeTextPrimary)
                                                .lineLimit(1)

                                            Spacer()

                                            Text(child.formattedSize)
                                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                .foregroundStyle(Color.nukeTextSecondary)

                                            if child.isDirectory && child.children?.isEmpty == false {
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(Color.nukeTextTertiary)
                                            }
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .background(selectedNode?.id == child.id ? Color.nukeSurfaceHighlight : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .background(Color.nukeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Spacer(minLength: 16)

                        // Actions
                        VStack(spacing: 8) {
                            // Drill down for directories
                            if node.isDirectory && node.children?.isEmpty == false && currentRoot?.id != node.id {
                                Button {
                                    drillInto(node)
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.down.right.circle.fill")
                                        Text("Drill Into This Folder")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [node.color, node.color.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([node.url])
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Reveal in Finder")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.nukeCyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.nukeCyan.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)

                            Button {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(node.url.path, forType: .string)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Copy Path")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.nukeTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.nukeSurfaceHighlight)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)

                            if !node.isDirectory {
                                Button {
                                    // Delete action
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Move to Trash")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.nukeNeonRed)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.nukeNeonRed.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "cursorarrow.click.2")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.nukeTextTertiary)

                        Text("Select a folder to analyze")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.nukeTextSecondary)

                        Text("Use the button above to choose a folder")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.nukeTextTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
                }
            }
        }
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.nukeTextTertiary)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.nukeTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func iconForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "app": return "app.fill"
        case "dmg", "pkg", "zip", "rar", "7z": return "archivebox.fill"
        case "mp4", "mov", "mkv", "avi": return "film.fill"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo.fill"
        case "pdf": return "doc.richtext.fill"
        case "txt", "md": return "doc.text.fill"
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }

    // MARK: - Navigation Functions

    private func drillInto(_ node: FileNode) {
        guard node.isDirectory && node.children?.isEmpty == false else { return }

        zoomTransition = true

        withAnimation(.easeIn(duration: 0.15)) {
            zoomTransition = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            navigationPath.append(node)
            currentRoot = node
            selectedNode = node

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                zoomTransition = false
            }
        }
    }

    private func drillOut() {
        guard navigationPath.count > 1 else { return }

        zoomTransition = true

        withAnimation(.easeIn(duration: 0.15)) {
            zoomTransition = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            _ = navigationPath.popLast()
            currentRoot = navigationPath.last
            selectedNode = currentRoot

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                zoomTransition = false
            }
        }
    }

    private func drillTo(index: Int) {
        guard index < navigationPath.count - 1 else { return }

        zoomTransition = true

        withAnimation(.easeIn(duration: 0.15)) {
            zoomTransition = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            navigationPath = Array(navigationPath.prefix(index + 1))
            currentRoot = navigationPath.last
            selectedNode = currentRoot

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                zoomTransition = false
            }
        }
    }

    private func drillToRoot() {
        guard navigationPath.count > 1 else { return }

        zoomTransition = true

        withAnimation(.easeIn(duration: 0.15)) {
            zoomTransition = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            navigationPath = [navigationPath[0]]
            currentRoot = navigationPath.first
            selectedNode = currentRoot

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                zoomTransition = false
            }
        }
    }

    // MARK: - Actions

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to analyze"
        panel.prompt = "Analyze"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                startAnalysis(url: url)
            }
        }
    }

    private func startAnalysis(url: URL) {
        // Cancel any existing task for this feature
        if let existingTaskId = currentTaskId {
            BackgroundTaskManager.shared.cancelTask(existingTaskId)
        }
        BackgroundTaskManager.shared.cancelTasksForFeature("Disk Analysis")

        isScanning = true
        analyzerState.rootNode = nil
        currentRoot = nil
        navigationPath = []

        // Register background task
        let taskId = BackgroundTaskManager.shared.startTask(
            name: "Disk Analysis: \(url.lastPathComponent)",
            icon: "chart.pie.fill",
            color: .nukeCyan
        )
        currentTaskId = taskId

        Task {
            let root = await SpaceAnalyzer.shared.analyze(url: url) { count, path in
                Task { @MainActor in
                    analyzerState.scannedCount = count
                    analyzerState.currentPath = path

                    // Update task progress (only if this is still the current task)
                    if self.currentTaskId == taskId {
                        let progress = min(Double(count) / 10000.0, 0.95) // Estimate
                        BackgroundTaskManager.shared.updateProgress(taskId, progress: progress, status: "Scanned \(count) items")
                    }
                }
            }

            await MainActor.run {
                // Only update UI if this is still the current task
                if self.currentTaskId == taskId {
                    analyzerState.rootNode = root
                    currentRoot = root
                    navigationPath = [root]
                    selectedNode = root
                    isScanning = false

                    // Complete task
                    BackgroundTaskManager.shared.completeTask(taskId, status: "Found \(root.formattedSize)")
                    currentTaskId = nil
                }
            }
        }
    }
}
