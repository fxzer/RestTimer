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
    var autoResetOnIdle: Bool = true

    var hasAnyMonitorEnabled: Bool {
        monitorKeyboard || monitorMouse
    }

    var maxDelayDuration: TimeInterval? {
        maxDelayMinutes > 0 ? TimeInterval(maxDelayMinutes * 60) : nil
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

    /// 判断专注期间是否因长时间离开电脑而应进入“自然离开”挂起状态
    static func shouldEnterAwayState(
        elapsedWork: TimeInterval,
        idleElapsed: TimeInterval,
        breakDuration: TimeInterval,
        autoResetEnabled: Bool
    ) -> Bool {
        guard autoResetEnabled, breakDuration > 0 else { return false }
        // 至少专注超过 10 秒后才触发，避免刚重置完一直不动时反复重置
        guard elapsedWork >= 10 else { return false }
        return idleElapsed >= breakDuration
    }

    /// 处于“自然离开”状态时，用户是否已回到电脑前操作
    static func shouldResumeFromAway(idleElapsed: TimeInterval) -> Bool {
        idleElapsed < 2.0
    }
}

import CoreAudio

/// 系统级媒体自动暂停器：结合 CoreAudio 活跃音频进程检测 + MediaRemote kMRPause + 硬件媒体键兜底，
/// 确保仅在真有音乐/浏览器视频/播客正在出声时安全暂停，绝不在静默时误唤醒播放器。
enum MediaPlaybackPauser {
    private typealias MRMediaRemoteSendCommandFn = @convention(c) (UInt32, AnyObject?) -> Bool
    private static let kMRPlayCommand: UInt32 = 0
    private static let kMRPauseCommand: UInt32 = 1
    private static let nxKeyTypePlay: Int = 16

    /// 进入休息时调用：若当前有正在出声的媒体应用，自动将其暂停并返回 true（供休息结束后耳机在位续播判断）
    @discardableResult
    static func pauseActiveMediaIfNeeded() -> Bool {
        // 单元测试环境下不触发系统媒体控制
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return false
        }

        let wasPlayingAudio = isAnyUserMediaOutputtingAudio()

        // 1. 优先发送显式 kMRPause (1) 指令（即使当前无播放也是安全空操作，绝不会反向触发播放）
        _ = sendMediaRemoteCommand(kMRPauseCommand)

        // 2. 若入场时检测到有应用正在出声，120ms 后复查 CoreAudio 输出流；
        //    若仍在出声，则在确认“正在出声”的前提下发送一次硬件媒体暂停键（NX_KEYTYPE_PLAY）。
        guard wasPlayingAudio else { return false }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if isAnyUserMediaOutputtingAudio() {
                postHardwareMediaPlayPauseKey()
            }
        }
        return true
    }

    /// 仅当本次休息曾由 RestTimer 主动暂停过媒体，且当前音频输出确认为耳机（非外放扬声器）且当前仍处于静音时，安全续播
    @discardableResult
    static func resumePausedMediaIfHeadphonesConnected(contextProvider: SmartContextProviding) -> Bool {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return false
        }
        guard contextProvider.isHeadphonesOutputConnected(), !isAnyUserMediaOutputtingAudio() else {
            return false
        }

        _ = sendMediaRemoteCommand(kMRPlayCommand)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if contextProvider.isHeadphonesOutputConnected() && !isAnyUserMediaOutputtingAudio() {
                postHardwareMediaPlayPauseKey()
            }
        }
        return true
    }

    /// 通过 CoreAudio `kAudioHardwarePropertyProcessObjectList` + `kAudioProcessPropertyIsRunningOutput`
    /// 精确检查当前是否存在正在向声卡/耳机输出音频的用户级应用（排除系统驱动与输入法语音助手）
    static func isAnyUserMediaOutputtingAudio() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return false
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var processIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &processIDs) == noErr else {
            return false
        }

        let selfBundle = Bundle.main.bundleIdentifier?.lowercased() ?? "fxzer.top.resttimer"

        for objID in processIDs {
            var isOut: UInt32 = 0
            var outSize = UInt32(MemoryLayout<UInt32>.size)
            var outAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunningOutput,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(objID, &outAddr, 0, nil, &outSize, &isOut) == noErr,
                  isOut != 0 else {
                continue
            }

            var unmanagedBundle: Unmanaged<CFString>?
            var bSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var bAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyBundleID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = withUnsafeMutablePointer(to: &unmanagedBundle) { ptr in
                AudioObjectGetPropertyData(objID, &bAddr, 0, nil, &bSize, ptr)
            }
            let bundleID = (status == noErr ? unmanagedBundle?.takeUnretainedValue() as String? : nil) ?? ""
            let lower = bundleID.lowercased()

            // 过滤系统底层音频驱动、语音识别及输入法语音进程
            if lower == selfBundle
                || lower.hasPrefix("com.apple.audio.")
                || lower == "com.apple.coreaudiod"
                || lower.hasPrefix("com.apple.speech")
                || lower.hasPrefix("com.apple.siri")
                || lower.hasPrefix("com.apple.accessibility.")
                || lower.contains("ime")
                || lower.contains("inputmethod") {
                continue
            }
            return true
        }
        return false
    }

    private static func sendMediaRemoteCommand(_ command: UInt32) -> Bool {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY),
              let sym = dlsym(handle, "MRMediaRemoteSendCommand") else {
            return false
        }
        let fn = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFn.self)
        return fn(command, nil)
    }

    private static func postHardwareMediaPlayPauseKey() {
        for isKeyDown in [true, false] {
            let keyState = isKeyDown ? 0x0A : 0x0B
            let data1 = (nxKeyTypePlay << 16) | (keyState << 8)
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: isKeyDown ? 0xA00 : 0xB00),
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
