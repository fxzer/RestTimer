import AppKit
import SwiftUI

enum ToastNotificationKind: Equatable {
    case workStarted
    case earlyWarning(minutes: Int, seconds: Int)
}

private final class CapsuleVisualEffectView: NSVisualEffectView {
    override func layout() {
        super.layout()
        wantsLayer = true
        layer?.cornerRadius = bounds.height / 2
        layer?.masksToBounds = true
    }
}

/// 真实跨窗口毛玻璃材质（AppKit NSVisualEffectView behindWindow，在任意浅色/深色/彩色窗口上均通透清晰）
struct BehindWindowFrostedGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = CapsuleVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .popover
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.blendingMode = .behindWindow
        nsView.material = .popover
        nsView.state = .active
    }
}

/// 统一轻柔阴影毛玻璃胶囊背景（自动适配系统亮暗主题：轻微弥散浮起感，无重黑影）
struct FrostedGlassCapsuleBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        ZStack {
            BehindWindowFrostedGlass()
            Capsule()
                .fill(isDark ? Color(nsColor: .windowBackgroundColor).opacity(0.26) : Color.white.opacity(0.36))
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .inset(by: 0.5)
                .stroke(Color.white.opacity(isDark ? 0.22 : 0.70), lineWidth: 0.5)
        )
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(isDark ? 0.40 : 0.12), lineWidth: 0.5)
        )
        .shadow(
            color: Color.black.opacity(isDark ? 0.28 : 0.12),
            radius: isDark ? 9 : 8,
            x: 0,
            y: 3
        )
    }
}

private struct ToastCapsuleBannerView: View {
    let kind: ToastNotificationKind

    private var iconName: String {
        switch kind {
        case .workStarted:
            return "clock.fill"
        case .earlyWarning:
            return "bell.fill"
        }
    }

    private var titleText: String {
        switch kind {
        case .workStarted:
            return "开始专注"
        case .earlyWarning(let minutes, let seconds):
            if minutes > 0 && seconds > 0 {
                return "\(minutes)分\(seconds)秒后休息"
            } else if minutes > 0 {
                return "\(minutes)分后休息"
            } else {
                return "\(seconds)秒后休息"
            }
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.accentColor)

            Text(titleText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))
                .monospacedDigit()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(FrostedGlassCapsuleBackground())
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .fixedSize()
    }
}

/// 顶部磨砂玻璃胶囊轻提示状态机（跟随系统主题色，无杂色边框）
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: fadeWorkItem)
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
                context.duration = 0.25
                window.animator().alphaValue = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: cleanupWorkItem)
    }

    private func makeWindow(for kind: ToastNotificationKind, on screen: NSScreen) -> NSPanel {
        let hostingController = NSHostingController(rootView: ToastCapsuleBannerView(kind: kind))
        hostingController.view.wantsLayer = true
        let fitting = hostingController.view.fittingSize
        let contentSize = NSSize(width: max(136, ceil(fitting.width)), height: max(44, ceil(fitting.height)))

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.alphaValue = 1

        let visibleFrame = screen.visibleFrame
        let originX = visibleFrame.midX - contentSize.width / 2
        let originY = visibleFrame.maxY - contentSize.height - 10
        window.setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: contentSize), display: true)

        return window
    }
}
