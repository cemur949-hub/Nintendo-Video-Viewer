import SwiftUI

@MainActor
struct LockSection: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingEmergencyUnlock = false

    var body: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: model.isEffectivelyLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(model.isEffectivelyLocked ? .accentColor : .secondary)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isEffectivelyLocked ? "Locked" : "Unlocked").font(.title2.bold())
                    if model.isLocked, let lockedAt = model.lockedAt {
                        Text("Since \(lockedAt, style: .time)").font(.subheadline).foregroundColor(.secondary)
                    }
                    if model.isScheduleActive {
                        Text("Scheduled lock is running").font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)

            if model.isEffectivelyLocked {
                Button {
                    Task { await model.unlockWithTag() }
                } label: {
                    Label("Scan tag to unlock", systemImage: "wave.3.right")
                }
                .disabled(!model.canUnlockWithTag)

                Button(role: .destructive) {
                    showingEmergencyUnlock = true
                } label: {
                    Label("Emergency unlock", systemImage: "exclamationmark.triangle")
                }
            } else {
                Button {
                    model.lock()
                } label: {
                    Label("Lock now", systemImage: "lock")
                }
                .disabled(!model.canLock)
            }
        } footer: {
            Text(footer)
        }
        .sheet(isPresented: $showingEmergencyUnlock) {
            EmergencyUnlockView(delay: model.emergencyUnlockDelay) { model.emergencyUnlock() }
        }
    }

    private var footer: String {
        if !model.report.canBlockApps {
            return "Locking needs Screen Time access. See “Needs attention” above."
        }
        if model.isEffectivelyLocked && !model.report[.nfc].isUsable {
            return "This copy can't read NFC tags, so use Emergency unlock."
        }
        if !model.isEffectivelyLocked && model.selection.blocksNothing {
            return "Choose what to block below, then lock."
        }
        return "Scan a registered tag to unlock."
    }
}
