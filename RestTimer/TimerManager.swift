import Foundation
import AppKit
import SwiftUI

internal class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var isBreakTime = false
    @Published var remainingBreakTime: TimeInterval = 0
    var showSkipButton: Bool {
        get {
            UserDefaults.standard.bool(forKey: "showSkipButton")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showSkipButton")
            objectWillChange.send()
        }
    }
    @Published var lastWorkStartTime: TimeInterval = Date().timeIntervalSince1970
    
    private var workTimer: Timer?
    private var breakTimer: Timer?
    private var breakWindows: [NSWindow] = [] // 添加数组来存储所有显示器的休息窗口
    //   let workDuration: TimeInterval = 25 * 60 // 25分钟
    // let breakDuration: TimeInterval = 5 * 60  // 5分钟
    let workDuration: TimeInterval = 5  // 5秒
    let breakDuration: TimeInterval = 3  // 3秒
    
    // 添加一个属性来保持对通知窗口的引用
    private var notificationWindow: NSWindow?
    
    private init() {
        // 延迟初始化定时器，确保 AppKit 已完全初始化
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
    }
    
    private func startBreak() {
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
        
        // 创建并显示窗口
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
    }
    
    private func startWorkTimer() {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startWorkTimer()
            }
            return
        }
        
        workTimer?.invalidate()
        workTimer = nil
        
        lastWorkStartTime = Date().timeIntervalSince1970
        
        // 显示开始专注的通知
        showStartWorkNotification()
        
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
        
        // 使用 NSHostingController 来管理 SwiftUI 视图
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
               // 添加以下两行代码来启用点击穿透
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
            window.backgroundColor = NSColor.black.withAlphaComponent(0.7)
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.acceptsMouseMovedEvents = true
            
            // 创建休息视图
            let breakView = BreakView()
                .environmentObject(self)
            window.contentView = NSHostingView(rootView: breakView)
            
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
        
        // 2. 如果没有找到鼠标所在屏幕，尝试获取当前激活窗口所在屏幕
        if let keyWindow = NSApp.keyWindow,
           let windowScreen = keyWindow.screen {
            return windowScreen
        }
        
        // 3. 如果都没有，返回主屏幕
        return NSScreen.main
    }
}
