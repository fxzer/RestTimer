import SwiftUI

/// 多显示器共享的休息展示会话状态（单一数据源：主题、名言、拉伸编排与手动切换在全部屏幕间实时同步）
final class BreakDisplaySession: ObservableObject {
    @Published private(set) var displayedTheme: BreakGradientTheme = .frostedGlass
    @Published private(set) var currentQuote: CuratedQuote = CuratedQuoteLibrary.all[0]
    @Published private(set) var routine: [StretchExercise] = []
    @Published private(set) var catalogIndex: Int = 0
    @Published private(set) var hasManualSwitch: Bool = false

    private var recentExerciseIds: Set<String> = []
    private var rotationThemeIndex: Int = 0
    private var hasPreparedOnce = false

    func prepareSession(totalBreakSeconds: TimeInterval, themeSetting: BreakGradientTheme) {
        let themes = BreakGradientTheme.concreteThemes
        if themeSetting == .autoDayNight {
            displayedTheme = themes[rotationThemeIndex % themes.count]
            rotationThemeIndex += 1
        } else {
            displayedTheme = themeSetting
        }

        currentQuote = CuratedQuoteLibrary.nextQuote(excluding: hasPreparedOnce ? currentQuote : nil)
        hasPreparedOnce = true
        hasManualSwitch = false

        let planned = StretchRoutinePlanner.planRoutine(
            forBreakSeconds: Int(max(1.0, totalBreakSeconds)),
            excludingRecentIds: recentExerciseIds
        )
        routine = planned
        if let first = planned.first,
           let idx = StretchRoutinePlanner.catalog.firstIndex(where: { $0.id == first.id }) {
            catalogIndex = idx
        } else {
            catalogIndex = 0
        }
        recentExerciseIds = Set(planned.map(\.id))
    }

    func currentExercise(totalBreakSeconds: TimeInterval, elapsedSeconds: TimeInterval) -> StretchExercise? {
        let all = StretchRoutinePlanner.catalog
        guard !all.isEmpty else { return nil }
        if hasManualSwitch {
            return all[(catalogIndex % all.count + all.count) % all.count]
        }
        guard !routine.isEmpty else { return all[0] }
        let safeTotal = max(1.0, totalBreakSeconds)
        let safeElapsed = max(0.0, elapsedSeconds)
        let slotDuration = safeTotal / Double(routine.count)
        let idx = slotDuration > 0 ? min(routine.count - 1, max(0, Int(safeElapsed / slotDuration))) : 0
        return routine[idx]
    }

    func catalogPosition(for exercise: StretchExercise?) -> Int {
        guard let exercise = exercise,
              let idx = StretchRoutinePlanner.catalog.firstIndex(where: { $0.id == exercise.id }) else {
            return 1
        }
        return idx + 1
    }

    func selectTheme(_ theme: BreakGradientTheme) {
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.38)) {
            displayedTheme = theme
        }
    }

    func advanceQuote() {
        withAnimation(.easeInOut(duration: 0.28)) {
            currentQuote = CuratedQuoteLibrary.nextQuote(excluding: currentQuote)
        }
    }

    func stepCatalog(by delta: Int, totalBreakSeconds: TimeInterval, elapsedSeconds: TimeInterval) {
        let all = StretchRoutinePlanner.catalog
        guard !all.isEmpty else { return }
        let active = currentExercise(totalBreakSeconds: totalBreakSeconds, elapsedSeconds: elapsedSeconds)
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.22)) {
            let base = (!hasManualSwitch && active != nil)
                ? (all.firstIndex(where: { $0.id == active!.id }) ?? catalogIndex)
                : catalogIndex
            catalogIndex = (base + delta + all.count) % all.count
            hasManualSwitch = true
        }
    }

    func jumpToNextCategory(totalBreakSeconds: TimeInterval, elapsedSeconds: TimeInterval) {
        let all = StretchRoutinePlanner.catalog
        guard !all.isEmpty,
              let current = currentExercise(totalBreakSeconds: totalBreakSeconds, elapsedSeconds: elapsedSeconds) else {
            return
        }
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
}
