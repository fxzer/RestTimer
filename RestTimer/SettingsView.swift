import SwiftUI
import ServiceManagement

// 添加一个协调器类来处理通知
class SettingsViewCoordinator: ObservableObject {
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    init() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EarlyNotifyAdjusted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let message = notification.userInfo?["message"] as? String {
                self?.alertMessage = message
                self?.showAlert = true
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var timerManager: TimerManager
    @StateObject private var coordinator = SettingsViewCoordinator()
    @State private var showSkipButton: Bool
    @State private var launchAtLogin: Bool
    
    @State private var workMinutes: String
    @State private var workSeconds: String
    @State private var breakMinutes: String
    @State private var breakSeconds: String
    @State private var earlyNotifyMinutes: String
    @State private var earlyNotifySeconds: String
    
    init() {
        _showSkipButton = State(initialValue: TimerManager.shared.showSkipButton)
        if #available(macOS 13.0, *) {
            _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        } else {
            _launchAtLogin = State(initialValue: true)
        }
        
        _workMinutes = State(initialValue: String(TimerManager.shared.workDurationMinutes))
        _workSeconds = State(initialValue: String(TimerManager.shared.workDurationSeconds))
        _breakMinutes = State(initialValue: String(TimerManager.shared.breakDurationMinutes))
        _breakSeconds = State(initialValue: String(TimerManager.shared.breakDurationSeconds))
        _earlyNotifyMinutes = State(initialValue: String(TimerManager.shared.earlyNotifyMinutes))
        _earlyNotifySeconds = State(initialValue: String(TimerManager.shared.earlyNotifySeconds))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 基本设置模块
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
                        Toggle("", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                toggleLaunchAtLogin(enabled: newValue)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    
                    HStack {
                        Text("显示跳过按钮")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $showSkipButton)
                            .onChange(of: showSkipButton) { newValue in
                                timerManager.showSkipButton = newValue
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    
                    HStack {
                        Text("显示程序坞图标")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $timerManager.showDockIcon)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    
                    HStack {
                        Text("检测媒体播放暂停")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $timerManager.enableMediaDetection)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    .help("检测到网页视频、音乐播放时自动暂停计时器")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            }
            .frame(maxWidth: .infinity)
            
            // 时间设置模块
            VStack(spacing: 15) {
                Text("时间设置")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 5)
                
                VStack(spacing: 16) {
                    HStack {
                        Text("专注时长")
                            .frame(width: 80, alignment: .leading)
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            CustomTextField(text: $workMinutes, onEditingChanged: { _ in })
                                .frame(width: 45)
                            Text("分")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            CustomTextField(text: $workSeconds, onEditingChanged: { _ in })
                                .frame(width: 45)
                            Text("秒")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("提前提醒")
                            .frame(width: 80, alignment: .leading)
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            CustomTextField(text: $earlyNotifyMinutes, onEditingChanged: { _ in })
                                .frame(width: 45)
                            Text("分")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            CustomTextField(text: $earlyNotifySeconds, onEditingChanged: { _ in })
                                .frame(width: 45)
                            Text("秒")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("休息时长")
                            .frame(width: 80, alignment: .leading)
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            CustomTextField(text: $breakMinutes, onEditingChanged: { _ in })
                                .frame(width: 45)
                            Text("分")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            CustomTextField(text: $breakSeconds, onEditingChanged: { _ in })
                                .frame(width: 45)
                            Text("秒")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 按钮组
                    HStack(spacing: 14) {
                        Button(action: {
                            resetTimeSettings()
                        }) {
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
                        
                        Button(action: {
                            applyTimeSettings()
                        }) {
                            Text("应用")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue)
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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 480)
        .alert("设置错误", isPresented: $coordinator.showAlert) {
            Button("确定", action: {})
                .buttonStyle(.borderedProminent)
                .tint(.blue)
        } message: {
            Text(coordinator.alertMessage)
        }
    }
    
    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("切换开机自启动失败: \(error)")
            }
        } else {
            _ = SMLoginItemSetEnabled("fxzer.top.RestTimer" as CFString, enabled)
        }
    }

    private func applyTimeSettings() {
        // 验证输入值
        guard let workMin = Int(workMinutes), workMin >= 0,
              let workSec = Int(workSeconds), workSec >= 0, workSec < 60,
              let breakMin = Int(breakMinutes), breakMin >= 0,
              let breakSec = Int(breakSeconds), breakSec >= 0, breakSec < 60,
              let earlyMin = Int(earlyNotifyMinutes), earlyMin >= 0,
              let earlySec = Int(earlyNotifySeconds), earlySec >= 0, earlySec < 60 else {
            coordinator.alertMessage = "请输入有效的时间值"
            coordinator.showAlert = true
            return
        }
        
        // 验证提前提醒时长不能大于或等于专注时长
        let earlyNotifyTotal = earlyMin * 60 + earlySec
        let workTotal = workMin * 60 + workSec
        
        if earlyNotifyTotal >= workTotal {
            coordinator.alertMessage = "提前提醒时长不能大于或等于专注时长"
            coordinator.showAlert = true
            return
        }
        
        // 应用设置
        timerManager.workDurationMinutes = workMin
        timerManager.workDurationSeconds = workSec
        timerManager.breakDurationMinutes = breakMin
        timerManager.breakDurationSeconds = breakSec
        timerManager.earlyNotifyMinutes = earlyMin
        timerManager.earlyNotifySeconds = earlySec
    }
    
    private func resetTimeSettings() {
        // 重置为默认值
        workMinutes = "25"
        workSeconds = "0"
        breakMinutes = "3"
        breakSeconds = "0"
        earlyNotifyMinutes = "2"
        earlyNotifySeconds = "0"
    }
    
    // 验证提前提醒时长的辅助方法
    private func validateEarlyNotifyDuration() {
        if !timerManager.isValidEarlyNotifyDuration() {
            let alert = NSAlert()
            alert.messageText = "提前提醒时长必须小于专注时长"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确认")
            alert.runModal()
            
            // 重置为默认值
            timerManager.earlyNotifyMinutes = 2
            timerManager.earlyNotifySeconds = 0
            earlyNotifyMinutes = "2"
            earlyNotifySeconds = "0"
        }
    }

}

// 自定义 TextField 组件

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
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            
            // 过滤非数字字符
            let filtered = textField.stringValue.filter { "0123456789".contains($0) }
            
            // 限制为2位数
            let truncated = String(filtered.prefix(2))
            
            // 如果处理后的字符串与原字符串不同，更新文本框
            if truncated != textField.stringValue {
                textField.stringValue = truncated
            }
            
            // 更新绑定值和触发回调
            parent.text = truncated
            parent.onEditingChanged(truncated)
        }
        
        // 在开始编辑时选中所有文本
        func controlTextDidBeginEditing(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                textField.currentEditor()?.selectAll(nil)
            }
        }
    }
}
