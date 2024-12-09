import SwiftUI

@main
struct RestTimerApp: App {
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var statusBarManager: StatusBarManager
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        let manager = StatusBarManager(timerManager: TimerManager.shared)
        _statusBarManager = StateObject(wrappedValue: manager)
        
        // 延迟到下一个运行循环执行,确保 NSApp 已完全初始化
        DispatchQueue.main.async {
            if !TimerManager.shared.showDockIcon {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置") {
                    WindowManager.shared.showSettings(timerManager: timerManager)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
