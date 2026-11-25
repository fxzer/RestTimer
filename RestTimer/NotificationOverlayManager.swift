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

/// 真实跨窗口毛玻璃材质（AppKit NSVisualEffectView behindWindow，采用原生 .hudWindow 材质兼顾通透与对比度）
struct BehindWindowFrostedGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = CapsuleVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.blendingMode = .behindWindow
        nsView.material = .hudWindow
        nsView.state = .active
    }
}

/// 原生极简磨砂微胶囊背景（通透玻璃 + 单层 0.5pt 高光细边 + 柔和弥散阴影，去掉双层硬边）
struct FrostedGlassCapsuleBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        ZStack {
            BehindWindowFrostedGlass()
            Capsule()
                .fill(isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.32))
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .inset(by: 0.3)
                .stroke(Color.white.opacity(isDark ? 0.22 : 0.78), lineWidth: 0.6)
        )
        .shadow(
            color: Color.black.opacity(isDark ? 0.42 : 0.14),
            radius: 14,
            x: 0,
            y: 6
        )
    }
}

/// 统一共享的原生磨砂胶囊轻提示视图（通知提示与休息前倒数共用同一套醒目比例）
struct FrostedHudCapsulePill: View {
    let iconKind: HudIconKind
    let title: String
    var accent: Color = .accentColor

    var body: some View {
        HStack(spacing: 9) {
            CapsuleAccentIconBadge(
                kind: iconKind,
                accent: accent
            )

            Text(title)
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))
                .monospacedDigit()
        }
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .padding(.vertical, 9.5)
        .background(FrostedGlassCapsuleBackground())
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .fixedSize()
    }
}

private struct ToastCapsuleBannerView: View {
    let kind: ToastNotificationKind

    private var iconKind: HudIconKind {
        switch kind {
        case .workStarted:
            return .focusStart
        case .earlyWarning:
            return .bellReminder
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
        FrostedHudCapsulePill(
            iconKind: iconKind,
            title: titleText,
            accent: Color.accentColor
        )
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
        let contentSize = NSSize(width: max(136, ceil(fitting.width)), height: max(64, ceil(fitting.height)))

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
