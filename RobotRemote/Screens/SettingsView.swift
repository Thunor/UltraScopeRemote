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
                        Text("自訂發送指令")
                    }
                } header: {
                    Text("控制")
                } footer: {
                    Text("自訂每個方向與停止鍵送出的 ASCII 字元。")
                }

                // ── 測試 ──────────────────────────────────────────────
                Section {
                    Toggle(isOn: $previewMode) {
                        Text("預覽模式")
                    }
                } header: {
                    Text("測試")
                } footer: {
                    Text("預覽模式開啟後，不需連接藍牙即可操作介面，方便在實機上測試搖桿、方向鍵與指令浮層；實際連線時指令仍會正常送出。")
                }

                // ── 開發 ──────────────────────────────────────────────
                Section {
                    LabeledContent("開發者", value: "John Lin")
                    linkRow("GitHub 儲存庫", url: repoURL)
                } header: {
                    Text("開發")
                } footer: {
                    Text("本專案以 MIT 授權開源，歡迎一起貢獻。")
                }

                // ── 版本與版權（底部）────────────────────────────────
                Section {
                    VStack(spacing: 4) {
                        Text("版本 \(version)")
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
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
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
