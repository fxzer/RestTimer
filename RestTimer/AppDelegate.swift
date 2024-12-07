import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    @objc func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if TimerManager.shared.preventQuit {
            return .terminateCancel
        }
        return .terminateNow
    }
}
