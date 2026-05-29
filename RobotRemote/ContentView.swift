import SwiftUI

// MARK: - 根視圖

struct ContentView: View {
    @StateObject private var bt = BluetoothManager()

    var body: some View {
        RemoteView(bt: bt)
    }
}

#Preview {
    ContentView()
}
