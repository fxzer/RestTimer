import SwiftUI

extension BreakGradientTheme {
    var palette: (baseTop: Color, baseBottom: Color, orb1: Color, orb2: Color, accent: Color) {
        switch self {
        case .frostedGlass, .autoDayNight:
            // 极淡静音系：真实桌面毛玻璃（透出底层模糊桌面，零彩色光球，存在感最弱）
            return (
                Color(red: 0.24, green: 0.26, blue: 0.29),
                Color(red: 0.16, green: 0.18, blue: 0.21),
                Color(white: 0.80),
                Color(white: 0.62),
                Color(white: 0.90)
            )
        case .graphiteMist:
            // 极淡静音系：中性暖石墨灰雾面（无色相干扰、克制沉静）
            return (
                Color(red: 0.14, green: 0.15, blue: 0.16),
                Color(red: 0.18, green: 0.19, blue: 0.21),
                Color(red: 0.34, green: 0.36, blue: 0.39),
                Color(red: 0.28, green: 0.30, blue: 0.33),
                Color(white: 0.86)
            )
        case .warmIvory:
            // 极淡静音系：日间素宣白（浅米灰护眼底 + 深炭灰字，白底插图无缝融入，白天零明暗跳变）
            return (
                Color(red: 0.93, green: 0.92, blue: 0.90),
                Color(red: 0.89, green: 0.88, blue: 0.85),
                Color(red: 0.72, green: 0.70, blue: 0.66),
                Color(red: 0.82, green: 0.81, blue: 0.77),
                Color(red: 0.28, green: 0.42, blue: 0.35)
            )
        case .celadonEyeCare:
            // 柔和护眼系：淡豆沙绿（降饱和莫兰迪青灰绿）
            return (
                Color(red: 0.21, green: 0.28, blue: 0.24),
                Color(red: 0.25, green: 0.33, blue: 0.28),
                Color(red: 0.40, green: 0.52, blue: 0.44),
                Color(red: 0.33, green: 0.45, blue: 0.39),
                Color(red: 0.74, green: 0.88, blue: 0.78)
            )
        case .warmPaper:
            // 柔和护眼系：淡暖羊皮（低饱和亚麻灰棕）
            return (
                Color(red: 0.27, green: 0.24, blue: 0.21),
                Color(red: 0.32, green: 0.28, blue: 0.25),
                Color(red: 0.50, green: 0.43, blue: 0.36),
                Color(red: 0.43, green: 0.37, blue: 0.32),
                Color(red: 0.92, green: 0.82, blue: 0.70)
            )
        case .mistyTeal:
            // 柔和护眼系：淡晨雾蓝（远山莫兰迪灰青）
            return (
                Color(red: 0.19, green: 0.26, blue: 0.30),
                Color(red: 0.24, green: 0.31, blue: 0.35),
                Color(red: 0.37, green: 0.48, blue: 0.53),
                Color(red: 0.32, green: 0.42, blue: 0.48),
                Color(red: 0.74, green: 0.87, blue: 0.92)
            )
        case .forestMoss:
            // 静谧深色系：沉静暗松林（去高饱和荧光绿）
            return (
                Color(red: 0.08, green: 0.13, blue: 0.12),
                Color(red: 0.11, green: 0.17, blue: 0.15),
                Color(red: 0.18, green: 0.36, blue: 0.28),
                Color(red: 0.15, green: 0.30, blue: 0.32),
                Color(red: 0.50, green: 0.80, blue: 0.66)
            )
        case .auroraOcean:
            // 静谧深色系：沉静深海蓝（去高饱和青紫撞色）
            return (
                Color(red: 0.08, green: 0.11, blue: 0.17),
                Color(red: 0.11, green: 0.15, blue: 0.22),
                Color(red: 0.16, green: 0.34, blue: 0.44),
                Color(red: 0.22, green: 0.25, blue: 0.42),
                Color(red: 0.58, green: 0.82, blue: 0.92)
            )
        case .sunsetAmber:
            // 静谧深色系：沉静暗暮色（去高饱和亮橘紫）
            return (
                Color(red: 0.15, green: 0.11, blue: 0.16),
                Color(red: 0.20, green: 0.14, blue: 0.18),
                Color(red: 0.44, green: 0.26, blue: 0.24),
                Color(red: 0.34, green: 0.20, blue: 0.32),
                Color(red: 0.88, green: 0.66, blue: 0.52)
            )
        }
    }
}

/// 极简大尺寸办公室拉伸动作展示舞台（锁定 255×340 严格 3:4 比例，悬浮时左右浮现清爽半透明切换钮）
struct BreakExerciseHeroView: View {
    let exercise: StretchExercise
    let isLightTheme: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var isHoveringStage = false
    @State private var isHoveringPrev = false
    @State private var isHoveringNext = false

    var body: some View {
        ZStack {
            // 中央 255×340 3:4 插图（浅色主题下采用极淡柔影+细描边，深色主题下采用通透软影）
            switch exercise.visual {
            case .fitgateIllustration(let assetName):
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 255, height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(isLightTheme ? 0.06 : 0.0), lineWidth: 0.8)
                    )
                    .shadow(
                        color: Color.black.opacity(isLightTheme ? 0.08 : 0.24),
                        radius: isLightTheme ? 14 : 20,
                        x: 0,
                        y: isLightTheme ? 6 : 10
                    )
                    .id(assetName)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }

