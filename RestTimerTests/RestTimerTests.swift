import XCTest
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
            autoResetOnIdle: true
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
            autoResetOnIdle: true
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
        XCTAssertFalse(
            BreakDelayEvaluator.shouldEnterAwayState(
                elapsedWork: 5,
                idleElapsed: 400,
                breakDuration: 300,
                autoResetEnabled: true
            )
        )

        XCTAssertTrue(
            BreakDelayEvaluator.shouldEnterAwayState(
                elapsedWork: 360,
                idleElapsed: 300,
                breakDuration: 300,
                autoResetEnabled: true
            )
        )

        XCTAssertTrue(BreakDelayEvaluator.shouldResumeFromAway(idleElapsed: 0.5))
        XCTAssertFalse(BreakDelayEvaluator.shouldResumeFromAway(idleElapsed: 10.0))
    }

    func testScreenPresenceTrackerDeduplicatesLockSleepAndWakeUnlock() {
        var tracker = ScreenPresenceTracker()

        // 锁屏 -> 息屏：只触发一次暂停
        XCTAssertEqual(tracker.handleScreenLocked(), .pauseForSystemLock)
        XCTAssertEqual(tracker.handleScreenSlept(), .none)

        // 亮屏但仍在锁屏密码页：不提前重置
        XCTAssertEqual(tracker.handleScreenWoke(), .none)

        // 真正解锁：触发一次重置，重复解锁不再触发
        XCTAssertEqual(tracker.handleScreenUnlocked(), .resetOnSystemUnlock)
        XCTAssertEqual(tracker.handleScreenUnlocked(), .none)

        // 纯息屏未锁屏：唤醒时应正常重置
        XCTAssertEqual(tracker.handleScreenSlept(), .pauseForSystemLock)
        XCTAssertEqual(tracker.handleScreenWoke(), .resetOnSystemUnlock)
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

        manager.handleSystemUnlock()
        XCTAssertTrue(manager.isPaused)
        XCTAssertEqual(manager.state.pauseReason, .manual)

        // 恢复后改为工作态，此时系统锁屏并解锁应自动重置回工作态
        manager.toggleManualPause()
        XCTAssertFalse(manager.isPaused)

        manager.handleSystemLock()
        XCTAssertEqual(manager.state.pauseReason, .systemLocked)

        manager.handleSystemUnlock()
        XCTAssertFalse(manager.isPaused)
        if case .working = manager.state {
            // expected
        } else {
            XCTFail("Expected .working after system unlock, got \(manager.state)")
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
        XCTAssertEqual(decoded.autoResetOnIdle, true)
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

    func testCuratedQuoteLibraryProvidesSixtyUniqueQuotesWithNonRepeatingBag() {
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
}
