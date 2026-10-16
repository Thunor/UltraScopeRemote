import SwiftUI

// MARK: - Remote Control Screen

struct RemoteView: View {
    @ObservedObject var bt: BluetoothManager
    @Environment(\.verticalSizeClass) private var vSize
    @State private var showPicker = false
    @State private var showSettings = false
    @State private var showGoto = false
    @AppStorage("preview.mode") private var previewMode = false
    @AppStorage("control.mode") private var modeRaw = ControlMode.joystick.rawValue
    @State private var lastDrive = ""
    @State private var hud = DriveHUD()
    @State private var trackEnabled: Bool = false
    #if targetEnvironment(simulator)
    @State private var showCommandsPreview = false
    #endif

    @AppStorage("joystick.maxRPM") private var maxRPM: Double = 50
    private let rpmCeiling: Double = 50

    private var mode: ControlMode { ControlMode(rawValue: modeRaw) ?? .joystick }
    private var isConnected: Bool { bt.state == .connected || previewMode }

    /// When the height is "compact"—such as when a phone is held horizontally or an iPad is in
    /// split-screen mode—switch to a horizontal layout.
    private var isLandscape: Bool { vSize == .compact }
    private var padSize: CGFloat { isLandscape ? 260 : 300 }

    /// Sends a single command string. It is always sent when actually connected; if not
    /// connected but preview mode is enabled, it is merely printed (for interface testing).
    private func emit(_ cmd: String) {
        if bt.state == .connected { bt.send(cmd) }
        print("send: \(cmd)")
    }

    private func stopDrive() {
        lastDrive = ""
        hud = DriveHUD(icon: "stop.fill", label: "Stop", sending: false)
        emit(GCode.stop)
    }

    /// Disc mode: send the G-code and describe it in the HUD.
    private func discTapped(_ cmd: String) {
        emit(cmd)
        if cmd == GCode.stop {
            hud = DriveHUD(icon: "stop.fill", label: "Stop", sending: false)
        } else if let d = Direction.allCases.first(where: { GCode.jog($0) == cmd }) {
            hud = DriveHUD(icon: "arrow.\(d.icon.dropFirst("chevron.".count))", label: "Nudge \(d.compassName)", sending: true)
        } else if let d = Direction.allCases.first(where: { GCode.fastMove($0) == cmd }) {
            hud = DriveHUD(icon: "arrow.\(d.icon.dropFirst("chevron.".count))", label: "Fast \(d.compassName)", sending: true)
        } else {
            hud = DriveHUD(icon: "dot.radiowaves.left.and.right", label: cmd, sending: true)
        }
    }

    /// Sends a GOTO as equatorial coordinates of date, e.g. "G0A05.9195D+07.4071".
    private func goto(_ target: SkyPosition) {
        hud = DriveHUD(icon: "scope", label: "GOTO \(target.object.name)", sending: true)
        emit(GCode.goto(target.equatorial))
    }

