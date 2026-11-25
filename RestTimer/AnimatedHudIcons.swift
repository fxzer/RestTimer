import SwiftUI

/// 微胶囊左侧状态矢量动效类型（全版本 SwiftUI 原生部件驱动，无外部依赖）
enum HudIconKind: Equatable {
    case focusStart
    case bellReminder
    case breakCountdown(progress: Double)
    case warningCap(progress: Double)
}

/// 轻量无底色矢量动效徽章（将图标拆为独立矢量部件，出场瞬间呈现“状态 A → 状态 B”物理运动）
struct CapsuleAccentIconBadge: View {
    let kind: HudIconKind
    let accent: Color

    var body: some View {
        Group {
            switch kind {
            case .focusStart:
                FocusWatchEngageIcon(accent: accent)
            case .bellReminder:
                RingingBellIcon(accent: accent)
            case .breakCountdown(let progress):
                SteamingBreakCupIcon(accent: accent, progress: progress)
            case .warningCap(let progress):
                WarningCountdownIcon(accent: accent, progress: progress)
            }
        }
        .frame(width: 22, height: 22)
    }
}

/// 开始专注：外环顺时针闭合描绘 + 内部指针物理弹性上弦拨动归位
private struct FocusWatchEngageIcon: View {
    let accent: Color

    @State private var ringTrim: CGFloat = 0.16
    @State private var minuteAngle: Double = -135
    @State private var hourAngle: Double = 60
    @State private var centerScale: CGFloat = 0.45

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(accent, style: StrokeStyle(lineWidth: 1.65, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 18, height: 18)

            RoundedRectangle(cornerRadius: 0.85, style: .continuous)
                .fill(accent.opacity(0.88))
                .frame(width: 1.6, height: 4.2)
                .offset(y: -2.1)
                .rotationEffect(.degrees(hourAngle))

            RoundedRectangle(cornerRadius: 0.85, style: .continuous)
                .fill(accent)
                .frame(width: 1.65, height: 5.8)
                .offset(y: -2.9)
                .rotationEffect(.degrees(minuteAngle))

            Circle()
                .fill(accent)
                .frame(width: 2.8, height: 2.8)
                .scaleEffect(centerScale)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.52)) {
                    ringTrim = 1.0
                    centerScale = 1.0
                }
                withAnimation(.interpolatingSpring(stiffness: 185, damping: 13)) {
                    minuteAngle = 0
                    hourAngle = 105
                }
            }
        }
    }
}

/// 提前提醒：铃铛主体与底座铃锤拆分，带阻尼摇摆振铃与瞬态声波微弧
private struct RingingBellIcon: View {
    let accent: Color

    @State private var bellTilt: Double = 0
    @State private var clapperShift: CGFloat = 0
    @State private var waveOpacity: Double = 0

    var body: some View {
        ZStack {
            BellWavePair()
                .stroke(accent.opacity(waveOpacity), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
                .frame(width: 20, height: 9.5)
                .offset(y: -1.2)

            BellDomeOutline()
                .stroke(accent, style: StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round))
                .frame(width: 13.5, height: 12.8)
                .offset(y: -1.2)
                .rotationEffect(.degrees(bellTilt), anchor: UnitPoint(x: 0.5, y: 0.12))

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(accent)
                .frame(width: 3.8, height: 2.1)
                .offset(x: clapperShift, y: 6.6)
        }
        .onAppear {
            runDampedRingSequence()
        }
    }

    private func runDampedRingSequence() {
        let keyframes: [(delay: Double, dur: Double, tilt: Double, shift: CGFloat, wave: Double)] = [
            (0.06, 0.09, 17, -1.6, 0.65),
            (0.15, 0.11, -14, 1.4, 0.45),
            (0.26, 0.10, 8, -0.8, 0.18),
            (0.36, 0.10, -4, 0.4, 0.0),
            (0.46, 0.11, 0, 0.0, 0.0)
        ]
        for kf in keyframes {
            DispatchQueue.main.asyncAfter(deadline: .now() + kf.delay) {
                withAnimation(.easeInOut(duration: kf.dur)) {
                    bellTilt = kf.tilt
                    clapperShift = kf.shift
                    waveOpacity = kf.wave
                }
            }
        }
    }
}

