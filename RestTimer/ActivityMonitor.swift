import Foundation
import CoreGraphics
import AppKit

/// 智能延迟休息配置
struct SmartDelayConfig: Equatable {
    var enabled: Bool = true
    var monitorKeyboard: Bool = true
    var monitorMouse: Bool = true
    var idleDelaySeconds: Int = 10
    var maxDelayMinutes: Int = 5 // 0 表示不限制
    var showPreBreakCountdown: Bool = true
    var idleResetMinutes: Int = 10 // 0 表示关闭

    var hasAnyMonitorEnabled: Bool {
        monitorKeyboard || monitorMouse
    }

    var maxDelayDuration: TimeInterval? {
        maxDelayMinutes > 0 ? TimeInterval(maxDelayMinutes * 60) : nil
    }

    var idleResetDuration: TimeInterval? {
        idleResetMinutes > 0 ? TimeInterval(idleResetMinutes * 60) : nil
    }
}

/// 轻提示倒计时原因
enum CountdownReason: Equatable {
    case idleTrigger
    case maxDelayCap
}

/// 触发进入休息的原因
enum BreakTriggerReason: Equatable {
    case idleThresholdReached
    case maxDelayReached
}

/// 待休息状态单次评估结果
enum PendingBreakDecision: Equatable {
    case waiting(overdue: TimeInterval, idleElapsed: TimeInterval, idleRemaining: TimeInterval)
    case countdown(secondsLeft: Int, reason: CountdownReason, overdue: TimeInterval)
    case triggerBreak(reason: BreakTriggerReason)
}

/// 系统键鼠输入采样抽象（便于单元测试注入）
protocol ActivitySampling {
    func secondsSinceLastKeyboardEvent() -> TimeInterval
    func secondsSinceLastMouseAction() -> TimeInterval
    func currentMouseLocation() -> CGPoint
    func now() -> TimeInterval
}

/// 基于 CoreGraphics + AppKit 的零权限采样实现（兼容 App Sandbox）
struct SystemActivitySampler: ActivitySampling {
    private static let keyboardEventTypes: [CGEventType] = [
        .keyDown,
        .flagsChanged
    ]

    private static let mouseActionEventTypes: [CGEventType] = [
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .scrollWheel,
        .leftMouseDragged,
        .rightMouseDragged
    ]

    func secondsSinceLastKeyboardEvent() -> TimeInterval {
        minSecondsSince(Self.keyboardEventTypes)
    }

    func secondsSinceLastMouseAction() -> TimeInterval {
        minSecondsSince(Self.mouseActionEventTypes)
    }

    func currentMouseLocation() -> CGPoint {
        NSEvent.mouseLocation
    }

    func now() -> TimeInterval {
        Date().timeIntervalSince1970
    }

    private func minSecondsSince(_ types: [CGEventType]) -> TimeInterval {
        var minIdle = TimeInterval.greatestFiniteMagnitude
        for type in types {
            let elapsed = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
            if elapsed.isFinite && elapsed >= 0 {
                minIdle = min(minIdle, elapsed)
            }
        }
        return minIdle
    }
}

/// 键鼠活动监测器：键盘与鼠标点击/滚轮走系统空闲计数，鼠标移动通过显式状态机 + 位移阈值过滤微抖动
final class ActivityMonitor {
    enum MouseTrackState: Equatable {
        case unprimed
        case anchored(position: CGPoint)
        case moved(position: CGPoint, at: TimeInterval)
    }

    private let sampler: ActivitySampling
    private let mouseMoveThreshold: CGFloat
    private(set) var mouseTrackState: MouseTrackState = .unprimed

    init(
        sampler: ActivitySampling = SystemActivitySampler(),
        mouseMoveThreshold: CGFloat = 15.0
    ) {
        self.sampler = sampler
        self.mouseMoveThreshold = mouseMoveThreshold
    }

    /// 重置鼠标采样基线（通常在启动专注或恢复监听时调用）
    func resetBaseline() {
        mouseTrackState = .anchored(position: sampler.currentMouseLocation())
    }

    /// 采样一次鼠标位置，仅当位移超过防抖阈值时记为有效鼠标移动
    func sampleMouseMovement() {
        let current = sampler.currentMouseLocation()
        let timestamp = sampler.now()

        switch mouseTrackState {
        case .unprimed:
            mouseTrackState = .anchored(position: current)

        case .anchored(let previous), .moved(let previous, _):
            let distance = hypot(current.x - previous.x, current.y - previous.y)
            if distance >= mouseMoveThreshold {
                mouseTrackState = .moved(position: current, at: timestamp)
            }
        }
    }

