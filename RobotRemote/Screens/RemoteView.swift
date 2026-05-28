import SwiftUI

// MARK: - 遙控頁面

struct RemoteView: View {
    @ObservedObject var bt: BluetoothManager
    @State private var showPicker = false
    @AppStorage("preview.mode") private var previewMode = false
    @AppStorage("control.mode") private var modeRaw = ControlMode.joystick.rawValue
    @State private var lastDrive = ""
    @State private var hud = DriveHUD()
    #if targetEnvironment(simulator)
    @State private var showCommandsPreview = false
    #endif

    @AppStorage("joystick.maxRPM") private var maxRPM: Double = 50
    private let rpmCeiling: Double = 50

    @AppStorage("cmd.up") private var cmdUp = "F"
    @AppStorage("cmd.down") private var cmdDown = "B"
    @AppStorage("cmd.left") private var cmdLeft = "L"
    @AppStorage("cmd.right") private var cmdRight = "R"
    @AppStorage("cmd.stop") private var cmdStop = "S"

    private var mode: ControlMode { ControlMode(rawValue: modeRaw) ?? .joystick }
    private var isConnected: Bool { bt.state == .connected || previewMode }

    /// 送出單一指令字串。真的連線時一律送出；未連線且開啟預覽模式時只印出（供測試介面）。
    private func emit(_ cmd: String) {
        if bt.state == .connected { bt.send(cmd) }
        else if previewMode { print("send: \(cmd)") }
    }

    /// 搖桿向量 → 差速混控 → 左右輪 RPM → "M<L>,<R>\n"（去重避免重複送）。
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
            hud = DriveHUD(icon: "stop.fill", label: "停止", sending: false)
        } else {
            let deg = atan2(Double(L - R), Double(L + R)) * 180 / .pi
            hud = DriveHUD(icon: "arrow.up", label: "L \(L) · R \(R)",
                           sending: true, angle: deg, rotates: true)
        }
        emit(cmd)
    }

    private func stopDrive() {
        lastDrive = ""
        hud = DriveHUD(icon: "stop.fill", label: "停止", sending: false)
        emit("M0,0\n")
    }

    /// 圓盤模式：依送出的字元更新 HUD（對照自訂指令字元）。
    private func discTapped(_ cmd: String) {
        emit(cmd)
        if cmd == cmdStop      { hud = DriveHUD(icon: "stop.fill",  label: "停止", sending: false) }
        else if cmd == cmdUp   { hud = DriveHUD(icon: "arrow.up",    label: "前進", sending: true) }
        else if cmd == cmdDown { hud = DriveHUD(icon: "arrow.down",  label: "後退", sending: true) }
        else if cmd == cmdLeft { hud = DriveHUD(icon: "arrow.left",  label: "左轉", sending: true) }
        else if cmd == cmdRight{ hud = DriveHUD(icon: "arrow.right", label: "右轉", sending: true) }
        else                   { hud = DriveHUD(icon: "dot.radiowaves.left.and.right", label: "指令 \(cmd)", sending: true) }
    }

    /// 圓盤模式：把滑桿轉速同步給 Arduino（設定 F/B/L/R 的執行速度）。
    private func sendDiscSpeed() {
        emit("V\(Int(maxRPM))\n")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack {
                    modeMenu
                    Spacer()
                }
                .padding(.horizontal, 20)

                Group {
                    if isConnected {
                        commandHUD
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(height: 44)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isConnected)

                Spacer()

                Group {
                    if mode == .joystick {
                        JoystickPad(size: 300, onVector: drive, onRelease: stopDrive)
                    } else {
                        ControlPad(discSize: 300) { cmd in discTapped(cmd) }
                    }
                }
                .disabled(!isConnected)
                .allowsHitTesting(isConnected)
                .opacity(isConnected ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.25), value: isConnected)

                speedControl

                statusLine

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("遙控")
            .onChange(of: modeRaw) { _, _ in
                guard isConnected else { return }
                stopDrive()
                if mode == .disc { sendDiscSpeed() }
            }
            .onChange(of: Int(maxRPM)) { _, _ in
                if isConnected && mode == .disc { sendDiscSpeed() }
            }
            .onChange(of: bt.state) { _, newState in
                if newState == .connected && mode == .disc { sendDiscSpeed() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { connectionButton }
            }
            .sheet(isPresented: $showPicker) {
                DevicePicker(bt: bt, previewMode: $previewMode)
            }
            #if targetEnvironment(simulator)
            .sheet(isPresented: $showCommandsPreview) {
                NavigationStack { CommandSettingsView() }
                    .presentationDetents([.medium, .large])
            }
            #endif
        }
        #if targetEnvironment(simulator)
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-preview") { previewMode = true }
            if args.contains("-picker") { showPicker = true }
            if args.contains("-commands") { showCommandsPreview = true }
        }
        #endif
    }

    /// 動態島風格的指令浮層：即時顯示正在發送的指令。
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

    private var speedControl: some View {
        VStack(spacing: 6) {
            HStack {
                Label(mode == .joystick ? "轉速上限" : "轉速",
                      systemImage: "gauge.with.dots.needle.50percent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(maxRPM)) RPM")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            HStack(spacing: 12) {
                Image(systemName: "tortoise.fill").foregroundStyle(.secondary)
                Slider(value: $maxRPM, in: 5...rpmCeiling, step: 1)
                Image(systemName: "hare.fill").foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 340)
        .disabled(!isConnected)
        .opacity(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.25), value: isConnected)
    }

    private var modeMenu: some View {
        Menu {
            Picker("控制方式", selection: $modeRaw) {
                Label("搖桿", systemImage: "arcade.stick").tag(ControlMode.joystick.rawValue)
                Label("方向鍵", systemImage: "circle.grid.cross.fill").tag(ControlMode.disc.rawValue)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode == .joystick ? "arcade.stick" : "circle.grid.cross.fill")
                Text(mode == .joystick ? "搖桿" : "方向鍵")
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

    @ViewBuilder
    private var connectionButton: some View {
        switch bt.state {
        case .connecting:
            ProgressView()
        default:
            Button { showPicker = true } label: {
                Image(systemName: isConnected
                      ? "antenna.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right.slash")
            }
            .tint(isConnected ? .green : .red)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let name = bt.connectedName, bt.state == .connected {
            Label(name, systemImage: "dot.radiowaves.left.and.right")
                .font(.subheadline).foregroundStyle(.green)
        } else if previewMode {
            Label("預覽模式 · 未連線", systemImage: "eye")
                .font(.subheadline).foregroundStyle(.orange)
        } else {
            Text("未連線 · 點右上角 \(Image(systemName: "antenna.radiowaves.left.and.right.slash")) 連線裝置")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
