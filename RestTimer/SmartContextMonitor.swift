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
        !CoreAudioProcessScanner.activeUserProcessBundleIDs(direction: .input).isEmpty
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

/// 单次休息/跳过事件记录（纯本地轻量持久化，自动滚动保留近 140 天）
struct BreakEventRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: TimeInterval
    let breakSeconds: Int
    let focusSeconds: Int
    let wasSkipped: Bool

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        breakSeconds: Int,
        focusSeconds: Int,
        wasSkipped: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.breakSeconds = breakSeconds
        self.focusSeconds = focusSeconds
        self.wasSkipped = wasSkipped
    }

    static func rawTimelineRatio(for date: Date) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let mins = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        return CGFloat((mins - 480.0) / 900.0)
    }

    static func xPosition(for timestamp: TimeInterval, width: CGFloat) -> CGFloat {
        let ratio = min(1.0, max(0.0, rawTimelineRatio(for: Date(timeIntervalSince1970: timestamp))))
        return max(6, min(width - 6, ratio * width))
    }

    /// 根据鼠标水平坐标就近吸附休息事件，避免多段竖条叠加时只有最后一条响应悬停
    static func nearestEvent(
        atX x: CGFloat,
        width: CGFloat,
        events: [BreakEventRecord],
        maxDistance: CGFloat = 14.0
    ) -> BreakEventRecord? {
        var best: (event: BreakEventRecord, distance: CGFloat)?
        for event in events {
            let posX = xPosition(for: event.timestamp, width: width)
            let distance = abs(x - posX)
            if distance <= maxDistance, best == nil || distance < best!.distance {
                best = (event, distance)
            }
        }
        return best?.event
    }
}

/// 单日汇总桶（供近 7 日柱图与近 16 周热力图复用）
struct DailyStatsBucket: Equatable, Identifiable {
    let dayKey: String
    let date: Date
    let weekdayShort: String
    let completedCount: Int
    let skippedCount: Int
    let totalBreakSeconds: Int
    let totalFocusSeconds: Int
    let longestSitSeconds: Int

    var id: String { dayKey }
}

/// 今日休息极简轻统计模型（菜单栏与统计页共用）
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

/// 休息历史与统计存储器（兼容旧日统计，提供今日节律、近 7 日趋势与近 16 周热力聚合）
final class DailyBreakStatsStore {
    private let userDefaults: UserDefaults
    private let historyKey: String
    private let retentionDays: Int = 140

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String? = nil,
        historyKey: String = "BreakEventHistory_v1"
    ) {
        self.userDefaults = userDefaults
        self.historyKey = historyKey
    }

    func loadHistory(now: Date = Date()) -> [BreakEventRecord] {
        guard let data = userDefaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([BreakEventRecord].self, from: data) else {
            return []
        }
        let cutoff = now.timeIntervalSince1970 - TimeInterval(retentionDays * 86_400)
        return decoded.filter { $0.timestamp >= cutoff }
    }

    func todayStats(now: Date = Date()) -> DailyBreakStats {
        let today = Self.dayKey(for: now)
        let events = loadHistory(now: now).filter {
            !$0.wasSkipped && Self.dayKey(for: Date(timeIntervalSince1970: $0.timestamp)) == today
        }
        if !events.isEmpty {
            return DailyBreakStats(
                dayKey: today,
                completedCount: events.count,
                totalBreakSeconds: events.reduce(0) { $0 + $1.breakSeconds }
            )
        }
        return DailyBreakStats(dayKey: today, completedCount: 0, totalBreakSeconds: 0)
    }

    @discardableResult
    func recordCompletedBreak(seconds: Int, focusSeconds: Int = 0, now: Date = Date()) -> DailyBreakStats {
        let event = BreakEventRecord(
            timestamp: now.timeIntervalSince1970,
            breakSeconds: max(1, seconds),
            focusSeconds: max(0, focusSeconds),
            wasSkipped: false
        )
        appendEvent(event, now: now)
        return todayStats(now: now)
    }

    func recordSkippedBreak(focusSeconds: Int = 0, now: Date = Date()) {
        let event = BreakEventRecord(
            timestamp: now.timeIntervalSince1970,
            breakSeconds: 0,
            focusSeconds: max(0, focusSeconds),
            wasSkipped: true
        )
        appendEvent(event, now: now)
    }

    /// 一次性聚合全部快照数据（单次 JSON 反序列化与分组，单次计算供今日/本周/112天复用）
    func makeFullSnapshot(now: Date = Date()) -> (
        todayEvents: [BreakEventRecord],
        weeklyBuckets: [DailyStatsBucket],
        heatmapBuckets: [DailyStatsBucket]
    ) {
        let history = loadHistory(now: now)
        let today = Self.dayKey(for: now)
        let todayEvents = history
            .filter { Self.dayKey(for: Date(timeIntervalSince1970: $0.timestamp)) == today }
            .sorted { $0.timestamp < $1.timestamp }

        let heatmap = dailyBuckets(days: 112, now: now, preloadedHistory: history)
        let weekly = Array(heatmap.suffix(7))
        return (todayEvents, weekly, heatmap)
    }

    /// 聚合近 N 天的每日汇总桶（从早到晚，最后一项为今日）
    func dailyBuckets(days: Int, now: Date = Date(), preloadedHistory: [BreakEventRecord]? = nil) -> [DailyStatsBucket] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let history = preloadedHistory ?? loadHistory(now: now)

        var grouped: [String: [BreakEventRecord]] = [:]
        for record in history {
            let key = Self.dayKey(for: Date(timeIntervalSince1970: record.timestamp))
            grouped[key, default: []].append(record)
        }

        let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
        var result: [DailyStatsBucket] = []
        result.reserveCapacity(days)
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let dayDate = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let key = Self.dayKey(for: dayDate)
            let dayEvents = grouped[key] ?? []
            let completed = dayEvents.filter { !$0.wasSkipped }
            let skipped = dayEvents.filter { $0.wasSkipped }
            let weekdayIdx = max(0, min(6, calendar.component(.weekday, from: dayDate) - 1))
            let label = offset == 0 ? "今" : weekdaySymbols[weekdayIdx]

            result.append(
                DailyStatsBucket(
                    dayKey: key,
                    date: dayDate,
                    weekdayShort: label,
                    completedCount: completed.count,
                    skippedCount: skipped.count,
                    totalBreakSeconds: completed.reduce(0) { $0 + $1.breakSeconds },
                    totalFocusSeconds: dayEvents.reduce(0) { $0 + $1.focusSeconds },
                    longestSitSeconds: dayEvents.map(\.focusSeconds).max() ?? 0
                )
            )
        }
        return result
    }

    /// 获取指定日期当天的全部事件（按时间升序，供今日呼吸节律轴绘制）
    func eventsForDay(now: Date = Date()) -> [BreakEventRecord] {
        let today = Self.dayKey(for: now)
        return loadHistory(now: now)
            .filter { Self.dayKey(for: Date(timeIntervalSince1970: $0.timestamp)) == today }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func appendEvent(_ event: BreakEventRecord, now: Date) {
        var list = loadHistory(now: now)
        list.append(event)
        if let encoded = try? JSONEncoder().encode(list) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }
}
