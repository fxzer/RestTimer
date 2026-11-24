import SwiftUI

extension BreakGradientTheme {
    var palette: (baseTop: Color, baseBottom: Color, orb1: Color, orb2: Color, accent: Color) {
        switch self {
        case .celadonEyeCare, .autoDayNight:
            // 柔和护眼：豆沙绿 / 莫兰迪鼠尾草绿（低对比度、零蓝光刺激、缩小与白底插图的明暗落差）
            return (
                Color(red: 0.23, green: 0.35, blue: 0.28),
                Color(red: 0.30, green: 0.43, blue: 0.35),
                Color(red: 0.48, green: 0.68, blue: 0.54),
                Color(red: 0.38, green: 0.58, blue: 0.49),
                Color(red: 0.72, green: 0.94, blue: 0.78)
            )
        case .warmPaper:
            // 柔和护眼：暖羊皮 / 亚麻燕麦棕（墨水屏暖光质感，温润松弛）
            return (
                Color(red: 0.34, green: 0.29, blue: 0.24),
                Color(red: 0.41, green: 0.35, blue: 0.29),
                Color(red: 0.65, green: 0.54, blue: 0.42),
                Color(red: 0.55, green: 0.44, blue: 0.35),
                Color(red: 0.96, green: 0.84, blue: 0.68)
            )
        case .mistyTeal:
            // 柔和护眼：晨雾蓝 / 远山莫兰迪灰青（舒缓睫状肌）
            return (
                Color(red: 0.22, green: 0.32, blue: 0.37),
                Color(red: 0.28, green: 0.39, blue: 0.44),
                Color(red: 0.44, green: 0.62, blue: 0.67),
                Color(red: 0.38, green: 0.52, blue: 0.61),
                Color(red: 0.72, green: 0.90, blue: 0.96)
            )
        case .forestMoss:
            // 深邃自然：森林松针绿
            return (
                Color(red: 0.05, green: 0.13, blue: 0.12),
                Color(red: 0.08, green: 0.20, blue: 0.16),
                Color(red: 0.16, green: 0.55, blue: 0.38),
                Color(red: 0.12, green: 0.42, blue: 0.45),
                Color(red: 0.35, green: 0.88, blue: 0.65)
            )
        case .auroraOcean:
            // 深邃静谧：深海午夜蓝
            return (
                Color(red: 0.04, green: 0.08, blue: 0.18),
                Color(red: 0.06, green: 0.14, blue: 0.24),
                Color(red: 0.00, green: 0.62, blue: 0.72),
                Color(red: 0.26, green: 0.22, blue: 0.68),
                Color.cyan
            )
        case .sunsetAmber:
            // 深邃晚霞：暮光暖珀紫
            return (
                Color(red: 0.12, green: 0.07, blue: 0.16),
                Color(red: 0.20, green: 0.10, blue: 0.18),
                Color(red: 0.78, green: 0.34, blue: 0.22),
                Color(red: 0.56, green: 0.18, blue: 0.42),
                Color(red: 0.98, green: 0.64, blue: 0.32)
            )
        }
    }
}

/// 极简大尺寸办公室拉伸动作展示舞台（锁定 255×340 严格 3:4 比例，悬浮时左右两侧浮现半透明圆形轮播切换按钮）
struct BreakExerciseHeroView: View {
    let exercise: StretchExercise
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var isHoveringStage = false
    @State private var isHoveringPrev = false
    @State private var isHoveringNext = false

    var body: some View {
        ZStack {
            // 中央 255×340 3:4 插图
            switch exercise.visual {
            case .fitgateIllustration(let assetName):
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 255, height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
                    .id(assetName)
                    .transition(.opacity)
            }

            // 左右两侧悬浮清爽半透明圆形轮播切换按钮（零黑底掺杂，纯粹半透明白，小巧简约）
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
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isHoveringButton.wrappedValue ? 0.24 : 0.11))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isHoveringButton.wrappedValue ? 0.45 : 0.22), lineWidth: 0.8)
                    )

                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(isHoveringButton.wrappedValue ? 0.98 : 0.82))
            }
            .frame(width: 32, height: 32)
            .scaleEffect(isHoveringButton.wrappedValue ? 1.06 : 1.0)
            .animation(.easeOut(duration: 0.14), value: isHoveringButton.wrappedValue)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { hovering in
            isHoveringButton.wrappedValue = hovering
        }
    }
}

/// 流体极光弥散渐变背景
struct AuroraMeshBackgroundView: View {
    let theme: BreakGradientTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let p = theme.palette

                ZStack {
                    LinearGradient(
                        colors: [p.baseTop, p.baseBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(p.orb1.opacity(0.45))
                        .frame(width: min(w, h) * 0.65, height: min(w, h) * 0.65)
                        .blur(radius: 95)
                        .offset(
                            x: CGFloat(sin(t * 0.35)) * w * 0.22 - w * 0.15,
                            y: CGFloat(cos(t * 0.28)) * h * 0.18 - h * 0.12
                        )

                    Circle()
                        .fill(p.orb2.opacity(0.38))
                        .frame(width: min(w, h) * 0.58, height: min(w, h) * 0.58)
                        .blur(radius: 105)
                        .offset(
                            x: CGFloat(cos(t * 0.31)) * w * 0.24 + w * 0.18,
                            y: CGFloat(sin(t * 0.24)) * h * 0.20 + h * 0.14
                        )
                }
            }
        }
    }
}

/// 设置页矩形可视化主题预览卡片（直接渲染该主题真实渐变底色、弥散光斑、护眼标记与微缩预览）
struct BreakThemePreviewCardView: View {
    let theme: BreakGradientTheme
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let p = theme.palette
        Button(action: action) {
            ZStack {
                // 1. 真实主题渐变与柔光缩略背景
                LinearGradient(
                    colors: [p.baseTop, p.baseBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(p.orb1.opacity(0.55))
                    .frame(width: 54, height: 54)
                    .blur(radius: 14)
                    .offset(x: -22, y: -12)

                Circle()
                    .fill(p.orb2.opacity(0.48))
                    .frame(width: 48, height: 48)
                    .blur(radius: 14)
                    .offset(x: 24, y: 12)

                // 2. 极简卡片前景：顶部微缩时间 + 选中勾，底部主题名
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text("05:00")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.90))
                            .monospacedDigit()

                        Spacer(minLength: 2)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    Spacer(minLength: 4)

                    Text(theme.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.accentColor
                            : Color.white.opacity(isHovering ? 0.45 : 0.16),
                        lineWidth: isSelected ? 2.0 : 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovering ? 0.18 : 0.08),
                radius: isHovering ? 5 : 2,
                x: 0,
                y: 2
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
