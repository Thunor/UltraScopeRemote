import SwiftUI

// MARK: - 自訂發送指令（二級頁）

struct CommandSettingsView: View {
    @AppStorage("cmd.up") private var cmdUp = "F"
    @AppStorage("cmd.down") private var cmdDown = "B"
    @AppStorage("cmd.left") private var cmdLeft = "L"
    @AppStorage("cmd.right") private var cmdRight = "R"
    @AppStorage("cmd.stop") private var cmdStop = "S"

    var body: some View {
        Form {
            Section {
                row("前進", "arrow.up", $cmdUp)
                row("後退", "arrow.down", $cmdDown)
                row("左轉", "arrow.left", $cmdLeft)
                row("右轉", "arrow.right", $cmdRight)
                row("停止", "stop.fill", $cmdStop)
            } header: {
                Text("方向指令對應字元")
            } footer: {
                Text("按住方向鍵會送出對應字元、放開送出「停止」字元；Arduino 端依字元辨識動作。可輸入 1～8 個字元。")
            }

            Section {
                Button("恢復預設", role: .destructive) {
                    cmdUp = "F"; cmdDown = "B"; cmdLeft = "L"; cmdRight = "R"; cmdStop = "S"
                }
            }
        }
        .navigationTitle("自訂發送指令")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ icon: String, _ text: Binding<String>) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            TextField("字元", text: text)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .frame(maxWidth: 120)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let cleaned = String(newValue.filter { !$0.isNewline }.prefix(8))
                    if cleaned != newValue { text.wrappedValue = cleaned }
                }
        }
    }
}
