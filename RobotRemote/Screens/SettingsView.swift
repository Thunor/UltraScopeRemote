import SwiftUI

// MARK: - 設定頁面

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preview.mode") private var previewMode = false

    private let repoURL = URL(string: "https://github.com/robotctust/robot-bluetooth-remote-app-for-ios")!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                // ── 控制 ──────────────────────────────────────────────
                Section {
                    NavigationLink {
                        CommandSettingsView()
                    } label: {
                        Text("Custom Send Command")
                    }
                } header: {
                    Text("Control")
                } footer: {
                    Text("Customize the ASCII characters sent for each direction and the stop key.")
                }

                // ── 測試 ──────────────────────────────────────────────
                Section {
                    Toggle(isOn: $previewMode) {
                        Text("Preview Mode")
                    }
                } header: {
                    Text("Test")
                } footer: {
                    Text("Once preview mode is enabled, you can operate the interface without a Bluetooth connection, making it convenient to test the joystick, directional buttons, and command overlays on the actual device; commands will still be transmitted normally when the device is actually connected.")
                }

                // ── 開發 ──────────────────────────────────────────────
                Section {
                    LabeledContent("開發者", value: "John Lin")
                    linkRow("GitHub 儲存庫", url: repoURL)
                } header: {
                    Text("Development")
                } footer: {
                    Text("This project is open-source under the MIT License; contributions are welcome.")
                }

                // ── 版本與版權（底部）────────────────────────────────
                Section {
                    VStack(spacing: 4) {
                        Text("Version \(version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Copyright @ 2026 中臺機器人研究社")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Setting")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { dismiss() }
                }
            }
        }
    }

    private func linkRow(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    SettingsView()
}
