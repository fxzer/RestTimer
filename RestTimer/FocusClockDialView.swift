import SwiftUI
import AppKit

/// 极简 Apple 风格 60 分钟环形时钟表盘
struct FocusClockDialView: View {
    let workMinutes: Int
    let onWorkMinutesChanged: (Int) -> Void

    @State private var isDragging = false

    private let dialSize: CGFloat = 204
    private let ringRadius: CGFloat = 74
    private let trackLineWidth: CGFloat = 11
    private let majorHourMarks: [Int] = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]

    private var clampedWorkMinutes: Int {
        min(max(workMinutes, 1), 60)
    }

    private var workProgress: Double {
        Double(clampedWorkMinutes) / 60.0
    }


    private var primaryAccentColor: Color {
        Color.accentColor
    }

    var body: some View {
        ZStack {
            minuteTicksLayer
            clockNumbersLayer

            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: trackLineWidth)
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            Circle()
                .trim(from: 0, to: workProgress)
                .stroke(
                    primaryAccentColor,
                    style: StrokeStyle(lineWidth: trackLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            knobHandle
            centerReadout
        }
        .frame(width: dialSize, height: dialSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    updateMinutes(from: value.location)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: clampedWorkMinutes)
    }

    private var minuteTicksLayer: some View {
        ForEach(1...60, id: \.self) { minute in
            let isMajor = minute % 5 == 0
            let isReached = minute <= clampedWorkMinutes
            Capsule()
                .fill(
                    isReached
                        ? primaryAccentColor.opacity(isMajor ? 0.75 : 0.35)
                        : Color.secondary.opacity(isMajor ? 0.28 : 0.12)
                )
                .frame(width: isMajor ? 1.5 : 1.0, height: isMajor ? 5 : 2.5)
                .offset(y: -(ringRadius + 12))
                .rotationEffect(.degrees(Double(minute) * 6.0))
        }
    }

    private var clockNumbersLayer: some View {
        ForEach(majorHourMarks, id: \.self) { mark in
            let angleRad = (Double(mark) / 60.0 * 2.0 * .pi) - (.pi / 2.0)
            let labelRadius = ringRadius + 24
            let x = cos(angleRad) * labelRadius
            let y = sin(angleRad) * labelRadius
            let isSelected = mark == clampedWorkMinutes

            Button {
                onWorkMinutesChanged(mark)
            } label: {
                Text("\(mark)")
                    .font(.system(size: mark % 15 == 0 ? 11 : 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(
                        isSelected
                            ? primaryAccentColor
                            : (mark % 15 == 0 ? .primary.opacity(0.75) : .secondary.opacity(0.5))
                    )
                    .frame(width: 22, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: x, y: y)
        }
    }

    private var knobHandle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: isDragging ? 17 : 15, height: isDragging ? 17 : 15)
            .overlay(Circle().strokeBorder(primaryAccentColor, lineWidth: 3))
            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
            .modifier(ArcKnobOffset(progress: workProgress, radius: ringRadius))
    }

    private var centerReadout: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                if clampedWorkMinutes > 1 {
                    onWorkMinutesChanged(clampedWorkMinutes - 1)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)

            Text("\(clampedWorkMinutes)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
                .frame(minWidth: 46, alignment: .center)

            Button {
                if clampedWorkMinutes < 60 {
                    onWorkMinutesChanged(clampedWorkMinutes + 1)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
    }

    private func updateMinutes(from location: CGPoint) {
        let center = CGPoint(x: dialSize / 2.0, y: dialSize / 2.0)
        let dx = location.x - center.x
        let dy = location.y - center.y
        guard hypot(dx, dy) > 40 else { return }

        var angle = atan2(dy, dx) + (.pi / 2.0)
        if angle < 0 {
            angle += 2.0 * .pi
        }

        let rawMinutes = Int(round((angle / (2.0 * .pi)) * 60.0))
        let normalized = rawMinutes <= 0 ? 60 : min(60, rawMinutes)

        let fineTune = NSEvent.modifierFlags.contains(.option)
        let finalMinutes: Int
        if !fineTune {
            let nearestFive = max(5, min(60, Int(round(Double(normalized) / 5.0)) * 5))
            finalMinutes = abs(nearestFive - normalized) <= 1 ? nearestFive : normalized
        } else {
            finalMinutes = normalized
        }

        if finalMinutes != clampedWorkMinutes {
            onWorkMinutesChanged(finalMinutes)
        }
    }
}

/// 沿圆弧极坐标插值定位拖动手柄，确保点击跳转时跟随弧线与蓝色进度条末端同步运动而非直线斜穿表盘
struct ArcKnobOffset: ViewModifier, Animatable {
    var progress: Double
    let radius: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    static func point(progress: Double, radius: CGFloat) -> CGPoint {
        let angleRad = (progress * 2.0 * .pi) - (.pi / 2.0)
        return CGPoint(x: cos(angleRad) * radius, y: sin(angleRad) * radius)
    }

    func body(content: Content) -> some View {
        let pt = Self.point(progress: progress, radius: radius)
        content.offset(x: pt.x, y: pt.y)
    }
}
