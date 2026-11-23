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
        HStack(spacing: 10) {
            Image(systemName: viewModel.isWarningCap ? "exclamationmark.circle.fill" : "cup.and.saucer.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(viewModel.isWarningCap ? .orange : .cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text(viewModel.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.78))
                .overlay(
                    Capsule()
                        .stroke(
                            (viewModel.isWarningCap ? Color.orange : Color.white).opacity(0.25),
                            lineWidth: 1
                        )
                )
        )
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
            viewModel.title = "\(secondsLeft) 秒后进入休息"
            viewModel.subtitle = "继续操作键盘或鼠标可推迟"
        case .maxDelayCap:
            viewModel.isWarningCap = true
            viewModel.title = "\(secondsLeft) 秒后强制休息"
            viewModel.subtitle = "已达到最长顺延上限，请保存进度"
        }
    }

    private func createPanels() -> [NSPanel] {
        var result: [NSPanel] = []

        for screen in NSScreen.screens {
            let hostingController = NSHostingController(rootView: PreBreakHudView(viewModel: viewModel))
            hostingController.view.wantsLayer = true
            let fittingSize = hostingController.view.fittingSize
            let size = NSSize(width: max(240, fittingSize.width), height: max(48, fittingSize.height))

            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = hostingController
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.ignoresMouseEvents = true
            panel.alphaValue = 0.98

            position(panel: panel, on: screen, size: size)
            panel.orderFront(nil)
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
                let size = NSSize(width: max(240, fittingSize.width), height: max(48, fittingSize.height))
                position(panel: panel, on: screen, size: size)
            }
        }
    }

    private func position(panel: NSPanel, on screen: NSScreen, size: NSSize) {
        let visibleFrame = screen.visibleFrame
        let originX = visibleFrame.midX - size.width / 2
        let originY = visibleFrame.maxY - size.height - 20
        panel.setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: size), display: true)
    }
}