            // 左右两侧悬浮清爽半透明圆形轮播切换按钮
            HStack {
                carouselArrowButton(
                    systemName: "chevron.left",
                    isHoveringButton: $isHoveringPrev,
                    helpText: "上一招 (←)",
                    action: onPrevious
                )

                Spacer()

                carouselArrowButton(
                    systemName: "chevron.right",
                    isHoveringButton: $isHoveringNext,
                    helpText: "下一招 (→)",
                    action: onNext
                )
            }
            .padding(.horizontal, 2)
            .opacity(isHoveringStage ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.16), value: isHoveringStage)
        }
        .frame(width: 336, height: 340)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHoveringStage = hovering
        }
    }

    private func carouselArrowButton(
        systemName: String,
        isHoveringButton: Binding<Bool>,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        let hovered = isHoveringButton.wrappedValue
        let baseTint: Color = isLightTheme ? .black : .white
        return Button(action: action) {
            ZStack {
                Circle()
                    .fill(baseTint.opacity(isLightTheme ? (hovered ? 0.11 : 0.05) : (hovered ? 0.22 : 0.10)))
                    .overlay(
                        Circle()
                            .stroke(baseTint.opacity(isLightTheme ? (hovered ? 0.20 : 0.12) : (hovered ? 0.42 : 0.20)), lineWidth: 0.8)
                    )

                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(baseTint.opacity(hovered ? 0.90 : 0.72))
            }
            .frame(width: 32, height: 32)
            .scaleEffect(hovered ? 1.06 : 1.0)
            .animation(.easeOut(duration: 0.14), value: hovered)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(helpText)
        .onHover { hovering in
            isHoveringButton.wrappedValue = hovering
        }
    }
}

/// 低存在感克制背景视图：毛玻璃透出真实模糊桌面，素宣白采用静谧纸面，其余主题以 12fps 极缓 70 秒微光呼吸
struct AuroraMeshBackgroundView: View {
    let theme: BreakGradientTheme

    var body: some View {
        let p = theme.palette
        if theme.isFrostedDesktop {
            // 透出 BreakWindowManager 底层 NSVisualEffectView 实时模糊桌面，仅覆极轻柔暗雾
            LinearGradient(
                colors: [Color(white: 0.10).opacity(0.24), Color(white: 0.06).opacity(0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if theme.isStaticMinimal {
            // 素宣白：静态温润纸感底色，零动画零干扰
            LinearGradient(
                colors: [p.baseTop, p.baseBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // 克制微光呼吸：12fps 低功耗、70 秒级极慢微移、18%/15% 低透明大半径柔雾
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    ZStack {
                        LinearGradient(
                            colors: [p.baseTop, p.baseBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Circle()
                            .fill(p.orb1.opacity(0.18))
                            .frame(width: min(w, h) * 0.72, height: min(w, h) * 0.72)
                            .blur(radius: 155)
                            .offset(
                                x: CGFloat(sin(t * 0.09)) * w * 0.06 - w * 0.12,
                                y: CGFloat(cos(t * 0.07)) * h * 0.05 - h * 0.10
                            )

                        Circle()
                            .fill(p.orb2.opacity(0.15))
                            .frame(width: min(w, h) * 0.65, height: min(w, h) * 0.65)
                            .blur(radius: 165)
                            .offset(
                                x: CGFloat(cos(t * 0.08)) * w * 0.06 + w * 0.14,
                                y: CGFloat(sin(t * 0.06)) * h * 0.05 + h * 0.10
                            )
                    }
                }
            }
        }
    }
}

/// 设置页矩形可视化主题预览卡片（3×3 矩阵，自动适配素宣白浅底深字与毛玻璃质感）
struct BreakThemePreviewCardView: View {
    let theme: BreakGradientTheme
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let p = theme.palette
        let isLight = theme.isLightTheme
        let fg: Color = isLight ? Color(red: 0.18, green: 0.20, blue: 0.22) : .white

        Button(action: action) {
            ZStack {
                LinearGradient(
                    colors: [p.baseTop, p.baseBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if theme.isFrostedDesktop {
                    // 毛玻璃缩略卡：柔和半透斜向玻璃高光，直观区分实时桌面磨砂质感
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.white.opacity(0.03), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if !isLight {
                    Circle()
                        .fill(p.orb1.opacity(0.32))
                        .frame(width: 52, height: 52)
                        .blur(radius: 16)
                        .offset(x: -22, y: -12)

                    Circle()
                        .fill(p.orb2.opacity(0.28))
                        .frame(width: 46, height: 46)
                        .blur(radius: 16)
                        .offset(x: 24, y: 12)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text("05:00")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(fg.opacity(0.86))
                            .monospacedDigit()

                        Spacer(minLength: 2)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isLight ? Color.accentColor : .white)
                        }
                    }

                    Spacer(minLength: 2)

                    Text(theme.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(fg)
                        .shadow(color: isLight ? .clear : Color.black.opacity(0.20), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.accentColor
                            : (isLight ? Color.black.opacity(isHovering ? 0.22 : 0.12) : Color.white.opacity(isHovering ? 0.40 : 0.16)),
                        lineWidth: isSelected ? 2.0 : 0.8
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.14), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
