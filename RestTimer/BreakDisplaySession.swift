import SwiftUI

/// 多显示器共享的休息展示会话状态（单一数据源：主题、名言、拉伸编排与手动切换在全部屏幕间实时同步）
final class BreakDisplaySession: ObservableObject {
    static let multiCardBatchCount = 3

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

    /// 返回当前多张并排模式下应同屏展示的一组不重复动作（默认 3 张，兼容短休息自动补齐与手动整批翻页）
    func displayedBatch(
        totalBreakSeconds: TimeInterval,
        elapsedSeconds: TimeInterval,
        batchCount: Int = BreakDisplaySession.multiCardBatchCount
    ) -> [StretchExercise] {
        let all = StretchRoutinePlanner.catalog
        guard !all.isEmpty else { return [] }
        let targetCount = min(max(1, batchCount), all.count)

        if hasManualSwitch {
            return (0..<targetCount).map { offset in
                let idx = ((catalogIndex + offset) % all.count + all.count) % all.count
                return all[idx]
            }
        }

        var result: [StretchExercise] = []
        if routine.count > targetCount,
           let active = currentExercise(totalBreakSeconds: totalBreakSeconds, elapsedSeconds: elapsedSeconds),
           let activeIdx = routine.firstIndex(where: { $0.id == active.id }) {
            let pageStart = min(routine.count - targetCount, (activeIdx / targetCount) * targetCount)
            result = Array(routine[pageStart..<(pageStart + targetCount)])
        } else {
            result = routine
        }

        if result.count < targetCount {
            let existingIds = Set(result.map(\.id))
            for candidate in all where !existingIds.contains(candidate.id) {
                result.append(candidate)
                if result.count >= targetCount { break }
            }
        }
        return result
    }

    func selectExercise(_ exercise: StretchExercise) {
        guard let idx = StretchRoutinePlanner.catalog.firstIndex(where: { $0.id == exercise.id }) else { return }
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.22)) {
            catalogIndex = idx
            hasManualSwitch = true
        }
    }

    /// 格式化当前多张批次在总动作库中的序号进度（连续切片显示 `1-3/20`，跨部位套餐显示 `2·8·15/20`）
    func batchProgressLabel(for batch: [StretchExercise]) -> String {
        let total = StretchRoutinePlanner.catalog.count
        guard !batch.isEmpty, total > 0 else { return "0/0" }
        let positions = batch.map { catalogPosition(for: $0) }
        if positions.count == 1 {
            return "\(positions[0])/\(total)"
        }
        let isContiguous = zip(positions, positions.dropFirst()).allSatisfy { prev, next in
            next == (prev % total) + 1
        }
        if isContiguous, let first = positions.first, let last = positions.last {
            return "\(first)-\(last)/\(total)"
        }
        return positions.map(String.init).joined(separator: "·") + "/\(total)"
    }

    func selectTheme(_ theme: BreakGradientTheme) {
        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.38)) {
            displayedTheme = theme
        }
    }

    func advanceAutoTheme() {
        let themes = BreakGradientTheme.concreteThemes
        guard !themes.isEmpty else { return }
        let nextIndex: Int
        if let currentIdx = themes.firstIndex(of: displayedTheme) {
            nextIndex = (currentIdx + 1) % themes.count
        } else {
            nextIndex = rotationThemeIndex % themes.count
        }
        rotationThemeIndex = (nextIndex + 1) % themes.count
        selectTheme(themes[nextIndex])
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
