import SwiftUI

struct ContentView: View {
    @StateObject private var timerManager = TimerManager.shared
    
    var body: some View {
        VStack {
            if !timerManager.isBreakTime {
                Text("专注工作中...")
                    .font(.title)
            }
        }
        .frame(width: 200, height: 60)
    }
}
