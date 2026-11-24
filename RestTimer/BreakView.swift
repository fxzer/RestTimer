import SwiftUI
import Combine
import AppKit

/// 单轴对称沉浸休息视图：支持 9 款克制静音主题（含毛玻璃与浅色素宣白）、贝塞尔丝滑滑块与键鼠轮播
struct BreakView: View {
    @EnvironmentObject var timerManager: TimerManager
    @Namespace private var themePillNamespace

    @State private var currentTime = Date()
    @State private var currentQuote: CuratedQuote = CuratedQuoteLibrary.all[0]
    @State private var catalogIndex: Int = 0
    @State private var hasManualSwitch = false
    @State private var routine: [StretchExercise] = []
    @State private var breathingIn = false
    @State private var keyEventMonitor: Any?
    @State private var hoveredTheme: BreakGradientTheme?
    @State private var escapeTapTimestamps: [TimeInterval] = []

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let breathTimer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()

    private static var recentExerciseIds: Set<String> = []
    private static var rotationThemeIndex: Int = 0
    @State private var displayedTheme: BreakGradientTheme = .frostedGlass

    private var totalBreakSeconds: Double { max(1.0, timerManager.breakDuration) }
    private var remainingSeconds: Double { max(0.0, timerManager.remainingBreakTime) }
    private var elapsedSeconds: Double { max(0.0, totalBreakSeconds - remainingSeconds) }
    private var overallProgress: Double { min(1.0, max(0.0, remainingSeconds / totalBreakSeconds)) }

    private var currentExercise: StretchExercise? {
        let all = StretchRoutinePlanner.catalog
        guard !all.isEmpty else { return nil }
        if hasManualSwitch {
            return all[(catalogIndex % all.count + all.count) % all.count]
        }
        guard !routine.isEmpty else { return all[0] }
        let slotDuration = totalBreakSeconds / Double(routine.count)
        let idx = slotDuration > 0 ? min(routine.count - 1, max(0, Int(elapsedSeconds / slotDuration))) : 0
        return routine[idx]
    }

    private var currentCatalogPosition: Int {
        guard let current = currentExercise,
              let idx = StretchRoutinePlanner.catalog.firstIndex(where: { $0.id == current.id }) else {
            return 1
        }
        return idx + 1
    }

    private var resolvedTheme: BreakGradientTheme { displayedTheme }
    private var isLight: Bool { resolvedTheme.isLightTheme }
    private var fgBase: Color { isLight ? Color(red: 0.14, green: 0.16, blue: 0.18) : .white }
    private var pillSurface: Color { isLight ? .black : .white }
    private var themeAccentColor: Color { resolvedTheme.palette.accent }

    var body: some View {
        ZStack {
            // 1. 克制背景层（毛玻璃透出真实桌面 / 素宣白静态纸面 / 其余极缓低功耗微雾）
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
            prepareBreakSession()
            installKeyboardShortcuts()
            withAnimation(.easeInOut(duration: 4.0)) {
                breathingIn = true
            }
        }
        .onDisappear {
            removeKeyboardShortcuts()
        }
        .onReceive(clockTimer) { input in
            currentTime = input
        }
        .onReceive(breathTimer) { _ in
            withAnimation(.easeInOut(duration: 3.8)) {
                breathingIn.toggle()
            }
        }
    }

    // MARK: - 顶部丝滑滑动控制栏

    private var topControlBar: some View {
        HStack(spacing: 10) {
            Text(currentTime.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundColor(fgBase.opacity(0.84))
                .monospacedDigit()

            Rectangle()
                .fill(fgBase.opacity(isLight ? 0.16 : 0.22))
                .frame(width: 1, height: 18)

            // 9 款主题滑动胶囊（全高 34pt 大热区 + 贝塞尔缓出滑块）
            HStack(spacing: 1) {
                ForEach(BreakGradientTheme.concreteThemes, id: \.self) { theme in
                    let isCurrent = resolvedTheme == theme
                    let isHovered = hoveredTheme == theme && !isCurrent
                    Button {
                        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.38)) {
                            displayedTheme = theme
                        }
                        timerManager.settings.breakGradientTheme = theme
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.palette.orb1)
                                .overlay(
                                    Circle().stroke(fgBase.opacity(theme.isLightTheme ? 0.22 : 0.0), lineWidth: 0.5)
                                )
                                .frame(width: 7.5, height: 7.5)
                            Text(theme.displayName)
                                .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                        }
                        .foregroundColor(isCurrent ? fgBase : fgBase.opacity(isHovered ? 0.88 : 0.64))
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background {
                            ZStack {
                                Capsule()
                                    .fill(pillSurface.opacity(isHovered ? (isLight ? 0.06 : 0.10) : 0.001))
                                if isCurrent {
                                    Capsule()
                                        .fill(pillSurface.opacity(isLight ? 0.11 : 0.22))
                                        .matchedGeometryEffect(id: "activeBreakThemePill", in: themePillNamespace)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.14)) {
                            if hovering {
                                hoveredTheme = theme
                            } else if hoveredTheme == theme {
                                hoveredTheme = nil
                            }
                        }
                    }
                }
            }

