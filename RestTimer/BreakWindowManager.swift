import AppKit
import SwiftUI

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
        for screen in NSScreen.screens {
            let window = NSWindow(
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
            let hostingView = NSHostingView(rootView: breakView)
            hostingView.frame = visualEffectView.bounds

            visualEffectView.addSubview(hostingView)
            window.contentView = visualEffectView
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)

            windows.append(window)
        }

        state = .visible(windows: windows)
        NSApplication.shared.activate(ignoringOtherApps: true)
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
