import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var timerManager: TimerManager

    @State private var launchAtLogin: Bool
    @State private var workMinutes: String
    @State private var workSeconds: String
    @State private var breakMinutes: String
    @State private var breakSeconds: String
    @State private var earlyNotifyMinutes: String
    @State private var earlyNotifySeconds: String

    @State private var showAlert = false
    @State private var alertMessage = ""

    init() {
        let current = TimerManager.shared.settings
        if #available(macOS 13.0, *) {
            _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        } else {
            _launchAtLogin = State(initialValue: false)
        }

        _workMinutes = State(initialValue: String(current.workDurationMinutes))
        _workSeconds = State(initialValue: String(current.workDurationSeconds))
        _breakMinutes = State(initialValue: String(current.breakDurationMinutes))
        _breakSeconds = State(initialValue: String(current.breakDurationSeconds))
        _earlyNotifyMinutes = State(initialValue: String(current.earlyNotifyMinutes))
        _earlyNotifySeconds = State(initialValue: String(current.earlyNotifySeconds))
    }

    private var hasUnsavedTimeChanges: Bool {
        let current = timerManager.settings
        return workMinutes != String(current.workDurationMinutes)
            || workSeconds != String(current.workDurationSeconds)
            || breakMinutes != String(current.breakDurationMinutes)
            || breakSeconds != String(current.breakDurationSeconds)
            || earlyNotifyMinutes != String(current.earlyNotifyMinutes)
            || earlyNotifySeconds != String(current.earlyNotifySeconds)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                basicSettingsSection
                timeSettingsSection
                smartDelaySection
            }
            .padding(24)
        }
        .frame(width: 460, height: 640)
        .onAppear {
            syncLaunchAtLoginStatus()
            syncDraftFromSettings(timerManager.settings)
        }
        .alert("设置错误", isPresented: $showAlert) {
            Button("确定", action: {})
                .buttonStyle(.borderedProminent)
                .tint(.blue)
        } message: {
            Text(alertMessage)
        }
    }

    private var basicSettingsSection: some View {
        VStack(spacing: 15) {
            Text("基本设置")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 5)

            VStack(spacing: 12) {
                HStack {
                    Text("开机自启动")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            applyLaunchAtLogin(enabled: newValue)
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }

                HStack {
                    Text("显示跳过按钮")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $timerManager.settings.showSkipButton)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }

                HStack {
                    Text("显示程序坞图标")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $timerManager.settings.showDockIcon)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
        }
        .frame(maxWidth: .infinity)
    }

    private var timeSettingsSection: some View {
        VStack(spacing: 15) {
            Text("时间设置")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 5)

            VStack(spacing: 16) {
                timeInputRow(title: "专注时长", minutes: $workMinutes, seconds: $workSeconds)
                timeInputRow(title: "提前提醒", minutes: $earlyNotifyMinutes, seconds: $earlyNotifySeconds)
                timeInputRow(title: "休息时长", minutes: $breakMinutes, seconds: $breakSeconds)

                if hasUnsavedTimeChanges {
                    Text("有未应用的时间修改，点击“应用”生效")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                HStack(spacing: 14) {
                    Button(action: resetTimeSettings) {
                        Text("重置")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: applyTimeSettings) {
                        Text("应用")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(hasUnsavedTimeChanges ? Color.blue : Color.blue.opacity(0.6))
                                    .shadow(color: Color.blue.opacity(0.2), radius: 2, x: 0, y: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
        }
        .frame(maxWidth: .infinity)
    }

    private var smartDelaySection: some View {
        VStack(spacing: 15) {
            Text("智能延迟休息")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 5)

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("操作时延迟锁屏")
                            .font(.system(size: 14, weight: .medium))
                        Text("打字或操作鼠标时自动顺延，空闲后进入休息")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $timerManager.settings.smartDelayEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }

                if timerManager.settings.smartDelayEnabled {
                    Divider()

                    HStack {
                        Text("监听键盘输入")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $timerManager.settings.monitorKeyboard)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("监听鼠标操作")
                            Text("含点击、滚轮与超过 15pt 的移动")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $timerManager.settings.monitorMouse)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }

                    if !timerManager.settings.monitorKeyboard && !timerManager.settings.monitorMouse {
                        Text("当前未开启任何输入监听，到点将直接休息")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("空闲多久后休息")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Stepper(
                                "\(timerManager.settings.idleDelaySeconds) 秒",
                                value: $timerManager.settings.idleDelaySeconds,
                                in: 3...120,
                                step: 1
                            )
                            .monospacedDigit()
                        }

                        HStack(spacing: 8) {
                            Text("快捷:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            ForEach([5, 10, 15, 30], id: \.self) { seconds in
                                Button("\(seconds)秒") {
                                    timerManager.settings.idleDelaySeconds = seconds
                                }
                                .buttonStyle(PlainButtonStyle())
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(
                                        timerManager.settings.idleDelaySeconds == seconds
                                            ? Color.blue.opacity(0.2)
                                            : Color.gray.opacity(0.15)
                                    )
                                )
                                .foregroundColor(
                                    timerManager.settings.idleDelaySeconds == seconds ? .blue : .primary
                                )
                            }
                            Spacer()
                        }
                    }

                    HStack {
                        Text("最长允许顺延")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: $timerManager.settings.maxDelayMinutes) {
                            Text("3 分钟").tag(3)
                            Text("5 分钟").tag(5)
                            Text("10 分钟").tag(10)
                            Text("不限制").tag(0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 110)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("休息前 3 秒轻提示")
                            Text("顶部浮窗倒数，继续操作可立即推迟")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $timerManager.settings.showPreBreakCountdown)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自然离开自动重置")
                            .font(.system(size: 14, weight: .medium))
                        Text("离开电脑满一个休息时长，回来自动开始新一轮专注")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $timerManager.settings.autoResetOnIdle)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
        }
        .frame(maxWidth: .infinity)
    }

    private func timeInputRow(title: String, minutes: Binding<String>, seconds: Binding<String>) -> some View {
        HStack {
            Text(title)
                .frame(width: 80, alignment: .leading)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            HStack(spacing: 8) {
                CustomTextField(text: minutes, onEditingChanged: { _ in })
                    .frame(width: 45)
                Text("分")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                CustomTextField(text: seconds, onEditingChanged: { _ in })
                    .frame(width: 45)
                Text("秒")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(NSColor.controlBackgroundColor))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func syncLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func syncDraftFromSettings(_ settings: TimerSettings) {
        workMinutes = String(settings.workDurationMinutes)
        workSeconds = String(settings.workDurationSeconds)
        breakMinutes = String(settings.breakDurationMinutes)
        breakSeconds = String(settings.breakDurationSeconds)
        earlyNotifyMinutes = String(settings.earlyNotifyMinutes)
        earlyNotifySeconds = String(settings.earlyNotifySeconds)
    }

    private func applyLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLogin = SMAppService.mainApp.status == .enabled
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
                alertMessage = "切换开机自启动失败: \(error.localizedDescription)"
                showAlert = true
            }
        } else {
            let success = SMLoginItemSetEnabled("fxzer.top.RestTimer" as CFString, enabled)
            if success {
                launchAtLogin = enabled
            }
        }
    }

    private func applyTimeSettings() {
        guard let workMin = Int(workMinutes),
              let workSec = Int(workSeconds),
              let breakMin = Int(breakMinutes),
              let breakSec = Int(breakSeconds),
              let earlyMin = Int(earlyNotifyMinutes),
              let earlySec = Int(earlyNotifySeconds) else {
            alertMessage = TimeSettingsValidationError.invalidInput.localizedDescription
            showAlert = true
            return
        }

        let result = timerManager.updateTimeSettings(
            workMinutes: workMin,
            workSeconds: workSec,
            breakMinutes: breakMin,
            breakSeconds: breakSec,
            earlyMinutes: earlyMin,
            earlySeconds: earlySec
        )

        if case .failure(let error) = result {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func resetTimeSettings() {
        let defaults = TimerSettings.default
        workMinutes = String(defaults.workDurationMinutes)
        workSeconds = String(defaults.workDurationSeconds)
        breakMinutes = String(defaults.breakDurationMinutes)
        breakSeconds = String(defaults.breakDurationSeconds)
        earlyNotifyMinutes = String(defaults.earlyNotifyMinutes)
        earlyNotifySeconds = String(defaults.earlyNotifySeconds)
    }
}

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    var onEditingChanged: (String) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.alignment = .right
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.controlSize = .regular
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let filtered = textField.stringValue.filter { "0123456789".contains($0) }
            let truncated = String(filtered.prefix(2))

            if truncated != textField.stringValue {
                textField.stringValue = truncated
            }

            parent.text = truncated
            parent.onEditingChanged(truncated)
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                textField.currentEditor()?.selectAll(nil)
            }
        }
    }
}
