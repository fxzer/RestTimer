import SwiftUI

@main
struct RestTimerApp: App {
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var statusBarManager: StatusBarManager
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        let manager = StatusBarManager(timerManager: TimerManager.shared)
        _statusBarManager = StateObject(wrappedValue: manager)
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
