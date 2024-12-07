import SwiftUI

struct BreakView: View {
    @EnvironmentObject var timerManager: TimerManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("休息时间！")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            Text("剩余时间: \(Int(timerManager.remainingBreakTime))秒")
                .font(.title)
                .foregroundColor(.white)
            
            if timerManager.showSkipButton {
                Button("跳过休息") {
                    timerManager.skipBreak()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
