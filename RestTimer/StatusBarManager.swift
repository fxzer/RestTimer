import SwiftUI
import AppKit
import ServiceManagement

class StatusBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var timerManager: TimerManager
    private var updateTimer: Timer?
    private var buttonUpdateTimer: Timer?
    
    init(timerManager: TimerManager) {
        self.timerManager = timerManager
        super.init()
        setupStatusBar()
        
        // 默认启用开机自启动
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status != .enabled {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    print("启用开机自启动失败: \(error)")
                }
            }
        } else {
            // 旧版本 API
            _ = SMLoginItemSetEnabled("fxzer.top.RestTimer" as CFString, true)
        }
    }
    
    private func setupStatusBar() {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            if let button = self?.statusItem?.button {
                if let customImage = NSImage(named: "YourIconName") {
                    customImage.size = NSSize(width: 16, height: 16)
                    customImage.isTemplate = true
                    button.image = customImage
                }
                self?.updateButtonDisplay()
                self?.setupMenu()
                self?.startButtonUpdateTimer()
            }
        }
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // 设置选项
        let settingsItem = NSMenuItem(
            title: "设置",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 添加暂停/开始选项
        menu.addItem(NSMenuItem.separator())
        let pauseItem = NSMenuItem(
            title: "暂停",
            action: #selector(togglePause),
            keyEquivalent: "p"
        )
        pauseItem.target = self
        menu.addItem(pauseItem)
        
        // 关于选项
        menu.addItem(NSMenuItem.separator())
        let aboutItem = NSMenuItem(
            title: "关于",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // 退出选项
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }    
    private func startButtonUpdateTimer() {
        stopButtonUpdateTimer()
        buttonUpdateTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateButtonDisplay()
        }
        RunLoop.main.add(buttonUpdateTimer!, forMode: .common)
    }
    
    private func stopButtonUpdateTimer() {
        buttonUpdateTimer?.invalidate()
        buttonUpdateTimer = nil
    }
    
    private func updateButtonDisplay() {
        if let button = statusItem?.button {
            if timerManager.isPaused {
                if let pauseImage = NSImage(named: "YourPauseIconName") {
                    pauseImage.size = NSSize(width: 16, height: 16)
                    pauseImage.isTemplate = true
                    button.image = pauseImage
                }
                if let pausedTime = timerManager.getRemainingPausedTime(),
                   pausedTime > 0 {
                    let remainingTime = Int(pausedTime)
                    let minutes = remainingTime / 60
                    let seconds = remainingTime % 60
                    button.title = String(format: "%02d:%02d", minutes, seconds)
                } else {
                    button.title = "--:--"
                }
            } else {
                if let timerImage = NSImage(named: "YourIconName") {
                    timerImage.size = NSSize(width: 16, height: 16)
                    timerImage.isTemplate = true
                    button.image = timerImage
                }
                let remainingTime = Int(timerManager.workDuration - (Date().timeIntervalSince1970 - timerManager.lastWorkStartTime))
                if remainingTime > 0 {
                    let minutes = remainingTime / 60
                    let seconds = remainingTime % 60
                    button.title = String(format: "%02d:%02d", minutes, seconds)
                } else {
                    button.title = "--:--"
                }
            }
            
            button.imagePosition = .imageLeft
            button.imageScaling = .scaleProportionallyDown
            
            if let image = button.image {
                image.size = NSSize(width: 16, height: 16)
                button.image = image
            }
        }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let isEnabled = sender.state == .on
        
        if #available(macOS 13.0, *) {
            // 使用新的 API
            do {
                try SMAppService.mainApp.register()
                sender.state = .on
            } catch {
                print("启用开机自启动失败: \(error)")
                sender.state = .off
            }
        } else {
            // 使用旧的 API
            let success = SMLoginItemSetEnabled("fxzer.top.RestTimer" as CFString, !isEnabled)
            sender.state = success ? (isEnabled ? .off : .on) : sender.state
        }
    }
    
    @objc private func toggleShowSkipButton(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        timerManager.showSkipButton = (sender.state == .on)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Rest Timer"
        alert.informativeText = """
            版本: 1.0.0
            开发者: fxzer
            
            一个简单的工休息提醒工具
            帮助你保持健康的工作节奏
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        
        // 获取当前的关键窗口
        if let window = NSApp.keyWindow {
            // 以模态方式显示在当前窗口之上
            alert.beginSheetModal(for: window) { _ in }
        } else {
            // 如果没有关键窗口，则以独立窗口方式显示
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }
    
    @objc private func showSettings() {
        WindowManager.shared.showSettings(timerManager: timerManager)
    }
    
    @objc private func handleQuit() {
        if timerManager.preventQuit {
            return
        }
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func togglePause(_ sender: NSMenuItem) {
        timerManager.togglePause()
        sender.title = timerManager.isPaused ? "继续" : "暂停"
        updateButtonDisplay()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        buttonUpdateTimer?.invalidate()
    }
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    @Published var isSettingsWindowVisible = false
    private var settingsWindow: NSWindow?
    
    private init() {}
    
    func showSettings(timerManager: TimerManager) {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        
        let controller = NSHostingController(
            rootView: SettingsView()
                .environmentObject(timerManager)
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "设置"
        window.contentViewController = controller
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = WindowDelegate.shared
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        isSettingsWindowVisible = true
    }
    
    func closeSettings() {
        settingsWindow?.orderOut(nil)  // 使用 orderOut 替代 close
        isSettingsWindowVisible = false
    }
}

// 窗口代理类
class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 不直接关闭窗口，而是隐藏它
        WindowManager.shared.closeSettings()
        return false // 返回 false 防止窗口被销毁
    }
}
