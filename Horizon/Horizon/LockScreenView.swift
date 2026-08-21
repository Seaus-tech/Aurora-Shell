import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @Binding var isLocked: Bool
    @State private var pin: String = ""
    @State private var authState: AuthState = .idle
    @State private var shake: Bool = false
    @State private var attempts: Int = 0
    @FocusState private var pinFocused: Bool

    enum AuthState {
        case idle, tryingBiometric, tryingKey, failed, success
    }

    var body: some View {
        ZStack {
            // Blurred terminal behind
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Gray overlay
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Lock icon
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 90, height: 90)
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

                    Image(systemName: authState == .success ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(authState == .failed ? .red : .white)
                        .symbolEffect(.bounce, value: authState == .success)
                        .contentTransition(.symbolEffect(.replace))
                }

                VStack(spacing: 6) {
                    Text("Aurora-Shell")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                // PIN dots — variable length, max 20
                HStack(spacing: 10) {
                    ForEach(0..<max(pin.count + 1, 4), id: \.self) { i in
                        if i < pin.count {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .scaleEffect(1.1)
                                .animation(.spring(response: 0.2), value: pin.count)
                        } else if i == pin.count {
                            // blinking cursor dot
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 10, height: 10)
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .offset(x: shake ? -8 : 0)
                .animation(shake ? .interpolatingSpring(stiffness: 800, damping: 10).repeatCount(4, autoreverses: true) : .default, value: shake)

                // Hidden text field — Enter key submits
                SecureField("", text: $pin)
                    .focused($pinFocused)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .onSubmit { attemptPIN() }
                    .onChange(of: pin) { _, new in
                        // limit length
                        if new.count > 20 { pin = String(new.prefix(20)) }
                    }

                // Tap to focus / method buttons
                VStack(spacing: 12) {
                    Button {
                        pinFocused = true
                    } label: {
                        Text("Enter PIN")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        // Touch ID
                        Button {
                            tryTouchID()
                        } label: {
                            Label("Touch ID", systemImage: "touchid")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        // Security Key
                        Button {
                            trySecurityKey()
                        } label: {
                            Label("Security Key", systemImage: "key.fill")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(40)
        }
        .onAppear {
            pinFocused = true
            tryTouchID()
        }
    }

    // MARK: - Status

    var statusText: String {
        switch authState {
        case .idle:           return "Locked"
        case .tryingBiometric: return "Waiting for Touch ID..."
        case .tryingKey:      return "Insert security key..."
        case .failed:         return attempts >= 5 ? "Too many attempts" : "Incorrect PIN — try again"
        case .success:        return "Unlocked"
        }
    }

    // MARK: - Auth Methods

    func tryTouchID() {
        authState = .tryingBiometric
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            authState = .idle; return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Aurora-Shell") { ok, _ in
            DispatchQueue.main.async {
                if ok { unlock() } else { authState = .idle }
            }
        }
    }

    func trySecurityKey() {
        authState = .tryingKey
        // Check USB presence via ioreg in background
        DispatchQueue.global().async {
            let result = shell("ioreg -p IOUSB -l -w 0 2>/dev/null | grep -qi \"$(security find-generic-password -a \"$USER\" -s aurora-shell-yubikey -w 2>/dev/null)\" && echo found || echo notfound")
            DispatchQueue.main.async {
                if result.trimmingCharacters(in: .whitespacesAndNewlines) == "found" {
                    unlock()
                } else {
                    authState = .idle
                }
            }
        }
    }

    func attemptPIN() {
        let stored = shell("security find-generic-password -a \"$USER\" -s aurora-shell-pin -w 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        if stored.isEmpty || pin == stored {
            unlock()
        } else {
            attempts += 1
            pin = ""
            authState = .failed
            shake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false; authState = .idle }
        }
    }

    func unlock() {
        authState = .success
        withAnimation(.spring(response: 0.4)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLocked = false
            }
        }
    }

    @discardableResult
    func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
