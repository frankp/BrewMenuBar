import SwiftUI

struct PreferencesView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 3600.0  // Default to 1 hour
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    private let refreshIntervals: [(label: String, value: Double)] = [
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("4 hours", 14400),
        ("12 hours", 43200),
        ("24 hours", 86400),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preferences")
                .font(.title)

            Picker("Refresh Interval:", selection: $refreshInterval) {
                ForEach(refreshIntervals, id: \.value) { interval in
                    Text(interval.label).tag(interval.value)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.shared.setLaunchAtLogin(enabled: newValue)
                }

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}
