import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        // 注册工作区通知
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        // 注册系统通知
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }
    
    @objc func handleScreenLock() {
        if !TimerManager.shared.isPaused {
            TimerManager.shared.togglePause()
            // 通过 TimerManager 获取 statusBarManager
            if let statusBarManager = TimerManager.shared.statusBarManager {
                statusBarManager.updatePauseMenuItem()
            }
        }
    }
    
    @objc func handleScreenUnlock() {
        // 屏幕解锁时，重置计时器
        TimerManager.shared.resetTimer()
        // 通过 TimerManager 获取 statusBarManager
        if let statusBarManager = TimerManager.shared.statusBarManager {
            statusBarManager.updatePauseMenuItem()
        }
    }
    
    @objc func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if TimerManager.shared.preventQuit {
            return .terminateCancel
        }
        return .terminateNow
    }
    
    deinit {
        // 移除观察者
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
