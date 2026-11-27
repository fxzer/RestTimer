import SwiftUI

/// 主题渐变与流体光团视觉规格（单一数据源，统一驱动全屏流体背景与设置页缩略图）
struct BreakThemeVisualSpec {
    let baseTop: Color
    let baseBottom: Color
    let orb1: Color
    let orb2: Color
    let orb3: Color
    let accent: Color
    let orbOpacities: (primary: Double, secondary: Double, tertiary: Double)
}

extension BreakGradientTheme {
    var visualSpec: BreakThemeVisualSpec {
        switch self {
        case .frostedGlass, .autoDayNight:
            // 极淡静音系：真实桌面毛玻璃（保持原样不变，透出底层模糊桌面）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.24, green: 0.26, blue: 0.29),
                baseBottom: Color(red: 0.16, green: 0.18, blue: 0.21),
                orb1: Color(white: 0.80),
                orb2: Color(white: 0.62),
                orb3: Color(white: 0.70),
                accent: Color(white: 0.90),
                orbOpacities: (0.0, 0.0, 0.0)
            )
        case .graphiteMist:
            // 极淡静音系：液态石墨丝绸（冷钛银 + 暖烟灰双色调微光流转，不染强色相但富有金属织物光泽）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.11, green: 0.12, blue: 0.14),
                baseBottom: Color(red: 0.17, green: 0.18, blue: 0.20),
                orb1: Color(red: 0.44, green: 0.49, blue: 0.56),
                orb2: Color(red: 0.42, green: 0.39, blue: 0.36),
                orb3: Color(red: 0.28, green: 0.31, blue: 0.36),
                accent: Color(red: 0.86, green: 0.88, blue: 0.91),
                orbOpacities: (0.34, 0.28, 0.24)
            )
        case .slateIce:
            // 静音冷调系：冰岩蓝（Tailwind Slate/Sky 极客冷板岩蓝灰，沉静清澈）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.06, green: 0.09, blue: 0.14),
                baseBottom: Color(red: 0.10, green: 0.14, blue: 0.21),
                orb1: Color(red: 0.36, green: 0.56, blue: 0.76),
                orb2: Color(red: 0.42, green: 0.49, blue: 0.62),
                orb3: Color(red: 0.33, green: 0.43, blue: 0.66),
                accent: Color(red: 0.68, green: 0.84, blue: 0.96),
                orbOpacities: (0.36, 0.30, 0.24)
            )
        case .midnightViolet:
            // 极淡静音系：夜幕紫（烟熏薰衣草紫 + 月夜雾蓝，静谧护眼不刺目）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.11, green: 0.11, blue: 0.16),
                baseBottom: Color(red: 0.16, green: 0.14, blue: 0.22),
                orb1: Color(red: 0.46, green: 0.38, blue: 0.68),
                orb2: Color(red: 0.30, green: 0.44, blue: 0.64),
                orb3: Color(red: 0.52, green: 0.35, blue: 0.54),
                accent: Color(red: 0.78, green: 0.75, blue: 0.94),
                orbOpacities: (0.38, 0.32, 0.24)
            )
        case .celadonEyeCare:
            // 柔和护眼系：豆沙青瓷（苍翠青玉 + 远雾湖绿 + 淡苔橄榄，温润有呼吸感）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.17, green: 0.25, blue: 0.21),
                baseBottom: Color(red: 0.24, green: 0.34, blue: 0.28),
                orb1: Color(red: 0.44, green: 0.64, blue: 0.50),
                orb2: Color(red: 0.32, green: 0.54, blue: 0.52),
                orb3: Color(red: 0.52, green: 0.62, blue: 0.45),
                accent: Color(red: 0.74, green: 0.91, blue: 0.80),
                orbOpacities: (0.36, 0.30, 0.22)
            )
        case .warmPaper:
            // 柔和护眼系：暖羊皮（柔麦金 + 淡赤陶 + 亚麻鼠尾草，纸墨温润层次）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.23, green: 0.20, blue: 0.17),
                baseBottom: Color(red: 0.31, green: 0.26, blue: 0.22),
                orb1: Color(red: 0.64, green: 0.52, blue: 0.39),
                orb2: Color(red: 0.56, green: 0.40, blue: 0.34),
                orb3: Color(red: 0.45, green: 0.46, blue: 0.37),
                accent: Color(red: 0.94, green: 0.83, blue: 0.69),
                orbOpacities: (0.36, 0.30, 0.22)
            )
        case .amberGlow:
            // 柔和护眼系：琥珀金（Tailwind Amber/Stone 低蓝光暖烛暗金，夜间护眼松弛）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.14, green: 0.10, blue: 0.06),
                baseBottom: Color(red: 0.20, green: 0.14, blue: 0.08),
                orb1: Color(red: 0.78, green: 0.54, blue: 0.20),
                orb2: Color(red: 0.64, green: 0.36, blue: 0.16),
                orb3: Color(red: 0.72, green: 0.58, blue: 0.28),
                accent: Color(red: 0.96, green: 0.78, blue: 0.44),
                orbOpacities: (0.38, 0.31, 0.23)
            )
        case .mistyTeal:
            // 柔和护眼系：晨雾蓝（清冽湖青 + 烟紫暮蓝 + 浅海沫，舒缓视野）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.15, green: 0.23, blue: 0.28),
                baseBottom: Color(red: 0.22, green: 0.31, blue: 0.37),
                orb1: Color(red: 0.39, green: 0.62, blue: 0.69),
                orb2: Color(red: 0.36, green: 0.45, blue: 0.64),
                orb3: Color(red: 0.46, green: 0.62, blue: 0.59),
                accent: Color(red: 0.74, green: 0.89, blue: 0.95),
                orbOpacities: (0.36, 0.30, 0.22)
            )
        case .forestMoss:
            // 静谧深色系：森林绿（深松翠绿 + 峡湾幽蓝 + 林间苔影，克制去荧光）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.05, green: 0.11, blue: 0.10),
                baseBottom: Color(red: 0.09, green: 0.17, blue: 0.14),
                orb1: Color(red: 0.16, green: 0.52, blue: 0.38),
                orb2: Color(red: 0.12, green: 0.42, blue: 0.50),
                orb3: Color(red: 0.28, green: 0.46, blue: 0.30),
                accent: Color(red: 0.46, green: 0.84, blue: 0.66),
                orbOpacities: (0.42, 0.35, 0.26)
            )
        case .auroraOcean:
            // 静谧深色系：深海蓝（丝绒海青 + 暮夜群青 + 午夜钴蓝，恢复冷调层次但去刺眼霓虹）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.05, green: 0.08, blue: 0.15),
                baseBottom: Color(red: 0.08, green: 0.13, blue: 0.23),
                orb1: Color(red: 0.08, green: 0.54, blue: 0.66),
                orb2: Color(red: 0.26, green: 0.25, blue: 0.62),
                orb3: Color(red: 0.12, green: 0.36, blue: 0.58),
                accent: Color(red: 0.52, green: 0.85, blue: 0.95),
                orbOpacities: (0.42, 0.36, 0.26)
            )
        case .sunsetAmber:
            // 静谧深色系：暮光霞（落日赤珀 + 深梅暮紫 + 玫瑰金霞，柔暖浪漫而不刺目）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.12, green: 0.08, blue: 0.15),
                baseBottom: Color(red: 0.19, green: 0.11, blue: 0.18),
                orb1: Color(red: 0.68, green: 0.33, blue: 0.25),
                orb2: Color(red: 0.49, green: 0.22, blue: 0.45),
                orb3: Color(red: 0.68, green: 0.46, blue: 0.31),
                accent: Color(red: 0.94, green: 0.66, blue: 0.48),
                orbOpacities: (0.40, 0.34, 0.25)
            )
        case .smokyRose:
            // 静谧深色系：烟玫瑰（Tailwind Rose/Pink 低饱和烟熏绯粉 + 柔梅暮雾）
            return BreakThemeVisualSpec(
                baseTop: Color(red: 0.15, green: 0.08, blue: 0.12),
                baseBottom: Color(red: 0.21, green: 0.11, blue: 0.16),
                orb1: Color(red: 0.72, green: 0.35, blue: 0.46),
                orb2: Color(red: 0.54, green: 0.28, blue: 0.48),
                orb3: Color(red: 0.74, green: 0.46, blue: 0.50),
                accent: Color(red: 0.96, green: 0.72, blue: 0.79),
                orbOpacities: (0.38, 0.32, 0.24)
            )
        }
    }

    var palette: (baseTop: Color, baseBottom: Color, orb1: Color, orb2: Color, accent: Color) {
        let s = visualSpec
        return (s.baseTop, s.baseBottom, s.orb1, s.orb2, s.accent)
    }
}

