import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @StateObject private var bt = BluetoothManager()

    var body: some View {
        RemoteView(bt: bt)
    }
}

#Preview {
    ContentView()
}
