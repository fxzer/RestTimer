import Foundation

/// 暂停来源：区分用户主动暂停与系统锁屏/息屏触发的自动暂停
enum PauseReason: Equatable {
    case manual
    case systemLocked
}

/// 暂停前的工作快照，用于恢复时精确还原
enum PauseSnapshot: Equatable {
    case working(remaining: TimeInterval)
    case pendingBreak(overdue: TimeInterval)
    case breaking(remaining: TimeInterval)
    case away
}

/// 主计时器单一显式状态机（状态与其负载绑定，消除非法状态组合）
enum SessionState: Equatable {
    case idle
    case working(startedAt: TimeInterval)
    case pendingBreak(startedAt: TimeInterval, overdue: TimeInterval)
    case breaking(remaining: TimeInterval)
    case away
    case paused(snapshot: PauseSnapshot, reason: PauseReason)

    var isBreaking: Bool {
        if case .breaking = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var pauseReason: PauseReason? {
        if case .paused(_, let reason) = self { return reason }
        return nil
    }

    var preventQuit: Bool {
        switch self {
        case .breaking:
            return true
        case .paused(let snapshot, _):
            if case .breaking = snapshot { return true }
            return false
        default:
            return false
        }
    }

    var remainingBreakTime: TimeInterval {
        switch self {
        case .breaking(let remaining):
            return remaining
        case .paused(.breaking(let remaining), _):
            return remaining
        default:
            return 0
        }
    }

    var pendingOverdueSeconds: TimeInterval {
        switch self {
        case .pendingBreak(_, let overdue):
            return overdue
        case .paused(.pendingBreak(let overdue), _):
            return overdue
        default:
            return 0
        }
    }

    var pausedRemainingTime: TimeInterval? {
        guard case .paused(let snapshot, _) = self else { return nil }
        switch snapshot {
        case .working(let remaining), .breaking(let remaining):
            return remaining
        case .pendingBreak, .away:
            return nil
        }
    }
}

/// 系统息屏 / 锁屏存在性追踪器：将 4 个系统通知收敛为无重复的状态流转
struct ScreenPresenceTracker: Equatable {
    private(set) var isScreenLocked = false
    private(set) var isScreenAsleep = false

    enum Action: Equatable {
        case none
        case pauseForSystemLock
        case resetOnSystemUnlock
    }

    var isInactive: Bool {
        isScreenLocked || isScreenAsleep
    }

    mutating func handleScreenLocked() -> Action {
        let wasInactive = isInactive
        isScreenLocked = true
        return wasInactive ? .none : .pauseForSystemLock
    }

    mutating func handleScreenSlept() -> Action {
        let wasInactive = isInactive
        isScreenAsleep = true
        return wasInactive ? .none : .pauseForSystemLock
    }

    mutating func handleScreenWoke() -> Action {
        let wasInactive = isInactive
        isScreenAsleep = false
        // 若仍处于锁屏密码页，等待真正解锁通知再重置
        guard wasInactive && !isInactive else { return .none }
        return .resetOnSystemUnlock
    }

    mutating func handleScreenUnlocked() -> Action {
        let wasInactive = isInactive
        isScreenLocked = false
        isScreenAsleep = false
        return wasInactive ? .resetOnSystemUnlock : .none
    }
}

/// 时间设置原子校验错误
enum TimeSettingsValidationError: LocalizedError, Equatable {
    case invalidInput
    case workDurationMustBePositive
    case breakDurationMustBePositive
    case earlyNotifyMustBeLessThanWork

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "请输入有效的时间值"
        case .workDurationMustBePositive:
            return "专注时长必须大于 0 秒"
        case .breakDurationMustBePositive:
            return "休息时长必须大于 0 秒"
        case .earlyNotifyMustBeLessThanWork:
            return "提前提醒时长不能大于或等于专注时长"
        }
    }
}

/// 持久化配置模型（兼容历史版本的缺省字段解码）
struct TimerSettings: Codable, Equatable {
    var showSkipButton: Bool
    var showDockIcon: Bool
    var workDurationMinutes: Int
    var workDurationSeconds: Int
    var breakDurationMinutes: Int
    var breakDurationSeconds: Int
    var earlyNotifyMinutes: Int
    var earlyNotifySeconds: Int
    var smartDelayEnabled: Bool = true
    var monitorKeyboard: Bool = true
    var monitorMouse: Bool = true
    var idleDelaySeconds: Int = 10
    var maxDelayMinutes: Int = 5
    var showPreBreakCountdown: Bool = true
    var autoResetOnIdle: Bool = true

    static let `default` = TimerSettings(
        showSkipButton: false,
        showDockIcon: true,
        workDurationMinutes: 25,
        workDurationSeconds: 0,
        breakDurationMinutes: 5,
        breakDurationSeconds: 0,
        earlyNotifyMinutes: 2,
        earlyNotifySeconds: 0,
        smartDelayEnabled: true,
        monitorKeyboard: true,
        monitorMouse: true,
        idleDelaySeconds: 10,
        maxDelayMinutes: 5,
        showPreBreakCountdown: true,
        autoResetOnIdle: true
    )

