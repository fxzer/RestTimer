import Foundation
import AppKit
import SwiftUI

internal class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var isBreakTime = false
    @Published var remainingBreakTime: TimeInterval = 0
    @Published var showSkipButton: Bool = false {
        didSet {
            if oldValue != showSkipButton {
                saveSettings()
            }
        }
    }
    @Published var lastWorkStartTime: TimeInterval = Date().timeIntervalSince1970
    @Published var workDurationMinutes: Int = 25 {
        didSet {
            if oldValue != workDurationMinutes {
                // 只在非初始化时进行校验
                if !isInitializing && !isValidWorkDuration() {
                    let alert = NSAlert()
                    alert.messageText = "专注时长必须大于提前提醒时长"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "确认")
                    alert.runModal()
                } else {
                    resetWorkTimer()
                }
                saveSettings()
            }
        }
    }
    @Published var workDurationSeconds: Int = 0 {
        didSet {
            if oldValue != workDurationSeconds {
                if !isInitializing && !isValidWorkDuration() {
                    let alert = NSAlert()
                    alert.messageText = "专注时长必须大于提前提醒时长"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "确认")
                    alert.runModal()
                } else {
                    resetWorkTimer() // 只有在条件满足时才重置计时器
                }
                saveSettings()
            }
        }
    }
    @Published var breakDurationMinutes: Int = 5 {
        didSet {
            saveSettings()
        }
    }
    @Published var breakDurationSeconds: Int = 0 {
        didSet {
            saveSettings()
        }
    }
    @Published var earlyNotifyMinutes: Int = 2 {
        didSet {
            saveSettings()
        }
    }
    @Published var earlyNotifySeconds: Int = 0 {
        didSet {
            saveSettings()
        }
    }
    @Published var preventQuit: Bool = false
    @Published var isPaused: Bool = false
    private var pausedTimeRemaining: TimeInterval?
  
  
    private var workTimer: Timer?
    private var breakTimer: Timer?
    private var breakWindows: [NSWindow] = [] // 添加数组来存储所有显示器的休息窗口
    
    // 计算属性
    var workDuration: TimeInterval {
        TimeInterval(workDurationMinutes * 60 + workDurationSeconds)
    }
    
    var breakDuration: TimeInterval {
        TimeInterval(breakDurationMinutes * 60 + breakDurationSeconds)
    }
    
    var earlyNotifyDuration: TimeInterval {
        TimeInterval(earlyNotifyMinutes * 60 + earlyNotifySeconds)
    }
    
    // 添加一个属性来保持对通知窗口的引用
    private var notificationWindow: NSWindow?
    
    private let defaults = UserDefaults.standard
    
    // 添加一个标志来标识是否在初始化过程中
    private var isInitializing = true
    
    // 添加 statusBarManager 属性
    weak var statusBarManager: StatusBarManager?
    
    @Published var showDockIcon: Bool {
        didSet {
            if oldValue != showDockIcon {
                saveSettings()
                // 确保在主线程执行，并立即更新 Dock 图标状态
                DispatchQueue.main.async { [weak self] in
                    self?.updateDockIconVisibility()
                }
            }
        }
    }
    
    // 添加一个属性来跟踪提前提醒的定时器
    private var earlyNotifyTimer: Timer?
    
    private init() {
        // 从 UserDefaults 读取设置
        if let data = UserDefaults.standard.data(forKey: "TimerSettings"),
           let settings = try? JSONDecoder().decode(TimerSettings.self, from: data) {
            self.showDockIcon = settings.showDockIcon
        } else {
            self.showDockIcon = true
        }
        
        isInitializing = true
        loadSettings()
        
        // 初始化完成后立即应用 Dock 图标状态
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateDockIconVisibility()
        }
        
        isInitializing = false
        
        // 延迟初始化定时器...
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startWorkTimer()
        }
    }
    
    func skipBreak() {
        cleanupAndEndBreak()
    }
    
    private func cleanupAndEndBreak() {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.cleanupAndEndBreak()
            }
            return
        }
        
        // 清理所有定时器
        workTimer?.invalidate()
        workTimer = nil
        breakTimer?.invalidate()
        breakTimer = nil
        
        // 关闭所有休息窗口
        breakWindows.forEach { window in
            window.orderOut(nil)
        }
        breakWindows.removeAll()
        
        // 重置状态
        isBreakTime = false
        remainingBreakTime = 0
        
        // 重新开始工作定时器
        startWorkTimer()
        
        preventQuit = false
    }
    
    private func startBreak() {
        // 如果当前是暂停状态，不要启动休息
        if isPaused {
            return
        }
        
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startBreak()
            }
            return
        }
        
        // 清理现有定时器
        breakTimer?.invalidate()
        breakTimer = nil
        
        isBreakTime = true
        remainingBreakTime = breakDuration
        
        // 建并显示窗口
        createAndShowBreakWindow()
        
        // 创建新的定时器
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                if self.remainingBreakTime > 0 {
                    self.remainingBreakTime -= 1
                } else {
                    self.cleanupAndEndBreak()
                    timer.invalidate()
                }
            }
        }
        
        preventQuit = true
    }
    
    private func startWorkTimer() {
        // 如果当前是暂停状态，不要启动计时器
        if isPaused {
            return
        }
        
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startWorkTimer()
            }
            return
        }
        
        // 清理所有定时器
        workTimer?.invalidate()
        workTimer = nil
        earlyNotifyTimer?.invalidate()
        earlyNotifyTimer = nil
        
        lastWorkStartTime = Date().timeIntervalSince1970
        
        // 显示开始专注的通知
        showStartWorkNotification()
        
        // 设置提前提醒的定时器
        if earlyNotifyDuration > 0 && !isInitializing {
            let earlyNotifyDelay = workDuration - earlyNotifyDuration
            earlyNotifyTimer = Timer.scheduledTimer(withTimeInterval: earlyNotifyDelay, repeats: false) { [weak self] _ in
                self?.showEarlyNotification()
            }
        }
        
        // 设置工作结束的定时器
        workTimer = Timer.scheduledTimer(withTimeInterval: workDuration, repeats: false) { [weak self] _ in
            self?.startBreak()
        }
    }
    
    private func showStartWorkNotification() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showStartWorkNotification()
            }
            return
        }
        
        // 果已有通知窗口，先关闭它
        if let existingWindow = notificationWindow {
            existingWindow.close()
            notificationWindow = nil
        }
        
        // 创建并配置通知视图
        let notificationContent = VStack {
            Text("开始专注")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 200, height: 200)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        
        // 使用 NSHostingController 来管理 SwiftUI 图
        let hostingController = NSHostingController(rootView: notificationContent)
        hostingController.view.wantsLayer = true
        
        // 创建并配置窗口
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 配置窗口属性
        window.contentViewController = hostingController
        window.isOpaque = false
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
               // 添加以下两码来启用点击穿透
        window.ignoresMouseEvents = true
        window.contentView?.appearance = NSAppearance(named: .vibrantDark)
        // 设置窗口圆角
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true
        
        // 获取当前活动屏幕或鼠标所在屏幕
        let activeScreen = getCurrentScreen()
        
        // 计算窗口位置（在当前活动屏幕居中）
        if let screen = activeScreen {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.minX + (screenFrame.width - window.frame.width) / 2
            let y = screenFrame.minY + (screenFrame.height - window.frame.height) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // 保存窗口引用
        notificationWindow = window
        
        // 显示窗口并设置自动关闭
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 显示窗口
            self.notificationWindow?.orderFront(nil)
            
            // 3秒后关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                
                if let window = self.notificationWindow {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.3
                        window.animator().alphaValue = 0
                    }, completionHandler: { [weak self] in
                        window.close()
                        self?.notificationWindow = nil
                    })
                }
            }
        }
    }
    
    private func createAndShowBreakWindow() {
        // 清理现有的窗口
        breakWindows.forEach { window in
            window.orderOut(nil)
        }
        breakWindows.removeAll()
        
        // 为每个屏幕创建休息窗口
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.level = .screenSaver
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.acceptsMouseMovedEvents = true
            
            // 创建一个视觉效果视图作为背景
            let visualEffectView = NSVisualEffectView(frame: window.contentView?.bounds ?? .zero)
            visualEffectView.material = .dark  // 可以尝试其他材质效果：.ultraDark, .light, .mediumLight 等
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            
            // 添加半透明黑色背景层
            let overlayView = NSView(frame: visualEffectView.bounds)
            overlayView.wantsLayer = true
            overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
            visualEffectView.addSubview(overlayView)
            
            // 创并配置 SwiftUI 休息视图
            let breakView = BreakView()
                .environmentObject(self)
            let hostingView = NSHostingView(rootView: breakView)
            hostingView.frame = visualEffectView.bounds
            
            // 组合视图层次
            visualEffectView.addSubview(hostingView)
            window.contentView = visualEffectView
            
            // 设置窗口位置到对应屏幕
            window.setFrame(screen.frame, display: true)
            
            // 保存窗口引用
            breakWindows.append(window)
            
            // 显示窗口
            window.makeKeyAndOrderFront(nil)
        }
        
        // 激活应用
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    deinit {
        cleanupAndEndBreak()
    }
    
    // 添加获取当前活动屏幕的方法
    private func getCurrentScreen() -> NSScreen? {
        // 1. 首先尝试获取鼠标所在屏幕
        let mouseLocation = NSEvent.mouseLocation
        let mouseScreen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
        
        if let screen = mouseScreen {
            return screen
        }
        
        // 2. 果没有找��鼠标所在屏幕，尝试获取当前激活窗口在屏幕
        if let keyWindow = NSApp.keyWindow,
           let windowScreen = keyWindow.screen {
            return windowScreen
        }
        
        // 3. 如果都没有，返回主屏幕
        return NSScreen.main
    }
    
    func resetWorkTimer() {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.resetWorkTimer()
            }
            return
        }
        
        // 清理现有定时器
        workTimer?.invalidate()
        workTimer = nil
        
        // 重新开始工作定时器
        lastWorkStartTime = Date().timeIntervalSince1970
        startWorkTimer()
    }
    
    func isValidEarlyNotifyDuration() -> Bool {
        let totalEarlySeconds = earlyNotifyMinutes * 60 + earlyNotifySeconds
        let totalWorkSeconds = workDurationMinutes * 60 + workDurationSeconds
        return totalEarlySeconds < totalWorkSeconds
    }
    
    private func showEarlyNotification() {
        // 如果当前是暂停状态，不显示提醒
        if isPaused {
            return
        }
        
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showEarlyNotification()
            }
            return
        }
        
        // 如果已有通知窗口，先关闭它
        if let existingWindow = notificationWindow {
            existingWindow.close()
            notificationWindow = nil
        }
        
        // 计算剩余时间
        let remainingMinutes = Int(earlyNotifyDuration) / 60
        let remainingSeconds = Int(earlyNotifyDuration) % 60
        
        // 创建并配置通知视图
        let notificationContent = VStack {
            Text("\(remainingMinutes)分\(remainingSeconds)秒后")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
            Text("将进入休息")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(width: 250, height: 150)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        
        // 使用 NSHostingController 理 SwiftUI 视图
        let hostingController = NSHostingController(rootView: notificationContent)
        hostingController.view.wantsLayer = true
        
        // 创建并配置窗口
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 配置窗口属性
        window.contentViewController = hostingController
        window.isOpaque = false
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.contentView?.appearance = NSAppearance(named: .vibrantDark)
        
        // 设置窗口圆角
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true
        
        // 获取当前活动屏幕
        let activeScreen = getCurrentScreen()
        
        // 计算窗口位置（在当前活动屏幕居中）
        if let screen = activeScreen {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.minX + (screenFrame.width - window.frame.width) / 2
            let y = screenFrame.minY + (screenFrame.height - window.frame.height) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // 保存窗口引用
        notificationWindow = window
        
        // 显示窗口并设置自动关闭
        window.orderFront(nil)
        
        // 3秒后关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            
            if let window = self.notificationWindow {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    window.animator().alphaValue = 0
                }, completionHandler: { [weak self] in
                    window.close()
                    self?.notificationWindow = nil
                })
            }
        }
    }
    
    func togglePause() {
        isPaused.toggle()
        
        if isPaused {
            // 暂停时，停止所有计时器和提醒
            workTimer?.invalidate()
            workTimer = nil
            breakTimer?.invalidate()
            breakTimer = nil
            earlyNotifyTimer?.invalidate()
            earlyNotifyTimer = nil
            
            // 关闭前显示的通知窗口
            if let window = notificationWindow {
                window.close()
                notificationWindow = nil
            }
            
            // 保存��停时的剩余时间
            if isBreakTime {
                pausedTimeRemaining = remainingBreakTime
            } else {
                pausedTimeRemaining = workDuration - (Date().timeIntervalSince1970 - lastWorkStartTime)
            }
        } else {
            // 恢复时，更新开始时间并重新启动计时器
            if let remaining = pausedTimeRemaining {
                if isBreakTime {
                    // 如果是休息时间
                    remainingBreakTime = remaining
                    breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                        guard let self = self else {
                            timer.invalidate()
                            return
                        }
                        
                        DispatchQueue.main.async {
                            if self.remainingBreakTime > 0 {
                                self.remainingBreakTime -= 1
                            } else {
                                self.cleanupAndEndBreak()
                                timer.invalidate()
                            }
                        }
                    }
                } else {
                    // 如果是工作时间
                    lastWorkStartTime = Date().timeIntervalSince1970 - (workDuration - remaining)
                    
                    // 创建新的工作计时器
                    workTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
                        self?.startBreak()
                    }
                    
                    // 如果还需要提前提醒，也要重新设置
                    if remaining > earlyNotifyDuration {
                        let earlyNotifyDelay = remaining - earlyNotifyDuration
                        earlyNotifyTimer = Timer.scheduledTimer(withTimeInterval: earlyNotifyDelay, repeats: false) { [weak self] _ in
                            self?.showEarlyNotification()
                        }
                    }
                }
            }
            pausedTimeRemaining = nil
        }
        
        // 更新状态栏菜单
        statusBarManager?.updatePauseMenuItem()
    }
    
    func getRemainingPausedTime() -> TimeInterval? {
        return pausedTimeRemaining
    }
    
    private func saveSettings() {
        let settings = TimerSettings(
            showSkipButton: showSkipButton,
            showDockIcon: showDockIcon,
            workDurationMinutes: workDurationMinutes,
            workDurationSeconds: workDurationSeconds,
            breakDurationMinutes: breakDurationMinutes,
            breakDurationSeconds: breakDurationSeconds,
            earlyNotifyMinutes: earlyNotifyMinutes,
            earlyNotifySeconds: earlyNotifySeconds
        )
        
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "TimerSettings")
            UserDefaults.standard.synchronize() // 强制同步保存
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "TimerSettings"),
           let settings = try? JSONDecoder().decode(TimerSettings.self, from: data) {
            // 不要在这里设置 showDockIcon，因为它已经在 init 中设置过了
            showSkipButton = settings.showSkipButton
            workDurationMinutes = settings.workDurationMinutes
            workDurationSeconds = settings.workDurationSeconds
            breakDurationMinutes = settings.breakDurationMinutes
            breakDurationSeconds = settings.breakDurationSeconds
            earlyNotifyMinutes = settings.earlyNotifyMinutes
            earlyNotifySeconds = settings.earlyNotifySeconds
        } else {
            let defaultSettings = TimerSettings.default
            showSkipButton = defaultSettings.showSkipButton
            // showDockIcon 已经在 init 中设置过了
            workDurationMinutes = defaultSettings.workDurationMinutes
            workDurationSeconds = defaultSettings.workDurationSeconds
            breakDurationMinutes = defaultSettings.breakDurationMinutes
            breakDurationSeconds = defaultSettings.breakDurationSeconds
            earlyNotifyMinutes = defaultSettings.earlyNotifyMinutes
            earlyNotifySeconds = defaultSettings.earlyNotifySeconds
            
            saveSettings()
        }
    }
    
    private func validateAndAdjustEarlyNotify() {
        let settings = TimerSettings(
            showSkipButton: showSkipButton,
            showDockIcon: showDockIcon,
            workDurationMinutes: workDurationMinutes,
            workDurationSeconds: workDurationSeconds,
            breakDurationMinutes: breakDurationMinutes,
            breakDurationSeconds: breakDurationSeconds,
            earlyNotifyMinutes: earlyNotifyMinutes,
            earlyNotifySeconds: earlyNotifySeconds
        )
        
        // 如果提前提醒时间大于等于专注时间
        if settings.earlyNotifyTotalSeconds >= settings.workTotalSeconds {
            // 将提前提醒时间设置为专注时间的一半或默认值(2分钟)取较小值
            let halfWorkSeconds = settings.workTotalSeconds / 2
            let defaultEarlyNotifySeconds = 2 * 60 // 2分钟
            let newEarlyNotifySeconds = min(halfWorkSeconds, defaultEarlyNotifySeconds)
            
            earlyNotifyMinutes = newEarlyNotifySeconds / 60
            earlyNotifySeconds = newEarlyNotifySeconds % 60
            
            // 通知用户设置已被调整
            NotificationCenter.default.post(
                name: NSNotification.Name("EarlyNotifyAdjusted"),
                object: nil,
                userInfo: ["message": "提前提醒时间已自动调整为\(earlyNotifyMinutes)分\(earlyNotifySeconds)秒"]
            )
        }
    }
    
    // 添加一个验证方法
    private func isValidWorkDuration() -> Bool {
        let workTotalSeconds = workDurationMinutes * 60 + workDurationSeconds
        let earlyNotifyTotalSeconds = earlyNotifyMinutes * 60 + earlyNotifySeconds
        return workTotalSeconds > earlyNotifyTotalSeconds
    }
    
    private func updateDockIconVisibility() {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateDockIconVisibility()
            }
            return
        }
        
        // 先更新激活策略
        if showDockIcon {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
        } else {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        
        // 使用 async 延迟执行窗口更新，确保激活策略已经生效
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 先激活应用
            NSApp.activate(ignoringOtherApps: true)
            
            // 等待短暂延迟后再更新窗口
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 更新所有窗口
                NSApp.windows.forEach { window in
                    if window.isVisible {
                        window.orderFront(nil)
                    }
                }
            }
        }
    }
    
    func resetTimer() {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.resetTimer()
            }
            return
        }
        
        // 清理所有现有定时器
        workTimer?.invalidate()
        workTimer = nil
        breakTimer?.invalidate()
        breakTimer = nil
        earlyNotifyTimer?.invalidate()
        earlyNotifyTimer = nil
        
        // 清理所有窗口
        if let window = notificationWindow {
            window.close()
            notificationWindow = nil
        }
        
        breakWindows.forEach { window in
            window.orderOut(nil)
        }
        breakWindows.removeAll()
        
        // 重置状态
        lastWorkStartTime = Date().timeIntervalSince1970
        isPaused = false
        isBreakTime = false
        remainingBreakTime = 0
        pausedTimeRemaining = nil
        
        // 更新状态栏菜单项
        statusBarManager?.updatePauseMenuItem()
        
        // 重新开始工作定时器
        startWorkTimer()
    }
}

private struct TimerSettings: Codable {
    var showSkipButton: Bool
    var showDockIcon: Bool
    var workDurationMinutes: Int
    var workDurationSeconds: Int 
    var breakDurationMinutes: Int
    var breakDurationSeconds: Int
    var earlyNotifyMinutes: Int
    var earlyNotifySeconds: Int
    
    static let `default` = TimerSettings(
        showSkipButton: false,
        showDockIcon: true,
        workDurationMinutes: 25,
        workDurationSeconds: 0,
        breakDurationMinutes: 5,
        breakDurationSeconds: 0,
        earlyNotifyMinutes: 2,
        earlyNotifySeconds: 0
    )
    
    // 添加一个计算总数扩展方法
    func totalSeconds(minutes: Int, seconds: Int) -> Int {
        return minutes * 60 + seconds
    }
    
    var workTotalSeconds: Int {
        return totalSeconds(minutes: workDurationMinutes, seconds: workDurationSeconds)
    }
    
    var earlyNotifyTotalSeconds: Int {
        return totalSeconds(minutes: earlyNotifyMinutes, seconds: earlyNotifySeconds)
    }
}

