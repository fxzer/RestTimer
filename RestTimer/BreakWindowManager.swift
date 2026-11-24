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

/// 全屏休息遮罩窗口显式状态管理器
final class BreakWindowManager {
    private enum WindowState {
        case hidden
        case visible(windows: [NSWindow])
    }

    private var state: WindowState = .hidden

    func show(timerManager: TimerManager) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(timerManager: timerManager)
            }
            return
        }

        hide()

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

            window.level = .screenSaver
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

        state = .visible(windows: windows)
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

        guard case .visible(let windows) = state else { return }
        windows.forEach { $0.orderOut(nil) }
        state = .hidden
    }
}
