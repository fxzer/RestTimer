import SwiftUI

@main
struct RestTimerApp: App {
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var statusBarManager = StatusBarManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
