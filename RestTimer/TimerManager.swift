import Foundation
import AppKit
import SwiftUI

internal final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    private static let settingsKey = "TimerSettings"

    private enum PreviewRestoreTarget {
        case idle
        case working(remaining: TimeInterval)
        case pendingBreak(overdue: TimeInterval)
        case away
        case paused(snapshot: PauseSnapshot, reason: PauseReason)
    }

    @Published private(set) var state: SessionState = .idle
    @Published private(set) var isBreakPreview: Bool = false
    @Published var settings: TimerSettings {
        didSet {
            handleSettingsDidChange(from: oldValue)
        }
    }

    private let activityMonitor: ActivityMonitor
    private let preBreakHud = PreBreakHudManager()
    private let toastOverlay = NotificationOverlayManager()
    private let breakWindowManager = BreakWindowManager()

    private var workTimer: Timer?
    private var earlyNotifyTimer: Timer?
    private var breakTimer: Timer?
    private var breakDeadline: TimeInterval?
    private var breakWatchdogWorkItem: DispatchWorkItem?
    private var activityCheckTimer: Timer?
    private var startupWorkItem: DispatchWorkItem?
    private var dockPolicyWorkItem: DispatchWorkItem?
    private var previewRestoreTarget: PreviewRestoreTarget?
    private var isAdjustingSettings = false

    // MARK: - 派生属性（全部源自单一状态机与配置，杜绝镜像失步）

    var isPaused: Bool { state.isPaused }
    var isBreakTime: Bool { state.isBreaking }
    var preventQuit: Bool { !isBreakPreview && state.preventQuit }
    var remainingBreakTime: TimeInterval { state.remainingBreakTime }
    var pendingOverdueSeconds: TimeInterval { state.pendingOverdueSeconds }

    var workDuration: TimeInterval { TimeInterval(settings.workTotalSeconds) }
    var breakDuration: TimeInterval { TimeInterval(settings.breakTotalSeconds) }
    var earlyNotifyDuration: TimeInterval { TimeInterval(settings.earlyNotifyTotalSeconds) }

    var smartDelayConfig: SmartDelayConfig {
        SmartDelayConfig(
            enabled: settings.smartDelayEnabled,
            monitorKeyboard: settings.monitorKeyboard,
            monitorMouse: settings.monitorMouse,
            idleDelaySeconds: settings.idleDelaySeconds,
            maxDelayMinutes: settings.maxDelayMinutes,
            showPreBreakCountdown: settings.showPreBreakCountdown,
            autoResetOnIdle: settings.autoResetOnIdle
        )
    }

    // MARK: - 初始化

    init(
        activityMonitor: ActivityMonitor = ActivityMonitor(),
        autoStart: Bool = true
    ) {
        self.activityMonitor = activityMonitor

        let loadedSettings: TimerSettings
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(TimerSettings.self, from: data) {
            loadedSettings = decoded
        } else {
            loadedSettings = .default
            if let encoded = try? JSONEncoder().encode(loadedSettings) {
                UserDefaults.standard.set(encoded, forKey: Self.settingsKey)
            }
        }
        self.settings = loadedSettings

        if autoStart {
            scheduleDockIconUpdate()
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, self.state == .idle else { return }
                self.transition(to: .working(startedAt: Date().timeIntervalSince1970), notifyWorkStart: true)
            }
            startupWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
        }
    }

    deinit {
        startupWorkItem?.cancel()
        dockPolicyWorkItem?.cancel()
        invalidateAllTimers()
        preBreakHud.hide()
        toastOverlay.dismissImmediately()
        breakWindowManager.hide()
    }

    // MARK: - 公共操作入口

    func skipBreak() {
        runOnMain {
            if self.isBreakPreview {
                self.endBreakPreview()
                return
            }
            self.transition(to: .working(startedAt: Date().timeIntervalSince1970), notifyWorkStart: true)
        }
    }

    /// 紧急逃生通道（连按 3 次 Esc / ⌘⇧Esc / 退出应用时触发）：无条件立刻撤销全部遮罩窗并退出休息
    func emergencyExitBreak() {
        runOnMain {
            self.breakWindowManager.hide(animated: false)
            if self.isBreakPreview {
                self.endBreakPreview()
            } else if self.state.isBreaking {
                self.transition(to: .working(startedAt: Date().timeIntervalSince1970), notifyWorkStart: false)
            }
        }
    }

    /// 正式立即进入休息（如菜单栏点击「休息」）：触发媒体自动暂停，遵循「显示跳过按钮」设置
    func startBreakImmediately() {
        runOnMain {
            if self.isBreakPreview {
                self.isBreakPreview = false
                self.previewRestoreTarget = nil
            }
            guard !self.state.isBreaking else { return }
            self.startupWorkItem?.cancel()
            self.startupWorkItem = nil
            self.transition(to: .breaking(remaining: self.breakDuration))
        }
    }

    /// 主题预览模式：不暂停媒体，退出预览后无损恢复预览前的专注剩余时间
    func startBreakPreview() {
        runOnMain {
            guard !self.state.isBreaking else { return }
            let now = Date().timeIntervalSince1970
            switch self.state {
            case .idle:
                self.previewRestoreTarget = .idle
            case .working(let startedAt):
                let remaining = max(1.0, self.workDuration - (now - startedAt))
                self.previewRestoreTarget = .working(remaining: remaining)
            case .pendingBreak(let startedAt, _):
                self.previewRestoreTarget = .pendingBreak(overdue: max(0, now - startedAt))
            case .away:
                self.previewRestoreTarget = .away
            case .paused(let snapshot, let reason):
                self.previewRestoreTarget = .paused(snapshot: snapshot, reason: reason)
            case .breaking:
                return
            }
            self.startupWorkItem?.cancel()
            self.startupWorkItem = nil
            self.isBreakPreview = true
            self.transition(to: .breaking(remaining: self.breakDuration))
        }
    }

    /// 退出主题预览并无损恢复原有专注进度
    func endBreakPreview() {
        runOnMain {
            guard self.isBreakPreview else { return }
            let restoreTarget = self.previewRestoreTarget ?? .idle
            self.isBreakPreview = false
            self.previewRestoreTarget = nil

            let now = Date().timeIntervalSince1970
            switch restoreTarget {
            case .idle:
                self.transition(to: .idle)
            case .working(let remaining):
                let adjustedStart = now - (self.workDuration - remaining)
                self.transition(to: .working(startedAt: adjustedStart), notifyWorkStart: false)
            case .pendingBreak(let overdue):
                let adjustedStart = now - max(0, overdue)
                self.transition(to: .pendingBreak(startedAt: adjustedStart, overdue: max(0, overdue)))
            case .away:
                self.transition(to: .away)
            case .paused(let snapshot, let reason):
                self.transition(to: .paused(snapshot: snapshot, reason: reason))
            }
        }
    }

    func toggleManualPause() {
        runOnMain {
            if self.state.isPaused {
                self.resume()
            } else {
                self.pause(reason: .manual)
            }
        }
    }

    func pause(reason: PauseReason) {
        runOnMain {
            if self.isBreakPreview {
                self.endBreakPreview()
            }
            self.startupWorkItem?.cancel()
            self.startupWorkItem = nil

            let now = Date().timeIntervalSince1970
            switch self.state {
            case .idle:
                let snapshot = PauseSnapshot.working(remaining: self.workDuration)
                self.transition(to: .paused(snapshot: snapshot, reason: reason))

            case .working(let startedAt):
                let remaining = max(0, self.workDuration - (now - startedAt))
                self.transition(to: .paused(snapshot: .working(remaining: remaining), reason: reason))

            case .pendingBreak(let startedAt, _):
                let overdue = max(0, now - startedAt)
                self.transition(to: .paused(snapshot: .pendingBreak(overdue: overdue), reason: reason))

            case .breaking(let remaining):
                self.transition(to: .paused(snapshot: .breaking(remaining: remaining), reason: reason))

            case .away:
                self.transition(to: .paused(snapshot: .away, reason: reason))

            case .paused(_, let existingReason):
                // 不允许系统锁屏覆盖用户主动暂停的原因
                if existingReason == .manual && reason == .systemLocked {
                    return
                }
            }
        }
    }

    func resume() {
        runOnMain {
            guard case .paused(let snapshot, _) = self.state else { return }
            let now = Date().timeIntervalSince1970

            switch snapshot {
            case .working(let remaining):
                if remaining <= 0 {
                    self.handleWorkExpiredFromResume()
                } else {
                    let adjustedStart = now - (self.workDuration - remaining)
                    self.transition(to: .working(startedAt: adjustedStart), notifyWorkStart: false)
                }

            case .pendingBreak(let overdue):
                let adjustedStart = now - max(0, overdue)
                self.transition(to: .pendingBreak(startedAt: adjustedStart, overdue: max(0, overdue)))

            case .breaking(let remaining):
                if remaining <= 0 {
                    self.transition(to: .working(startedAt: now), notifyWorkStart: true)
                } else {
                    self.transition(to: .breaking(remaining: remaining))
                }

            case .away:
                self.transition(to: .working(startedAt: now), notifyWorkStart: true)
            }
        }
    }

    func handleSystemLock() {
        pause(reason: .systemLocked)
    }

    func handleSystemUnlock() {
        runOnMain {
            // 保留用户在锁屏前主动触发的手动暂停
            if case .paused(_, .manual) = self.state {
                return
            }
            self.resetTimer()
        }
    }

    func resetTimer() {
        runOnMain {
            self.isBreakPreview = false
            self.previewRestoreTarget = nil
            self.startupWorkItem?.cancel()
            self.startupWorkItem = nil
            self.transition(to: .working(startedAt: Date().timeIntervalSince1970), notifyWorkStart: true)
        }
    }

    /// 原子校验并更新所有时间设置，避免逐字段修改触发中间非法状态
    @discardableResult
    func updateTimeSettings(
        workMinutes: Int,
        workSeconds: Int,
        breakMinutes: Int,
        breakSeconds: Int,
        earlyMinutes: Int,
        earlySeconds: Int
    ) -> Result<Void, TimeSettingsValidationError> {
        let validation = TimerSettings.validateTimeValues(
            workMinutes: workMinutes,
            workSeconds: workSeconds,
            breakMinutes: breakMinutes,
            breakSeconds: breakSeconds,
            earlyMinutes: earlyMinutes,
            earlySeconds: earlySeconds
        )

        guard case .success = validation else {
            return validation
        }

        let workChanged = settings.workDurationMinutes != workMinutes
            || settings.workDurationSeconds != workSeconds
            || settings.earlyNotifyMinutes != earlyMinutes
            || settings.earlyNotifySeconds != earlySeconds

        var updated = settings
        updated.workDurationMinutes = workMinutes
        updated.workDurationSeconds = workSeconds
        updated.breakDurationMinutes = breakMinutes
        updated.breakDurationSeconds = breakSeconds
        updated.earlyNotifyMinutes = earlyMinutes
        updated.earlyNotifySeconds = earlySeconds
        settings = updated

        if workChanged && !state.isBreaking && !state.isPaused {
            resetTimer()
        }

        return .success(())
    }

    // MARK: - 状态机唯一转换入口

    private func transition(to newState: SessionState, notifyWorkStart: Bool = false) {
        assert(Thread.isMainThread, "SessionState transitions must happen on main thread")
        let wasBreaking = state.isBreaking
        invalidateAllTimers()
        state = newState

        switch newState {
        case .idle:
            breakWindowManager.hide()
            preBreakHud.hide()
            toastOverlay.dismissImmediately()

        case .working(let startedAt):
            breakWindowManager.hide()
            preBreakHud.hide()
            activityMonitor.resetBaseline()

            let now = Date().timeIntervalSince1970
            let remaining = max(0, workDuration - (now - startedAt))
            if remaining <= 0 {
                handleWorkTimerExpired()
                return
            }
            if notifyWorkStart {
                toastOverlay.show(.workStarted)
            }
            if earlyNotifyDuration > 0 && remaining > earlyNotifyDuration {
                let delay = remaining - earlyNotifyDuration
                earlyNotifyTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    self?.showEarlyNotification()
                }
            }
            workTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
                self?.handleWorkTimerExpired()
            }
            startActivityCheckTimer(interval: 1.0)

        case .pendingBreak:
            breakWindowManager.hide()
            toastOverlay.dismissImmediately()
            startActivityCheckTimer(interval: 0.5)
            evaluateActivityTick()

        case .breaking(let initialRemaining):
            preBreakHud.hide()
            toastOverlay.dismissImmediately()
            if !wasBreaking && !isBreakPreview && settings.pauseMediaOnBreak {
                MediaPlaybackPauser.pauseActiveMediaIfNeeded()
            }
            breakWindowManager.show(timerManager: self)

            let safeDuration = max(1.0, initialRemaining)
            breakDeadline = Date().timeIntervalSince1970 + safeDuration

            // 挂载至 RunLoop.Mode.common，防止菜单/拖拽等模态循环阻塞倒计时
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                self.handleBreakTick()
            }
            RunLoop.main.add(timer, forMode: .common)
            breakTimer = timer

            // 硬超时看门狗：即使 Timer 意外停摆，到期后 +2s 仍强制关闭休息窗，杜绝卡死
            let watchdog = DispatchWorkItem { [weak self] in
                guard let self = self, self.state.isBreaking else { return }
                self.finishBreakNormally()
            }
            breakWatchdogWorkItem = watchdog
            DispatchQueue.main.asyncAfter(deadline: .now() + safeDuration + 2.0, execute: watchdog)

        case .away:
            breakWindowManager.hide()
            preBreakHud.hide()
            startActivityCheckTimer(interval: 1.0)

        case .paused:
            breakWindowManager.hide()
            preBreakHud.hide()
            toastOverlay.dismissImmediately()
        }
    }

    // MARK: - 内部事件处理

    private func handleBreakTick() {
        guard case .breaking = state else {
            breakTimer?.invalidate()
            breakTimer = nil
            return
        }

        let remaining: TimeInterval
        if let deadline = breakDeadline {
            remaining = max(0, deadline - Date().timeIntervalSince1970)
        } else {
            remaining = 0
        }

        if remaining > 0.25 {
            state = .breaking(remaining: ceil(remaining))
        } else {
            finishBreakNormally()
        }
    }

    private func finishBreakNormally() {
        guard state.isBreaking else { return }
        if isBreakPreview {
            endBreakPreview()
        } else {
            // 休息自然结束时播放一声轻柔系统提示音，方便闭眼拉伸或离座时知晓
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                NSSound(named: NSSound.Name("Glass"))?.play()
            }
            transition(to: .working(startedAt: Date().timeIntervalSince1970), notifyWorkStart: true)
        }
    }

    private func handleWorkTimerExpired() {
        guard case .working = state else { return }
        handleWorkExpiredFromResume()
    }

    private func handleWorkExpiredFromResume() {
        let config = smartDelayConfig
        guard config.enabled && config.hasAnyMonitorEnabled else {
            transition(to: .breaking(remaining: breakDuration))
            return
        }

        let currentIdle = activityMonitor.idleDuration(
            monitorKeyboard: config.monitorKeyboard,
            monitorMouse: config.monitorMouse
        )
        if currentIdle >= TimeInterval(max(1, config.idleDelaySeconds)) {
            transition(to: .breaking(remaining: breakDuration))
            return
        }

        transition(to: .pendingBreak(startedAt: Date().timeIntervalSince1970, overdue: 0))
    }

    private func showEarlyNotification() {
        guard case .working = state else { return }
        let total = Int(earlyNotifyDuration)
        toastOverlay.show(.earlyWarning(minutes: total / 60, seconds: total % 60))
    }

    private func evaluateActivityTick() {
        assert(Thread.isMainThread)

        switch state {
        case .working(let startedAt):
            if settings.smartDelayEnabled && settings.monitorMouse {
                activityMonitor.sampleMouseMovement()
            }
            if settings.autoResetOnIdle {
                let idle = activityMonitor.idleDuration(monitorKeyboard: true, monitorMouse: true)
                let elapsedWork = Date().timeIntervalSince1970 - startedAt
                if BreakDelayEvaluator.shouldEnterAwayState(
                    elapsedWork: elapsedWork,
                    idleElapsed: idle,
                    breakDuration: breakDuration,
                    autoResetEnabled: settings.autoResetOnIdle
                ) {
                    transition(to: .away)
                }
            }

        case .away:
            let idle = activityMonitor.idleDuration(monitorKeyboard: true, monitorMouse: true)
            if BreakDelayEvaluator.shouldResumeFromAway(idleElapsed: idle) {
                transition(to: .working(startedAt: Date().timeIntervalSince1970), notifyWorkStart: true)
            }

        case .pendingBreak(let startedAt, _):
            let config = smartDelayConfig
            guard config.enabled && config.hasAnyMonitorEnabled else {
                transition(to: .breaking(remaining: breakDuration))
                return
            }

            let overdue = max(0, Date().timeIntervalSince1970 - startedAt)
            state = .pendingBreak(startedAt: startedAt, overdue: overdue)

            let idle = activityMonitor.idleDuration(
                monitorKeyboard: config.monitorKeyboard,
                monitorMouse: config.monitorMouse
            )
            let decision = BreakDelayEvaluator.evaluatePendingBreak(
                overdue: overdue,
                idleElapsed: idle,
                config: config
            )

            switch decision {
            case .waiting:
                preBreakHud.hide()
            case .countdown(let secondsLeft, let reason, _):
                preBreakHud.showOrUpdate(secondsLeft: secondsLeft, reason: reason)
            case .triggerBreak:
                transition(to: .breaking(remaining: breakDuration))
            }

        case .idle, .breaking, .paused:
            stopActivityCheckTimer()
        }
    }

    // MARK: - 配置变更与持久化

    private func handleSettingsDidChange(from oldValue: TimerSettings) {
        guard !isAdjustingSettings else { return }

        let clampedIdle = min(max(settings.idleDelaySeconds, 3), 120)
        let clampedMaxDelay = settings.maxDelayMinutes <= 0 ? 5 : min(settings.maxDelayMinutes, 10)
        if clampedIdle != settings.idleDelaySeconds || clampedMaxDelay != settings.maxDelayMinutes {
            isAdjustingSettings = true
            settings.idleDelaySeconds = clampedIdle
            settings.maxDelayMinutes = clampedMaxDelay
            isAdjustingSettings = false
        }

        guard settings != oldValue else { return }
        saveSettings()

        if settings.showDockIcon != oldValue.showDockIcon {
            scheduleDockIconUpdate()
        }

        if !settings.showPreBreakCountdown && oldValue.showPreBreakCountdown {
            preBreakHud.hide()
        }

        if !settings.autoResetOnIdle && state == .away {
            transition(to: .working(startedAt: Date().timeIntervalSince1970), notifyWorkStart: true)
        }

        if case .pendingBreak = state {
            let config = smartDelayConfig
            if !config.enabled || !config.hasAnyMonitorEnabled {
                transition(to: .breaking(remaining: breakDuration))
            }
        }
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: Self.settingsKey)
        }
    }

    /// 可取消的 Dock 策略切换，避免快速切换开关时多层 asyncAfter 互相踩踏
    private func scheduleDockIconUpdate() {
        dockPolicyWorkItem?.cancel()

        let showDock = settings.showDockIcon
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let targetPolicy: NSApplication.ActivationPolicy = showDock ? .regular : .accessory
            if NSApp.activationPolicy() != targetPolicy {
                NSApp.setActivationPolicy(targetPolicy)
            }

            let activateItem = DispatchWorkItem {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.forEach { window in
                    if window.isVisible {
                        window.orderFront(nil)
                    }
                }
            }
            self.dockPolicyWorkItem = activateItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: activateItem)
        }

        dockPolicyWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    // MARK: - 定时器与线程辅助

    private func startActivityCheckTimer(interval: TimeInterval) {
        stopActivityCheckTimer()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.evaluateActivityTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        activityCheckTimer = timer
    }

    private func stopActivityCheckTimer() {
        activityCheckTimer?.invalidate()
        activityCheckTimer = nil
    }

    private func invalidateAllTimers() {
        workTimer?.invalidate()
        workTimer = nil
        earlyNotifyTimer?.invalidate()
        earlyNotifyTimer = nil
        breakTimer?.invalidate()
        breakTimer = nil
        breakDeadline = nil
        breakWatchdogWorkItem?.cancel()
        breakWatchdogWorkItem = nil
        stopActivityCheckTimer()
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
