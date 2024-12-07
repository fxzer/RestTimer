import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var timerManager: TimerManager
    @State private var showSkipButton: Bool
    @State private var launchAtLogin: Bool
    
    init() {
        _showSkipButton = State(initialValue: TimerManager.shared.showSkipButton)
        if #available(macOS 13.0, *) {
            _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        } else {
            _launchAtLogin = State(initialValue: true)
        }
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
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 400, height: 360)
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
