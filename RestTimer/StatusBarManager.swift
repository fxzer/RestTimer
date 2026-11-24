import SwiftUI
import AppKit
import Combine

final class StatusBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private let timerManager: TimerManager
    private var buttonUpdateTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    private weak var todayStatsMenuItem: NSMenuItem?
    private weak var breakNowMenuItem: NSMenuItem?
    private weak var pauseMenuItem: NSMenuItem?

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
        super.init()
        setupStatusBar()
        observeTimerState()
    }

    deinit {
        cancellables.removeAll()
        buttonUpdateTimer?.invalidate()
    }

    private func observeTimerState() {
        timerManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncUI(for: state)
            }
            .store(in: &cancellables)

        timerManager.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.syncUI(for: self.timerManager.state)
            }
            .store(in: &cancellables)

        timerManager.$todayStats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.todayStatsMenuItem?.title = stats.menuSummary
            }
            .store(in: &cancellables)

        timerManager.$isDeferredByDND
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateButtonDisplay(for: self.timerManager.state)
            }
            .store(in: &cancellables)
    }

    private func setupStatusBar() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            if let button = self.statusItem?.button {
                button.image = self.makeProgressRingImage(progress: 1.0, isPaused: false, isBreaking: false)
                button.imagePosition = .imageLeft
                button.imageHugsTitle = true
            }

            self.setupMenu()
            self.syncUI(for: self.timerManager.state)
            self.startButtonUpdateTimer()
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // 0. 今日休息极简轻统计（浅灰只读状态行，零弹窗负担）
        let statsItem = NSMenuItem(
            title: timerManager.todayStats.menuSummary,
            action: nil,
            keyEquivalent: ""
        )
        statsItem.isEnabled = false
        menu.addItem(statsItem)
        self.todayStatsMenuItem = statsItem

        menu.addItem(NSMenuItem.separator())

        // 1. 计时器控制组（高频动作归拢，组内不加分割线）
        let breakNowItem = NSMenuItem(
            title: "休息",
            action: #selector(startBreakNow(_:)),
            keyEquivalent: "b"
        )
        breakNowItem.target = self
        menu.addItem(breakNowItem)
        self.breakNowMenuItem = breakNowItem

        let pauseItem = NSMenuItem(
            title: "暂停",
            action: #selector(togglePause(_:)),
            keyEquivalent: "p"
        )
        pauseItem.target = self
        menu.addItem(pauseItem)
        self.pauseMenuItem = pauseItem

        let resetItem = NSMenuItem(
            title: "重置",
            action: #selector(resetTimer(_:)),
            keyEquivalent: "r"
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // 2. 应用设置与信息组
        let settingsItem = NSMenuItem(
            title: "设置",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "关于",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // 3. 退出
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
        buttonUpdateTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateButtonDisplay(for: self.timerManager.state)
        }
        RunLoop.main.add(timer, forMode: .common)
        buttonUpdateTimer = timer
    }

    private func syncUI(for state: SessionState) {
        pauseMenuItem?.title = state.isPaused ? "继续" : "暂停"

        if let breakNowItem = breakNowMenuItem {
            switch state {
            case .breaking:
                breakNowItem.isHidden = true
            case .idle, .working, .pendingBreak, .paused, .away:
                breakNowItem.title = "休息"
                breakNowItem.isHidden = false
                breakNowItem.isEnabled = true
            }
        }

        updateButtonDisplay(for: state)
    }

    private func updateButtonDisplay(for state: SessionState) {
        guard let button = statusItem?.button else { return }

        let timeFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let normalAttributes: [NSAttributedString.Key: Any] = [.font: timeFont]

        switch state {
        case .idle:
            button.image = makeProgressRingImage(progress: 1.0, isPaused: false, isBreaking: false)
            button.attributedTitle = NSAttributedString(string: "--:--", attributes: normalAttributes)

        case .paused:
            if let pausedTime = state.pausedRemainingTime, pausedTime > 0 {
                let total = max(1.0, timerManager.workDuration)
                button.image = makeProgressRingImage(progress: min(1.0, pausedTime / total), isPaused: true, isBreaking: false)
                button.attributedTitle = NSAttributedString(
                    string: formatTime(Int(pausedTime)),
                    attributes: normalAttributes
                )
            } else {
                button.image = makeProgressRingImage(progress: 0.0, isPaused: true, isBreaking: false)
                button.attributedTitle = NSAttributedString(string: "暂停", attributes: normalAttributes)
            }

        case .pendingBreak(_, let overdue):
            button.image = makeProgressRingImage(progress: 0.08, isPaused: false, isBreaking: false)
            if timerManager.isDeferredByDND {
                let dndAttributes: [NSAttributedString.Key: Any] = [
                    .font: timeFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                button.attributedTitle = NSAttributedString(string: "免打扰", attributes: dndAttributes)
            } else {
                let pendingAttributes: [NSAttributedString.Key: Any] = [
                    .font: timeFont,
                    .foregroundColor: NSColor.systemOrange
                ]
                button.attributedTitle = NSAttributedString(
                    string: "+\(formatTime(max(0, Int(overdue))))",
                    attributes: pendingAttributes
                )
            }

        case .away:
            button.image = makeProgressRingImage(progress: 0.0, isPaused: true, isBreaking: false)
            button.attributedTitle = NSAttributedString(string: "离开", attributes: normalAttributes)

        case .breaking(let remaining):
            let total = max(1.0, timerManager.breakDuration)
            button.image = makeProgressRingImage(progress: min(1.0, max(0.0, remaining / total)), isPaused: false, isBreaking: true)
            button.attributedTitle = NSAttributedString(
                string: formatTime(max(0, Int(remaining))),
                attributes: normalAttributes
            )

        case .working(let startedAt):
            let total = max(1.0, timerManager.workDuration)
            let remainingDouble = max(0.0, total - (Date().timeIntervalSince1970 - startedAt))
            button.image = makeProgressRingImage(progress: min(1.0, remainingDouble / total), isPaused: false, isBreaking: false)
            let remaining = Int(remainingDouble)
            let title = remaining > 0 ? formatTime(remaining) : "00:00"
            button.attributedTitle = NSAttributedString(string: title, attributes: normalAttributes)
        }

        button.imagePosition = .imageLeft
        button.imageScaling = .scaleProportionallyDown
    }

    /// 动态绘制 macOS 原生模板风格倒计时圆环图标（支持深浅色菜单栏自动反色）
    private func makeProgressRingImage(progress: Double, isPaused: Bool, isBreaking: Bool) -> NSImage {
        let size = NSSize(width: 15, height: 15)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 5.6
            let lineWidth: CGFloat = 2.0

            // 底层浅色轨道圆环
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            NSColor.black.withAlphaComponent(0.26).setStroke()
            track.stroke()

            // 前景剩余进度圆弧（从 12 点钟顺时针衰减）
            let clamped = min(1.0, max(0.0, progress))
            if clamped > 0.01 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - CGFloat(clamped * 360.0),
                    clockwise: true
                )
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                NSColor.black.setStroke()
                arc.stroke()
            }

            // 中心状态微标识：暂停显示双竖线，休息显示圆点
            if isPaused {
                NSColor.black.setFill()
                NSRect(x: center.x - 2.0, y: center.y - 2.3, width: 1.4, height: 4.6).fill()
                NSRect(x: center.x + 0.6, y: center.y - 2.3, width: 1.4, height: 4.6).fill()
            } else if isBreaking {
                let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 2.0, y: center.y - 2.0, width: 4.0, height: 4.0))
                NSColor.black.setFill()
                dot.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @objc private func showAbout() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.1"
        let alert = NSAlert()
        alert.messageText = "Rest Timer"
        alert.informativeText = """
            版本: \(appVersion)
            开发者: fxzer

            一个简单的工作休息提醒工具
            帮助你保持健康的工作节奏
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")

        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { _ in }
        } else {
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
        guard !timerManager.preventQuit else { return }
        NSApplication.shared.terminate(nil)
    }

    @objc private func startBreakNow(_ sender: NSMenuItem) {
        timerManager.startBreakImmediately()
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        timerManager.toggleManualPause()
    }

    @objc private func resetTimer(_ sender: NSMenuItem) {
        timerManager.resetTimer()
    }
}

/// 设置窗口显式生命周期状态机（修复二次打开时可见性标志失步）
final class WindowManager: ObservableObject {
    enum SettingsWindowState {
        case notCreated
        case visible(NSWindow)
        case hidden(NSWindow)

        var isVisible: Bool {
            if case .visible = self { return true }
            return false
        }
    }

    static let shared = WindowManager()

    @Published private(set) var isSettingsWindowVisible = false
    private var windowState: SettingsWindowState = .notCreated {
        didSet {
            isSettingsWindowVisible = windowState.isVisible
        }
    }

    private init() {}

    func showSettings(timerManager: TimerManager) {
        switch windowState {
        case .visible(let window), .hidden(let window):
            window.setContentSize(NSSize(width: SettingsTokens.windowWidth, height: SettingsTokens.windowHeight))
            window.makeKeyAndOrderFront(nil)
            centerWindowOnMainScreen(window)
            NSApplication.shared.activate(ignoringOtherApps: true)
            windowState = .visible(window)

        case .notCreated:
            let controller = NSHostingController(
                rootView: SettingsView().environmentObject(timerManager)
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: SettingsTokens.windowWidth, height: SettingsTokens.windowHeight),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.setContentSize(NSSize(width: SettingsTokens.windowWidth, height: SettingsTokens.windowHeight))
            window.title = "设置"
            window.contentViewController = controller
            window.isReleasedWhenClosed = false
            window.delegate = WindowDelegate.shared
            window.level = .floating

            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            windowState = .visible(window)

            DispatchQueue.main.async {
                self.centerWindowOnMainScreen(window)
            }
        }
    }

    func closeSettings() {
        switch windowState {
        case .visible(let window):
            window.orderOut(nil)
            windowState = .hidden(window)
        case .hidden, .notCreated:
            break
        }
    }

    private func centerWindowOnMainScreen(_ window: NSWindow) {
        guard let mainScreen = NSScreen.main else { return }
        let visibleFrame = mainScreen.visibleFrame
        let x = visibleFrame.midX - window.frame.width / 2
        let y = visibleFrame.midY - window.frame.height / 2
        window.setFrame(
            NSRect(x: x, y: y, width: window.frame.width, height: window.frame.height),
            display: true,
            animate: false
        )
    }
}

final class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        WindowManager.shared.closeSettings()
        return false
    }
}

extension StatusBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        timerManager.refreshTodayStats()
        todayStatsMenuItem?.title = timerManager.todayStats.menuSummary
    }
}
