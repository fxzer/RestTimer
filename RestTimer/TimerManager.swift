import Foundation
import AppKit
import SwiftUI

internal class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var isBreakTime = false
    @Published var remainingBreakTime: TimeInterval = 0
    @Published var showSkipButton = true
    @Published var lastWorkStartTime: TimeInterval = Date().timeIntervalSince1970
    
    private var workTimer: Timer?
    private var breakTimer: Timer?
    private var breakWindow: NSWindow?
    //   let workDuration: TimeInterval = 25 * 60 // 25分钟
    // let breakDuration: TimeInterval = 5 * 60  // 5分钟
    let workDuration: TimeInterval = 5  // 5秒
    let breakDuration: TimeInterval = 3  // 3秒
    
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
        
        // 关闭窗口
        if let window = breakWindow {
            window.orderOut(nil)
            breakWindow = nil
        }
        
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
        
        workTimer = Timer.scheduledTimer(withTimeInterval: workDuration, repeats: false) { [weak self] _ in
            self?.startBreak()
        }
    }
    
    private func createAndShowBreakWindow() {
        guard let screen = NSScreen.main else { return }
        
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
        
        let breakView = BreakView()
            .environmentObject(self)
        window.contentView = NSHostingView(rootView: breakView)
        
        breakWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    deinit {
        cleanupAndEndBreak()
    }
}
