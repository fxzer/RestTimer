import SwiftUI
import Combine
import AppKit

/// 单轴对称沉浸休息视图：中轴聚焦时间与动作，左侧边缘 Hover 展开主题抽屉，四角放置低打扰控制键
struct BreakView: View {
    @EnvironmentObject var timerManager: TimerManager
    @ObservedObject var session: BreakDisplaySession

    @State private var breathingIn = false
    @State private var isHoveringTopRightAction = false
    @State private var isHoveringBottomControls = false
    @State private var isHoveringQuote = false

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
                Spacer(minLength: 32)

                centerHeroStage

                Spacer(minLength: 28)

                quoteSection
                    .padding(.bottom, 52)
            }
            .padding(.horizontal, 48)

            // 3. 左侧边缘 Hover 主题抽屉（默认仅留微弱竖条提示）
            BreakSideThemeDrawerView(
                selectedThemeSetting: $timerManager.settings.breakGradientTheme,
                displayedTheme: resolvedTheme,
                onSelectAutoRotation: { session.advanceAutoTheme() },
                onSelectTheme: { session.selectTheme($0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // 4. 右上角退出 / 跳过入口
            if timerManager.isBreakPreview || timerManager.settings.showSkipButton {
                topRightActionButton
                    .padding(.top, 28)
                    .padding(.trailing, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            // 5. 右下角模式与视图切换圆钮
            bottomRightModeControls
                .padding(.bottom, 28)
                .padding(.trailing, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breathingIn = true
            }
        }
    }

    // MARK: - 右上角退出 / 跳过

    @ViewBuilder
    private var topRightActionButton: some View {
        if timerManager.isBreakPreview {
            cornerActionCapsule(icon: "xmark.circle.fill", iconSize: 13.5, title: "退出") {
                timerManager.endBreakPreview()
            }
            .keyboardShortcut(.escape, modifiers: [])
        } else if timerManager.settings.showSkipButton {
            cornerActionCapsule(icon: "forward.end.fill", iconSize: 12.5, title: "跳过") {
                timerManager.skipBreak()
            }
        }
    }

    private func cornerActionCapsule(icon: String, iconSize: CGFloat, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(Color.white.opacity(isHoveringTopRightAction ? 0.94 : 0.66))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isHoveringTopRightAction ? 0.18 : 0.10))
                    .overlay(Capsule().stroke(Color.white.opacity(isHoveringTopRightAction ? 0.28 : 0.14), lineWidth: 0.5))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHoveringTopRightAction = hovering
            }
        }
    }

    // MARK: - 右下角模式切换双圆钮

    private var bottomRightModeControls: some View {
        HStack(spacing: 10) {
            if timerManager.settings.enableBreakExerciseGuide {
                let isMulti = timerManager.settings.breakExerciseMultiView
                cornerCircleButton(
                    icon: isMulti ? "rectangle.split.3x1.fill" : "rectangle.split.3x1",
                    iconSize: 14,
                    isActive: isMulti,
                    help: isMulti ? "切换为单张大图模式 (V)" : "切换为多张并排模式 (V)",
                    action: toggleExerciseMultiView
                )
            }

            cornerCircleButton(
                icon: timerManager.settings.enableBreakExerciseGuide ? "figure.cooldown" : "wind",
                iconSize: 14.5,
                isActive: timerManager.settings.enableBreakExerciseGuide,
                help: timerManager.settings.enableBreakExerciseGuide ? "切换为静谧呼吸模式 (M)" : "切换为拉伸引导模式 (M)",
                action: toggleExerciseGuideMode
            )
        }
        .opacity(isHoveringBottomControls ? 1.0 : 0.52)
        .animation(.easeOut(duration: 0.16), value: isHoveringBottomControls)
        .onHover { hovering in
            isHoveringBottomControls = hovering
        }
    }

    private func cornerCircleButton(icon: String, iconSize: CGFloat, isActive: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(Color.white.opacity(isHoveringBottomControls ? 0.94 : 0.72))
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isActive ? 0.20 : 0.11))
                        .overlay(Circle().stroke(Color.white.opacity(isHoveringBottomControls ? 0.28 : 0.14), lineWidth: 0.6))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }

    // MARK: - 居中视觉核心舞台

    private var centerHeroStage: some View {
        VStack(spacing: timerManager.settings.breakExerciseMultiView ? 18 : 22) {
            if timerManager.settings.enableBreakExerciseGuide, let exercise = currentExercise {
                if timerManager.settings.breakExerciseMultiView {
                    multiExerciseStage(activeExercise: exercise)
                } else {
                    timeAndCountdownHeader(countdownFontSize: 56)

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
                    }
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
                        VStack(spacing: 6) {
                            Text(breathingIn ? "深吸气 · 4s" : "慢呼气 · 4s")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(themeAccentColor)
                            Text(remainingTimeText())
                                .font(.system(size: 74, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            currentTimeLabel
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
            VStack(spacing: 6) {
                Text(session.currentQuote.text)
                    .font(.system(size: 21, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(isHoveringQuote ? 0.88 : 0.42))
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.black.opacity(isHoveringQuote ? 0.14 : 0.0), radius: 3, x: 0, y: 1)

                Text(session.currentQuote.author)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.68))
                    .opacity(isHoveringQuote ? 1.0 : 0.0)
            }
            .frame(maxWidth: 760)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.18), value: isHoveringQuote)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("点击切换下一条名言")
        .onHover { hovering in
            isHoveringQuote = hovering
        }
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

    private func toggleExerciseMultiView() {
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.28)) {
            timerManager.settings.breakExerciseMultiView.toggle()
        }
    }

    private func nextBatch() {
        stepCatalog(by: BreakDisplaySession.multiCardBatchCount)
    }

    private func selectBatchCard(_ exercise: StretchExercise) {
        session.selectExercise(exercise)
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.28)) {
            timerManager.settings.breakExerciseMultiView = false
        }
    }

    private func multiExerciseStage(activeExercise: StretchExercise) -> some View {
        let totalCatalog = StretchRoutinePlanner.catalog.count
        let batch = session.displayedBatch(
            totalBreakSeconds: totalBreakSeconds,
            elapsedSeconds: elapsedSeconds
        )
        return VStack(spacing: 18) {
            timeAndCountdownHeader(countdownFontSize: 48)

            HStack(alignment: .top, spacing: 18) {
                ForEach(batch) { item in
                    BreakExerciseBatchCard(
                        exercise: item,
                        positionText: "\(session.catalogPosition(for: item))/\(totalCatalog)",
                        isActive: item.id == activeExercise.id,
                        accentColor: themeAccentColor
                    ) {
                        selectBatchCard(item)
                    }
                }
            }

            HStack(spacing: 10) {
                heroActionButton(
                    icon: activeExercise.category.symbolName,
                    text: activeExercise.badgeText,
                    help: "点击切换部位（颈部 ➔ 肩背 ➔ 手腕 ➔ 腰脊 ➔ 臀腿）",
                    action: jumpToNextCategory
                )
                heroActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    text: "换一批 (\(session.batchProgressLabel(for: batch)))",
                    help: "同时切换下一组 \(BreakDisplaySession.multiCardBatchCount) 个动作 (→ 或空格)",
                    action: nextBatch
                )
            }
        }
    }

    private func timeAndCountdownHeader(countdownFontSize: CGFloat) -> some View {
        VStack(spacing: 4) {
            currentTimeLabel
            countdownToggleButton(fontSize: countdownFontSize)
        }
    }

    private var currentTimeLabel: some View {
        Text(Date(), style: .time)
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundColor(Color.white.opacity(0.66))
            .monospacedDigit()
    }

    private func countdownToggleButton(fontSize: CGFloat) -> some View {
        Button(action: toggleExerciseGuideMode) {
            Text(remainingTimeText())
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("点击切换为静谧呼吸模式 (M)")
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
