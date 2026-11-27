import XCTest
import SwiftUI
@testable import RestTimer

private final class MockActivitySampler: ActivitySampling {
    var keyboardIdle: TimeInterval = 100
    var mouseActionIdle: TimeInterval = 100
    var mouseLocation: CGPoint = CGPoint(x: 100, y: 100)
    var currentTime: TimeInterval = 1000

    func secondsSinceLastKeyboardEvent() -> TimeInterval { keyboardIdle }
    func secondsSinceLastMouseAction() -> TimeInterval { mouseActionIdle }
    func currentMouseLocation() -> CGPoint { mouseLocation }
    func now() -> TimeInterval { currentTime }
}

final class RestTimerTests: XCTestCase {
    private var savedSettingsBackup: Data?

    override func setUp() {
        super.setUp()
        savedSettingsBackup = UserDefaults.standard.data(forKey: "TimerSettings")
    }

    override func tearDown() {
        if let backup = savedSettingsBackup {
            UserDefaults.standard.set(backup, forKey: "TimerSettings")
        } else {
            UserDefaults.standard.removeObject(forKey: "TimerSettings")
        }
        super.tearDown()
    }

    func testActivityMonitorIgnoresSmallMouseJitterAndDetectsRealMove() {
        let sampler = MockActivitySampler()
        let monitor = ActivityMonitor(sampler: sampler, mouseMoveThreshold: 15.0)
        XCTAssertEqual(monitor.mouseTrackState, .unprimed)

        monitor.resetBaseline()
        XCTAssertEqual(monitor.mouseTrackState, .anchored(position: CGPoint(x: 100, y: 100)))

        // 轻微抖动 5pt 不应视为鼠标活跃，状态维持 anchored
        sampler.mouseLocation = CGPoint(x: 103, y: 104)
        sampler.currentTime = 1005
        XCTAssertEqual(
            monitor.idleDuration(monitorKeyboard: false, monitorMouse: true),
            100,
            accuracy: 0.001
        )
        XCTAssertEqual(monitor.mouseTrackState, .anchored(position: CGPoint(x: 100, y: 100)))

        // 移动 25pt 应刷新活跃时间并进入 moved 态
        sampler.mouseLocation = CGPoint(x: 120, y: 115)
        sampler.currentTime = 1010
        XCTAssertEqual(
            monitor.idleDuration(monitorKeyboard: false, monitorMouse: true),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(monitor.mouseTrackState, .moved(position: CGPoint(x: 120, y: 115), at: 1010))

        // 静止 6 秒后空闲时长应为 6 秒
        sampler.currentTime = 1016
        XCTAssertEqual(
            monitor.idleDuration(monitorKeyboard: false, monitorMouse: true),
            6,
            accuracy: 0.001
        )
    }

    func testActivityMonitorRespectsIndependentKeyboardAndMouseToggles() {
        let sampler = MockActivitySampler()
        sampler.keyboardIdle = 1.5
        sampler.mouseActionIdle = 40.0
        let monitor = ActivityMonitor(sampler: sampler)
        monitor.resetBaseline()

        XCTAssertEqual(
            monitor.idleDuration(monitorKeyboard: true, monitorMouse: true),
            1.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            monitor.idleDuration(monitorKeyboard: false, monitorMouse: true),
            40.0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            monitor.idleDuration(monitorKeyboard: false, monitorMouse: false),
            .greatestFiniteMagnitude
        )
    }

    func testPendingBreakWaitingCountdownAndInterrupt() {
        let config = SmartDelayConfig(
            enabled: true,
            monitorKeyboard: true,
            monitorMouse: true,
            idleDelaySeconds: 10,
            maxDelayMinutes: 5,
            showPreBreakCountdown: true,
            idleResetMinutes: 10
        )

        let waiting = BreakDelayEvaluator.evaluatePendingBreak(overdue: 20, idleElapsed: 2, config: config)
        XCTAssertEqual(waiting, .waiting(overdue: 20, idleElapsed: 2, idleRemaining: 8))

        let countdown = BreakDelayEvaluator.evaluatePendingBreak(overdue: 27.2, idleElapsed: 7.2, config: config)
        XCTAssertEqual(countdown, .countdown(secondsLeft: 3, reason: .idleTrigger, overdue: 27.2))

        let interrupted = BreakDelayEvaluator.evaluatePendingBreak(overdue: 28, idleElapsed: 0.1, config: config)
        XCTAssertEqual(interrupted, .waiting(overdue: 28, idleElapsed: 0.1, idleRemaining: 9.9))

        let trigger = BreakDelayEvaluator.evaluatePendingBreak(overdue: 40, idleElapsed: 10.0, config: config)
        XCTAssertEqual(trigger, .triggerBreak(reason: .idleThresholdReached))
    }

    func testPendingBreakHardCapWarningAndForceTrigger() {
        let config = SmartDelayConfig(
            enabled: true,
            monitorKeyboard: true,
            monitorMouse: true,
            idleDelaySeconds: 10,
            maxDelayMinutes: 5,
            showPreBreakCountdown: true,
            idleResetMinutes: 10
        )

        let capWarning = BreakDelayEvaluator.evaluatePendingBreak(overdue: 288, idleElapsed: 0.2, config: config)
        XCTAssertEqual(capWarning, .countdown(secondsLeft: 12, reason: .maxDelayCap, overdue: 288))

        let capTrigger = BreakDelayEvaluator.evaluatePendingBreak(overdue: 300, idleElapsed: 0.1, config: config)
        XCTAssertEqual(capTrigger, .triggerBreak(reason: .maxDelayReached))

        var unlimited = config
        unlimited.maxDelayMinutes = 0
        let stillWaiting = BreakDelayEvaluator.evaluatePendingBreak(overdue: 3600, idleElapsed: 1.0, config: unlimited)
        XCTAssertEqual(stillWaiting, .waiting(overdue: 3600, idleElapsed: 1.0, idleRemaining: 9.0))
    }

    func testAutoResetOnNaturalAway() {
        // 刚重置完前 10 秒不触发
        XCTAssertFalse(
            BreakDelayEvaluator.shouldEnterAwayState(
                elapsedWork: 5,
                idleElapsed: 700,
                idleResetDuration: 600
            )
        )

        // 坐着玩 3 分钟手机（小于 10 分钟重计阈值）：绝不清零，防止漏掉久坐提醒
        XCTAssertFalse(
            BreakDelayEvaluator.shouldEnterAwayState(
                elapsedWork: 1500,
                idleElapsed: 180,
                idleResetDuration: 600
            )
        )

        // 达到 10 分钟真正长时间无操作：进入离开态
        XCTAssertTrue(
            BreakDelayEvaluator.shouldEnterAwayState(
                elapsedWork: 1500,
                idleElapsed: 600,
                idleResetDuration: 600
            )
        )

        // 设置为「关闭」（nil）时，不锁屏空闲永不自动重计
        XCTAssertFalse(
            BreakDelayEvaluator.shouldEnterAwayState(
                elapsedWork: 1500,
                idleElapsed: 3600,
                idleResetDuration: nil
            )
        )

        // 息屏与锁屏分级回归判定
        XCTAssertFalse(
            BreakDelayEvaluator.shouldResetOnSystemReturn(
                inactiveElapsed: 180,
                wasLocked: false,
                breakDuration: 120,
                idleResetDuration: 600
            )
        )
        XCTAssertTrue(
            BreakDelayEvaluator.shouldResetOnSystemReturn(
                inactiveElapsed: 600,
                wasLocked: false,
                breakDuration: 120,
                idleResetDuration: 600
            )
        )
        XCTAssertFalse(
            BreakDelayEvaluator.shouldResetOnSystemReturn(
                inactiveElapsed: 3600,
                wasLocked: false,
                breakDuration: 120,
                idleResetDuration: nil
            )
        )
        XCTAssertFalse(
            BreakDelayEvaluator.shouldResetOnSystemReturn(
                inactiveElapsed: 30,
                wasLocked: true,
                breakDuration: 120,
                idleResetDuration: 600
            )
        )
        XCTAssertTrue(
            BreakDelayEvaluator.shouldResetOnSystemReturn(
                inactiveElapsed: 120,
                wasLocked: true,
                breakDuration: 120,
                idleResetDuration: 600
            )
        )

        XCTAssertTrue(BreakDelayEvaluator.shouldResumeFromAway(idleElapsed: 0.5))
        XCTAssertFalse(BreakDelayEvaluator.shouldResumeFromAway(idleElapsed: 10.0))
    }

    func testScreenPresenceTrackerDeduplicatesLockSleepAndWakeUnlock() {
        var tracker = ScreenPresenceTracker()

        // 锁屏 -> 息屏：只触发一次暂停
        XCTAssertEqual(tracker.handleScreenLocked(at: 100), .pauseForSystemLock)
        XCTAssertEqual(tracker.handleScreenSlept(at: 110), .none)

        // 亮屏但仍在锁屏密码页：不提前结束挂起
        XCTAssertEqual(tracker.handleScreenWoke(at: 250), .none)

        // 真正解锁：按最早离线时间计算累计时长并标记为锁屏过
        XCTAssertEqual(tracker.handleScreenUnlocked(at: 280), .endSystemInactivity(elapsed: 180, wasLocked: true))
        XCTAssertEqual(tracker.handleScreenUnlocked(at: 285), .none)

        // 纯息屏未锁屏：唤醒时标记 wasLocked = false
        XCTAssertEqual(tracker.handleScreenSlept(at: 400), .pauseForSystemLock)
        XCTAssertEqual(tracker.handleScreenWoke(at: 520), .endSystemInactivity(elapsed: 120, wasLocked: false))
    }

    func testTimerManagerManualPauseSurvivesSystemLockUnlock() {
        let sampler = MockActivitySampler()
        let manager = TimerManager(activityMonitor: ActivityMonitor(sampler: sampler), autoStart: false)
        manager.resetTimer()

        // 用户手动暂停
        manager.toggleManualPause()
        XCTAssertEqual(manager.state.pauseReason, .manual)

        // 系统锁屏不应降级暂停原因，系统解锁也不应覆盖用户的手动暂停
        manager.handleSystemLock()
        XCTAssertEqual(manager.state.pauseReason, .manual)

        manager.handleSystemUnlock(inactiveElapsed: 600, wasLocked: true)
        XCTAssertTrue(manager.isPaused)
        XCTAssertEqual(manager.state.pauseReason, .manual)

        // 恢复后改为工作态；先推进 0.25s，再验证未锁屏短息屏与短时误锁会保留原进度而非重开一轮
        manager.toggleManualPause()
        XCTAssertFalse(manager.isPaused)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))

