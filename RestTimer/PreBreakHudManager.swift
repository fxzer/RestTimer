import AppKit
import QuartzCore
import SwiftUI

final class PreBreakHudViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var isWarningCap: Bool = false
}

private struct PreBreakHudView: View {
    @ObservedObject var viewModel: PreBreakHudViewModel

    var body: some View {
        let accent: Color = viewModel.isWarningCap ? .orange : Color.accentColor
        HStack(spacing: 10) {
            CapsuleAccentIconBadge(
                systemName: viewModel.isWarningCap ? "exclamationmark" : "cup.and.saucer.fill",
                accent: accent,
                isPulsing: true
            )

            Text(viewModel.title)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))
                .monospacedDigit()
        }
        .padding(.leading, 9)
        .padding(.trailing, 20)
        .padding(.vertical, 8)
        .background(FrostedGlassCapsuleBackground(accent: accent))
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .fixedSize()
    }
}

/// 休息前轻提示浮窗管理器：弹性滑落入场 + 脉冲圆标倒数 + 退场向上收回，不抢焦点、不拦截输入
final class PreBreakHudManager {
    private enum HudState {
        case hidden
        case visible(panels: [NSPanel], reason: CountdownReason, secondsLeft: Int)
    }

    private let viewModel = PreBreakHudViewModel()
    private var state: HudState = .hidden
    private var screenObserver: NSObjectProtocol?
    private let slideOffsetY: CGFloat = 16

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
    }

    func showOrUpdate(secondsLeft: Int, reason: CountdownReason) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showOrUpdate(secondsLeft: secondsLeft, reason: reason)
            }
            return
        }

        updateViewModel(secondsLeft: secondsLeft, reason: reason)

        switch state {
        case .hidden:
            let panels = createPanels(animated: true)
            state = .visible(panels: panels, reason: reason, secondsLeft: secondsLeft)

        case .visible(let panels, _, _):
            if panels.count != NSScreen.screens.count {
                panels.forEach { $0.close() }
                let rebuilt = createPanels(animated: false)
                state = .visible(panels: rebuilt, reason: reason, secondsLeft: secondsLeft)
            } else {
                layout(panels: panels)
                state = .visible(panels: panels, reason: reason, secondsLeft: secondsLeft)
            }
        }
    }

    func hide() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.hide()
            }
            return
        }

        guard case .visible(let panels, _, _) = state else { return }
        state = .hidden

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for panel in panels {
                var exitFrame = panel.frame
                exitFrame.origin.y += 10
                panel.animator().setFrame(exitFrame, display: true)
                panel.animator().alphaValue = 0.0
            }
        }, completionHandler: {
            DispatchQueue.main.async {
                panels.forEach { $0.close() }
            }
        })
    }

    private func handleScreenParametersChanged() {
        guard case .visible(let panels, let reason, let secondsLeft) = state else { return }
        panels.forEach { $0.close() }
        let rebuilt = createPanels(animated: false)
        state = .visible(panels: rebuilt, reason: reason, secondsLeft: secondsLeft)
    }

    private func updateViewModel(secondsLeft: Int, reason: CountdownReason) {
        switch reason {
        case .idleTrigger:
            viewModel.isWarningCap = false
            viewModel.title = "\(secondsLeft)秒后休息"
            viewModel.subtitle = ""
        case .maxDelayCap:
            viewModel.isWarningCap = true
            viewModel.title = "\(secondsLeft)秒后休息"
            viewModel.subtitle = ""
        }
    }

    private func createPanels(animated: Bool) -> [NSPanel] {
        var entries: [(panel: NSPanel, targetFrame: NSRect)] = []

        for screen in NSScreen.screens {
            let hostingController = NSHostingController(rootView: PreBreakHudView(viewModel: viewModel))
            hostingController.view.wantsLayer = true
            let fittingSize = hostingController.view.fittingSize
            let size = NSSize(width: max(156, ceil(fittingSize.width)), height: max(56, ceil(fittingSize.height)))

            let targetFrame = computeFrame(on: screen, size: size)
            let startFrame = animated
                ? NSRect(origin: NSPoint(x: targetFrame.origin.x, y: targetFrame.origin.y + slideOffsetY), size: size)
                : targetFrame

            let panel = NSPanel(
                contentRect: startFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = hostingController
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.ignoresMouseEvents = true
            panel.alphaValue = animated ? 0.0 : 1.0
            panel.setFrame(startFrame, display: true)
            panel.orderFront(nil)

            entries.append((panel, targetFrame))
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.34
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.16, 0.32, 1.0)
                for entry in entries {
                    entry.panel.animator().setFrame(entry.targetFrame, display: true)
                    entry.panel.animator().alphaValue = 1.0
                }
            }
        }

        return entries.map(\.panel)
    }

    private func layout(panels: [NSPanel]) {
        for (index, panel) in panels.enumerated() where index < NSScreen.screens.count {
            let screen = NSScreen.screens[index]
            if let contentView = panel.contentViewController?.view {
                contentView.layoutSubtreeIfNeeded()
                let fittingSize = contentView.fittingSize
                let size = NSSize(width: max(156, ceil(fittingSize.width)), height: max(56, ceil(fittingSize.height)))
                panel.setFrame(computeFrame(on: screen, size: size), display: true)
            }
        }
    }

    private func computeFrame(on screen: NSScreen, size: NSSize) -> NSRect {
        let visibleFrame = screen.visibleFrame
        let originX = visibleFrame.midX - size.width / 2
        let originY = visibleFrame.maxY - size.height - 8
        return NSRect(origin: NSPoint(x: originX, y: originY), size: size)
    }
}
