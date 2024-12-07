import SwiftUI
import AppKit

class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var timerManager: TimerManager
    
    init() {
        self.timerManager = TimerManager.shared
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            if let button = self?.statusItem?.button {
                button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Rest Timer")
                self?.setupMenu()
            }
        }
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // 工作倒计时
        let timerItem = NSMenuItem(title: "工作倒计时: --:--", action: nil, keyEquivalent: "")
        menu.addItem(timerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 设置子菜单
        let settingsMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "设置", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu
        
        // 开机自启动选项
        let launchAtLoginItem = NSMenuItem(
            title: "开机自启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        settingsMenu.addItem(launchAtLoginItem)
        
        // 显示跳过按钮选项
        let showSkipButtonItem = NSMenuItem(
            title: "显示跳过按钮",
            action: #selector(toggleShowSkipButton),
            keyEquivalent: ""
        )
        showSkipButtonItem.target = self
        settingsMenu.addItem(showSkipButtonItem)
        
        menu.addItem(settingsItem)
        
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
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        // 开始定时更新倒计时显示
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimerDisplay()
        }
    }
    
    private func updateTimerDisplay() {
        if let timerItem = statusItem?.menu?.item(at: 0) {
            let remainingTime = Int(timerManager.workDuration - (Date().timeIntervalSince1970 - timerManager.lastWorkStartTime))
            if remainingTime > 0 {
                let minutes = remainingTime / 60
                let seconds = remainingTime % 60
                timerItem.title = String(format: "工作倒计时: %02d:%02d", minutes, seconds)
            } else {
                timerItem.title = "工作倒计时: --:--"
            }
        }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        // TODO: 实现开机自启动功能
    }
    
    @objc private func toggleShowSkipButton(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        timerManager.showSkipButton = sender.state == .on
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Rest Timer"
        alert.informativeText = """
            版本: 1.0.0
            开发者: fxzer
            
            一个简单的工作休息提醒工具
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
}
