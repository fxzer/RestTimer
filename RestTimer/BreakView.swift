import SwiftUI
import Combine
import AppKit

/// 单轴对称沉浸休息视图：支持 9 款克制静音主题（含毛玻璃与浅色素宣白）、贝塞尔丝滑滑块与键鼠轮播
struct BreakView: View {
    @EnvironmentObject var timerManager: TimerManager
    @ObservedObject var session: BreakDisplaySession
    @Namespace private var themePillNamespace

    @State private var breathingIn = false
    @State private var hoveredTheme: BreakGradientTheme?

    private var totalBreakSeconds: Double { max(1.0, timerManager.breakDuration) }
    private var remainingSeconds: Double { max(0.0, timerManager.remainingBreakTime) }
    private var elapsedSeconds: Double { max(0.0, totalBreakSeconds - remainingSeconds) }
    private var overallProgress: Double { min(1.0, max(0.0, remainingSeconds / totalBreakSeconds)) }

    private var currentExercise: StretchExercise? {
        session.currentExercise(totalBreakSeconds: totalBreakSeconds, elapsedSeconds: elapsedSeconds)
    }

    private var currentCatalogPosition: Int {
        session.catalogPosition(for: currentExercise)
    }

    private var resolvedTheme: BreakGradientTheme { session.displayedTheme }
    private var themeAccentColor: Color { resolvedTheme.palette.accent }

    var body: some View {
        ZStack {
            // 1. 克制背景层（毛玻璃透出真实桌面 / 其余极缓低功耗流光）
            AuroraMeshBackgroundView(theme: resolvedTheme)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.36), value: resolvedTheme)

