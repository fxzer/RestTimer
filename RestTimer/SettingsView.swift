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
            Form {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.vertical, 5)
                
                Toggle("显示跳过按钮", isOn: $showSkipButton)
                    .onChange(of: showSkipButton) { newValue in
                        timerManager.showSkipButton = newValue
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.vertical, 5)
                
                HStack {
                    Text("专注时长")
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    CustomTextField(text: $workMinutes, onEditingChanged: { newValue in
                        if let minutes = Int(newValue), minutes >= 0 {
                            timerManager.workDurationMinutes = minutes
                        }
                    })
                    .frame(width: 40)
                    
                    Text("分")
                        .fixedSize()
                    
                    CustomTextField(text: $workSeconds, onEditingChanged: { newValue in
                        if let seconds = Int(newValue), seconds >= 0 && seconds < 60 {
                            timerManager.workDurationSeconds = seconds
                        }
                    })
                    .frame(width: 40)
                    
                    Text("秒")
                        .fixedSize()
                }
                .padding(.vertical, 5)
                
                HStack {
                    Text("提前提醒")
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    CustomTextField(text: $earlyNotifyMinutes, onEditingChanged: { newValue in
                        if let minutes = Int(newValue), minutes >= 0 {
                            timerManager.earlyNotifyMinutes = minutes
                            validateEarlyNotifyDuration()
                        }
                    })
                    .frame(width: 40)
                    
                    Text("分")
                        .fixedSize()
                    
                    CustomTextField(text: $earlyNotifySeconds, onEditingChanged: { newValue in
                        if let seconds = Int(newValue), seconds >= 0 && seconds < 60 {
                            timerManager.earlyNotifySeconds = seconds
                            validateEarlyNotifyDuration()
                        }
                    })
                    .frame(width: 40)
                    
                    Text("秒")
                        .fixedSize()
                }
                .padding(.vertical, 5)

                HStack {
                    Text("休息时长")
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    CustomTextField(text: $breakMinutes, onEditingChanged: { newValue in
                        if let minutes = Int(newValue), minutes >= 0 {
                            timerManager.breakDurationMinutes = minutes
                        }
                    })
                    .frame(width: 40)
                    
                    Text("分")
                        .fixedSize()
                    
                    CustomTextField(text: $breakSeconds, onEditingChanged: { newValue in
                        if let seconds = Int(newValue), seconds >= 0 && seconds < 60 {
                            timerManager.breakDurationSeconds = seconds
                        }
                    })
                    .frame(width: 40)
                    
                    Text("秒")
                        .fixedSize()
                }
                .padding(.vertical, 5)

                // 添加警告提示
                .alert("设置错误", isPresented: $coordinator.showAlert) {
                    Button("确定", action: {})
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                } message: {
                    Text(coordinator.alertMessage)
                }
                }
                .formStyle(.grouped)
                .padding()
       
        }
        .frame(width: 400, height: 340)
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

    // 添加验证方法
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
