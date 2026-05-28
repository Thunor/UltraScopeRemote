import SwiftUI

// MARK: - 根視圖（Tab 切換）

struct ContentView: View {
    @StateObject private var bt = BluetoothManager()

    var body: some View {
        TabView {
            Tab("遙控", systemImage: "dot.radiowaves.left.and.right") {
                RemoteView(bt: bt)
            }
            Tab("設定", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
