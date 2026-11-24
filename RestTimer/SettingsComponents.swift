import SwiftUI
import AppKit

// MARK: - NexWan 风格设计 Token 与设置页共享辅助组件

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