        manager.handleSystemLock()
        XCTAssertEqual(manager.state.pauseReason, .systemLocked)
        manager.handleSystemUnlock(inactiveElapsed: 180, wasLocked: false)
        XCTAssertFalse(manager.isPaused)
        if case .working(let startedAfterShortSleep) = manager.state {
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince1970 - startedAfterShortSleep, 0.20)
        } else {
            XCTFail("Expected .working after short screen wake, got \(manager.state)")
        }

        manager.handleSystemLock()
        manager.handleSystemUnlock(inactiveElapsed: 30, wasLocked: true)
        XCTAssertFalse(manager.isPaused)
        if case .working(let startedAfterShortLock) = manager.state {
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince1970 - startedAfterShortLock, 0.20)
        } else {
            XCTFail("Expected .working after short unlock, got \(manager.state)")
        }

        // 真锁屏超过休息时长（>= 120s）才重置为新一轮工作态
        manager.handleSystemLock()
        manager.handleSystemUnlock(inactiveElapsed: manager.breakDuration, wasLocked: true)
        XCTAssertFalse(manager.isPaused)
        if case .working(let startedAt) = manager.state {
            XCTAssertLessThan(Date().timeIntervalSince1970 - startedAt, 0.1)
        } else {
            XCTFail("Expected .working after long system unlock, got \(manager.state)")
        }
    }

    func testAtomicTimeSettingsValidationAvoidsIntermediateInvalidState() {
        let manager = TimerManager(activityMonitor: ActivityMonitor(sampler: MockActivitySampler()), autoStart: false)
        manager.settings.workDurationMinutes = 25
        manager.settings.workDurationSeconds = 0
        manager.settings.earlyNotifyMinutes = 2
        manager.settings.earlyNotifySeconds = 0

        // 同时将专注调短到 1 分钟、提前提醒调短到 30 秒，应一次性原子通过
        let okResult = manager.updateTimeSettings(
            workMinutes: 1,
            workSeconds: 0,
            breakMinutes: 5,
            breakSeconds: 0,
            earlyMinutes: 0,
            earlySeconds: 30
        )
        if case .failure(let error) = okResult {
            XCTFail("Expected success, got error: \(error)")
        }
        XCTAssertEqual(manager.settings.workDurationMinutes, 1)
        XCTAssertEqual(manager.settings.earlyNotifySeconds, 30)

        // 非法配置（提前提醒 >= 专注时长）应失败且不修改现有值
        let badResult = manager.updateTimeSettings(
            workMinutes: 2,
            workSeconds: 0,
            breakMinutes: 5,
            breakSeconds: 0,
            earlyMinutes: 2,
            earlySeconds: 0
        )
        if case .failure(let error) = badResult {
            XCTAssertEqual(error, .earlyNotifyMustBeLessThanWork)
        } else {
            XCTFail("Expected earlyNotifyMustBeLessThanWork")
        }
        XCTAssertEqual(manager.settings.workDurationMinutes, 1)

        // 0 秒休息应被拦截
        let zeroBreak = manager.updateTimeSettings(
            workMinutes: 10,
            workSeconds: 0,
            breakMinutes: 0,
            breakSeconds: 0,
            earlyMinutes: 1,
            earlySeconds: 0
        )
        if case .failure(let error) = zeroBreak {
            XCTAssertEqual(error, .breakDurationMustBePositive)
        } else {
            XCTFail("Expected breakDurationMustBePositive")
        }

        // 超过 60 分钟的专注时长应被防久坐硬上限拦截
        let overOneHour = manager.updateTimeSettings(
            workMinutes: 61,
            workSeconds: 0,
            breakMinutes: 5,
            breakSeconds: 0,
            earlyMinutes: 2,
            earlySeconds: 0
        )
        if case .failure(let error) = overOneHour {
            XCTAssertEqual(error, .workDurationExceedsOneHour)
        } else {
            XCTFail("Expected workDurationExceedsOneHour")
        }
    }

    func testStretchRoutinePlannerBalancesCategoriesAndDeduplicatesRecent() {
        // 30 秒微休：只安排 1 个不需起身的桌前放松动作
        let microRoutine = StretchRoutinePlanner.planRoutine(forBreakSeconds: 30)
        XCTAssertEqual(microRoutine.count, 1)
        XCTAssertFalse(microRoutine[0].requiresStanding)

        // 5 分钟（300 秒）标准休息：编排 6-7 个跨部位动作且互不重复
        let fullRoutine = StretchRoutinePlanner.planRoutine(forBreakSeconds: 300)
        XCTAssertGreaterThanOrEqual(fullRoutine.count, 6)
        XCTAssertEqual(Set(fullRoutine.map(\.id)).count, fullRoutine.count)

        // 第二轮传入上一轮 ID 集合时，优先挑选未做过的新动作
        let recentIds = Set(fullRoutine.map(\.id))
        let nextRoutine = StretchRoutinePlanner.planRoutine(forBreakSeconds: 180, excludingRecentIds: recentIds)
        XCTAssertFalse(nextRoutine.isEmpty)
        let overlap = Set(nextRoutine.map(\.id)).intersection(recentIds)
        XCTAssertTrue(overlap.isEmpty, "Expected fresh exercises when catalog has enough unused items")
    }

    func testLegacyTimerSettingsBackwardCompatibility() throws {
        let legacyJSON = """
        {
            "showSkipButton": true,
            "showDockIcon": false,
            "workDurationMinutes": 45,
            "workDurationSeconds": 0,
            "breakDurationMinutes": 8,
            "breakDurationSeconds": 0,
            "earlyNotifyMinutes": 3,
            "earlyNotifySeconds": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TimerSettings.self, from: legacyJSON)
        XCTAssertEqual(decoded.showSkipButton, true)
        XCTAssertEqual(decoded.showDockIcon, false)
        XCTAssertEqual(decoded.workDurationMinutes, 45)
        XCTAssertEqual(decoded.breakDurationMinutes, 8)
        XCTAssertEqual(decoded.earlyNotifyMinutes, 3)

        XCTAssertEqual(decoded.smartDelayEnabled, true)
        XCTAssertEqual(decoded.monitorKeyboard, true)
        XCTAssertEqual(decoded.monitorMouse, true)
        XCTAssertEqual(decoded.idleDelaySeconds, 10)
        XCTAssertEqual(decoded.maxDelayMinutes, 5)
        XCTAssertEqual(decoded.showPreBreakCountdown, true)
        XCTAssertEqual(decoded.idleResetMinutes, 10)
        XCTAssertEqual(decoded.dndOnMeetingOrCall, true)
        XCTAssertEqual(decoded.dndOnFullscreenMedia, true)
        XCTAssertEqual(decoded.pauseMediaOnBreak, true)
        XCTAssertEqual(decoded.resumeMediaWithHeadphones, true)
        XCTAssertEqual(decoded.enableBreakExerciseGuide, true)
        XCTAssertEqual(decoded.breakGradientTheme, .autoDayNight)

        // 校验新默认时间：专注 30 分钟 / 提前提醒 2 分钟 / 休息 2 分钟
        XCTAssertEqual(TimerSettings.default.workDurationMinutes, 30)
        XCTAssertEqual(TimerSettings.default.earlyNotifyMinutes, 2)
        XCTAssertEqual(TimerSettings.default.breakDurationMinutes, 2)

        // 历史已移除主题（如 warmIvory）应平滑回退至 autoDayNight，防止整份设置丢失
        let removedThemeJSON = """
        {
            "showSkipButton": true,
            "showDockIcon": true,
            "workDurationMinutes": 25,
            "workDurationSeconds": 0,
            "breakDurationMinutes": 3,
            "breakDurationSeconds": 0,
            "earlyNotifyMinutes": 1,
            "earlyNotifySeconds": 0,
            "breakGradientTheme": "warmIvory"
        }
        """.data(using: .utf8)!
        let fallbackDecoded = try JSONDecoder().decode(TimerSettings.self, from: removedThemeJSON)
        XCTAssertEqual(fallbackDecoded.workDurationMinutes, 25)
        XCTAssertEqual(fallbackDecoded.breakGradientTheme, .autoDayNight)
        XCTAssertEqual(fallbackDecoded.idleResetMinutes, 10)

        // 旧版 autoResetOnIdle = false 应平滑迁移为 idleResetMinutes = 0（关闭）
        let legacyDisabledAutoResetJSON = """
        {
            "showSkipButton": false,
            "showDockIcon": true,
            "workDurationMinutes": 30,
            "workDurationSeconds": 0,
            "breakDurationMinutes": 2,
            "breakDurationSeconds": 0,
            "earlyNotifyMinutes": 2,
            "earlyNotifySeconds": 0,
            "autoResetOnIdle": false
        }
        """.data(using: .utf8)!
        let migratedDisabled = try JSONDecoder().decode(TimerSettings.self, from: legacyDisabledAutoResetJSON)
        XCTAssertEqual(migratedDisabled.idleResetMinutes, 0)
    }

    func testBreakPreviewRestoresWorkTimerWithoutReset() {
        let manager = TimerManager(activityMonitor: ActivityMonitor(sampler: MockActivitySampler()), autoStart: false)
        manager.resetTimer()

        guard case .working(let initialStartedAt) = manager.state else {
            XCTFail("Expected .working state")
            return
        }

        // 进入主题预览态：不阻止退出，且 isBreakPreview == true
        manager.startBreakPreview()
        XCTAssertTrue(manager.isBreakPreview)
        XCTAssertTrue(manager.isBreakTime)
        XCTAssertFalse(manager.preventQuit)

        // 退出预览态：应恢复到专注态且保持剩余进度，不重头重置
        manager.endBreakPreview()
        XCTAssertFalse(manager.isBreakPreview)
        XCTAssertFalse(manager.isBreakTime)
        if case .working(let restoredStartedAt) = manager.state {
            XCTAssertEqual(restoredStartedAt, initialStartedAt, accuracy: 0.5)
        } else {
            XCTFail("Expected .working after ending preview, got \(manager.state)")
        }
    }

    func testBreakPreviewToImmediateBreakSeamlesslyTransitionsToRealBreak() {
        let manager = TimerManager(activityMonitor: ActivityMonitor(sampler: MockActivitySampler()), autoStart: false)
        manager.resetTimer()
        manager.startBreakPreview()
        XCTAssertTrue(manager.isBreakPreview)
        XCTAssertTrue(manager.isBreakTime)

        // 从预览态直接点击立即休息，应平滑转换为正式休息，退出预览并重置为完整休息时长
        manager.startBreakImmediately()
        XCTAssertFalse(manager.isBreakPreview)
        XCTAssertTrue(manager.isBreakTime)
        if case .breaking(let remaining) = manager.state {
            XCTAssertEqual(remaining, manager.breakDuration, accuracy: 1.0)
        } else {
            XCTFail("Expected .breaking state after startBreakImmediately")
        }
    }

    func testCuratedQuoteLibraryProvidesSixtyUniqueQuotesWithNonRepeatingBag() {
        CuratedQuoteLibrary.resetBag()
        XCTAssertEqual(CuratedQuoteLibrary.all.count, 60)
        XCTAssertEqual(Set(CuratedQuoteLibrary.all.map(\.text)).count, 60)

        var seen = Set<String>()
        var last: CuratedQuote?
        for _ in 0..<60 {
            let next = CuratedQuoteLibrary.nextQuote(excluding: last)
            XCTAssertNotEqual(next, last)
            seen.insert(next.text)
            last = next
        }
        XCTAssertEqual(seen.count, 60, "All 60 curated quotes should appear before repeating")
    }

    func testEmergencyExitBreakAlwaysExitsBothRealAndPreviewBreaks() {
        let manager = TimerManager(activityMonitor: ActivityMonitor(sampler: MockActivitySampler()), autoStart: false)
        manager.resetTimer()

        // 1. 正式休息态紧急退出
        manager.startBreakImmediately()
        XCTAssertTrue(manager.isBreakTime)
        XCTAssertFalse(manager.isBreakPreview)
        manager.emergencyExitBreak()
        XCTAssertFalse(manager.isBreakTime)

        // 2. 主题预览态紧急退出
        manager.startBreakPreview()
        XCTAssertTrue(manager.isBreakPreview)
        XCTAssertTrue(manager.isBreakTime)
        manager.emergencyExitBreak()
        XCTAssertFalse(manager.isBreakPreview)
        XCTAssertFalse(manager.isBreakTime)
    }

    func testDailyBreakStatsRecordsAndResetsAcrossMidnight() {
        let suiteName = "RestTimerTests.DailyStats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DailyBreakStatsStore(userDefaults: defaults, storageKey: "testStats")
        let day1 = Date(timeIntervalSince1970: 1_760_000_000)
        let day2 = day1.addingTimeInterval(86_400)

        XCTAssertEqual(store.todayStats(now: day1).menuSummary, "今日尚未休息")

        let after1 = store.recordCompletedBreak(seconds: 120, now: day1)
        XCTAssertEqual(after1.completedCount, 1)
        XCTAssertEqual(after1.totalBreakSeconds, 120)
        XCTAssertEqual(after1.menuSummary, "今日已休 1 次 · 2 分钟")

        let after2 = store.recordCompletedBreak(seconds: 120, now: day1)
        XCTAssertEqual(after2.completedCount, 2)
        XCTAssertEqual(after2.menuSummary, "今日已休 2 次 · 4 分钟")

        // 跨日自动清零
        let nextDay = store.todayStats(now: day2)
        XCTAssertEqual(nextDay.completedCount, 0)
        XCTAssertEqual(nextDay.menuSummary, "今日尚未休息")
    }

    func testDailyBreakStatsHistoryBucketsAndSkipTracking() {
        let suiteName = "RestTimerTests.HistoryBuckets.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DailyBreakStatsStore(
            userDefaults: defaults,
            storageKey: "legacyStats",
            historyKey: "historyEvents"
        )
        let now = Date()
        store.recordCompletedBreak(seconds: 120, focusSeconds: 1800, now: now.addingTimeInterval(-3600))
        store.recordSkippedBreak(focusSeconds: 2400, now: now.addingTimeInterval(-1200))
        store.recordCompletedBreak(seconds: 120, focusSeconds: 1500, now: now)

        let events = store.eventsForDay(now: now)
        XCTAssertEqual(events.count, 3)

        let week = store.dailyBuckets(days: 7, now: now)
        XCTAssertEqual(week.count, 7)
        let todayBucket = week.last!
        XCTAssertEqual(todayBucket.completedCount, 2)
        XCTAssertEqual(todayBucket.skippedCount, 1)
        XCTAssertEqual(todayBucket.totalBreakSeconds, 240)
        XCTAssertEqual(todayBucket.longestSitSeconds, 2400)

        let heat = store.dailyBuckets(days: 112, now: now)
        XCTAssertEqual(heat.count, 112)
        XCTAssertEqual(heat.last?.completedCount, 2)
    }

    func testMeetingAndFullscreenDNDDefersBreakUntilEnded() {
        final class MockContext: SmartContextProviding {
            var inMeeting = true
            var fullscreenMedia = false
            var headphones = true
            func isInMeetingOrCall() -> Bool { inMeeting }
            func isFullscreenMediaOrPresentation() -> Bool { fullscreenMedia }
            func isHeadphonesOutputConnected() -> Bool { headphones }
        }

        let sampler = MockActivitySampler()
        sampler.keyboardIdle = 30
        sampler.mouseActionIdle = 30
        let context = MockContext()
        let manager = TimerManager(
            activityMonitor: ActivityMonitor(sampler: sampler),
            contextProvider: context,
            autoStart: false
        )
        manager.settings.dndOnMeetingOrCall = true
        manager.settings.dndOnFullscreenMedia = true

        let exp = expectation(description: "wait work timer")
        _ = manager.updateTimeSettings(
            workMinutes: 0, workSeconds: 1,
            breakMinutes: 0, breakSeconds: 2,
            earlyMinutes: 0, earlySeconds: 0
        )
        manager.resetTimer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            XCTAssertFalse(manager.isBreakTime, "Should defer break while in meeting")
            XCTAssertTrue(manager.isDeferredByDND, "Should mark deferred by DND")
            context.inMeeting = false
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testExerciseImageLoaderDownsamplingAndPurge() {
        let loader = ExerciseImageLoader.shared
        loader.purge()

        let image = loader.loadThumbnail(named: "fg_01_raise_hands", targetPixelWidth: 510, targetPixelHeight: 680)
        XCTAssertNotNil(image)
        if let img = image {
            XCTAssertEqual(img.size.width, 255.0)
            XCTAssertEqual(img.size.height, 340.0)
        }

        let cached = loader.loadThumbnail(named: "fg_01_raise_hands", targetPixelWidth: 510, targetPixelHeight: 680)
        XCTAssertTrue(image === cached)

        loader.purge()
    }

    func testSettingsWindowOpenAndCloseCycleDoesNotCrashOrRecurse() {
        let manager = TimerManager.shared
        WindowManager.shared.showSettings(timerManager: manager)
        XCTAssertTrue(WindowManager.shared.isSettingsWindowVisible)

        WindowManager.shared.closeSettings()
        XCTAssertFalse(WindowManager.shared.isSettingsWindowVisible)

        WindowManager.shared.closeSettings()
        XCTAssertFalse(WindowManager.shared.isSettingsWindowVisible)

        WindowManager.shared.showSettings(timerManager: manager)
        XCTAssertTrue(WindowManager.shared.isSettingsWindowVisible)
        WindowManager.shared.closeSettings()
        XCTAssertFalse(WindowManager.shared.isSettingsWindowVisible)
    }

    func testHeadphoneMediaResumeExplicitStateTransitions() {
        final class MockHeadphoneContext: SmartContextProviding {
            var headphonesConnected = true
            func isHeadphonesOutputConnected() -> Bool { headphonesConnected }
            func isInMeetingOrCall() -> Bool { false }
            func isFullscreenMediaOrPresentation() -> Bool { false }
        }

        let coordinator = HeadphoneMediaResumeCoordinator()
        let context = MockHeadphoneContext()

        XCTAssertEqual(coordinator.state, .idle)

        // 1. 进入休息时记录媒体暂停
        coordinator.recordBreakStarted(mediaWasPaused: true)
        XCTAssertEqual(coordinator.state, .pausedForBreak)

        // 2. 用户不在工位结束休息 -> 开启观察窗
        coordinator.handleBreakEnded(
            userIsPresent: false,
            contextProvider: context,
            pauseMediaOnBreak: true,
            resumeMediaWithHeadphones: true
        )
        if case .observingReturn(let deadline) = coordinator.state {
            XCTAssertGreaterThan(deadline, Date().timeIntervalSince1970)
        } else {
            XCTFail("Should transition to observingReturn")
        }

        // 3. 用户回工位 (idle < 2.0) -> 触发续播并回归 idle
        coordinator.evaluateActivityTick(
            idle: 1.0,
            now: Date().timeIntervalSince1970,
            contextProvider: context,
            pauseMediaOnBreak: true,
            resumeMediaWithHeadphones: true
        )
        XCTAssertEqual(coordinator.state, .idle)

        // 4. 重置验证
        coordinator.recordBreakStarted(mediaWasPaused: true)
        coordinator.reset()
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testBreakDisplaySessionSharesSingleStateAndAdvancesDeterministically() {
        let session = BreakDisplaySession()

        session.prepareSession(totalBreakSeconds: 120, themeSetting: .autoDayNight)
        let firstTheme = session.displayedTheme
        XCTAssertEqual(firstTheme, BreakGradientTheme.concreteThemes[0])
        XCTAssertFalse(session.routine.isEmpty)
        XCTAssertFalse(session.hasManualSwitch)
        let firstExercise = session.currentExercise(totalBreakSeconds: 120, elapsedSeconds: 0)
        XCTAssertEqual(firstExercise?.id, session.routine.first?.id)

        // 下一次会话仅轮换一次主题，而非按显示器数量递增
        session.prepareSession(totalBreakSeconds: 120, themeSetting: .autoDayNight)
        XCTAssertEqual(session.displayedTheme, BreakGradientTheme.concreteThemes[1])

        // 显式切主题、自动轮换切下一款、切名言、切动作均作用于同一个共享会话
        session.selectTheme(.midnightViolet)
        XCTAssertEqual(session.displayedTheme, .midnightViolet)
        session.advanceAutoTheme()
        XCTAssertNotEqual(session.displayedTheme, .midnightViolet)

        let quoteBefore = session.currentQuote
        session.advanceQuote()
        XCTAssertNotEqual(session.currentQuote, quoteBefore)

        let beforeStep = session.currentExercise(totalBreakSeconds: 120, elapsedSeconds: 0)
        session.stepCatalog(by: 1, totalBreakSeconds: 120, elapsedSeconds: 0)
        XCTAssertTrue(session.hasManualSwitch)
        let afterStep = session.currentExercise(totalBreakSeconds: 120, elapsedSeconds: 0)
        XCTAssertNotEqual(afterStep?.id, beforeStep?.id)

        session.jumpToNextCategory(totalBreakSeconds: 120, elapsedSeconds: 0)
        let afterCategory = session.currentExercise(totalBreakSeconds: 120, elapsedSeconds: 0)
        XCTAssertNotEqual(afterCategory?.category, afterStep?.category)

        // 多张并排视图：返回指定数量的不重复动作批次，点击单个动作可切换并选中它
        session.prepareSession(totalBreakSeconds: 120, themeSetting: .slateIce)
        let autoBatch = session.displayedBatch(totalBreakSeconds: 120, elapsedSeconds: 0)
        XCTAssertEqual(autoBatch.count, BreakDisplaySession.multiCardBatchCount)
        XCTAssertEqual(Set(autoBatch.map(\.id)).count, BreakDisplaySession.multiCardBatchCount)

        session.stepCatalog(by: BreakDisplaySession.multiCardBatchCount, totalBreakSeconds: 120, elapsedSeconds: 0)
        let manualBatch = session.displayedBatch(totalBreakSeconds: 120, elapsedSeconds: 0)
        XCTAssertEqual(manualBatch.count, BreakDisplaySession.multiCardBatchCount)
        XCTAssertNotEqual(manualBatch.map(\.id), autoBatch.map(\.id))

        let picked = StretchRoutinePlanner.catalog[10]
        session.selectExercise(picked)
        XCTAssertEqual(session.currentExercise(totalBreakSeconds: 120, elapsedSeconds: 0)?.id, picked.id)

        let contiguousSample = Array(StretchRoutinePlanner.catalog[0..<3])
        XCTAssertEqual(session.batchProgressLabel(for: contiguousSample), "1-3/\(StretchRoutinePlanner.catalog.count)")
        let wrapSample = [
            StretchRoutinePlanner.catalog[18],
            StretchRoutinePlanner.catalog[19],
            StretchRoutinePlanner.catalog[0]
        ]
        XCTAssertEqual(session.batchProgressLabel(for: wrapSample), "19-1/\(StretchRoutinePlanner.catalog.count)")
        let mixedSample = [
            StretchRoutinePlanner.catalog[1],
            StretchRoutinePlanner.catalog[7],
            StretchRoutinePlanner.catalog[14]
        ]
        XCTAssertEqual(session.batchProgressLabel(for: mixedSample), "2·8·15/\(StretchRoutinePlanner.catalog.count)")
    }

    func testBreakWindowManagerPreservesSessionOnScreenChangeAndSingleKeyHandling() {
        let windowManager = BreakWindowManager()
        let manager = TimerManager(
            activityMonitor: ActivityMonitor(sampler: MockActivitySampler()),
            breakWindowManager: windowManager,
            autoStart: false
        )
        let savedSettings = manager.settings
        manager.settings.breakGradientTheme = .autoDayNight
        manager.settings.enableBreakExerciseGuide = true
        manager.settings.breakExerciseMultiView = false
        manager.settings.pauseMediaOnBreak = false

        manager.startBreakImmediately()
        defer {
            manager.emergencyExitBreak()
            manager.settings = savedSettings
        }

        let initialQuote = windowManager.displaySession.currentQuote
        let initialTheme = windowManager.displaySession.displayedTheme
        let initialRoutine = windowManager.displaySession.routine

        // 模拟外接显示器插拔重建窗口：同一轮休息内不应重新抽取名言、主题或动作
        windowManager.handleScreenParametersChanged()
        XCTAssertEqual(windowManager.displaySession.currentQuote, initialQuote)
        XCTAssertEqual(windowManager.displaySession.displayedTheme, initialTheme)
        XCTAssertEqual(windowManager.displaySession.routine, initialRoutine)

        // 键盘事件由 BreakWindowManager 单一处理：按一次右方向键只切一招，按一次 M 只切换一次模式
        if let rightArrow = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 124
        ) {
            let expectedNext = (windowManager.displaySession.catalogIndex + 1) % StretchRoutinePlanner.catalog.count
            XCTAssertNil(windowManager.handleKeyDown(rightArrow, timerManager: manager))
            XCTAssertTrue(windowManager.displaySession.hasManualSwitch)
            XCTAssertEqual(windowManager.displaySession.catalogIndex, expectedNext)
        } else {
            XCTFail("Failed to construct keyDown event")
        }

        if let toggleMultiView = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "v",
            charactersIgnoringModifiers: "v",
            isARepeat: false,
            keyCode: 9
        ), let rightArrow = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 124
        ) {
            XCTAssertNil(windowManager.handleKeyDown(toggleMultiView, timerManager: manager))
            XCTAssertTrue(manager.settings.breakExerciseMultiView)
            let expectedBatchNext = (windowManager.displaySession.catalogIndex + BreakDisplaySession.multiCardBatchCount) % StretchRoutinePlanner.catalog.count
            XCTAssertNil(windowManager.handleKeyDown(rightArrow, timerManager: manager))
            XCTAssertEqual(windowManager.displaySession.catalogIndex, expectedBatchNext)
        } else {
            XCTFail("Failed to construct V/RightArrow keyDown event")
        }

        if let toggleGuide = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "m",
            charactersIgnoringModifiers: "m",
            isARepeat: false,
            keyCode: 46
        ) {
            XCTAssertNil(windowManager.handleKeyDown(toggleGuide, timerManager: manager))
            XCTAssertFalse(manager.settings.enableBreakExerciseGuide)
        } else {
            XCTFail("Failed to construct M keyDown event")
        }
    }

    func testBreakThemeVisualSpecKeepsFrostedStaticAndAnimatesAllOtherThemes() {
        XCTAssertEqual(BreakGradientTheme.concreteThemes.count, 12)
        XCTAssertTrue(BreakGradientTheme.frostedGlass.isFrostedDesktop)
        XCTAssertEqual(BreakGradientTheme.frostedGlass.visualSpec.orbOpacities.primary, 0.0)

        for theme in BreakGradientTheme.concreteThemes {
            XCTAssertEqual(theme.displayName.count, 3, "\(theme.displayName) should have 3 characters")
            if !theme.isFrostedDesktop {
                let spec = theme.visualSpec
                XCTAssertGreaterThan(spec.orbOpacities.primary, 0.20, "\(theme.displayName) primary orb should be visible")
                XCTAssertGreaterThan(spec.orbOpacities.secondary, 0.15, "\(theme.displayName) secondary orb should be visible")
                XCTAssertGreaterThan(spec.orbOpacities.tertiary, 0.15, "\(theme.displayName) tertiary orb should be visible")
                XCTAssertNotEqual(spec.orb1, spec.orb2, "\(theme.displayName) should use dual-tone contrast")
            }
        }

        // 确保预览卡片的背景光团不会撑高卡片容器，12 个主题在 4 列宽度下全部锁定在 48pt 高度内
        for theme in BreakGradientTheme.concreteThemes {
            let hosting = NSHostingView(
                rootView: BreakThemePreviewCardView(theme: theme, isSelected: true, action: {})
                    .frame(width: 78)
            )
            hosting.layoutSubtreeIfNeeded()
            XCTAssertEqual(hosting.fittingSize.height, 48.0, accuracy: 0.5, "\(theme.displayName) preview card should stay 48pt tall")
        }

        // 确保设置窗口布局及「关于」Tab 在固定尺寸 380×436 内不撑破
        let settingsHosting = NSHostingView(
            rootView: SettingsView().environmentObject(TimerManager.shared)
        )
        settingsHosting.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(settingsHosting.fittingSize.width, SettingsTokens.windowWidth + 0.5)
        XCTAssertLessThanOrEqual(settingsHosting.fittingSize.height, SettingsTokens.windowHeight + 0.5)

        let aboutHosting = NSHostingView(
            rootView: SettingsAboutView().frame(width: SettingsTokens.windowWidth - 28)
        )
        aboutHosting.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(aboutHosting.fittingSize.height, SettingsTokens.tabContentHeight + 0.5)

        let statsHosting = NSHostingView(
            rootView: BreakStatsView()
                .environmentObject(TimerManager.shared)
                .frame(width: SettingsTokens.windowWidth - 28)
        )
        statsHosting.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(statsHosting.fittingSize.height, SettingsTokens.tabContentHeight + 0.5)
    }

    func testArcKnobOffsetInterpolatesStrictlyAlongCircularArc() {
        var modifier = ArcKnobOffset(progress: 20.0 / 60.0, radius: 74.0)
        XCTAssertEqual(modifier.animatableData, 20.0 / 60.0, accuracy: 0.0001)
        modifier.animatableData = 45.0 / 60.0
        XCTAssertEqual(modifier.progress, 45.0 / 60.0, accuracy: 0.0001)

        // 从 20 分到 45 分插值任意中间帧，半径应始终锁定在 74pt 圆周上（而非直线弦穿心）
        for step in 0...20 {
            let p = (20.0 / 60.0) + (25.0 / 60.0) * (Double(step) / 20.0)
            let pt = ArcKnobOffset.point(progress: p, radius: 74.0)
            XCTAssertEqual(hypot(pt.x, pt.y), 74.0, accuracy: 0.001)
        }
    }

    func testTodayRhythmNearestEventSelectsEachBarIndependently() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 10; comps.minute = 0
        let morning = Calendar.current.date(from: comps)!
        comps.hour = 16; comps.minute = 30
        let afternoon = Calendar.current.date(from: comps)!
        comps.hour = 19; comps.minute = 47
        let evening = Calendar.current.date(from: comps)!

        let events = [
            BreakEventRecord(timestamp: morning.timeIntervalSince1970, breakSeconds: 120, focusSeconds: 1800, wasSkipped: false),
            BreakEventRecord(timestamp: afternoon.timeIntervalSince1970, breakSeconds: 120, focusSeconds: 1800, wasSkipped: false),
            BreakEventRecord(timestamp: evening.timeIntervalSince1970, breakSeconds: 120, focusSeconds: 1800, wasSkipped: false)
        ]

        let trackWidth: CGFloat = 328
        let morningX = BreakEventRecord.xPosition(for: events[0].timestamp, width: trackWidth)
        let afternoonX = BreakEventRecord.xPosition(for: events[1].timestamp, width: trackWidth)
        let eveningX = BreakEventRecord.xPosition(for: events[2].timestamp, width: trackWidth)

        XCTAssertEqual(BreakEventRecord.nearestEvent(atX: morningX, width: trackWidth, events: events)?.id, events[0].id)
        XCTAssertEqual(BreakEventRecord.nearestEvent(atX: afternoonX + 3, width: trackWidth, events: events)?.id, events[1].id)
        XCTAssertEqual(BreakEventRecord.nearestEvent(atX: eveningX, width: trackWidth, events: events)?.id, events[2].id)
        XCTAssertNil(BreakEventRecord.nearestEvent(atX: (morningX + afternoonX) / 2, width: trackWidth, events: events))
    }

    func testBreakViewRendersCleanlyInDesktopLayout() {
        let session = BreakDisplaySession()
        session.prepareSession(totalBreakSeconds: 120, themeSetting: .slateIce)

        let breakHosting = NSHostingView(
            rootView: BreakView(session: session)
                .environmentObject(TimerManager.shared)
                .frame(width: 1200, height: 800)
        )
        breakHosting.layoutSubtreeIfNeeded()
        XCTAssertGreaterThanOrEqual(breakHosting.fittingSize.width, 1200)

        let prevMulti = TimerManager.shared.settings.breakExerciseMultiView
        TimerManager.shared.settings.breakExerciseMultiView = true
        defer { TimerManager.shared.settings.breakExerciseMultiView = prevMulti }
        let multiHosting = NSHostingView(
            rootView: BreakView(session: session)
                .environmentObject(TimerManager.shared)
                .frame(width: 1200, height: 800)
        )
        multiHosting.layoutSubtreeIfNeeded()
        XCTAssertGreaterThanOrEqual(multiHosting.fittingSize.width, 1200)

        for (iconKind, title) in [
            (HudIconKind.focusStart, "开始专注"),
            (HudIconKind.bellReminder, "2分后休息"),
            (HudIconKind.breakCountdown(progress: 0.6), "3秒后休息"),
            (HudIconKind.warningCap(progress: 0.3), "5秒后休息")
        ] {
            let hudHosting = NSHostingView(
                rootView: FrostedHudCapsulePill(iconKind: iconKind, title: title)
            )
            hudHosting.layoutSubtreeIfNeeded()
            // 含上下 10+18pt 阴影留白，整体高度应在 64-74pt（胶囊本体约 41pt，兼顾醒目度与比例）
            XCTAssertGreaterThanOrEqual(hudHosting.fittingSize.height, 64.0)
            XCTAssertLessThanOrEqual(hudHosting.fittingSize.height, 74.0)
        }
    }
}
