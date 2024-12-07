import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var timerManager: TimerManager
    @State private var showSkipButton: Bool
    @State private var launchAtLogin: Bool
    
    @State private var workMinutes: String
    @State private var workSeconds: String
    @State private var breakMinutes: String
    @State private var breakSeconds: String
    
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
                
                HStack(alignment: .center) {
                    Text("专注时长")
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        TextField("", text: $workMinutes)
                            .frame(width: 40)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.trailing)
                            .onChange(of: workMinutes) { newValue in
                                if let minutes = Int(newValue), minutes >= 0 {
                                    timerManager.workDurationMinutes = minutes
                                }
                            }
                        Text("分")
                            .frame(height: 22)
                        
                        TextField("", text: $workSeconds)
                            .frame(width: 40)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.trailing)
                            .onChange(of: workSeconds) { newValue in
                                if let seconds = Int(newValue), seconds >= 0 && seconds < 60 {
                                    timerManager.workDurationSeconds = seconds
                                }
                            }
                        Text("秒")
                            .frame(height: 22)
                    }
                }
                .padding(.vertical, 5)
                
                HStack(alignment: .center) {
                    Text("休息时长")
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        TextField("", text: $breakMinutes)
                            .frame(width: 40)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.trailing)
                            .onChange(of: breakMinutes) { newValue in
                                if let minutes = Int(newValue), minutes >= 0 {
                                    timerManager.breakDurationMinutes = minutes
                                }
                            }
                        Text("分")
                            .frame(height: 22)
                        
                        TextField("", text: $breakSeconds)
                            .frame(width: 40)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.trailing)
                            .onChange(of: breakSeconds) { newValue in
                                if let seconds = Int(newValue), seconds >= 0 && seconds < 60 {
                                    timerManager.breakDurationSeconds = seconds
                                }
                            }
                        Text("秒")
                            .frame(height: 22)
                    }
                }
                .padding(.vertical, 5)
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 400, height: 400)
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
}
