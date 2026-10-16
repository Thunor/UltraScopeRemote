import SwiftUI

// MARK: - GOTO Target Picker

struct GotoView: View {
    /// Called with the chosen target; the sheet dismisses itself afterwards.
    let onSelect: (SkyPosition) -> Void
    /// Called when the user syncs on a target they have centered in the eyepiece.
    var onSync: ((SkyPosition) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var locator = LocationProvider()
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if let location = locator.location {
                    // Re-evaluate every 30 s so altitudes and the "visible now" list keep up with the sky.
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        targetList(Sky.snapshot(at: context.date,
                                                latitude: location.coordinate.latitude,
                                                longitude: location.coordinate.longitude))
                    }
                } else if locator.isDenied {
                    ContentUnavailableView(
                        "Location Needed",
                        systemImage: "location.slash",
                        description: Text("Allow location access in Settings so the app can work out which objects are above your horizon.")
                    )
                } else {
                    ProgressView("Finding your location…")
                        .tint(.red)
                }
            }
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search stars, planets, nebulae")
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .foregroundStyle(.red)
            .navigationTitle("GOTO")
            .navigationBarTitleTextColor(.red)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.red)
                }
            }
        }
        .tint(.red)
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
        .task { await locator.start() }
    }

    @ViewBuilder
    private func targetList(_ sky: Sky.Snapshot) -> some View {
        let search = query.trimmingCharacters(in: .whitespaces)
        List {
            if search.isEmpty {
                let best = sky.brightestVisible()
                Section {
                    if best.isEmpty {
                        Text("Nothing bright enough is visible right now.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(best) { row($0) }
                } header: {
                    Text("Brightest Visible Now")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if sky.sunAltitude > -6 {
                            Text("The sky is still bright, so only the brightest objects are listed. Search to see everything.")
                        }
                        if onSync != nil {
                            Text("Before your first GOTO, center a target in the eyepiece, then swipe right on it and tap Sync.")
                        }
                    }
                }
            } else {
                // Slewable targets first, then by brightness.
                let matches = sky.positions
                    .filter { matches($0.object, search) }
                    .sorted { ($0.canSlew ? 0 : 1, $0.magnitude) < ($1.canSlew ? 0 : 1, $1.magnitude) }
                if matches.isEmpty {
                    ContentUnavailableView.search(text: search)
                        .listRowBackground(Color.clear)
                }
                ForEach(matches) { row($0) }
            }
        }
    }

    private func matches(_ object: CelestialObject, _ text: String) -> Bool {
        [object.name, object.detail, object.kind.rawValue]
            .contains { $0.localizedStandardContains(text) }
    }

    private func row(_ target: SkyPosition) -> some View {
        Button {
            onSelect(target)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: target.object.kind.icon)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.object.name)
                        .font(.body.weight(.semibold))
                    Text(target.object.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("mag \(target.magnitude, format: .number.precision(.fractionLength(1)))")
                        .font(.caption.monospacedDigit())
                    Text(status(target))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.red)
        }
        .disabled(!target.canSlew)
        .opacity(target.canSlew ? 1 : 0.4)
        .swipeActions(edge: .leading) {
            if let onSync {
                Button("Sync") {
                    onSync(target)
                    dismiss()
                }
                .tint(.red)
            }
        }
        .listRowBackground(Color.red.opacity(0.12))
    }

    private func status(_ target: SkyPosition) -> String {
        if target.isTooCloseToSun { return "Too close to Sun" }
        if !target.isAboveHorizon { return "Below horizon" }
        return "Alt \(Int(target.horizontal.alt.rounded()))° · \(target.horizontal.compass)"
    }
}

#Preview {
    GotoView { print($0.object.name) }
}
