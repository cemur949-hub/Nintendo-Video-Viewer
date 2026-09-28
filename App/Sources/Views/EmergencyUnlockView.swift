import SwiftUI

/// Unlock without a tag after a countdown. Also the fallback when NFC was stripped at signing.
@MainActor
struct EmergencyUnlockView: View {
    let delay: Int
    let onUnlock: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int

    init(delay: Int, onUnlock: @escaping () -> Void) {
        self.delay = delay
        self.onUnlock = onUnlock
        _remaining = State(initialValue: delay)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "hourglass")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("Emergency unlock").font(.title2.bold())
                Text("Use this if you lost your tag or this copy can't read NFC. Wait for the timer, then unlock.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Text(remaining > 0 ? "\(remaining)s" : "Ready")
                    .font(.system(size: 48, weight: .semibold, design: .rounded).monospacedDigit())
                Button {
                    onUnlock()
                    dismiss()
                } label: {
                    Text("Unlock now").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(remaining > 0)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
            }
        }
    }
}
