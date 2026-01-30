import SwiftUI

/// Scheduled scans manager - automate cleanup tasks
struct ScheduledScansView: View {
    @State private var schedules: [ScheduledScan] = []
    @State private var showingAddSheet = false
    @State private var editingSchedule: ScheduledScan?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(Color.nukeSurfaceHighlight)

            if schedules.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(schedules.enumerated()), id: \.element.id) { index, schedule in
                            scheduleCard(schedule, index: index)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.nukeBackground)
        .onAppear {
            loadSchedules()
        }
        .sheet(isPresented: $showingAddSheet) {
            scheduleEditorSheet(schedule: nil)
        }
        .sheet(item: $editingSchedule) { schedule in
            scheduleEditorSheet(schedule: schedule)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCHEDULED SCANS")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextPrimary)

                let enabledCount = schedules.filter { $0.isEnabled }.count
                Text("\(enabledCount) of \(schedules.count) schedules active")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nukeTextSecondary)
            }

            Spacer()

            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("NEW SCHEDULE")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.nukeToxicGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.nukeToxicGreen.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.nukeSurface)
    }

    // MARK: - Schedule Card

    private func scheduleCard(_ schedule: ScheduledScan, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Enable toggle
                Toggle("", isOn: Binding(
                    get: { schedule.isEnabled },
                    set: { newValue in
                        schedules[index].isEnabled = newValue
                        saveSchedules()
                    }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .frame(width: 40)

                // Schedule icon
                ZStack {
                    Circle()
                        .fill(schedule.isEnabled ? Color.nukeToxicGreen.opacity(0.15) : Color.nukeSurfaceHighlight)
                        .frame(width: 44, height: 44)

                    Image(systemName: frequencyIcon(schedule.frequency))
                        .font(.system(size: 18))
                        .foregroundStyle(schedule.isEnabled ? Color.nukeToxicGreen : Color.nukeTextTertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(schedule.isEnabled ? Color.nukeTextPrimary : Color.nukeTextSecondary)

                    HStack(spacing: 8) {
                        // Frequency badge
                        Text(schedule.frequency.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.nukeNeonOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.nukeNeonOrange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                        // Categories count
                        Text("\(schedule.categories.count) categories")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.nukeTextTertiary)

                        // Auto-clean badge
                        if schedule.autoClean {
                            Text("AUTO-CLEAN")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.nukeNeonRed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.nukeNeonRed.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }

                Spacer()

                // Next run info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next Run")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nukeTextTertiary)

                    if let nextRun = schedule.nextRun {
                        Text(nextRun, style: .relative)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.nukeTextSecondary)
                    } else {
                        Text("Not scheduled")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.nukeTextTertiary)
                    }
                }

                // Actions
                HStack(spacing: 8) {
                    Button {
                        editingSchedule = schedule
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.nukeCyan)
                    }
                    .buttonStyle(.plain)

                    Button {
                        deleteSchedule(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.nukeNeonRed)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            // Last run info
            if let lastRun = schedule.lastRun {
                Divider().overlay(Color.nukeSurfaceHighlight)

                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nukeTextTertiary)

                    Text("Last run: \(lastRun.formatted())")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nukeTextTertiary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.nukeSurfaceHighlight.opacity(0.3))
            }
        }
        .background(Color.nukeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(schedule.isEnabled ? Color.nukeToxicGreen.opacity(0.3) : Color.nukeSurfaceHighlight, lineWidth: 1)
        )
    }

    private func frequencyIcon(_ frequency: ScanFrequency) -> String {
        switch frequency {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.nukeTextTertiary)

            Text("Scheduled Scans")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.nukeTextPrimary)

            Text("Automate your cleanup tasks with\nscheduled scans and optional auto-cleaning.")
                .font(.system(size: 13))
                .foregroundStyle(Color.nukeTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("CREATE SCHEDULE")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.nukePrimaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Schedule Editor Sheet

    private func scheduleEditorSheet(schedule: ScheduledScan?) -> some View {
        ScheduleEditorView(
            schedule: schedule,
            onSave: { newSchedule in
                if let existing = schedule,
                   let index = schedules.firstIndex(where: { $0.id == existing.id }) {
                    schedules[index] = newSchedule
                } else {
                    schedules.append(newSchedule)
                }
                saveSchedules()
                showingAddSheet = false
                editingSchedule = nil
            },
            onCancel: {
                showingAddSheet = false
                editingSchedule = nil
            }
        )
    }

    // MARK: - Actions

    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: "scheduled_scans"),
           let decoded = try? JSONDecoder().decode([ScheduledScan].self, from: data) {
            schedules = decoded
        }
    }

    private func saveSchedules() {
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: "scheduled_scans")
        }
    }

    private func deleteSchedule(at index: Int) {
        schedules.remove(at: index)
        saveSchedules()
    }
}

