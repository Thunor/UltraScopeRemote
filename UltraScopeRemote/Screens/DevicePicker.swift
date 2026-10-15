import SwiftUI

// MARK: - Device Picker Sheet

struct DevicePicker: View {
    @ObservedObject var bt: BluetoothManager
    @Binding var previewMode: Bool
    @Environment(\.dismiss) private var dismiss

    /// Dim red row fill so list cells don't use the system gray.
    private let rowBackground = Color.red.opacity(0.12)

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
                    .listRowBackground(rowBackground)
                } else {
                    if bt.state == .connected, let name = bt.connectedName {
                        Section("Connected") {
                            HStack {
                                Label(name, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.red)
                                Spacer()
                                Button("Interrupt", role: .destructive) { bt.disconnect() }
                                    .buttonStyle(.borderless)
                            }
                        }
                        .listRowBackground(rowBackground)
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
                    .listRowBackground(rowBackground)

                    #if targetEnvironment(simulator)
                    Section {
                        Button("Preview Disc Interface") { previewMode = true; dismiss() }
                    } footer: {
                        Text("The emulator lacks Bluetooth hardware; this option is for interface preview purposes only.")
                    }
                    .listRowBackground(rowBackground)
                    #endif
                }
            }
            // Hide the List's default grouped background, which turns white at the large detent.
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .foregroundStyle(.red)
            .navigationTitle("device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.red)
                }
            }
            .onAppear { bt.startScan() }
            .onDisappear { bt.stopScan() }
        }
        .tint(.red)
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
