import AppKit
import QuartzCore
import SwiftUI

final class PreBreakHudViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var isWarningCap: Bool = false
    @Published var countdownProgress: Double = 1.0
}

private struct PreBreakHudView: View {
    @ObservedObject var viewModel: PreBreakHudViewModel

    var body: some View {
        let accent: Color = viewModel.isWarningCap ? .orange : Color.accentColor
        FrostedHudCapsulePill(
            iconKind: viewModel.isWarningCap
                ? .warningCap(progress: viewModel.countdownProgress)
                : .breakCountdown(progress: viewModel.countdownProgress),
            title: viewModel.title,
            accent: accent
        )
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
    private var idleTotalSeconds: Int = 3
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
                tearDownPanels(panels)
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
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.tearDownPanels(panels)
            }
        })
    }

    private func handleScreenParametersChanged() {
        guard case .visible(let panels, let reason, let secondsLeft) = state else { return }
        tearDownPanels(panels)
        let rebuilt = createPanels(animated: false)
        state = .visible(panels: rebuilt, reason: reason, secondsLeft: secondsLeft)
    }

    private func tearDownPanels(_ panels: [NSPanel]) {
        for panel in panels {
            panel.orderOut(nil)
            panel.contentViewController = nil
            panel.contentView = nil
            panel.close()
        }
    }

    private func updateViewModel(secondsLeft: Int, reason: CountdownReason) {
        if case .hidden = state {
            idleTotalSeconds = max(3, secondsLeft)
        }
        switch reason {
        case .idleTrigger:
            viewModel.isWarningCap = false
            viewModel.title = "\(secondsLeft)秒后休息"
            viewModel.subtitle = ""
            idleTotalSeconds = max(idleTotalSeconds, secondsLeft)
            viewModel.countdownProgress = min(1.0, max(0.0, Double(secondsLeft) / Double(max(1, idleTotalSeconds))))
        case .maxDelayCap:
            viewModel.isWarningCap = true
            viewModel.title = "\(secondsLeft)秒后休息"
            viewModel.subtitle = ""
            viewModel.countdownProgress = min(1.0, max(0.0, Double(secondsLeft) / BreakDelayEvaluator.maxCapWarningWindow))
        }
    }

    private func createPanels(animated: Bool) -> [NSPanel] {
        var entries: [(panel: NSPanel, targetFrame: NSRect)] = []

        for screen in NSScreen.screens {
            let hostingController = NSHostingController(rootView: PreBreakHudView(viewModel: viewModel))
            hostingController.view.wantsLayer = true
            let fittingSize = hostingController.view.fittingSize
            let size = NSSize(width: max(136, ceil(fittingSize.width)), height: max(64, ceil(fittingSize.height)))

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
                let size = NSSize(width: max(136, ceil(fittingSize.width)), height: max(64, ceil(fittingSize.height)))
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