// MARK: - Schedule Editor View

struct ScheduleEditorView: View {
    let schedule: ScheduledScan?
    let onSave: (ScheduledScan) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var frequency: ScanFrequency = .weekly
    @State private var selectedCategories: Set<String> = []
    @State private var autoClean: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text(schedule == nil ? "New Schedule" : "Edit Schedule")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.nukeTextPrimary)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.nukeTextTertiary)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Color.nukeSurfaceHighlight)

            // Name
            VStack(alignment: .leading, spacing: 8) {
                Text("NAME")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextTertiary)

                TextField("Schedule name...", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.nukeSurfaceHighlight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Frequency
            VStack(alignment: .leading, spacing: 8) {
                Text("FREQUENCY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextTertiary)

                Picker("Frequency", selection: $frequency) {
                    ForEach(ScanFrequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Categories
            VStack(alignment: .leading, spacing: 8) {
                Text("CATEGORIES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nukeTextTertiary)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(CleanCategory.allCases) { category in
                            categoryToggle(category)
                        }
                    }
                }
                .frame(height: 150)
            }

            // Auto-clean toggle
            HStack {
                Toggle("Auto-clean after scan", isOn: $autoClean)
                    .toggleStyle(.switch)

                Spacer()

                if autoClean {
                    Text("⚠️ Deletes files automatically")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nukeNeonOrange)
                }
            }
            .padding(12)
            .background(autoClean ? Color.nukeNeonOrange.opacity(0.1) : Color.nukeSurfaceHighlight)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.nukeTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.nukeSurfaceHighlight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    save()
                } label: {
                    Text("Save Schedule")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.nukeToxicGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty || selectedCategories.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500, height: 550)
        .background(Color.nukeSurface)
        .onAppear {
            if let schedule = schedule {
                name = schedule.name
                frequency = schedule.frequency
                selectedCategories = Set(schedule.categories)
                autoClean = schedule.autoClean
            }
        }
    }

    private func categoryToggle(_ category: CleanCategory) -> some View {
        let isSelected = selectedCategories.contains(category.rawValue)

        return Button {
            if isSelected {
                selectedCategories.remove(category.rawValue)
            } else {
                selectedCategories.insert(category.rawValue)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))

                Text(category.rawValue)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? Color.nukeNeonOrange : Color.nukeTextSecondary)
            .padding(8)
            .background(isSelected ? Color.nukeNeonOrange.opacity(0.1) : Color.nukeSurfaceHighlight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let nextRun = Calendar.current.date(byAdding: frequency.calendarComponent, value: 1, to: Date())

        let newSchedule = ScheduledScan(
            id: schedule?.id ?? UUID(),
            name: name,
            frequency: frequency,
            categories: Array(selectedCategories),
            isEnabled: schedule?.isEnabled ?? true,
            autoClean: autoClean
        )

        var mutableSchedule = newSchedule
        mutableSchedule.nextRun = nextRun

        onSave(mutableSchedule)
    }
}

#Preview("Scheduled Scans") {
    ScheduledScansView()
        .frame(width: 700, height: 500)
}
