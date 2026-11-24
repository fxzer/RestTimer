import AppKit
import SwiftUI
import QuartzCore

/// 支持成为 Key Window 的无边框全屏休息窗口（解决无边框 NSWindow 默认无法响应首击与快捷键的问题）
private final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 始终响应首次点击的 SwiftUI HostingView，避免多屏或切换焦点时需要点击两次
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// 全屏休息遮罩窗口显式状态管理器（轻柔缓出淡入淡出、绝不遮挡系统强制退出窗、支持外接显示器热插拔重建）
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
            tearDownCurrentWindows(animated: false)
        }
    }

    func show(timerManager: TimerManager, animated: Bool = true) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(timerManager: timerManager, animated: animated)
            }
            return
        }

        tearDownCurrentWindows(animated: false)

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
            window.backgroundColor = .clear
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.acceptsMouseMovedEvents = true
            window.alphaValue = animated ? 0.0 : 1.0

            let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
            visualEffectView.material = .fullScreenUI
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            visualEffectView.autoresizingMask = [.width, .height]

            let breakView = BreakView().environmentObject(timerManager)
            let hostingView = FirstClickHostingView(rootView: breakView)
            hostingView.frame = visualEffectView.bounds
            hostingView.autoresizingMask = [.width, .height]

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

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.40
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                windows.forEach { $0.animator().alphaValue = 1.0 }
            }
        }
    }

    func hide(animated: Bool = true) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.hide(animated: animated)
            }
            return
        }

        tearDownCurrentWindows(animated: animated)
    }

    private func handleScreenParametersChanged() {
        guard case .visible(_, let timerManager) = state else { return }
        show(timerManager: timerManager, animated: false)
    }

    private func tearDownCurrentWindows(animated: Bool) {
        guard case .visible(let windows, _) = state else { return }
        state = .hidden

        let closeAll = {
            for window in windows {
                window.orderOut(nil)
                window.contentView = nil
                window.close()
            }
            ExerciseImageLoader.shared.purge()
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                windows.forEach { $0.animator().alphaValue = 0.0 }
            }, completionHandler: {
                DispatchQueue.main.async(execute: closeAll)
            })
        } else {
            closeAll()
        }
    }
}
