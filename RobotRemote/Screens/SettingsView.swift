import SwiftUI

// MARK: - Settings Screen

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Development ──────────────────────────────────────────────
                Section {
                    LabeledContent("Developer", value: "Eric Freitas")
                } header: {
                    Text("Development")
                } footer: {
                    Text("This project is open-source under the MIT License; contributions are welcome.")
                }

                // ── Version and copyright (bottom) ────────────────────────────────
                Section {
                    VStack(spacing: 4) {
                        Text("Version \(version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Copyright @ 2026 Eric Freitas")
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
                    Button("Close") { dismiss() }
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
