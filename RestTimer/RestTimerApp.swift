import SwiftUI

@main
struct RestTimerApp: App {
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var statusBarManager: StatusBarManager
    
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
