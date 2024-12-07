import SwiftUI

@main
struct RestTimerApp: App {
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var statusBarManager = StatusBarManager()
    
    var body: some Scene {
        Settings {
            ContentView()
                .environmentObject(timerManager)
        }
    }
}
