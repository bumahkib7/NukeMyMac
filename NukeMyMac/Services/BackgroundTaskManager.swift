import Foundation
import SwiftUI
import Combine

/// Represents a background task that can run while user navigates elsewhere
struct BackgroundTask: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    var progress: Double = 0
    var status: String = ""
    var isComplete: Bool = false
    var isFailed: Bool = false
    var startTime: Date = Date()

    var isRunning: Bool {
        !isComplete && !isFailed
    }

    var formattedDuration: String {
        let duration = Date().timeIntervalSince(startTime)
        if duration < 60 {
            return "\(Int(duration))s"
        } else {
            return "\(Int(duration / 60))m \(Int(duration.truncatingRemainder(dividingBy: 60)))s"
        }
    }
}

/// Manages background tasks across the app
@MainActor
final class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()

    @Published var tasks: [BackgroundTask] = []
    @Published var showTasksPanel: Bool = false

    /// Number of currently running tasks
    var runningCount: Int {
        tasks.filter { $0.isRunning }.count
    }

    /// Whether any task is running
    var hasRunningTasks: Bool {
        runningCount > 0
    }

    /// Get tasks for a specific feature
    func tasksForFeature(_ name: String) -> [BackgroundTask] {
        tasks.filter { $0.name.contains(name) }
    }

    /// Create and start a new background task
    @discardableResult
    func startTask(name: String, icon: String, color: Color) -> UUID {
        let task = BackgroundTask(name: name, icon: icon, color: color)
        tasks.append(task)

        // Keep only last 10 completed tasks
        let completed = tasks.filter { $0.isComplete || $0.isFailed }
        if completed.count > 10 {
            let toRemove = completed.prefix(completed.count - 10)
            tasks.removeAll { task in toRemove.contains { $0.id == task.id } }
        }

        return task.id
    }

    /// Update task progress
    func updateProgress(_ taskId: UUID, progress: Double, status: String = "") {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].progress = progress
        if !status.isEmpty {
            tasks[index].status = status
        }
    }

    /// Mark task as complete
    func completeTask(_ taskId: UUID, status: String = "Complete") {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].progress = 1.0
        tasks[index].status = status
        tasks[index].isComplete = true
    }

    /// Mark task as failed
    func failTask(_ taskId: UUID, error: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].status = error
        tasks[index].isFailed = true
    }

    /// Remove a task
    func removeTask(_ taskId: UUID) {
        tasks.removeAll { $0.id == taskId }
    }

    /// Cancel a task (mark as failed with cancelled status)
    func cancelTask(_ taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].status = "Cancelled"
        tasks[index].isFailed = true
    }

    /// Cancel all running tasks for a feature (by name prefix)
    func cancelTasksForFeature(_ featurePrefix: String) {
        for i in tasks.indices {
            if tasks[i].name.contains(featurePrefix) && tasks[i].isRunning {
                tasks[i].status = "Cancelled"
                tasks[i].isFailed = true
            }
        }
    }

    /// Get current running task for a feature
    func runningTaskForFeature(_ featurePrefix: String) -> BackgroundTask? {
        tasks.first { $0.name.contains(featurePrefix) && $0.isRunning }
    }

    /// Clear all completed tasks
    func clearCompleted() {
        tasks.removeAll { $0.isComplete || $0.isFailed }
    }
}

// MARK: - Task Indicator View (for sidebar)

struct TaskIndicatorDot: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.8), radius: isAnimating ? 4 : 2)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Running Tasks Panel

struct RunningTasksPanel: View {
    @ObservedObject var taskManager = BackgroundTaskManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nukeNeonOrange)

                Text("BACKGROUND TASKS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextSecondary)

                Spacer()

                if !taskManager.tasks.filter({ $0.isComplete || $0.isFailed }).isEmpty {
                    Button {
                        taskManager.clearCompleted()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().overlay(Color.nukeSurfaceHighlight)

            if taskManager.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.nukeTextTertiary)
                    Text("No background tasks")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(taskManager.tasks) { task in
                            TaskRowView(task: task)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 280)
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.3), radius: 10)
    }
}

struct TaskRowView: View {
    let task: BackgroundTask

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(task.color.opacity(0.15))
                    .frame(width: 28, height: 28)

                if task.isRunning {
                    NukeSpinner(size: 14, color: task.color)
                } else if task.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.nukeToxicGreen)
                } else if task.isFailed {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.nukeNeonRed)
                } else {
                    Image(systemName: task.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(task.color)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.nukeTextPrimary)
                    .lineLimit(1)

                if task.isRunning {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.nukeSurfaceHighlight)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(task.color)
                                .frame(width: geo.size.width * task.progress)
                        }
                    }
                    .frame(height: 3)
                } else {
                    Text(task.status)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nukeTextTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Duration or status
            if task.isRunning {
                Text(task.formattedDuration)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.nukeTextTertiary)
            }
        }
        .padding(8)
        .background(Color.nukeSurfaceHighlight.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
