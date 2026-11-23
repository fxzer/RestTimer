import AppKit
import SwiftUI

enum ToastNotificationKind: Equatable {
    case workStarted
    case earlyWarning(minutes: Int, seconds: Int)
}

/// 居中 Toast 通知弹窗显式状态机（可真正取消挂起的淡出任务，避免重复 close 竞态）
final class NotificationOverlayManager {
    private enum OverlayState {
        case hidden
        case visible(windows: [NSWindow], fadeWorkItem: DispatchWorkItem)
        case fadingOut(windows: [NSWindow], cleanupWorkItem: DispatchWorkItem)
    }

    private var state: OverlayState = .hidden

    func show(_ kind: ToastNotificationKind) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(kind)
            }
            return
        }

        dismissImmediately()

        let windows = NSScreen.screens.map { makeWindow(for: kind, on: $0) }
        windows.forEach { $0.orderFront(nil) }

        let fadeWorkItem = DispatchWorkItem { [weak self] in
            self?.beginFadeOut()
        }
        state = .visible(windows: windows, fadeWorkItem: fadeWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: fadeWorkItem)
    }

    func dismissImmediately() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.dismissImmediately()
            }
            return
        }

        switch state {
        case .hidden:
            return
        case .visible(let windows, let fadeWorkItem):
            fadeWorkItem.cancel()
            windows.forEach { $0.close() }
        case .fadingOut(let windows, let cleanupWorkItem):
            cleanupWorkItem.cancel()
            windows.forEach { $0.close() }
        }
        state = .hidden
    }

    private func beginFadeOut() {
        guard case .visible(let windows, _) = state else { return }

        let cleanupWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self, case .fadingOut(let activeWindows, _) = self.state else { return }
            activeWindows.forEach { $0.close() }
            self.state = .hidden
        }

        state = .fadingOut(windows: windows, cleanupWorkItem: cleanupWorkItem)

        for window in windows {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                window.animator().alphaValue = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: cleanupWorkItem)
    }

    private func makeWindow(for kind: ToastNotificationKind, on screen: NSScreen) -> NSPanel {
        let contentSize: CGSize
        let rootView: AnyView

        switch kind {
        case .workStarted:
            contentSize = CGSize(width: 200, height: 200)
            rootView = AnyView(
                VStack {
                    Text("开始专注")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: contentSize.width, height: contentSize.height)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            )

        case .earlyWarning(let minutes, let seconds):
            contentSize = CGSize(width: 250, height: 150)
            rootView = AnyView(
                VStack {
                    Text("\(minutes)分\(seconds)秒后")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                    Text("将进入休息")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .frame(width: contentSize.width, height: contentSize.height)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            )
        }

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.isOpaque = false
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.alphaValue = 1
        window.contentView?.appearance = NSAppearance(named: .vibrantDark)
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true

        let screenFrame = screen.frame
        window.contentViewController?.view.layout()
        window.contentViewController?.view.layoutSubtreeIfNeeded()

        let windowSize = window.frame.size
        let originX = screenFrame.midX - windowSize.width / 2
        let originY = screenFrame.midY - windowSize.height / 2
        window.setFrameOrigin(NSPoint(x: originX, y: originY))

        return window
    }
}
