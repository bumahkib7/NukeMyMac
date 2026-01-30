import SwiftUI

struct SunburstView: View {
    @ObservedObject var rootNode: FileNode
    @Binding var selectedNode: FileNode?
    @Binding var hoveredNode: FileNode?
    var onDrillDown: ((FileNode) -> Void)?

    // State for drill-down animation
    @State private var displayRoot: FileNode

    // Animation state
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    @State private var hitTestNodes: [(FileNode, Path)] = []

    init(rootNode: FileNode, selectedNode: Binding<FileNode?>, hoveredNode: Binding<FileNode?>, onDrillDown: ((FileNode) -> Void)? = nil) {
        self.rootNode = rootNode
        self._selectedNode = selectedNode
        self._hoveredNode = hoveredNode
        self.onDrillDown = onDrillDown
        self._displayRoot = State(initialValue: rootNode)
    }
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2

            ZStack {
                // Background
                Circle()
                    .fill(Color.nukeBackground)

                // Canvas-based drawing for performance and precision
                Canvas { context, size in
                    let drawCenter = CGPoint(x: size.width / 2, y: size.height / 2)
                    let drawRadius = min(size.width, size.height) / 2

                    // Clear hit test nodes before redraw
                    var nodes: [(FileNode, Path)] = []

                    drawRecursively(
                        context: context,
                        node: displayRoot,
                        center: drawCenter,
                        maxRadius: drawRadius,
                        startAngle: .degrees(-90),
                        sweepAngle: .degrees(360),
                        depth: 0,
                        maxDepth: 5,
                        totalSize: displayRoot.size,
                        hitTestNodes: &nodes
                    )

                    // Update hit test nodes on main thread
                    DispatchQueue.main.async {
                        self.hitTestNodes = nodes
                    }
                }
                .drawingGroup() // Metal acceleration
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            handleTap(at: value.location, center: center, radius: radius)
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            // Double tap to drill into selected
                            if let node = selectedNode, node.isDirectory && node.children?.isEmpty == false {
                                onDrillDown?(node)
                            }
                        }
                )

                // Center Navigation
                centerControl(radius: radius, center: center)

                // Hover info overlay
                if let hovered = hoveredNode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            hoverInfoCard(for: hovered)
                                .padding()
                        }
                    }
                }
            }
        }
        .onChange(of: rootNode) { newNode in
            displayRoot = newNode
            hitTestNodes = []
        }
    }

    private func handleTap(at location: CGPoint, center: CGPoint, radius: CGFloat) {
        // Find which segment was tapped using hit test paths
        for (node, path) in hitTestNodes.reversed() {
            if path.contains(location) {
                selectedNode = node
                return
            }
        }
    }

    private func hoverInfoCard(for node: FileNode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 16))
                .foregroundStyle(node.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.nukeTextPrimary)
                    .lineLimit(1)

                Text(node.formattedSize)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.nukeNeonOrange)
            }

            if node.isDirectory && node.children?.isEmpty == false {
                Image(systemName: "arrow.down.right.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.nukeTextTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.nukeSurface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
    
    private func drawRecursively(context: GraphicsContext, node: FileNode, center: CGPoint, maxRadius: CGFloat, startAngle: Angle, sweepAngle: Angle, depth: Int, maxDepth: Int, totalSize: Int64, hitTestNodes: inout [(FileNode, Path)]) {

        guard depth < maxDepth else { return }

        // Ring Dimensions
        let ringThickness = maxRadius * 0.9 / CGFloat(maxDepth + 1) // +1 for center gap
        let innerRadius = (CGFloat(depth) * ringThickness) + (maxRadius * 0.25)
        let outerRadius = innerRadius + ringThickness - 1 // 1px gap

        guard let children = node.children, !children.isEmpty else { return }

        var currentStart = startAngle

        // Sort large to small for better visualization
        // Using visible nodes only
        let minRatio = 0.005 // 0.5% minimum
        let visibleChildren = children.filter { Double($0.size) / Double(totalSize) > minRatio }

        for child in visibleChildren {
            let ratio = Double(child.size) / Double(totalSize)
            let childSweep = Angle.degrees(sweepAngle.degrees * ratio)

            // Draw Arc
            var path = Path()
            path.addArc(center: center, radius: innerRadius, startAngle: currentStart, endAngle: currentStart + childSweep, clockwise: false)
            path.addArc(center: center, radius: outerRadius, startAngle: currentStart + childSweep, endAngle: currentStart, clockwise: true)
            path.closeSubpath()

            // Determine if hovered or selected
            let isHovered = hoveredNode?.id == child.id
            let isSelected = selectedNode?.id == child.id

            // Fill with highlight if hovered/selected
            var fillColor = color(for: child)
            if isSelected {
                fillColor = fillColor.opacity(1.0)
            } else if isHovered {
                fillColor = fillColor.opacity(0.9)
            }

            context.fill(path, with: .color(fillColor))

            // Stroke - highlight if selected
            let strokeColor = isSelected ? Color.nukeNeonRed : Color.nukeBackground
            let strokeWidth: CGFloat = isSelected ? 2 : 1
            context.stroke(path, with: .color(strokeColor), lineWidth: strokeWidth)

            // Add to hit test collection
            hitTestNodes.append((child, path))

            // Recursion
            drawRecursively(
                context: context,
                node: child,
                center: center,
                maxRadius: maxRadius,
                startAngle: currentStart,
                sweepAngle: childSweep, // Child fills its own slice
                depth: depth + 1,
                maxDepth: maxDepth,
                totalSize: child.size, // Relative to parent
                hitTestNodes: &hitTestNodes
            )

            currentStart += childSweep
        }
    }
    
    private func centerControl(radius: CGFloat, center: CGPoint) -> some View {
        Group {
            ZStack {
                // Outer ring glow
                Circle()
                    .stroke(Color.nukeNeonOrange.opacity(0.3), lineWidth: 3)
                    .frame(width: radius * 0.42, height: radius * 0.42)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.nukeSurface, Color.nukeSurface.opacity(0.9)],
                            center: .center,
                            startRadius: 0,
                            endRadius: radius * 0.2
                        )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 8)
                    .overlay(Circle().stroke(Color.nukeSurfaceHighlight, lineWidth: 1))

                VStack(spacing: 4) {
                    Text("TOTAL")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.nukeTextTertiary)

                    Text(displayRoot.formattedSize)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.nukeNeonOrange)

                    if let children = displayRoot.children {
                        Text("\(children.count) items")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                }
            }
        }
        .frame(width: radius * 0.4, height: radius * 0.4)
        .position(center)
    }

    func color(for node: FileNode) -> Color {
        if node.isDirectory {
            let name = node.name.lowercased()
            if name.contains("application") || name == "applications" { return .nukeNeonRed }
            if name.contains("system") || name == "library" { return .purple }
            if name.contains("download") { return .nukeCyan }
            if name.contains("document") { return .nukeBlue }
            if name.contains("desktop") { return .nukeToxicGreen }
            if name.contains("picture") || name.contains("photo") { return .pink }
            if name.contains("music") || name.contains("audio") { return .indigo }
            if name.contains("movie") || name.contains("video") { return .teal }
            if name.contains("cache") || name.contains("temp") { return .nukeNeonOrange }
            if name == "users" { return .nukeCyan }
            return Color.nukeBlue.opacity(0.7)
        }

        let ext = node.url.pathExtension.lowercased()
        switch ext {
        // Apps
        case "app": return .nukeNeonRed
        // Archives
        case "dmg", "iso", "zip", "rar", "7z", "pkg": return .nukeNeonOrange
        // Video
        case "mov", "mp4", "mkv", "avi", "webm", "m4v": return .purple
        // Images
        case "jpg", "jpeg", "png", "heic", "gif", "webp", "raw", "psd": return .pink
        // Audio
        case "mp3", "wav", "aac", "flac", "m4a": return .indigo
        // Documents
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx": return .nukeBlue
        // Code
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h", "go", "rs": return .nukeToxicGreen
        // Data
        case "json", "xml", "yaml", "yml", "csv", "db", "sqlite": return .teal
        default: return .gray.opacity(0.7)
        }
    }
}
