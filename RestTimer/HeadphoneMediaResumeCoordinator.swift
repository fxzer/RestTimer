import Foundation

/// 耳机续播显式状态机：将散落的布尔标记与时间戳收敛为显式状态流转，支持取消令牌保护
final class HeadphoneMediaResumeCoordinator {
    enum State: Equatable {
        case idle
        case pausedForBreak
        case observingReturn(deadline: TimeInterval)
    }

    private(set) var state: State = .idle

    /// 进入休息时记录媒体暂停状态
    func recordBreakStarted(mediaWasPaused: Bool) {
        state = mediaWasPaused ? .pausedForBreak : .idle
    }

    /// 休息结束（正常完成或跳过）：若用户在位则立即续播；不在位则挂起 90 秒观察窗
    func handleBreakEnded(
        userIsPresent: Bool,
        contextProvider: SmartContextProviding,
        pauseMediaOnBreak: Bool,
        resumeMediaWithHeadphones: Bool
    ) {
        guard state == .pausedForBreak else {
            state = .idle
            return
        }
        state = .idle
        guard pauseMediaOnBreak && resumeMediaWithHeadphones else { return }

        if userIsPresent {
            _ = MediaPlaybackPauser.resumePausedMediaIfHeadphonesConnected(contextProvider: contextProvider)
        } else {
            let deadline = Date().timeIntervalSince1970 + 90.0
            state = .observingReturn(deadline: deadline)
        }
    }

    /// 轮询检测：在观察窗内若用户回到工位操作键鼠且耳机在位，安全续播
    func evaluateActivityTick(
        idle: TimeInterval,
        now: TimeInterval,
        contextProvider: SmartContextProviding,
        pauseMediaOnBreak: Bool,
        resumeMediaWithHeadphones: Bool
    ) {
        guard case .observingReturn(let deadline) = state else { return }
        if now > deadline {
            state = .idle
        } else if idle < 2.0 {
            state = .idle
            if pauseMediaOnBreak && resumeMediaWithHeadphones {
                _ = MediaPlaybackPauser.resumePausedMediaIfHeadphonesConnected(contextProvider: contextProvider)
            }
        }
    }

    /// 重置状态机并取消在途的延迟重试
    func reset() {
        state = .idle
        MediaPlaybackPauser.cancelPendingRetries()
    }
}