/// 插图内存降采样硬件解码器与极简受限缓存（将 1792×2400 原图在内存中按目标 255×340 @2x 降采样，单张位图占用由 17.2MB 骤降至 1.38MB）
final class ExerciseImageLoader {
    static let shared = ExerciseImageLoader()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 8 // 最多缓存 8 张（支持多张并排 3 卡预览与单张大图缓存复用）
        cache.totalCostLimit = 12 * 1024 * 1024 // 上限 12MB
    }

    /// 针对 Retina 2x 屏幕，将 255×340 pt 解码为 510×680 像素
    func loadThumbnail(named assetName: String, targetPixelWidth: Int = 510, targetPixelHeight: Int = 680) -> NSImage? {
        let key = assetName as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let sourceImage = NSImage(named: assetName) else {
            return nil
        }

        var proposedRect = NSRect(
            x: 0,
            y: 0,
            width: CGFloat(targetPixelWidth) / 2.0,
            height: CGFloat(targetPixelHeight) / 2.0
        )
        guard let cgImage = sourceImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return sourceImage
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: targetPixelWidth,
            height: targetPixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetPixelWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return sourceImage
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetPixelWidth, height: targetPixelHeight))
        guard let downsampledCG = context.makeImage() else {
            return sourceImage
        }

        let logicalSize = NSSize(
            width: CGFloat(targetPixelWidth) / 2.0,
            height: CGFloat(targetPixelHeight) / 2.0
        )
        let resultImage = NSImage(cgImage: downsampledCG, size: logicalSize)

        // 从 AppKit 命名图片池解绑，防止 17.2MB 原始大图永久常驻系统缓存
        sourceImage.setName(nil)

        // 存入受限缩略图缓存，单张 cost 约为 510 * 680 * 4 ≈ 1.38MB
        let cost = targetPixelWidth * targetPixelHeight * 4
        cache.setObject(resultImage, forKey: key, cost: cost)

        return resultImage
    }

    /// 休息结束窗口关闭时主动清空全部解码图片缓存
    func purge() {
        cache.removeAllObjects()
    }
}

