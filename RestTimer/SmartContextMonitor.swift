import AppKit
import CoreAudio
import CoreMediaIO
import Foundation

/// 系统上下文检测协议（支持单元测试注入 Mock）
protocol SmartContextProviding {
    /// 是否正在开会 / 语音通话 / 录屏（麦克风被会议类应用占用或摄像头激活）
    func isInMeetingOrCall() -> Bool
    /// 是否处于全屏演示（Keynote/PPT）或全屏视频播放中
    func isFullscreenMediaOrPresentation() -> Bool
    /// 当前默认音频输出是否为耳机（蓝牙耳机 / USB 耳机 / 3.5mm 有线耳机；外放扬声器返回 false）
    func isHeadphonesOutputConnected() -> Bool
}

/// 原生 macOS 上下文感知器（零额外权限弹窗，复用 CoreAudio + CoreMediaIO + CGWindowList）
struct SystemSmartContextProvider: SmartContextProviding {
    private static let presentationAndMediaBundles: Set<String> = [
        "com.apple.iwork.keynote",
        "com.microsoft.powerpoint",
        "com.kingsoft.wpsoffice.mac",
        "com.colliderli.iina",
        "org.videolan.vlc",
        "com.apple.quicktimeplayerx",
        "com.firecore.infuse",
        "com.bilibili.bilibili",
        "com.tencent.tenvideo",
        "com.iqiyi.player",
        "com.youku.mac",
        "com.valvesoftware.steam",
        "tv.plex.desktop"
    ]

    func isInMeetingOrCall() -> Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        return isAnyCameraRunning() || isMeetingMicrophoneRunning()
    }

    func isFullscreenMediaOrPresentation() -> Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        let bundleLower = frontApp.bundleIdentifier?.lowercased() ?? ""
        if bundleLower == (Bundle.main.bundleIdentifier?.lowercased() ?? "fxzer.top.resttimer") {
            return false
        }
        guard isApplicationCoveringScreen(pid: frontApp.processIdentifier) else {
            return false
        }
        // 全屏演示/视频/游戏应用直接免打扰；浏览器等通用全屏应用仅在正在出声（全屏看视频/网课）时免打扰，不误伤全屏写代码
        if Self.presentationAndMediaBundles.contains(bundleLower) {
            return true
        }
        return MediaPlaybackPauser.isAnyUserMediaOutputtingAudio()
    }

    func isHeadphonesOutputConnected() -> Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID) == noErr,
              deviceID != kAudioObjectUnknown else {
            return false
        }

        var transport: UInt32 = 0
        var tSize = UInt32(MemoryLayout<UInt32>.size)
        var tAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &tAddr, 0, nil, &tSize, &transport) == noErr else {
            return false
        }

        // 蓝牙耳机 / BLE 耳机 / USB 耳机直接判定为耳机在位
        if transport == kAudioDeviceTransportTypeBluetooth
            || transport == kAudioDeviceTransportTypeBluetoothLE
            || transport == kAudioDeviceTransportTypeUSB {
            return true
        }

        // 内置音频通道：仅 3.5mm 有线耳机 ('hdpn' = 0x6864706e) 判定为在位，内置扬声器 ('ispk') 返回 false
        if transport == kAudioDeviceTransportTypeBuiltIn {
            var dataSource: UInt32 = 0
            var dsSize = UInt32(MemoryLayout<UInt32>.size)
            var dsAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDataSource,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(deviceID, &dsAddr, 0, nil, &dsSize, &dataSource) == noErr {
                return dataSource == 0x6864706E // 'hdpn'
            }
        }
        return false
    }

    // MARK: - 摄像头与麦克风活跃检测

    private func isAnyCameraRunning() -> Bool {
        var cmioAddr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var cmioSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &cmioAddr, 0, nil, &cmioSize) == noErr,
              cmioSize > 0 else {
            return false
        }
        let count = Int(cmioSize) / MemoryLayout<CMIODeviceID>.size
        var devices = [CMIODeviceID](repeating: 0, count: count)
        var dataUsed: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &cmioAddr, 0, nil, cmioSize, &dataUsed, &devices) == noErr else {
            return false
        }

        for device in devices {
            var running: UInt32 = 0
            var rUsed: UInt32 = 0
            var rAddr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            if CMIOObjectGetPropertyData(device, &rAddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &rUsed, &running) == noErr,
               running != 0 {
                return true
            }
        }
        return false
    }

    private func isMeetingMicrophoneRunning() -> Bool {
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
            var isIn: UInt32 = 0
            var inSize = UInt32(MemoryLayout<UInt32>.size)
            var inAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunningInput,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(objID, &inAddr, 0, nil, &inSize, &isIn) == noErr,
                  isIn != 0 else {
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
            let lower = ((status == noErr ? unmanagedBundle?.takeUnretainedValue() as String? : nil) ?? "").lowercased()

            // 过滤系统底层音频驱动、语音听写及输入法语音进程，仅针对真实会议/通话/录屏软件
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

    private func isApplicationCoveringScreen(pid: pid_t) -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let screenSizes = NSScreen.screens.map { $0.frame.size }
        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }
            for screenSize in screenSizes {
                if abs(width - screenSize.width) <= 4 && abs(height - screenSize.height) <= 4 {
                    return true
                }
            }
        }
        return false
    }
}

/// 今日休息极简轻统计模型（按自然日自动归零）
struct DailyBreakStats: Codable, Equatable {
    var dayKey: String
    var completedCount: Int
    var totalBreakSeconds: Int

    var menuSummary: String {
        guard completedCount > 0 else { return "今日尚未休息" }
        if totalBreakSeconds >= 60 {
            return "今日已休 \(completedCount) 次 · \(totalBreakSeconds / 60) 分钟"
        }
        return "今日已休 \(completedCount) 次 · \(totalBreakSeconds) 秒"
    }
}

/// 今日休息统计持久化存储器
final class DailyBreakStatsStore {
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "DailyBreakStats_v1") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func todayStats(now: Date = Date()) -> DailyBreakStats {
        let today = Self.dayKey(for: now)
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(DailyBreakStats.self, from: data),
           decoded.dayKey == today {
            return decoded
        }
        return DailyBreakStats(dayKey: today, completedCount: 0, totalBreakSeconds: 0)
    }

    @discardableResult
    func recordCompletedBreak(seconds: Int, now: Date = Date()) -> DailyBreakStats {
        var current = todayStats(now: now)
        current.completedCount += 1
        current.totalBreakSeconds += max(1, seconds)
        if let encoded = try? JSONEncoder().encode(current) {
            userDefaults.set(encoded, forKey: storageKey)
        }
        return current
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
