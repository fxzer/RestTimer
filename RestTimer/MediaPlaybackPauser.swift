import Foundation
import AppKit
import CoreAudio

/// 系统级媒体自动暂停器：结合 CoreAudio 活跃音频进程检测 + MediaRemote kMRPause + 硬件媒体键兜底，
/// 具有异步取消令牌保护，确保仅在真有音乐/浏览器视频/播客正在出声时安全暂停，绝不在静默或快速切状态时误唤醒播放器。
enum MediaPlaybackPauser {
    private typealias MRMediaRemoteSendCommandFn = @convention(c) (UInt32, AnyObject?) -> Bool
    private static let kMRPlayCommand: UInt32 = 0
    private static let kMRPauseCommand: UInt32 = 1
    private static let nxKeyTypePlay: Int = 16

    private static var activeVerifyWorkItem: DispatchWorkItem?

    /// 取消任何在途的延迟重试任务，避免在状态快速流转时误发硬件媒体按键
    static func cancelPendingRetries() {
        activeVerifyWorkItem?.cancel()
        activeVerifyWorkItem = nil
    }

    /// 进入休息时调用：若当前有正在出声的媒体应用，自动将其暂停并返回 true
    @discardableResult
    static func pauseActiveMediaIfNeeded() -> Bool {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return false
        }

        cancelPendingRetries()

        let wasPlayingAudio = CoreAudioProcessScanner.isAnyUserMediaOutputtingAudio()

        // 1. 优先发送显式 kMRPause (1) 指令（即使当前无播放也是安全空操作，绝不会反向触发播放）
        _ = sendMediaRemoteCommand(kMRPauseCommand)

        // 2. 若入场时检测到有应用正在出声，120ms 后复查 CoreAudio 输出流；
        //    若仍在出声，则在确认“正在出声”的前提下发送一次硬件媒体暂停键（NX_KEYTYPE_PLAY）。
        guard wasPlayingAudio else { return false }

        let workItem = DispatchWorkItem {
            if CoreAudioProcessScanner.isAnyUserMediaOutputtingAudio() {
                postHardwareMediaPlayPauseKey()
            }
        }
        activeVerifyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
        return true
    }

    /// 仅当本次休息曾由 RestTimer 主动暂停过媒体，且当前音频输出确认为耳机且当前仍处于静音时，安全续播
    @discardableResult
    static func resumePausedMediaIfHeadphonesConnected(contextProvider: SmartContextProviding) -> Bool {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return false
        }
        guard contextProvider.isHeadphonesOutputConnected(), !CoreAudioProcessScanner.isAnyUserMediaOutputtingAudio() else {
            return false
        }

        cancelPendingRetries()

        _ = sendMediaRemoteCommand(kMRPlayCommand)

        let workItem = DispatchWorkItem {
            if contextProvider.isHeadphonesOutputConnected() && !CoreAudioProcessScanner.isAnyUserMediaOutputtingAudio() {
                postHardwareMediaPlayPauseKey()
            }
        }
        activeVerifyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
        return true
    }

    /// 通过 CoreAudio 检查当前是否存在正在输出音频的用户级应用
    static func isAnyUserMediaOutputtingAudio() -> Bool {
        CoreAudioProcessScanner.isAnyUserMediaOutputtingAudio()
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
