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
                row("Forward", "arrow.up", $cmdUp)
                row("Backward", "arrow.down", $cmdDown)
                row("Left", "arrow.left", $cmdLeft)
                row("Right", "arrow.right", $cmdRight)
                row("Stop", "stop.fill", $cmdStop)
            } header: {
                Text("Characters corresponding to directional commands")
            } footer: {
                Text("Holding down a directional key sends the corresponding character, while releasing it sends a 'stop' character; the Arduino identifies the action based on the character received. You can input between 1 and 8 characters.")
            }

            Section {
                Button("Restore Defaults", role: .destructive) {
                    cmdUp = "F"; cmdDown = "B"; cmdLeft = "L"; cmdRight = "R"; cmdStop = "S"
                }
            }
        }
        .navigationTitle("Custom Send Command")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ icon: String, _ text: Binding<String>) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            TextField("Character", text: text)
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
