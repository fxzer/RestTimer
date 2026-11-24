import AppKit
import SwiftUI

final class PreBreakHudViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var isWarningCap: Bool = false
}

private struct PreBreakHudView: View {
    @ObservedObject var viewModel: PreBreakHudViewModel

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: viewModel.isWarningCap ? "exclamationmark.circle.fill" : "cup.and.saucer.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(viewModel.isWarningCap ? .orange : Color.accentColor)

            Text(viewModel.title)
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

/// 休息前轻提示浮窗管理器：显式 HudState 状态机 + 监听屏幕变更，不抢焦点、不拦截输入
final class PreBreakHudManager {
    private enum HudState {
        case hidden
        case visible(panels: [NSPanel], reason: CountdownReason, secondsLeft: Int)
    }

    private let viewModel = PreBreakHudViewModel()
    private var state: HudState = .hidden
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
            let panels = createPanels()
            state = .visible(panels: panels, reason: reason, secondsLeft: secondsLeft)

        case .visible(let panels, _, _):
            if panels.count != NSScreen.screens.count {
                panels.forEach { $0.close() }
                let rebuilt = createPanels()
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
        panels.forEach { $0.close() }
        state = .hidden
    }

    private func handleScreenParametersChanged() {
        guard case .visible(let panels, let reason, let secondsLeft) = state else { return }
        panels.forEach { $0.close() }
        let rebuilt = createPanels()
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

    private func createPanels() -> [NSPanel] {
        var result: [NSPanel] = []

        for screen in NSScreen.screens {
            let hostingController = NSHostingController(rootView: PreBreakHudView(viewModel: viewModel))
            hostingController.view.wantsLayer = true
            let fittingSize = hostingController.view.fittingSize
            let size = NSSize(width: max(150, ceil(fittingSize.width)), height: max(44, ceil(fittingSize.height)))

            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
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
            panel.alphaValue = 0.0

            position(panel: panel, on: screen, size: size)
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1.0
            }
            result.append(panel)
        }

        return result
    }

    private func layout(panels: [NSPanel]) {
        for (index, panel) in panels.enumerated() where index < NSScreen.screens.count {
            let screen = NSScreen.screens[index]
            if let contentView = panel.contentViewController?.view {
                contentView.layoutSubtreeIfNeeded()
                let fittingSize = contentView.fittingSize
                let size = NSSize(width: max(150, ceil(fittingSize.width)), height: max(44, ceil(fittingSize.height)))
                position(panel: panel, on: screen, size: size)
            }
        }
    }

    private func position(panel: NSPanel, on screen: NSScreen, size: NSSize) {
        let visibleFrame = screen.visibleFrame
        let originX = visibleFrame.midX - size.width / 2
        let originY = visibleFrame.maxY - size.height - 10
        panel.setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: size), display: true)
    }
}
