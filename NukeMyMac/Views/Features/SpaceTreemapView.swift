import SwiftUI

/// Interactive treemap visualization for disk space analysis - DaisyDisk style
struct SpaceTreemapView: View {
    @State private var rootNode: TreemapNode?
    @State private var currentPath: [TreemapNode] = []
    @State private var isScanning = false
    @State private var selectedNode: TreemapNode?
    @State private var hoveredNode: TreemapNode?
    @State private var zoomTransition = false
    @State private var drillDirection: DrillDirection = .none
    @State private var scanProgress: String = ""

    enum DrillDirection {
        case none, `in`, out
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with breadcrumb navigation
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            if isScanning {
                scanningView
            } else if let root = currentNode {
                // Main content
                HStack(spacing: 0) {
                    // Treemap visualization with zoom transition
                    ZStack {
                        treemapView(for: root)
                            .scaleEffect(zoomTransition ? (drillDirection == .in ? 1.5 : 0.8) : 1.0)
                            .opacity(zoomTransition ? 0 : 1)
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Divider().overlay(Color.nukeSurfaceHighlight)

                    // Details sidebar
                    detailsSidebar
                        .frame(width: 300)
                }
            } else {
                emptyStateView
            }
        }
        .background(Color.nukeBackground)
    }

    // MARK: - Computed Properties

