import SwiftUI

// MARK: - Remote Control Screen

struct RemoteView: View {
    @ObservedObject var bt: BluetoothManager
    @Environment(\.verticalSizeClass) private var vSize
    @State private var showPicker = false
    @State private var showSettings = false
    @AppStorage("preview.mode") private var previewMode = false
    @AppStorage("control.mode") private var modeRaw = ControlMode.joystick.rawValue
    @State private var lastDrive = ""
    @State private var hud = DriveHUD()
    #if targetEnvironment(simulator)
    @State private var showCommandsPreview = false
    #endif

    @AppStorage("joystick.maxRPM") private var maxRPM: Double = 50
    private let rpmCeiling: Double = 50

    @AppStorage("cmd.up") private var cmdNorth = "3"
    @AppStorage("cmd.down") private var cmdSouth = "4"
    @AppStorage("cmd.left") private var cmdWest = "2"
    @AppStorage("cmd.right") private var cmdEast = "1"
    @AppStorage("cmd.stop") private var cmdStop = "0"
    

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

    /// Joystick vector → Differential mixing → Left/Right wheel RPM → "M<L>,<R>\n" (deduplication to avoid redundant transmission)
    private func drive(_ v: CGVector) {
        let forward = max(-1, min(1, v.dy))
        let turn    = max(-1, min(1, v.dx))
        var left  = forward + turn
        var right = forward - turn
        let m = max(1, abs(left), abs(right))
        left /= m; right /= m
        let L = Int((left  * maxRPM).rounded())
        let R = Int((right * maxRPM).rounded())
        let cmd = "M\(L),\(R)\n"
        guard cmd != lastDrive else { return }
        lastDrive = cmd
        if L == 0 && R == 0 {
            hud = DriveHUD(icon: "stop.fill", label: "Stop", sending: false)
        } else {
            let deg = atan2(Double(L - R), Double(L + R)) * 180 / .pi
            hud = DriveHUD(icon: "arrow.up", label: "L \(L) · R \(R)",
                           sending: true, angle: deg, rotates: true)
        }
        emit(cmd)
    }

    private func stopDrive() {
        lastDrive = ""
        hud = DriveHUD(icon: "stop.fill", label: "Stop", sending: false)
        emit("M0,0\n")
    }

    /// Disc mode: update the HUD based on the sent character (matched against the custom command characters)
    private func discTapped(_ cmd: String) {
        emit(cmd)
        if      cmd == String(cmdStop)  { hud = DriveHUD(icon: "stop.fill",  label: "Stop", sending: false) }
        else if cmd == String(cmdNorth) { hud = DriveHUD(icon: "arrow.up",    label: "Forward", sending: true) }
        else if cmd == String(cmdSouth) { hud = DriveHUD(icon: "arrow.down",  label: "Backward", sending: true) }
        else if cmd == String(cmdWest)  { hud = DriveHUD(icon: "arrow.left",  label: "Turn Left", sending: true) }
        else if cmd == String(cmdEast)  { hud = DriveHUD(icon: "arrow.right", label: "Turn Right", sending: true) }
        else { hud = DriveHUD(icon: "dot.radiowaves.left.and.right", label: "Instruction \(cmd)", sending: true) }
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
        }
        .foregroundStyle(.red)
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
//                modeMenu
                Spacer()
            }
            .padding(.horizontal, 20)

            hudBar

            Spacer()

            controlPad

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
//                modeMenu
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
//            if mode == .joystick {
//                JoystickPad(size: padSize, onVector: drive, onRelease: stopDrive)
//            } else {
                ControlPad(discSize: padSize) { cmd in discTapped(cmd) }
//            }
        }
        .disabled(!isConnected)
        .allowsHitTesting(isConnected)
        .opacity(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.25), value: isConnected)
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

    private var modeMenu: some View {
        Menu {
            Picker("Control method", selection: $modeRaw) {
                Label("joystick", systemImage: "arcade.stick").tag(ControlMode.joystick.rawValue)
                Label("Directional Keys", systemImage: "circle.grid.cross.fill").tag(ControlMode.disc.rawValue)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode == .joystick ? "arcade.stick" : "circle.grid.cross.fill")
                Text(mode == .joystick ? "joystick" : "Directional keys")
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.headline)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .disabled(!isConnected)
        .opacity(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.25), value: isConnected)
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape")
        }
    }

    @ViewBuilder
    private var connectionButton: some View {
        switch bt.state {
        case .connecting:
            HStack(spacing: 6) {
                ProgressView()
                Text("Connecting...").fontWeight(.semibold)
            }
            .font(.subheadline)
        default:
            Button { showPicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: connectionIcon)
                    Text(connectionLabel)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
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

    private var connectionTint: Color {
        if bt.state == .connected { return .green }
        if previewMode { return .orange }
        return .red
    }
}

#Preview {
    @Previewable @StateObject var bt = BluetoothManager()
//    RemoteView(bt: bt)
    RemoteView(bt: bt)
}