    /// Tells the controller it is centered on `target` (needed before the first GOTO).
    private func sync(_ target: SkyPosition) {
        hud = DriveHUD(icon: "scope", label: "Synced on \(target.object.name)", sending: false)
        emit(GCode.sync(target.equatorial))
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .navigationBarTitle("Scope Control")
            .navigationBarTitleTextColor(Color.red)
            .onChange(of: modeRaw) { _, _ in
                guard isConnected else { return }
                stopDrive()
            }
            .onChange(of: bt.scope.mode) { _, mode in
                trackEnabled = mode == .track
            }
            .onChange(of: bt.scope.errorCount) { _, _ in
                hud = DriveHUD(icon: "exclamationmark.triangle.fill", label: bt.scope.errorMessage, sending: false)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { settingsButton }
                ToolbarItem(placement: .topBarTrailing) { connectionButton }
            }
            .sheet(isPresented: $showPicker) {
                DevicePicker(bt: bt, previewMode: $previewMode)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showGoto) {
                GotoView(onSelect: { goto($0) }, onSync: { sync($0) })
            }
        }
        .foregroundStyle(.red)
        .tint(.red)
        // Always dark so sheets and system chrome never flash white at the eyepiece.
        .preferredColorScheme(.dark)
        #if targetEnvironment(simulator)
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-preview") { previewMode = true }
            if args.contains("-picker") { showPicker = true }
            if args.contains("-commands") { showCommandsPreview = true }
        }
        #endif
    }

    /// Vertical orientation: Stacked vertically from top to bottom.
    private var portraitLayout: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
            }
            .padding(.horizontal, 20)

            hudBar

            scopeStatus

            Spacer()

            controlPad
            
            Spacer()
            
            // gotoCoords
            gotoCoords
            
            Spacer()
            
            // track button
            trackButton

            Spacer()
            Spacer()
        }
        .background(Color.black)
        .frame(maxWidth: .infinity)
    }

    /// Horizontal layout: control panel on the left, speed zone on the right;
    /// HUD overlay at the top (does not take up bar height or obscure the title).
    private var landscapeLayout: some View {
        HStack(spacing: 24) {
            VStack() {
                controlPad
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .background(Color.black)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .top) { hudBar }
    }

    /// Control pad: Joystick or directional buttons; enabled based on connection status.
    private var controlPad: some View {
        Group {
            ControlPad(discSize: padSize) { cmd in discTapped(cmd) }
        }
        .disabled(!isConnected)
        .allowsHitTesting(isConnected)
        .opacity(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.25), value: isConnected)
    }
    
    private var gotoCoords: some View {
        VStack() {
            Text("GOTO")
        }
        .disabled(!isConnected)
        .allowsHitTesting(isConnected)
        .opacity(isConnected ? 1 : 0.3)
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(Capsule().fill(.black))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .scaleEffect(hud.sending ? 1.04 : 1)
        .animation(.easeInOut(duration: 0.25), value: isConnected)
        .onTapGesture { showGoto = true }
    }

    private var trackButton: some View {
        VStack() {
            Text("Track")
        }
        .disabled(!isConnected)
        .allowsHitTesting(isConnected)
        .opacity(isConnected ? 1 : 0.3)
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(Capsule().fill(.black))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .scaleEffect(hud.sending ? 1.04 : 1)
        .animation(.easeInOut(duration: 0.25), value: isConnected)
        .onTapGesture {
            if trackEnabled {
                print("goto manual mode")
                emit(GCode.trackOff)
                trackEnabled.toggle()
            } else {
                print("goto track mode")
                emit(GCode.trackOn)
                trackEnabled.toggle()
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// What the controller reports: direction of motion, mode and pointing position.
    private var scopeStatus: some View {
        VStack(spacing: 4) {
            if bt.state == .connected {
                Text("\(bt.scope.directionLabel) · \(bt.scope.mode.label)")
                Text(bt.scope.position?.formatted ?? "Not synced")
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(Color.red.opacity(0.8))
        .frame(height: 36)
    }

    /// HUD Fixed-height container within the overlay (visible only when connecting)
    private var hudBar: some View {
        Group {
            if isConnected {
                commandHUD
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(height: 44)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isConnected)
    }

    /// Dynamic Island-style command overlay: Instantly displays commands currently being sent.
    private var commandHUD: some View {
        HStack(spacing: 10) {
            Image(systemName: hud.icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(hud.sending ? Color.green : Color.white.opacity(0.55))
                .rotationEffect(.degrees(hud.rotates ? hud.angle : 0))
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hud.angle)
            Text(hud.label)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(Capsule().fill(.black))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .scaleEffect(hud.sending ? 1.04 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hud)
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(.red)
        }
        .tint(.red)
    }

    @ViewBuilder
    private var connectionButton: some View {
        switch bt.state {
        case .connecting:
            HStack(spacing: 6) {
                ProgressView()
                    .tint(.red)
                Text("Connecting...").fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(Color.red.opacity(0.7))
        default:
            Button { showPicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: connectionIcon)
                    Text(connectionLabel)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(connectionTint)
            }
            .tint(connectionTint)
        }
    }

    private var connectionIcon: String {
        if bt.state == .connected { return "antenna.radiowaves.left.and.right" }
        if previewMode { return "eye" }
        return "antenna.radiowaves.left.and.right.slash"
    }

    private var connectionLabel: String {
        if let name = bt.connectedName, bt.state == .connected { return name }
        if previewMode { return "preview mode" }
        return "Not connected"
    }

    /// Stays within red shades to preserve night vision; brightness indicates state.
    private var connectionTint: Color {
        if bt.state == .connected { return .red }
        if previewMode { return .red.opacity(0.7) }
        return .red.opacity(0.45)
    }
}

#Preview {
    @Previewable @StateObject var bt = BluetoothManager()
    RemoteView(bt: bt)
}