    private var currentNode: TreemapNode? {
        currentPath.last ?? rootNode
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Home button
            Button {
                drillToRoot()
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(currentPath.count > 1 ? Color.nukeNeonOrange : Color.nukeTextTertiary)
                    .frame(width: 28, height: 28)
                    .background(currentPath.count > 1 ? Color.nukeNeonOrange.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(currentPath.count <= 1)

            // Back button
            Button {
                drillOut()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(currentPath.count > 1 ? Color.nukeTextPrimary : Color.nukeTextTertiary)
                    .frame(width: 28, height: 28)
                    .background(currentPath.count > 1 ? Color.nukeSurfaceHighlight : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(currentPath.count <= 1)

            // Depth indicator
            if currentPath.count > 1 {
                HStack(spacing: 3) {
                    ForEach(0..<min(currentPath.count, 6), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(depthColor(for: i))
                            .frame(width: i == currentPath.count - 1 ? 16 : 6, height: 6)
                    }
                    if currentPath.count > 6 {
                        Text("+\(currentPath.count - 6)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.nukeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Breadcrumb
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(currentPath.enumerated()), id: \.element.id) { index, node in
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
                                if index == currentPath.count - 1 {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(depthColor(for: index))
                                }
                                Text(node.name)
                                    .font(.system(size: 11, weight: index == currentPath.count - 1 ? .bold : .medium))
                                    .foregroundStyle(index == currentPath.count - 1 ? Color.nukeTextPrimary : Color.nukeTextSecondary)
                            }
                            .padding(.horizontal, index == currentPath.count - 1 ? 8 : 4)
                            .padding(.vertical, 4)
                            .background(index == currentPath.count - 1 ? depthColor(for: index).opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Current size indicator
            if let node = currentNode {
                HStack(spacing: 6) {
                    Text(node.formattedSize)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.nukeNeonOrange)

                    if currentPath.count > 1, let parent = currentPath.dropLast().last {
                        let percentage = Double(node.size) / Double(parent.size) * 100
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

            // Scan button
            Button {
                Task { await startScan() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isScanning ? "stop.fill" : "arrow.clockwise")
                    Text(isScanning ? "STOP" : "SCAN")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isScanning ? Color.nukeNeonRed : Color.nukeNeonOrange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((isScanning ? Color.nukeNeonRed : Color.nukeNeonOrange).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.nukeSurface)
    }

    private func depthColor(for index: Int) -> Color {
        let colors: [Color] = [.nukeNeonOrange, .nukeCyan, .nukeToxicGreen, .nukeNeonRed, .nukeBlue, .purple]
        return colors[index % colors.count]
    }

    // MARK: - Navigation Functions

    private func drillInto(_ node: TreemapNode) {
        guard node.isDirectory && !node.children.isEmpty else { return }

        drillDirection = .in
        zoomTransition = true

        withAnimation(.easeIn(duration: 0.15)) {
            zoomTransition = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentPath.append(node)
            drillDirection = .none

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                zoomTransition = false
            }
        }
    }

    private func drillOut() {
        guard currentPath.count > 1 else { return }

        drillDirection = .out
        zoomTransition = true

        withAnimation(.easeIn(duration: 0.15)) {
            zoomTransition = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            _ = currentPath.popLast()
            drillDirection = .none

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                zoomTransition = false
            }
        }
    }

    private func drillTo(index: Int) {
        guard index < currentPath.count - 1 else { return }

        drillDirection = .out
        zoomTransition = true

        withAnimation(.easeIn(duration: 0.15)) {
            zoomTransition = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentPath = Array(currentPath.prefix(index + 1))
            drillDirection = .none

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                zoomTransition = false
            }
        }
    }

    private func drillToRoot() {
        guard currentPath.count > 1 else { return }

        drillDirection = .out
        zoomTransition = true

        withAnimation(.easeIn(duration: 0.15)) {
            zoomTransition = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentPath = [currentPath[0]]
            drillDirection = .none

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                zoomTransition = false
            }
        }
    }

    // MARK: - Treemap View

    private func treemapView(for node: TreemapNode) -> some View {
        GeometryReader { geo in
            if geo.size.width > 10 && geo.size.height > 10 {
                let rects = squarifiedLayout(items: node.children, in: CGRect(origin: .zero, size: geo.size))

                ZStack {
                    ForEach(Array(zip(node.children.indices, rects)), id: \.0) { index, rect in
                        // Skip very small cells
                        if rect.width > 4 && rect.height > 4 {
                            let child = node.children[index]
                            let isHovered = hoveredNode?.id == child.id
                            let isSelected = selectedNode?.id == child.id
                            let parentSize = node.size

                            treemapCell(for: child, rect: rect, isHovered: isHovered, isSelected: isSelected, parentSize: parentSize)
                        }
                    }
                }
            }
        }
        .padding(8)
    }

    private func treemapCell(for node: TreemapNode, rect: CGRect, isHovered: Bool, isSelected: Bool, parentSize: Int64) -> some View {
        let color = colorForNode(node)
        let canDrillDown = node.isDirectory && !node.children.isEmpty
        let percentage = parentSize > 0 ? Double(node.size) / Double(parentSize) * 100 : 0

        return Button {
            if canDrillDown {
                drillInto(node)
            }
            selectedNode = node
        } label: {
            ZStack {
                // Background with gradient for depth
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(isHovered ? 0.95 : 0.75),
                                color.opacity(isHovered ? 0.85 : 0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Inner shadow for depth
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear, .black.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                // Selection/hover border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isSelected ? Color.nukeNeonRed : (isHovered && canDrillDown ? Color.white.opacity(0.8) : Color.clear),
                        lineWidth: isSelected ? 2.5 : 2
                    )

                // Content
                VStack(spacing: 2) {
                    // Drill-down indicator for directories
                    if rect.width > 50 && rect.height > 35 {
                        if canDrillDown && isHovered {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down.right.circle.fill")
                                    .font(.system(size: 10))
                                Text("DRILL")
                                    .font(.system(size: 8, weight: .black))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    if rect.width > 45 && rect.height > 30 {
                        // Name with folder icon for directories
                        HStack(spacing: 3) {
                            if canDrillDown && rect.width > 70 {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: min(10, rect.width / 12)))
                            }
                            Text(node.name)
                                .font(.system(size: min(11, rect.width / 10), weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                    }

                    if rect.width > 55 && rect.height > 45 {
                        // Size
                        Text(node.formattedSize)
                            .font(.system(size: min(9, rect.width / 12), weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    if rect.width > 70 && rect.height > 60 {
                        // Percentage bar
                        HStack(spacing: 4) {
                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.black.opacity(0.3))

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.6))
                                        .frame(width: barGeo.size.width * min(percentage, 100) / 100)
                                }
                            }
                            .frame(height: 4)

                            Text("\(Int(percentage))%")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(width: min(60, rect.width - 16))
                    }
                }
                .padding(4)

                // Drill indicator corner badge for directories
                if canDrillDown && rect.width > 30 && rect.height > 30 && !isHovered {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.right.2")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(3)
                        }
                        Spacer()
                    }
                }
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: isHovered ? color.opacity(0.5) : .clear, radius: isHovered ? 8 : 0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .frame(width: max(1, rect.width - 2), height: max(1, rect.height - 2))
        .position(x: rect.midX, y: rect.midY)
        .onHover { hovering in
            DispatchQueue.main.async {
                hoveredNode = hovering ? node : nil
            }
        }
    }

    // MARK: - Squarified Treemap Layout

    private func squarifiedLayout(items: [TreemapNode], in rect: CGRect) -> [CGRect] {
        guard !items.isEmpty else { return [] }
        guard rect.width > 2, rect.height > 2 else { return items.map { _ in rect } }

        let totalSize = items.reduce(0) { $0 + Double($1.size) }
        guard totalSize > 0 else { return items.map { _ in rect } }

        var rects: [CGRect] = []
        var remaining = items
        var currentRect = rect

        while !remaining.isEmpty {
            let isHorizontal = currentRect.width > currentRect.height
            let side = isHorizontal ? currentRect.height : currentRect.width

            var row: [TreemapNode] = []
            var rowSize: Double = 0
            var bestRatio = Double.infinity

            for item in remaining {
                let testRow = row + [item]
                let testSize = rowSize + Double(item.size)
                let ratio = worstRatio(items: testRow, totalSize: testSize, side: side, totalAreaSize: totalSize, areaRect: currentRect)

                if ratio <= bestRatio {
                    row = testRow
                    rowSize = testSize
                    bestRatio = ratio
                } else {
                    break
                }
            }

            // Layout the row
            let rowFraction = rowSize / totalSize
            let rowLength = isHorizontal ? currentRect.width * rowFraction : currentRect.height * rowFraction

            var offset: CGFloat = 0
            for item in row {
                let itemFraction = Double(item.size) / rowSize
                let itemLength = (isHorizontal ? currentRect.height : currentRect.width) * itemFraction

                let itemRect: CGRect
                if isHorizontal {
                    itemRect = CGRect(x: currentRect.minX, y: currentRect.minY + offset, width: rowLength, height: itemLength)
                } else {
                    itemRect = CGRect(x: currentRect.minX + offset, y: currentRect.minY, width: itemLength, height: rowLength)
                }
                rects.append(itemRect)
                offset += itemLength
            }

            // Update remaining area
            if isHorizontal {
                currentRect = CGRect(x: currentRect.minX + rowLength, y: currentRect.minY, width: currentRect.width - rowLength, height: currentRect.height)
            } else {
                currentRect = CGRect(x: currentRect.minX, y: currentRect.minY + rowLength, width: currentRect.width, height: currentRect.height - rowLength)
            }

            remaining.removeFirst(row.count)
        }

        return rects
    }

    private func worstRatio(items: [TreemapNode], totalSize: Double, side: CGFloat, totalAreaSize: Double, areaRect: CGRect) -> Double {
        guard !items.isEmpty, totalSize > 0 else { return .infinity }

        let fraction = totalSize / totalAreaSize
        let rowLength = (areaRect.width > areaRect.height ? areaRect.width : areaRect.height) * fraction

        var worst: Double = 0
        for item in items {
            let itemFraction = Double(item.size) / totalSize
            let itemLength = Double(side) * itemFraction

            let ratio = max(rowLength / itemLength, itemLength / rowLength)
            worst = max(worst, ratio)
        }

        return worst
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
                if let node = selectedNode ?? hoveredNode ?? currentNode {
                    VStack(alignment: .leading, spacing: 16) {
                        // Icon and name - larger, more prominent
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorForNode(node).opacity(0.2))
                                    .frame(width: 50, height: 50)

                                Image(systemName: node.isDirectory ? "folder.fill" : iconForExtension(node.path.pathExtension))
                                    .font(.system(size: 22))
                                    .foregroundStyle(colorForNode(node))
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
                        if currentPath.count > 0, let parent = currentPath.last, parent.id != node.id {
                            let percentage = Double(node.size) / Double(parent.size) * 100

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("SIZE IN PARENT")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.nukeTextTertiary)

                                    Spacer()

                                    Text("\(String(format: "%.1f", percentage))%")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(colorForNode(node))
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.nukeSurfaceHighlight)

                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(
                                                LinearGradient(
                                                    colors: [colorForNode(node), colorForNode(node).opacity(0.7)],
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

                        // Quick stats grid
                        if node.isDirectory {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                statCard(icon: "folder.fill", label: "TYPE", value: "Directory", color: .nukeBlue)
                                statCard(icon: "number", label: "ITEMS", value: "\(node.children.count)", color: .nukeCyan)

                                if !node.children.isEmpty {
                                    let largestChild = node.children.max(by: { $0.size < $1.size })
                                    if let largest = largestChild {
                                        statCard(icon: "arrow.up.circle.fill", label: "LARGEST", value: largest.formattedSize, color: .nukeNeonOrange)
                                    }

                                    let dirCount = node.children.filter { $0.isDirectory }.count
                                    statCard(icon: "folder.badge.gearshape", label: "FOLDERS", value: "\(dirCount)", color: .nukeToxicGreen)
                                }
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                let ext = node.path.pathExtension.isEmpty ? "—" : node.path.pathExtension.uppercased()
                                statCard(icon: "doc.fill", label: "TYPE", value: ext, color: colorForNode(node))
                                statCard(icon: "internaldrive.fill", label: "SIZE", value: node.formattedSize, color: .nukeNeonOrange)
                            }
                        }

                        // Path section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PATH")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.nukeTextTertiary)

                            Text(node.path.path)
                                .font(.custom("Menlo", size: 9))
                                .foregroundStyle(Color.nukeTextSecondary)
                                .lineLimit(4)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.nukeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        // Children preview for directories
                        if node.isDirectory && !node.children.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("TOP ITEMS")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.nukeTextTertiary)

                                    Spacer()

                                    if node.children.count > 5 {
                                        Text("+\(node.children.count - 5) more")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.nukeTextTertiary)
                                    }
                                }

                                ForEach(node.children.sorted(by: { $0.size > $1.size }).prefix(5)) { child in
                                    HStack(spacing: 8) {
                                        Image(systemName: child.isDirectory ? "folder.fill" : "doc.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(colorForNode(child))
                                            .frame(width: 16)

                                        Text(child.name)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.nukeTextPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        Text(child.formattedSize)
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.nukeTextSecondary)
                                    }
                                    .padding(.vertical, 4)
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
                            if node.isDirectory && !node.children.isEmpty && (selectedNode?.id == node.id || hoveredNode?.id == node.id) && currentNode?.id != node.id {
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
                                            colors: [colorForNode(node), colorForNode(node).opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([node.path])
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
                                pasteboard.setString(node.path.path, forType: .string)
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
                                    // Delete action would go here
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

                        Text("Select an item")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.nukeTextSecondary)

                        Text("Hover or click on a treemap cell to see details")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.nukeTextTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
                }
            }
        }
        .background(Color.nukeSurface.opacity(0.5))
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.nukeNeonOrange.opacity(0.2 - Double(i) * 0.05), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i * 20), height: 80 + CGFloat(i * 15))
                        .rotationEffect(.degrees(Double(i) * 5))
                }

                Image(systemName: "square.grid.3x3.topleft.filled")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.nukeNeonOrange, .nukeNeonRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("SPACE TREEMAP")
                    .font(.system(size: 20, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                Text("Interactive disk space visualization")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            // Features list
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "arrow.down.right.circle", text: "Drill down into folders")
                featureRow(icon: "chart.pie.fill", text: "Visual size proportions")
                featureRow(icon: "magnifyingglass", text: "Find space hogs instantly")
                featureRow(icon: "folder.badge.gearshape", text: "Navigate with breadcrumbs")
            }
            .padding(20)
            .background(Color.nukeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await startScan() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("SCAN HOME DIRECTORY")
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

            Text("Scans your home directory up to 4 levels deep")
                .font(.system(size: 11))
                .foregroundStyle(Color.nukeTextTertiary)
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

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 24) {
            ReactorLoader(size: 80, color: .nukeNeonOrange)

            VStack(spacing: 8) {
                Text("ANALYZING DISK SPACE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.nukeTextPrimary)

                if !scanProgress.isEmpty {
                    Text(scanProgress)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.nukeTextSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 400)
                } else {
                    Text("Scanning directories...")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nukeTextTertiary)
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

    // MARK: - Helpers

    private func colorForNode(_ node: TreemapNode) -> Color {
        // Color based on file type
        if node.isDirectory {
            // Different colors for different directory types
            let name = node.name.lowercased()
            if name.contains("cache") || name.contains("temp") || name.contains("tmp") {
                return .nukeNeonOrange
            } else if name.contains("download") {
                return .nukeCyan
            } else if name.contains("library") {
                return .purple
            } else if name.contains("application") || name.contains("app") {
                return .nukeNeonRed
            } else if name.contains("document") {
                return .nukeBlue
            } else if name.contains("desktop") {
                return .nukeToxicGreen
            } else if name.contains("picture") || name.contains("photo") || name.contains("image") {
                return .pink
            } else if name.contains("music") || name.contains("audio") {
                return .indigo
            } else if name.contains("movie") || name.contains("video") {
                return .teal
            }
            return .nukeBlue
        }

        // File type colors
        let ext = node.path.pathExtension.lowercased()
        switch ext {
        // Apps & Executables
        case "app", "exe", "dmg", "pkg":
            return .nukeNeonRed

        // Archives
        case "zip", "rar", "7z", "tar", "gz", "bz2":
            return .nukeNeonOrange

        // Videos
        case "mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v":
            return .nukeCyan

        // Images
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "raw", "psd", "ai":
            return .nukeToxicGreen

        // Audio
        case "mp3", "wav", "aac", "flac", "m4a", "ogg", "wma":
            return .indigo

        // Documents
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "keynote":
            return .nukeBlue

        // Code & Text
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h", "go", "rs", "rb", "php":
            return .purple
        case "txt", "md", "rtf", "json", "xml", "yaml", "yml", "html", "css":
            return .mint

        // Data
        case "db", "sqlite", "sql", "csv":
            return .brown

        // Xcode specific
        case "xcodeproj", "xcworkspace", "playground":
            return .nukeNeonRed

        default:
            return .gray
        }
    }

    private func startScan() async {
        isScanning = true
        scanProgress = ""
        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        do {
            let node = try await TreemapScanner.shared.scanDirectory(homeDir, maxDepth: 4) { path in
                Task { @MainActor in
                    self.scanProgress = path
                }
            }
            await MainActor.run {
                rootNode = node
                currentPath = [node]
                isScanning = false
                scanProgress = ""
            }
        } catch {
            await MainActor.run {
                isScanning = false
                scanProgress = ""
            }
        }
    }
}

#Preview("Space Treemap") {
    SpaceTreemapView()
        .frame(width: 900, height: 600)
}