/// 极简大尺寸办公室拉伸动作展示舞台（锁定 255×340 严格 3:4 比例，悬浮时左右浮现清爽半透明切换钮）
struct BreakExerciseHeroView: View {
    let exercise: StretchExercise
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var isHoveringStage = false
    @State private var isHoveringCard = false
    @State private var isHoveringPrev = false
    @State private var isHoveringNext = false

    var body: some View {
        ZStack {
            // 中央 255×340 3:4 插图（降采样加载，仅 Hover 图片卡片时在底部浮现动作说明层）
            ZStack(alignment: .bottom) {
                switch exercise.visual {
                case .fitgateIllustration(let assetName):
                    let thumbnail = ExerciseImageLoader.shared.loadThumbnail(named: assetName)
                    (thumbnail != nil ? Image(nsImage: thumbnail!) : Image(assetName))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 255, height: 340)
                        .id(assetName)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }

                if isHoveringCard, !exercise.steps.isEmpty {
                    ExerciseStepsOverlay(steps: exercise.steps)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(width: 255, height: 340)
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(
                color: Color.black.opacity(0.24),
                radius: 20,
                x: 0,
                y: 10
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHoveringCard = hovering
                }
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
        return Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(hovered ? 0.22 : 0.10))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(hovered ? 0.42 : 0.20), lineWidth: 0.8)
                    )

                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(hovered ? 0.90 : 0.72))
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

/// 高斯平滑衰减流体光团（纯径向渐变拟合，零离屏模糊缓冲开销，支持椭圆拉伸与旋转呼吸）
private struct AuroraLobeView: View {
    let color: Color
    let opacity: Double
    let diameter: CGFloat
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    var rotationDegrees: Double = 0.0
    var offsetX: CGFloat = 0.0
    var offsetY: CGFloat = 0.0

    var body: some View {
        let safeDiameter = max(1.0, diameter)
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: color.opacity(opacity), location: 0.0),
                        .init(color: color.opacity(opacity * 0.68), location: 0.24),
                        .init(color: color.opacity(opacity * 0.28), location: 0.52),
                        .init(color: color.opacity(opacity * 0.07), location: 0.78),
                        .init(color: color.opacity(0.0), location: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: safeDiameter * 0.5
                )
            )
            .frame(width: safeDiameter, height: safeDiameter)
            .scaleEffect(x: scaleX, y: scaleY)
            .rotationEffect(.degrees(rotationDegrees))
            .offset(x: offsetX, y: offsetY)
    }
}

