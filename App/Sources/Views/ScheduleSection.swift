import SwiftUI

@MainActor
struct ScheduleSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Section {
            Toggle("Lock on a schedule", isOn: Binding(
                get: { model.schedule.isEnabled },
                set: { model.setScheduleEnabled($0) }
            ))
            .disabled(!model.canSchedule && !model.schedule.isEnabled)

            DatePicker("From", selection: Binding(
                get: { Self.date(hour: model.schedule.startHour, minute: model.schedule.startMinute) },
                set: { model.setScheduleTimes(start: $0) }
            ), displayedComponents: .hourAndMinute)

            DatePicker("Until", selection: Binding(
                get: { Self.date(hour: model.schedule.endHour, minute: model.schedule.endMinute) },
                set: { model.setScheduleTimes(end: $0) }
            ), displayedComponents: .hourAndMinute)
        } header: {
            Text("Schedule")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        if model.report[.familyControls] == .stripped {
            return "Needs the Family Controls entitlement, which was stripped at signing."
        }
        if model.report[.extensions] != .ready {
            return "Needs the Activity Monitor extension, which isn't installed in this copy."
        }
        if model.report[.appGroup] != .ready {
            return "Needs an App Group so the extension can read your block list."
        }
        return "Blocks the same apps every day in this window. The window can cross midnight."
    }

    nonisolated private static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
