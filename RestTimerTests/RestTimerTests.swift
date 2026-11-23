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
    }
}
