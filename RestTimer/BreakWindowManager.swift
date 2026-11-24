import AppKit
import SwiftUI

/// 支持成为 Key Window 的无边框全屏休息窗口（解决无边框 NSWindow 默认无法响应首击与快捷键的问题）
private final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 始终响应首次点击的 SwiftUI HostingView，避免多屏或切换焦点时需要点击两次
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// 全屏休息遮罩窗口显式状态管理器（绝不遮挡系统强制退出窗，支持外接显示器热插拔重建，退出时彻底释放视图与事件监听）
final class BreakWindowManager {
    private enum WindowState {
        case hidden
        case visible(windows: [NSWindow], timerManager: TimerManager)
    }

    private var state: WindowState = .hidden
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChanged()
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if Thread.isMainThread {
            tearDownCurrentWindows()
        }
    }

    func show(timerManager: TimerManager) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(timerManager: timerManager)
            }
            return
        }

        tearDownCurrentWindows()

        // 仅比系统菜单栏高 1 级（~25）：完整覆盖桌面、Dock 与全屏应用，但绝不遮挡系统「强制退出 (⌘⌥Esc)」和系统安全弹窗
        let overlayLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)

        var windows: [NSWindow] = []
        let mainScreen = NSScreen.main
        var primaryWindow: NSWindow?

        for screen in NSScreen.screens {
            let window = BreakOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            window.isReleasedWhenClosed = false
            window.level = overlayLevel
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.acceptsMouseMovedEvents = true

            let visualEffectView = NSVisualEffectView(frame: window.contentView?.bounds ?? .zero)
            visualEffectView.material = .fullScreenUI
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true

            let overlayView = NSView(frame: visualEffectView.bounds)
            overlayView.wantsLayer = true
            overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
            visualEffectView.addSubview(overlayView)

            let breakView = BreakView().environmentObject(timerManager)
            let hostingView = FirstClickHostingView(rootView: breakView)
            hostingView.frame = visualEffectView.bounds

            visualEffectView.addSubview(hostingView)
            window.contentView = visualEffectView
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()

            if screen == mainScreen || primaryWindow == nil {
                primaryWindow = window
            }
            windows.append(window)
        }

        state = .visible(windows: windows, timerManager: timerManager)
        NSApplication.shared.activate(ignoringOtherApps: true)
        primaryWindow?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.hide()
            }
            return
        }

        tearDownCurrentWindows()
    }

    private func handleScreenParametersChanged() {
        guard case .visible(_, let timerManager) = state else { return }
        show(timerManager: timerManager)
    }

    private func tearDownCurrentWindows() {
        guard case .visible(let windows, _) = state else { return }
        state = .hidden
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
    }
}
