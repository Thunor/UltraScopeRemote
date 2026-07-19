import SwiftUI

// MARK: - 裝置選擇器 Sheet

struct DevicePicker: View {
    @ObservedObject var bt: BluetoothManager
    @Binding var previewMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if bt.state == .poweredOff {
                    Section {
                        Label("Bluetooth is not turned on.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("Please go to 'Settings' to turn on Bluetooth and allow this app to use Bluetooth.")
                    }
                } else {
                    if bt.state == .connected, let name = bt.connectedName {
                        Section("Connected") {
                            HStack {
                                Label(name, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Spacer()
                                Button("Interrupt", role: .destructive) { bt.disconnect() }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }

                    Section {
                        ForEach(bt.discovered, id: \.identifier) { p in
                            Button { bt.connect(p); dismiss() } label: {
                                Label(p.name ?? "Unnamed Device", systemImage: "cpu")
                            }
                        }
                        if bt.discovered.isEmpty {
                            Label(bt.state == .scanning ? "Searching..." : "No device found yet",
                                  systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        HStack {
                            Text("Available devices")
                            Spacer()
                            if bt.state == .scanning { ProgressView().controlSize(.small) }
                        }
                    }

                    #if targetEnvironment(simulator)
                    Section {
                        Button("Preview Disc Interface") { previewMode = true; dismiss() }
                    } footer: {
                        Text("The emulator lacks Bluetooth hardware; this option is for interface preview purposes only.")
                    }
                    #endif
                }
            }
            .navigationTitle("device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { dismiss() }
                }
            }
            .onAppear { bt.startScan() }
            .onDisappear { bt.stopScan() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