/// 流体极光背景视图：毛玻璃主题保持实时桌面透出不变，其余 8 款主题以 24fps 三光团椭圆交错慢流
struct AuroraMeshBackgroundView: View {
    let theme: BreakGradientTheme

    var body: some View {
        if theme.isFrostedDesktop {
            // 透出 BreakWindowManager 底层 NSVisualEffectView 实时模糊桌面，仅覆极轻柔暗雾
            LinearGradient(
                colors: [Color(white: 0.10).opacity(0.24), Color(white: 0.06).opacity(0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            let spec = theme.visualSpec
            // 24fps 角落散射流光：光团锚定四角向画布内侧大幅扫掠（22 到 30 秒周期），避免全屏糊成一团在中央原地呼吸
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let minSpan = max(1.0, min(w, h))

                    ZStack {
                        LinearGradient(
                            colors: [spec.baseTop, spec.baseBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        // 左上角散射主光晕：从左上角外缘沿对角向中右扫掠
                        AuroraLobeView(
                            color: spec.orb1,
                            opacity: spec.orbOpacities.primary,
                            diameter: minSpan * 0.86,
                            scaleX: 1.36 + 0.12 * sin(t * 0.24),
                            scaleY: 0.88 + 0.08 * cos(t * 0.20),
                            rotationDegrees: sin(t * 0.18) * 28.0 - 24.0,
                            offsetX: CGFloat(sin(t * 0.28)) * w * 0.24 - w * 0.24,
                            offsetY: CGFloat(cos(t * 0.23)) * h * 0.22 - h * 0.22
                        )

                        // 右下角散射副光晕：从右下角外缘逆向扫向中左
                        AuroraLobeView(
                            color: spec.orb2,
                            opacity: spec.orbOpacities.secondary,
                            diameter: minSpan * 0.80,
                            scaleX: 1.30 + 0.10 * cos(t * 0.22),
                            scaleY: 0.90 + 0.08 * sin(t * 0.19),
                            rotationDegrees: cos(t * 0.16) * 26.0 + 28.0,
                            offsetX: CGFloat(cos(t * 0.25)) * w * 0.24 + w * 0.24,
                            offsetY: CGFloat(sin(t * 0.21)) * h * 0.22 + h * 0.22
                        )

                        // 右上-左下对角游走辅光晕：沿副对角线跨越边缘提供第三层色深
                        AuroraLobeView(
                            color: spec.orb3,
                            opacity: spec.orbOpacities.tertiary,
                            diameter: minSpan * 0.68,
                            scaleX: 1.20 + 0.10 * sin(t * 0.17 + 1.1),
                            scaleY: 0.92 + 0.08 * cos(t * 0.15),
                            rotationDegrees: sin(t * 0.14 + 0.8) * 24.0 + 35.0,
                            offsetX: CGFloat(sin(t * 0.21 + 1.6)) * w * 0.28 + w * 0.12,
                            offsetY: CGFloat(cos(t * 0.24 + 0.9)) * h * 0.26 - h * 0.12
                        )
                    }
                    .clipped()
                }
            }
        }
    }
}

/// 设置页矩形可视化主题预览卡片（3×3 矩阵，背景层与文字层解耦防止光团撑高卡片导致文字裁切）
struct BreakThemePreviewCardView: View {
    let theme: BreakGradientTheme
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let spec = theme.visualSpec

        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Spacer(minLength: 2)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 14)

                Spacer(minLength: 2)

                Text(theme.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [spec.baseTop, spec.baseBottom],
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
                    } else {
                        AuroraLobeView(
                            color: spec.orb1,
                            opacity: min(0.52, spec.orbOpacities.primary * 1.25),
                            diameter: 68,
                            scaleX: 1.30,
                            scaleY: 0.90,
                            rotationDegrees: -20,
                            offsetX: -28,
                            offsetY: -15
                        )

                        AuroraLobeView(
                            color: spec.orb2,
                            opacity: min(0.46, spec.orbOpacities.secondary * 1.25),
                            diameter: 64,
                            scaleX: 1.24,
                            scaleY: 0.90,
                            rotationDegrees: 24,
                            offsetX: 30,
                            offsetY: 15
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.accentColor
                            : Color.white.opacity(isHovering ? 0.40 : 0.16),
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
