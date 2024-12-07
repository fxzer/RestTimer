import Foundation
import AppKit
import SwiftUI

internal class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var isBreakTime = false
    @Published var remainingBreakTime: TimeInterval = 0
    
    private var workTimer: Timer?
    private var breakTimer: Timer?
    private var breakWindow: NSWindow?
    
    let workDuration: TimeInterval = 5 // 测试用5秒
    let breakDuration: TimeInterval = 3 // 测试用3秒
    
    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.startWorkTimer()
        }
    }
    
    func skipBreak() {
        DispatchQueue.main.async { [weak self] in
            self?.cleanupAndEndBreak()
        }
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
            window.orderOut(nil)  // 使用 orderOut 替代 close
            breakWindow = nil
        }
        
        // 重置状态
        isBreakTime = false
        remainingBreakTime = 0
        
        // 重新开始工作定时器
        startWorkTimer()
    }
    
    private func startBreak() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 清理现有定时器
            self.breakTimer?.invalidate()
            self.breakTimer = nil
            
            self.isBreakTime = true
            self.remainingBreakTime = self.breakDuration
            
            // 创建并显示窗口
            self.createAndShowBreakWindow()
            
            // 创建新的定时器
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                if self.remainingBreakTime > 0 {
                    self.remainingBreakTime -= 1
                } else {
                    DispatchQueue.main.async {
                        self.cleanupAndEndBreak()
                    }
                    timer.invalidate()
                }
            }
            self.breakTimer = timer
        }
    }
    
    private func startWorkTimer() {
        workTimer?.invalidate()
        workTimer = nil
        
        let timer = Timer(timeInterval: workDuration, repeats: false) { [weak self] _ in
            self?.startBreak()
        }
        workTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func createAndShowBreakWindow() {
        guard let screen = NSScreen.main else { return }
        
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],  // 移除 .titled，因为我们不需要标题栏
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver  // 使用 screenSaver 级别确保窗口始终在最前
        window.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        
        let breakView = BreakView()
            .environmentObject(self)
        window.contentView = NSHostingView(rootView: breakView)
        
        breakWindow = window
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    deinit {
        cleanupAndEndBreak()
    }
}
