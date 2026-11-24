import AppKit
import QuartzCore
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

/// 真实跨窗口毛玻璃材质（AppKit NSVisualEffectView behindWindow，自动适配亮暗模式）
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

/// LookAway 风格高识别毛玻璃胶囊背景（亮暗双态自适应 + 主题色微光描边 + 轻柔弥散阴影，不隐身也不突兀）
struct FrostedGlassCapsuleBackground: View {
    var accent: Color = .accentColor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        ZStack {
            BehindWindowFrostedGlass()
            Capsule()
                .fill(isDark ? Color(nsColor: .windowBackgroundColor).opacity(0.38) : Color.white.opacity(0.56))
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .inset(by: 0.75)
                .stroke(Color.white.opacity(isDark ? 0.24 : 0.78), lineWidth: 0.6)
        )
        .overlay(
            Capsule()
                .stroke(accent.opacity(isDark ? 0.42 : 0.32), lineWidth: 1.0)
        )
        .shadow(
            color: Color.black.opacity(isDark ? 0.28 : 0.11),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

/// 胶囊左侧实心主题色圆标徽章（强视觉锚点，在纯白网页与深色终端上均一眼可见）
struct CapsuleAccentIconBadge: View {
    let systemName: String
    let accent: Color
    var isPulsing: Bool = false

    @State private var pulseActive = false

    var body: some View {
        ZStack {
            if isPulsing {
                Circle()
                    .stroke(accent.opacity(pulseActive ? 0.0 : 0.48), lineWidth: 2.0)
                    .frame(width: 28, height: 28)
                    .scaleEffect(pulseActive ? 1.42 : 1.0)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                            pulseActive = true
                        }
                    }
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .inset(by: 0.5)
                        .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
                )

            Image(systemName: systemName)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 28, height: 28)
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
        HStack(spacing: 10) {
            CapsuleAccentIconBadge(systemName: iconName, accent: Color.accentColor)

            Text(titleText)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))
                .monospacedDigit()
        }
        .padding(.leading, 9)
        .padding(.trailing, 20)
        .padding(.vertical, 8)
        .background(FrostedGlassCapsuleBackground(accent: Color.accentColor))
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .fixedSize()
    }
}

/// 顶部毛玻璃胶囊轻提示状态机（从菜单栏向下弹性滑落入场，退场向上轻柔收回）
final class NotificationOverlayManager {
    private enum OverlayState {
        case hidden
        case visible(windows: [NSWindow], fadeWorkItem: DispatchWorkItem)
        case fadingOut(windows: [NSWindow], cleanupWorkItem: DispatchWorkItem)
    }

    private var state: OverlayState = .hidden
    private let slideOffsetY: CGFloat = 16

    func show(_ kind: ToastNotificationKind) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(kind)
            }
            return
        }

        dismissImmediately()

        let entries = NSScreen.screens.map { makeWindowAndTargetFrame(for: kind, on: $0) }
        let windows = entries.map(\.window)
        windows.forEach { $0.orderFront(nil) }

        // 从顶部菜单栏下方向下弹性滑落落位，余光一眼捕捉
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.34
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.16, 0.32, 1.0)
            for entry in entries {
                entry.window.animator().setFrame(entry.targetFrame, display: true)
                entry.window.animator().alphaValue = 1.0
            }
        }

        let fadeWorkItem = DispatchWorkItem { [weak self] in
            self?.beginFadeOut()
        }
        state = .visible(windows: windows, fadeWorkItem: fadeWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: fadeWorkItem)
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
            tearDownWindows(windows)
        case .fadingOut(let windows, let cleanupWorkItem):
            cleanupWorkItem.cancel()
            tearDownWindows(windows)
        }
        state = .hidden
    }

    private func beginFadeOut() {
        guard case .visible(let windows, _) = state else { return }

        let cleanupWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self, case .fadingOut(let activeWindows, _) = self.state else { return }
            self.tearDownWindows(activeWindows)
            self.state = .hidden
        }

        state = .fadingOut(windows: windows, cleanupWorkItem: cleanupWorkItem)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in windows {
                var exitFrame = window.frame
                exitFrame.origin.y += 10
                window.animator().setFrame(exitFrame, display: true)
                window.animator().alphaValue = 0.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: cleanupWorkItem)
    }

    private func tearDownWindows(_ windows: [NSWindow]) {
        for window in windows {
            window.orderOut(nil)
            window.contentViewController = nil
            window.contentView = nil
            window.close()
        }
    }

    private func makeWindowAndTargetFrame(for kind: ToastNotificationKind, on screen: NSScreen) -> (window: NSPanel, targetFrame: NSRect) {
        let hostingController = NSHostingController(rootView: ToastCapsuleBannerView(kind: kind))
        hostingController.view.wantsLayer = true
        let fitting = hostingController.view.fittingSize
        let contentSize = NSSize(width: max(150, ceil(fitting.width)), height: max(56, ceil(fitting.height)))

        let visibleFrame = screen.visibleFrame
        let originX = visibleFrame.midX - contentSize.width / 2
        let targetOriginY = visibleFrame.maxY - contentSize.height - 8
        let targetFrame = NSRect(origin: NSPoint(x: originX, y: targetOriginY), size: contentSize)
        let startFrame = NSRect(origin: NSPoint(x: originX, y: targetOriginY + slideOffsetY), size: contentSize)

        let window = NSPanel(
            contentRect: startFrame,
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
        window.alphaValue = 0.0
        window.setFrame(startFrame, display: true)

        return (window, targetFrame)
    }
}
