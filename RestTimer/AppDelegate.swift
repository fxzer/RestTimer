import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var screenPresence = ScreenPresenceTracker()

    override init() {
        super.init()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenSlept),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenWoke),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc private func handleScreenSlept() {
        applyPresenceUpdate { $0.handleScreenSlept() }
    }

    @objc private func handleScreenWoke() {
        applyPresenceUpdate { $0.handleScreenWoke() }
    }

    @objc private func handleScreenLocked() {
        applyPresenceUpdate { $0.handleScreenLocked() }
    }

    @objc private func handleScreenUnlocked() {
        applyPresenceUpdate { $0.handleScreenUnlocked() }
    }

    private func applyPresenceUpdate(_ update: @escaping (inout ScreenPresenceTracker) -> ScreenPresenceTracker.Action) {
        let perform = { [weak self] in
            guard let self = self else { return }
            let action = update(&self.screenPresence)
            switch action {
            case .none:
                break
            case .pauseForSystemLock:
                TimerManager.shared.handleSystemLock()
            case .endSystemInactivity(let elapsed, let wasLocked):
                TimerManager.shared.handleSystemUnlock(inactiveElapsed: elapsed, wasLocked: wasLocked)
            }
        }

        if Thread.isMainThread {
            perform()
        } else {
            DispatchQueue.main.async(execute: perform)
        }
    }

    @objc func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 永不拦截系统退出 / ⌘Q，确保在任何异常场景下用户都能立刻退出应用并清理遮罩
        TimerManager.shared.emergencyExitBreak()
        return .terminateNow
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
