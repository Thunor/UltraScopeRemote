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
                        .listRowBackground(Color.red.opacity(0.12))
                    if let url = URL(string: "https://thunor.github.io") {
                        linkRow("GitHub Page", url: url)
                            .listRowBackground(Color.red.opacity(0.12))
                    }
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
            // Hide the default grouped (white/gray) list background for a dark, red-only palette.
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .foregroundStyle(.red)
            .navigationTitle("Setting")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.red)
                }
            }
        }
        .tint(.red)
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
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
