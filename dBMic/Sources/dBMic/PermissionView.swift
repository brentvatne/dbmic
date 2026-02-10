import SwiftUI

/// Shown in the popover when microphone permission has not been granted.
struct PermissionView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Microphone Access Required")
                .font(.headline)

            Text("dBMic needs access to your microphone to display audio input levels.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Access") {
                onRequest()
            }
            .buttonStyle(.borderedProminent)

            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderless)
            .foregroundColor(.accentColor)
            .font(.subheadline)
        }
        .padding(24)
        .frame(width: 280)
    }
}