            // 2. 单一中轴对称布局
            VStack(spacing: 0) {
                topControlBar
                    .padding(.top, 34)

                Spacer(minLength: 24)

                centerHeroStage

                Spacer(minLength: 28)

                quoteSection
                    .padding(.bottom, 56)
            }
            .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breathingIn = true
            }
        }
    }

    // MARK: - 顶部丝滑滑动控制栏

    private var topControlBar: some View {
        HStack(spacing: 10) {
            Text(Date(), style: .time)
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.84))
                .monospacedDigit()

            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 1, height: 18)

            // 12 款主题滑动胶囊（全高 34pt 大热区 + 贝塞尔缓出滑块）
            HStack(spacing: 1) {
                ForEach(BreakGradientTheme.concreteThemes, id: \.self) { theme in
                    let isCurrent = resolvedTheme == theme
                    let isHovered = hoveredTheme == theme && !isCurrent
                    Button {
                        session.selectTheme(theme)
                        timerManager.settings.breakGradientTheme = theme
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.palette.orb1)
                                .frame(width: 7.5, height: 7.5)
                            Text(theme.displayName)
                                .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                        }
                        .foregroundColor(isCurrent ? .white : Color.white.opacity(isHovered ? 0.88 : 0.64))
                        .padding(.horizontal, 9)
                        .frame(height: 34)
                        .background {
                            if isCurrent {
                                Capsule()
                                    .fill(Color.white.opacity(0.22))
                                    .matchedGeometryEffect(id: "activeBreakThemePill", in: themePillNamespace)
                            } else if isHovered {
                                Capsule().fill(Color.white.opacity(0.10))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.14)) {
                            hoveredTheme = hovering ? theme : (hoveredTheme == theme ? nil : hoveredTheme)
                        }
                    }
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 1, height: 18)

            // 极简纯图标切换键：拉伸引导 ⇄ 静谧呼吸
            Button(action: toggleExerciseGuideMode) {
                Image(systemName: timerManager.settings.enableBreakExerciseGuide ? "figure.cooldown" : "wind")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.88))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(timerManager.settings.enableBreakExerciseGuide ? 0.20 : 0.09))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(timerManager.settings.enableBreakExerciseGuide ? "切换为静谧呼吸模式 (M)" : "切换为拉伸引导模式 (M)")

            if timerManager.isBreakPreview {
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 1, height: 18)

                Button {
                    timerManager.endBreakPreview()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                        Text("退出")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color.white.opacity(0.86))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .keyboardShortcut(.escape, modifiers: [])
            } else if timerManager.settings.showSkipButton {
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 1, height: 18)

                Button {
                    timerManager.skipBreak()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 13))
                        Text("跳过")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color.white.opacity(0.86))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.11))
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.5))
        )
    }

    // MARK: - 居中视觉核心舞台

    private var centerHeroStage: some View {
        VStack(spacing: 24) {
            if timerManager.settings.enableBreakExerciseGuide, let exercise = currentExercise {
                Button(action: toggleExerciseGuideMode) {
                    Text(remainingTimeText())
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("点击切换为静谧呼吸模式 (M)")

                BreakExerciseHeroView(
                    exercise: exercise,
                    onPrevious: previousExercise,
                    onNext: nextExercise
                )

                VStack(spacing: 14) {
                    Text(exercise.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
                        .id("title-\(exercise.id)")
                        .transition(.opacity)

                    HStack(spacing: 10) {
                        heroActionButton(
                            icon: exercise.category.symbolName,
                            text: exercise.badgeText,
                            help: "点击切换部位（颈部 ➔ 肩背 ➔ 手腕 ➔ 腰脊 ➔ 臀腿）",
                            action: jumpToNextCategory
                        )
                        heroActionButton(
                            icon: "arrow.triangle.2.circlepath",
                            text: "换一招 (\(currentCatalogPosition)/\(StretchRoutinePlanner.catalog.count))",
                            help: "切换下一招 (→ 或空格)",
                            action: nextExercise
                        )
                    }

                    VStack(spacing: 7) {
                        ForEach(exercise.steps, id: \.self) { step in
                            Text(step)
                                .font(.system(size: 19, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.90))
                                .multilineTextAlignment(.center)
                                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                        }
                    }
                    .frame(height: 56, alignment: .top)
                    .padding(.top, 2)
                    .id("steps-\(exercise.id)")
                    .transition(.opacity)
                }
            } else {
                // 纯静谧呼吸模式
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [themeAccentColor.opacity(breathingIn ? 0.22 : 0.05), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 210
                            )
                        )
                        .frame(width: 380, height: 380)
                        .scaleEffect(breathingIn ? 1.10 : 0.92)

                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 12)
                        .frame(width: 280, height: 280)

                    Circle()
                        .trim(from: 0, to: overallProgress)
                        .stroke(
                            AngularGradient(
                                colors: [themeAccentColor, Color.white.opacity(0.88), themeAccentColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 280, height: 280)

                    Button(action: toggleExerciseGuideMode) {
                        VStack(spacing: 10) {
                            Text(breathingIn ? "深吸气 · 4s" : "慢呼气 · 4s")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(themeAccentColor)
                            Text(remainingTimeText())
                                .font(.system(size: 74, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help("点击切换为拉伸引导模式 (M)")
                }
            }
        }
    }

    // MARK: - 底部优雅大字名言

    private var quoteSection: some View {
        Button {
            session.advanceQuote()
        } label: {
            VStack(spacing: 8) {
                Text("“ \(session.currentQuote.text) ”")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.90))
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.black.opacity(0.14), radius: 3, x: 0, y: 1)

                Text("—— \(session.currentQuote.author)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.62))
            }
            .frame(maxWidth: 760)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("点击切换下一条名言")
    }

    // MARK: - 会话动作转发（同步更新所有显示器）

    private func previousExercise() { stepCatalog(by: -1) }
    private func nextExercise() { stepCatalog(by: 1) }

    private func stepCatalog(by delta: Int) {
        session.stepCatalog(by: delta, totalBreakSeconds: totalBreakSeconds, elapsedSeconds: elapsedSeconds)
    }

    private func jumpToNextCategory() {
        session.jumpToNextCategory(totalBreakSeconds: totalBreakSeconds, elapsedSeconds: elapsedSeconds)
    }

    private func toggleExerciseGuideMode() {
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.34)) {
            timerManager.settings.enableBreakExerciseGuide.toggle()
        }
    }

    private func remainingTimeText() -> String {
        let total = Int(remainingSeconds)
        guard total > 0 else { return "00:00" }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func heroActionButton(icon: String, text: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(text)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(Color.white.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }
}
