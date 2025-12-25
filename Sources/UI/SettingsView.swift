import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Notch Buddy Settings")
                .font(.system(size: 18, weight: .semibold))
            Text("More settings will be added over time.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 360, height: 160)
    }
}
