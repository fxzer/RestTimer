import SwiftUI
import AppKit

// MARK: - NexWan 风格设计 Token 与辅助组件

enum SettingsTokens {
    static let windowWidth: CGFloat = 380
    static let tabContentHeight: CGFloat = 376
    static let windowHeight: CGFloat = 436

    static let cardCornerRadius: CGFloat = 12
    static let cornerRadius: CGFloat = 8
    static let stroke: CGFloat = 0.5

    static var activeTabFill: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            if match == .darkAqua {
                return NSColor.controlAccentColor.withAlphaComponent(0.18)
            } else {
                return NSColor.controlAccentColor.withAlphaComponent(0.24)
            }
        }))
    }

    static var cardFill: Color { Color.primary.opacity(0.04) }
    static var cardBorder: Color { Color.primary.opacity(0.08) }
    static var tabBarFill: Color { Color.primary.opacity(0.045) }
}

struct SettingsHairlineDivider: View {
    var horizontalPadding: CGFloat = 12
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, horizontalPadding)
    }
}

struct SettingsCardContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: SettingsTokens.cardCornerRadius, style: .continuous)
                .fill(SettingsTokens.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: SettingsTokens.cardCornerRadius, style: .continuous)
                        .stroke(SettingsTokens.cardBorder, lineWidth: SettingsTokens.stroke)
                }
        )
    }
}

/// 极简 Apple 风格 60 分钟环形时钟表盘
struct FocusClockDialView: View {
    let workMinutes: Int
    let earlyNotifyMinutes: Int
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

    private var earlyStartProgress: Double {
        guard earlyNotifyMinutes > 0, earlyNotifyMinutes < clampedWorkMinutes else {
            return workProgress
        }
        return Double(clampedWorkMinutes - earlyNotifyMinutes) / 60.0
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
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: earlyNotifyMinutes)
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
        let angleRad = (workProgress * 2.0 * .pi) - (.pi / 2.0)
        let knobX = cos(angleRad) * ringRadius
        let knobY = sin(angleRad) * ringRadius

        return Circle()
            .fill(Color.white)
            .frame(width: isDragging ? 17 : 15, height: isDragging ? 17 : 15)
            .overlay(Circle().strokeBorder(primaryAccentColor, lineWidth: 3))
            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
            .offset(x: knobX, y: knobY)
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

/// 快捷预设模型
struct TimePreset: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let workMinutes: Int
    let earlyMinutes: Int
    let breakSeconds: Int

    static let defaults: [TimePreset] = [
        TimePreset(id: "eyecare", symbol: "eye", title: "20分 护眼", workMinutes: 20, earlyMinutes: 1, breakSeconds: 60),
        TimePreset(id: "standard", symbol: "timer", title: "30分 标准", workMinutes: 30, earlyMinutes: 2, breakSeconds: 120),
        TimePreset(id: "deep", symbol: "figure.walk", title: "45分 深度", workMinutes: 45, earlyMinutes: 2, breakSeconds: 300)
    ]
}

/// 统一紧凑选项按钮（完全跟随系统主题色，无杂色边框，与顶部 Tab 视觉一致）
struct SettingsPillButton: View {
    let title: String
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            guard !isDisabled else { return }
            action()
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? SettingsTokens.activeTabFill : Color.primary.opacity(isDisabled ? 0.02 : 0.04))
                )
                .foregroundColor(
                    isDisabled
                        ? Color(nsColor: .tertiaryLabelColor)
                        : (isSelected ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
