import SwiftUI
import AppKit
import Combine

final class StatusBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private let timerManager: TimerManager
    private var buttonUpdateTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

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
    }

    private func setupStatusBar() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            if let button = self.statusItem?.button {
                if let customImage = NSImage(named: "YourIconName") {
                    customImage.size = NSSize(width: 14, height: 14)
                    customImage.isTemplate = true
                    button.image = customImage
                }
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

        let breakNowItem = NSMenuItem(
            title: "立即休息",
            action: #selector(startBreakNow(_:)),
            keyEquivalent: "b"
        )
        breakNowItem.target = self
        menu.addItem(breakNowItem)
        self.breakNowMenuItem = breakNowItem
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "设置",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        let pauseItem = NSMenuItem(
            title: "暂停",
            action: #selector(togglePause(_:)),
            keyEquivalent: "p"
        )
        pauseItem.target = self
        menu.addItem(pauseItem)
        self.pauseMenuItem = pauseItem

        menu.addItem(NSMenuItem.separator())
        let resetItem = NSMenuItem(
            title: "重置",
            action: #selector(resetTimer(_:)),
            keyEquivalent: "r"
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())
        let aboutItem = NSMenuItem(
            title: "关于",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

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
            case .pendingBreak:
                breakNowItem.title = "立即休息（待空闲中）"
                breakNowItem.isHidden = false
                breakNowItem.isEnabled = true
            case .breaking:
                breakNowItem.isHidden = true
            case .idle, .working, .paused, .away:
                breakNowItem.title = "立即休息"
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
            setIcon(named: "YourIconName", on: button)
            button.attributedTitle = NSAttributedString(string: "--:--", attributes: normalAttributes)

        case .paused:
            setIcon(named: "YourPauseIconName", on: button)
            if let pausedTime = state.pausedRemainingTime, pausedTime > 0 {
                button.attributedTitle = NSAttributedString(
                    string: formatTime(Int(pausedTime)),
                    attributes: normalAttributes
                )
            } else {
                button.attributedTitle = NSAttributedString(string: "暂停", attributes: normalAttributes)
            }

        case .pendingBreak(_, let overdue):
            setIcon(named: "YourIconName", on: button)
            let pendingAttributes: [NSAttributedString.Key: Any] = [
                .font: timeFont,
                .foregroundColor: NSColor.systemOrange
            ]
            button.attributedTitle = NSAttributedString(
                string: "+\(formatTime(max(0, Int(overdue))))",
                attributes: pendingAttributes
            )

        case .away:
            setIcon(named: "YourPauseIconName", on: button)
            button.attributedTitle = NSAttributedString(string: "离开", attributes: normalAttributes)

        case .breaking(let remaining):
            setIcon(named: "YourIconName", on: button)
            button.attributedTitle = NSAttributedString(
                string: formatTime(max(0, Int(remaining))),
                attributes: normalAttributes
            )

        case .working(let startedAt):
            setIcon(named: "YourIconName", on: button)
            let remaining = Int(timerManager.workDuration - (Date().timeIntervalSince1970 - startedAt))
            let title = remaining > 0 ? formatTime(remaining) : "00:00"
            button.attributedTitle = NSAttributedString(string: title, attributes: normalAttributes)
        }

        button.imagePosition = .imageLeft
        button.imageScaling = .scaleProportionallyDown
    }

    private func setIcon(named name: String, on button: NSStatusBarButton) {
        if let image = NSImage(named: name) {
            image.size = NSSize(width: 14, height: 14)
            image.isTemplate = true
            button.image = image
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @objc private func showAbout() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
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
            window.makeKeyAndOrderFront(nil)
            centerWindowOnMainScreen(window)
            NSApplication.shared.activate(ignoringOtherApps: true)
            windowState = .visible(window)

        case .notCreated:
            let controller = NSHostingController(
                rootView: SettingsView().environmentObject(timerManager)
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 640),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
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