            Rectangle()
                .fill(fgBase.opacity(isLight ? 0.16 : 0.22))
                .frame(width: 1, height: 18)

            // 极简纯图标切换键：拉伸引导 ⇄ 静谧呼吸
            Button(action: toggleExerciseGuideMode) {
                Image(systemName: timerManager.settings.enableBreakExerciseGuide ? "figure.cooldown" : "wind")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(fgBase.opacity(0.88))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(pillSurface.opacity(timerManager.settings.enableBreakExerciseGuide ? (isLight ? 0.10 : 0.20) : (isLight ? 0.04 : 0.09)))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(timerManager.settings.enableBreakExerciseGuide ? "切换为静谧呼吸模式 (M)" : "切换为拉伸引导模式 (M)")

            if timerManager.isBreakPreview {
                Rectangle()
                    .fill(fgBase.opacity(isLight ? 0.16 : 0.22))
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
                    .foregroundColor(fgBase.opacity(0.86))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .keyboardShortcut(.escape, modifiers: [])
            } else if timerManager.settings.showSkipButton {
                Rectangle()
                    .fill(fgBase.opacity(isLight ? 0.16 : 0.22))
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
                    .foregroundColor(fgBase.opacity(0.86))
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
                .fill(pillSurface.opacity(isLight ? 0.06 : 0.11))
                .overlay(Capsule().stroke(pillSurface.opacity(isLight ? 0.10 : 0.16), lineWidth: 0.5))
        )
    }

    // MARK: - 居中视觉核心舞台