    init(
        showSkipButton: Bool,
        showDockIcon: Bool,
        workDurationMinutes: Int,
        workDurationSeconds: Int,
        breakDurationMinutes: Int,
        breakDurationSeconds: Int,
        earlyNotifyMinutes: Int,
        earlyNotifySeconds: Int,
        smartDelayEnabled: Bool = true,
        monitorKeyboard: Bool = true,
        monitorMouse: Bool = true,
        idleDelaySeconds: Int = 10,
        maxDelayMinutes: Int = 5,
        showPreBreakCountdown: Bool = true,
        autoResetOnIdle: Bool = true
    ) {
        self.showSkipButton = showSkipButton
        self.showDockIcon = showDockIcon
        self.workDurationMinutes = workDurationMinutes
        self.workDurationSeconds = workDurationSeconds
        self.breakDurationMinutes = breakDurationMinutes
        self.breakDurationSeconds = breakDurationSeconds
        self.earlyNotifyMinutes = earlyNotifyMinutes
        self.earlyNotifySeconds = earlyNotifySeconds
        self.smartDelayEnabled = smartDelayEnabled
        self.monitorKeyboard = monitorKeyboard
        self.monitorMouse = monitorMouse
        self.idleDelaySeconds = idleDelaySeconds
        self.maxDelayMinutes = maxDelayMinutes
        self.showPreBreakCountdown = showPreBreakCountdown
        self.autoResetOnIdle = autoResetOnIdle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.default
        showSkipButton = try container.decodeIfPresent(Bool.self, forKey: .showSkipButton) ?? fallback.showSkipButton
        showDockIcon = try container.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? fallback.showDockIcon
        workDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .workDurationMinutes) ?? fallback.workDurationMinutes
        workDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .workDurationSeconds) ?? fallback.workDurationSeconds
        breakDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .breakDurationMinutes) ?? fallback.breakDurationMinutes
        breakDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .breakDurationSeconds) ?? fallback.breakDurationSeconds
        earlyNotifyMinutes = try container.decodeIfPresent(Int.self, forKey: .earlyNotifyMinutes) ?? fallback.earlyNotifyMinutes
        earlyNotifySeconds = try container.decodeIfPresent(Int.self, forKey: .earlyNotifySeconds) ?? fallback.earlyNotifySeconds
        smartDelayEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartDelayEnabled) ?? fallback.smartDelayEnabled
        monitorKeyboard = try container.decodeIfPresent(Bool.self, forKey: .monitorKeyboard) ?? fallback.monitorKeyboard
        monitorMouse = try container.decodeIfPresent(Bool.self, forKey: .monitorMouse) ?? fallback.monitorMouse
        idleDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .idleDelaySeconds) ?? fallback.idleDelaySeconds
        maxDelayMinutes = try container.decodeIfPresent(Int.self, forKey: .maxDelayMinutes) ?? fallback.maxDelayMinutes
        showPreBreakCountdown = try container.decodeIfPresent(Bool.self, forKey: .showPreBreakCountdown) ?? fallback.showPreBreakCountdown
        autoResetOnIdle = try container.decodeIfPresent(Bool.self, forKey: .autoResetOnIdle) ?? fallback.autoResetOnIdle
    }

    var workTotalSeconds: Int {
        workDurationMinutes * 60 + workDurationSeconds
    }

    var breakTotalSeconds: Int {
        breakDurationMinutes * 60 + breakDurationSeconds
    }

    var earlyNotifyTotalSeconds: Int {
        earlyNotifyMinutes * 60 + earlyNotifySeconds
    }

    static func validateTimeValues(
        workMinutes: Int,
        workSeconds: Int,
        breakMinutes: Int,
        breakSeconds: Int,
        earlyMinutes: Int,
        earlySeconds: Int
    ) -> Result<Void, TimeSettingsValidationError> {
        guard workMinutes >= 0, workSeconds >= 0, workSeconds < 60,
              breakMinutes >= 0, breakSeconds >= 0, breakSeconds < 60,
              earlyMinutes >= 0, earlySeconds >= 0, earlySeconds < 60 else {
            return .failure(.invalidInput)
        }

        let workTotal = workMinutes * 60 + workSeconds
        let breakTotal = breakMinutes * 60 + breakSeconds
        let earlyTotal = earlyMinutes * 60 + earlySeconds

        guard workTotal > 0 else {
            return .failure(.workDurationMustBePositive)
        }
        guard breakTotal > 0 else {
            return .failure(.breakDurationMustBePositive)
        }
        guard earlyTotal < workTotal else {
            return .failure(.earlyNotifyMustBeLessThanWork)
        }

        return .success(())
    }
}
