import SwiftUI

struct BreakView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var randomQuote: String = ""
    
    private let quotes = [
        "休息是为了走更远的路。 ——中国谚语",
        "休息时，不要想着工作；工作时，也不要想着休息。 ——托尔斯泰",
        "人是不能一直紧绷的，偶尔停下来看看风景，人生才有意义。 ——村上春树",
        "聪明的人懂得适时放下，短暂的休息是精神的加油站。 ——尼采",
        "健康不仅取决于工作的效率，还取决于他休息的质量。 ——托马斯·卡莱尔",
        "休息并不是浪费时间，而是为了更有效地利用时间。 ——爱默生",
        "没有健康，其他一切都是零。 ——贝尔纳",
        "懂得休息的人，更懂得如何生活。 ——林语堂",
        "劳逸结合，才能让思想的火花迸发。 ——莎士比亚",
        "疲惫是一种信号，它告诉你该停下来喘口气了。 ——卡夫卡",
        "适当的休息，才能更好地奔跑。 ——阿尔伯特·爱因斯坦",
        "健康是最大的财富，而休息是保护财富的保险。 ——本杰明·富兰克林",
        "过度的劳累就像透支健康的信用卡，终会付出代价。 ——爱迪生",
        "宁静是心灵的休息，而休息是身体的需要。 ——泰戈尔",
        "最深刻的智慧在于：知道何时该前进，何时该停下。 ——亚里士多德",
        "健康是智慧的基础，休息是健康的基石。 ——亚里士多德",
        "懂得休息的人，才能真正掌控自己的时间。 ——巴尔扎克",
        "适当的休息，是通往成功的必经之路。 ——乔布斯",
        "生命的节奏不在于不停奔跑，而在于懂得停下来欣赏风景。 ——乔治·桑",
        "过度劳累会让灵感远离你，休息则会让它如影随形。 ——梭罗",
        "一天中最重要的时刻，往往是你停下来呼吸的瞬间。 ——萨特",
        "繁忙的生活，需要插入适当的空白，休息能让生命更有色彩。 ——李小龙",
        "身体的疲惫可以通过睡眠恢复，而心灵的疲惫需要休息和关怀。 ——雪莱",
        "没有合理的休息，就没有创造力的巅峰。 ——马克·吐温",
        "过劳是健康的最大敌人，休息是最好的医生。 ——爱因斯坦",
        "休息不仅是为了恢复能量，也是为了保护生命的热情。 ——苏格拉底",
        // 新增谚语
        "猫捉老鼠中场休息——放松一会儿再较量",
        "打工人也要打‘暂停键’",
        "小憩一会，地球照样转",
        // 英文
        "Rest now, hustle later.",
        "You can't pour from an empty cup — take a break!",
        "Take a nap. It’s not being lazy, it’s being productive in the long run.",
        "Good things come to those who rest.",
        "Coffee first, then rest.",
        "I’m not lazy, I’m in energy-saving mode.",
        "Life’s too short to not take naps.",
        "Resting is an art; I am a master.",
        "Don’t forget to recharge your batteries... literally and figuratively!",
        "A day without rest is like a computer without a reboot — it crashes eventually.",
        "Rest: because you can’t do your best if you’re exhausted!",
        "Take a break, or your brain will break!",
        "Do your mind a favor: take five!",
        "Rest is the secret ingredient to success.",
        "Pause to recharge, not to procrastinate!",
        "Even superheroes need a nap!",
        "Rest today, conquer tomorrow!",
        "Don’t burn out, take the timeout.",
        "Short break = long-lasting productivity.",
        "Work hard, rest harder!"
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            // 仅显示倒计时
            Text(remainingTimeText())
                .font(.system(size: 150)) // 字体调大
                .fontWeight(.bold) // 字体加粗
                .foregroundColor(.white)
            
            // 显示随机名言
            Text(randomQuote)
                .font(.system(size: 40))
                .foregroundColor(.white)
                .fontWeight(.bold) // 字体加粗
                .multilineTextAlignment(.center)
                .padding()
            
            if timerManager.showSkipButton {
                Button(action: {
                    timerManager.skipBreak()
                }) {
                    Text("跳过休息")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.9)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .padding(.top, 20)
                .buttonStyle(CustomButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            randomQuote = quotes.randomElement() ?? ""
        }
    }
    
    private func remainingTimeText() -> String {
        let remainingTime = Int(timerManager.remainingBreakTime)
        if remainingTime > 0 {
            let minutes = remainingTime / 60
            let seconds = remainingTime % 60
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return "--:--"
        }
    }
}

// 添加自定义按钮样式
struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