    /// 计算当前连续空闲时长（秒）
    func idleDuration(monitorKeyboard: Bool, monitorMouse: Bool) -> TimeInterval {
        if !monitorKeyboard && !monitorMouse {
            return .greatestFiniteMagnitude
        }

        var candidates: [TimeInterval] = []

        if monitorKeyboard {
            candidates.append(max(0, sampler.secondsSinceLastKeyboardEvent()))
        }

        if monitorMouse {
            sampleMouseMovement()
            candidates.append(max(0, sampler.secondsSinceLastMouseAction()))
            if case .moved(_, let lastMoveTime) = mouseTrackState {
                candidates.append(max(0, sampler.now() - lastMoveTime))
            }
        }

        return candidates.min() ?? .greatestFiniteMagnitude
    }
}

/// 纯函数决策器：根据顺延时长、空闲时长与配置判定待休息阶段行为
enum BreakDelayEvaluator {
    static let maxCapWarningWindow: TimeInterval = 15.0

    static func evaluatePendingBreak(
        overdue: TimeInterval,
        idleElapsed: TimeInterval,
        config: SmartDelayConfig
    ) -> PendingBreakDecision {
        let safeOverdue = max(0, overdue)
        let safeIdle = max(0, idleElapsed)

        // 1. 先检查最大延迟硬上限
        if let maxCap = config.maxDelayDuration {
            if safeOverdue >= maxCap {
                return .triggerBreak(reason: .maxDelayReached)
            }
        }

        // 2. 再检查是否满足空闲触发阈值
        let idleThreshold = TimeInterval(max(1, config.idleDelaySeconds))
        if safeIdle >= idleThreshold {
            return .triggerBreak(reason: .idleThresholdReached)
        }

        // 3. 若已接近硬上限（最后 15 秒），优先展示硬上限倒数提示
        if let maxCap = config.maxDelayDuration {
            let capRemaining = maxCap - safeOverdue
            if capRemaining <= maxCapWarningWindow {
                return .countdown(
                    secondsLeft: max(1, Int(ceil(capRemaining))),
                    reason: .maxDelayCap,
                    overdue: safeOverdue
                )
            }
        }

        // 4. 若接近空闲触发阈值（最后 3 秒，或短阈值的一半），展示空闲轻提示
        let idleRemaining = idleThreshold - safeIdle
        let countdownWindow = min(3.0, max(1.0, floor(idleThreshold / 2.0)))
        if config.showPreBreakCountdown && idleRemaining <= countdownWindow {
            return .countdown(
                secondsLeft: max(1, Int(ceil(idleRemaining))),
                reason: .idleTrigger,
                overdue: safeOverdue
            )
        }

        return .waiting(
            overdue: safeOverdue,
            idleElapsed: safeIdle,
            idleRemaining: idleRemaining
        )
    }

    /// 判断专注期间是否因长时间离开电脑而应进入“自然离开”挂起状态（未达到重计阈值时绝不清零，防止刷手机误重置）
    static func shouldEnterAwayState(
        elapsedWork: TimeInterval,
        idleElapsed: TimeInterval,
        idleResetDuration: TimeInterval?
    ) -> Bool {
        guard let resetThreshold = idleResetDuration, resetThreshold > 0 else { return false }
        // 至少专注超过 10 秒后才触发，避免刚重置完一直不动时反复重置
        guard elapsedWork >= 10 else { return false }
        return idleElapsed >= resetThreshold
    }

    /// 处于“自然离开”状态时，用户是否已回到电脑前操作
    static func shouldResumeFromAway(idleElapsed: TimeInterval) -> Bool {
        idleElapsed < 2.0
    }

    /// 锁屏解锁或息屏唤醒时，判定是否达到重开新一轮的条件（短时误锁与未锁屏短息屏均恢复原进度）
    static func shouldResetOnSystemReturn(
        inactiveElapsed: TimeInterval,
        wasLocked: Bool,
        breakDuration: TimeInterval,
        idleResetDuration: TimeInterval?
    ) -> Bool {
        if wasLocked {
            return breakDuration > 0 && inactiveElapsed >= breakDuration
        }
        guard let resetThreshold = idleResetDuration, resetThreshold > 0 else { return false }
        return inactiveElapsed >= resetThreshold
    }
}
