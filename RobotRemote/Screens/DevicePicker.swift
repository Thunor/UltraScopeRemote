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
                        Label("藍牙未開啟", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("請到「設定」開啟藍牙，並允許本 App 使用藍牙。")
                    }
                } else {
                    if bt.state == .connected, let name = bt.connectedName {
                        Section("已連線") {
                            HStack {
                                Label(name, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Spacer()
                                Button("中斷", role: .destructive) { bt.disconnect() }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }

                    Section {
                        ForEach(bt.discovered, id: \.identifier) { p in
                            Button { bt.connect(p); dismiss() } label: {
                                Label(p.name ?? "未命名裝置", systemImage: "cpu")
                            }
                        }
                        if bt.discovered.isEmpty {
                            Label(bt.state == .scanning ? "搜尋中…" : "尚未找到裝置",
                                  systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        HStack {
                            Text("可用裝置")
                            Spacer()
                            if bt.state == .scanning { ProgressView().controlSize(.small) }
                        }
                    }

                    #if targetEnvironment(simulator)
                    Section {
                        Button("預覽圓盤介面") { previewMode = true; dismiss() }
                    } footer: {
                        Text("模擬器無藍牙硬體，此選項僅供預覽介面。")
                    }
                    #endif
                }
            }
            .navigationTitle("裝置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { bt.startScan() }
            .onDisappear { bt.stopScan() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