    private var centerHeroStage: some View {
        VStack(spacing: 24) {
            if timerManager.settings.enableBreakExerciseGuide, let exercise = currentExercise {
                Button(action: toggleExerciseGuideMode) {
                    Text(remainingTimeText())
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(fgBase)
                        .monospacedDigit()
                        .shadow(color: isLight ? .clear : Color.black.opacity(0.20), radius: 6, x: 0, y: 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("点击切换为静谧呼吸模式 (M)")

                BreakExerciseHeroView(
                    exercise: exercise,
                    isLightTheme: isLight,
                    onPrevious: previousExercise,
                    onNext: nextExercise
                )

                VStack(spacing: 14) {
                    Text(exercise.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(fgBase)
                        .shadow(color: isLight ? .clear : Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
                        .id("title-\(exercise.id)")
                        .transition(.opacity)

                    HStack(spacing: 10) {
                        Button(action: jumpToNextCategory) {
                            HStack(spacing: 5) {
                                Image(systemName: exercise.category.symbolName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(exercise.badgeText)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(fgBase.opacity(0.86))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(pillSurface.opacity(isLight ? 0.07 : 0.14)))
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help("点击切换部位（颈部 ➔ 肩背 ➔ 手腕 ➔ 腰脊 ➔ 臀腿）")

                        Button(action: nextExercise) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("换一招 (\(currentCatalogPosition)/\(StretchRoutinePlanner.catalog.count))")
                                    .font(.system(size: 13, weight: .medium))
                                    .monospacedDigit()
                            }
                            .foregroundColor(fgBase.opacity(0.88))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(pillSurface.opacity(isLight ? 0.08 : 0.16)))
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help("切换下一招 (→ 或空格)")
                    }

                    VStack(spacing: 7) {
                        ForEach(exercise.steps, id: \.self) { step in
                            Text(step)
                                .font(.system(size: 19, weight: .regular, design: .rounded))
                                .foregroundColor(fgBase.opacity(isLight ? 0.80 : 0.90))
                                .multilineTextAlignment(.center)
                                .shadow(color: isLight ? .clear : Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
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
                                colors: [themeAccentColor.opacity(breathingIn ? (isLight ? 0.16 : 0.22) : 0.05), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 210
                            )
                        )
                        .frame(width: 380, height: 380)
                        .scaleEffect(breathingIn ? 1.10 : 0.92)

                    Circle()
                        .stroke(fgBase.opacity(isLight ? 0.10 : 0.14), lineWidth: 12)
                        .frame(width: 280, height: 280)

                    Circle()
                        .trim(from: 0, to: overallProgress)
                        .stroke(
                            AngularGradient(
                                colors: [themeAccentColor, fgBase.opacity(0.88), themeAccentColor],
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
                                .foregroundColor(fgBase)
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
            withAnimation(.easeInOut(duration: 0.28)) {
                currentQuote = CuratedQuoteLibrary.nextQuote(excluding: currentQuote)
            }
        } label: {
            VStack(spacing: 8) {
                Text("“ \(currentQuote.text) ”")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundColor(fgBase.opacity(isLight ? 0.84 : 0.90))
                    .multilineTextAlignment(.center)
                    .shadow(color: isLight ? .clear : Color.black.opacity(0.14), radius: 3, x: 0, y: 1)

                Text("—— \(currentQuote.author)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(fgBase.opacity(isLight ? 0.54 : 0.62))
            }
            .frame(maxWidth: 760)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("点击切换下一条名言")
    }

    // MARK: - 会话编排与丝滑切换

    private func prepareBreakSession() {
        let themes = BreakGradientTheme.concreteThemes
        let setting = timerManager.settings.breakGradientTheme
        if setting == .autoDayNight {
            displayedTheme = themes[Self.rotationThemeIndex % themes.count]
            Self.rotationThemeIndex += 1
        } else {
            displayedTheme = setting
        }

        currentQuote = CuratedQuoteLibrary.nextQuote(excluding: currentQuote)
        hasManualSwitch = false
        let planned = StretchRoutinePlanner.planRoutine(
            forBreakSeconds: Int(totalBreakSeconds),
            excludingRecentIds: Self.recentExerciseIds
        )
        routine = planned
        if let first = planned.first,
           let idx = StretchRoutinePlanner.catalog.firstIndex(where: { $0.id == first.id }) {
            catalogIndex = idx
        }
        Self.recentExerciseIds = Set(planned.map(\.id))
    }

    private func previousExercise() {
        let all = StretchRoutinePlanner.catalog
        guard !all.isEmpty else { return }
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.22)) {
            if !hasManualSwitch,
               let current = currentExercise,
               let idx = all.firstIndex(where: { $0.id == current.id }) {
                catalogIndex = (idx - 1 + all.count) % all.count
                hasManualSwitch = true
            } else {
                catalogIndex = (catalogIndex - 1 + all.count) % all.count
            }
        }
    }

    private func nextExercise() {
        let all = StretchRoutinePlanner.catalog
        guard !all.isEmpty else { return }
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.22)) {
            if !hasManualSwitch,
               let current = currentExercise,
               let idx = all.firstIndex(where: { $0.id == current.id }) {
                catalogIndex = (idx + 1) % all.count
                hasManualSwitch = true
            } else {
                catalogIndex = (catalogIndex + 1) % all.count
            }
        }
    }

    private func jumpToNextCategory() {
        let all = StretchRoutinePlanner.catalog
        guard !all.isEmpty, let current = currentExercise else { return }
        let categories = StretchCategory.allCases
        guard let curCatIdx = categories.firstIndex(of: current.category) else { return }
        let nextCategory = categories[(curCatIdx + 1) % categories.count]
        if let firstIdx = all.firstIndex(where: { $0.category == nextCategory }) {
            withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.22)) {
                catalogIndex = firstIdx
                hasManualSwitch = true
            }
        }
    }

    private func toggleExerciseGuideMode() {
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.34)) {
            timerManager.settings.enableBreakExerciseGuide.toggle()
        }
    }

    private func installKeyboardShortcuts() {
        removeKeyboardShortcuts()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53: // Esc：预览态单按即退；正式休息态支持 ⌘⇧Esc 或 1.2 秒内连按 3 次 Esc 紧急逃生
                if timerManager.isBreakPreview {
                    timerManager.endBreakPreview()
                    return nil
                }
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if mods.contains([.command, .shift]) {
                    timerManager.emergencyExitBreak()
                    return nil
                }
                let now = Date().timeIntervalSince1970
                escapeTapTimestamps = escapeTapTimestamps.filter { now - $0 <= 1.2 } + [now]
                if escapeTapTimestamps.count >= 3 {
                    escapeTapTimestamps.removeAll()
                    timerManager.emergencyExitBreak()
                }
                return nil
            case 123:
                previousExercise()
                return nil
            case 124, 49:
                nextExercise()
                return nil
            case 48:
                jumpToNextCategory()
                return nil
            case 46:
                toggleExerciseGuideMode()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyboardShortcuts() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    private func remainingTimeText() -> String {
        let total = Int(remainingSeconds)
        guard total > 0 else { return "00:00" }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