private struct BellDomeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.16))
        p.move(to: CGPoint(x: w * 0.18, y: h * 0.62))
        p.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.16),
            control1: CGPoint(x: w * 0.18, y: h * 0.30),
            control2: CGPoint(x: w * 0.32, y: h * 0.16)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.62),
            control1: CGPoint(x: w * 0.68, y: h * 0.16),
            control2: CGPoint(x: w * 0.82, y: h * 0.30)
        )
        p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.84))
        p.addLine(to: CGPoint(x: w * 0.04, y: h * 0.84))
        p.closeSubpath()
        return p
    }
}

private struct BellWavePair: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let radius = rect.height * 0.56
        p.addArc(
            center: CGPoint(x: rect.minX + 2.4, y: rect.midY),
            radius: radius,
            startAngle: .degrees(135),
            endAngle: .degrees(225),
            clockwise: false
        )
        p.addArc(
            center: CGPoint(x: rect.maxX - 2.4, y: rect.midY),
            radius: radius,
            startAngle: .degrees(-45),
            endAngle: .degrees(45),
            clockwise: false
        )
        return p
    }
}

/// 共享的倒数紧缩微弧外框（用于休息前咖啡杯与强上限警示）
private struct CountdownRingWrapper<Content: View>: View {
    let accent: Color
    let progress: Double
    var trackOpacity: Double = 0.18
    @ViewBuilder let content: Content

    var body: some View {
        let clamped = min(1.0, max(0.0, progress))
        ZStack {
            Circle()
                .stroke(accent.opacity(trackOpacity), lineWidth: 1.45)
                .frame(width: 20.5, height: 20.5)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(accent, style: StrokeStyle(lineWidth: 1.55, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 20.5, height: 20.5)
                .animation(.easeInOut(duration: 0.4), value: clamped)

            content
        }
    }
}

/// 休息前倒数：外圈随秒数平滑收紧的微弧 + 中央热气袅袅上升的茶杯
private struct SteamingBreakCupIcon: View {
    let accent: Color
    let progress: Double

    @State private var steamPhase = false

    var body: some View {
        CountdownRingWrapper(accent: accent, progress: progress) {
            HStack(spacing: 2.6) {
                Capsule().frame(width: 1.3, height: 3.2)
                Capsule().frame(width: 1.3, height: 2.7)
            }
            .foregroundColor(accent.opacity(steamPhase ? 0.15 : 0.80))
            .offset(x: -0.7, y: steamPhase ? -5.8 : -3.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    steamPhase = true
                }
            }

            MiniCupOutline()
                .stroke(accent, style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))
                .frame(width: 11, height: 8)
                .offset(x: -0.3, y: 2.3)
        }
    }
}

private struct MiniCupOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 0, y: h * 0.56))
        p.addQuadCurve(to: CGPoint(x: w * 0.36, y: h), control: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: w * 0.44, y: h))
        p.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.56), control: CGPoint(x: w * 0.76, y: h))
        p.addLine(to: CGPoint(x: w * 0.76, y: 0))
        p.closeSubpath()
        p.move(to: CGPoint(x: w * 0.78, y: h * 0.16))
        p.addCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.64),
            control1: CGPoint(x: w * 1.08, y: h * 0.16),
            control2: CGPoint(x: w * 1.08, y: h * 0.64)
        )
        return p
    }
}

/// 延迟硬上限强制休息倒数：紧缩警示圆环 + 弹性感叹号
private struct WarningCountdownIcon: View {
    let accent: Color
    let progress: Double

    @State private var popScale: CGFloat = 0.75

    var body: some View {
        CountdownRingWrapper(accent: accent, progress: progress, trackOpacity: 0.20) {
            VStack(spacing: 1.8) {
                Capsule().frame(width: 1.8, height: 6.4)
                Circle().frame(width: 2.0, height: 2.0)
            }
            .foregroundColor(accent)
            .scaleEffect(popScale)
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 260, damping: 12)) {
                    popScale = 1.0
                }
            }
        }
    }
}
