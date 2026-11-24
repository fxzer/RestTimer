import SwiftUI

private enum StatsScope: String, CaseIterable, Identifiable {
    case today = "今日"
    case week = "本周"
    var id: String { rawValue }
}

/// 设置页第 4 个 Tab「统计」：今日 / 本周双视角身体节律仪 + 节律轴 / 7日柱图 + 近 16 周热力格
struct BreakStatsView: View {
    @EnvironmentObject var timerManager: TimerManager
    @Namespace private var scopeNamespace

    @State private var scope: StatsScope = .today
    @State private var hoveredEvent: BreakEventRecord?
    @State private var hoveredWeekBucket: DailyStatsBucket?
    @State private var hoveredHeatBucket: DailyStatsBucket?
    @State private var cachedSnapshot: (
        todayEvents: [BreakEventRecord],
        weeklyBuckets: [DailyStatsBucket],
        heatmapBuckets: [DailyStatsBucket]
    )?

    private var currentSnapshot: (
        todayEvents: [BreakEventRecord],
        weeklyBuckets: [DailyStatsBucket],
        heatmapBuckets: [DailyStatsBucket]
    ) {
        cachedSnapshot ?? timerManager.makeStatsSnapshot(now: Date())
    }

    private func refreshSnapshot() {
        cachedSnapshot = timerManager.makeStatsSnapshot(now: Date())
    }

    var body: some View {
        let now = Date()
        let snapshot = currentSnapshot
        let todayBucket = snapshot.weeklyBuckets.last
        let liveFocus = timerManager.currentActiveFocusElapsedSeconds

        VStack(spacing: 8) {
            // 卡片 1：身体节律核心数字 + [今日 | 本周] 滑动切换
            summaryCard(
                todayBucket: todayBucket,
                liveFocusSeconds: liveFocus,
                weeklyBuckets: snapshot.weeklyBuckets
            )

            // 卡片 2：今日 08-23 节律轴 / 近 7 日趋势柱图
            if scope == .today {
                todayRhythmCard(events: snapshot.todayEvents, now: now)
            } else {
                weeklyBarChartCard(buckets: snapshot.weeklyBuckets)
            }

            // 卡片 3：近 16 周健康热力方格（112 天）
            heatmapCard(buckets: snapshot.heatmapBuckets)
        }
        .onAppear { refreshSnapshot() }
        .onChange(of: timerManager.statsVersion) { _ in refreshSnapshot() }
    }

    // MARK: - 卡片 1：核心身体指标（休息次数 / 休息时长 / 最长连坐或完成率）

    private func summaryCard(
        todayBucket: DailyStatsBucket?,
        liveFocusSeconds: Int,
        weeklyBuckets: [DailyStatsBucket]
    ) -> some View {
        let todayCompleted = todayBucket?.completedCount ?? 0
        let todaySkipped = todayBucket?.skippedCount ?? 0
        let todayBreakSec = todayBucket?.totalBreakSeconds ?? 0
        let todayFocusSec = (todayBucket?.totalFocusSeconds ?? 0) + liveFocusSeconds
        let todayLongestSit = max(todayBucket?.longestSitSeconds ?? 0, liveFocusSeconds)

        let weekCompleted = weeklyBuckets.reduce(0) { $0 + $1.completedCount }
        let weekSkipped = weeklyBuckets.reduce(0) { $0 + $1.skippedCount }
        let weekBreakSec = weeklyBuckets.reduce(0) { $0 + $1.totalBreakSeconds }
        let weekTotalAttempts = weekCompleted + weekSkipped
        let weekRateText = weekTotalAttempts > 0 ? "\(Int(round(Double(weekCompleted) * 100.0 / Double(weekTotalAttempts))))%" : "--"

        let todayCols = [
            ("\(todayCompleted)次", "休息次数", todaySkipped > 0 ? "跳过 \(todaySkipped)次" : "零跳过", false),
            (formatDuration(todayBreakSec), "休息时长", "今日累计", false),
            (formatDuration(todayLongestSit), "最长连坐", "专注 \(formatFocusHours(todayFocusSec))", todayLongestSit >= 50 * 60)
        ]
        let weekCols = [
            ("\(weekCompleted)次", "本周休息", "近 7 日累计", false),
            (formatDuration(weekBreakSec), "累计时长", "日均 \(formatDuration(weekBreakSec / 7))", false),
            (weekRateText, "完成率", weekSkipped > 0 ? "跳过 \(weekSkipped)次" : "全部完成", weekTotalAttempts > 0 && weekSkipped > weekCompleted)
        ]

        return SettingsCardContainer {
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Color.accentColor)
                        Text("身体节律")
                            .font(.system(size: 12, weight: .medium))
                    }
                    Spacer()
                    // [今日 | 本周] 极简滑动切换
                    HStack(spacing: 2) {
                        ForEach(StatsScope.allCases) { item in
                            let selected = scope == item
                            Button {
                                withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.24)) {
                                    scope = item
                                }
                            } label: {
                                Text(item.rawValue)
                                    .font(.system(size: 11, weight: selected ? .semibold : .medium))
                                    .foregroundColor(selected ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                                    .frame(width: 40, height: 22)
                                    .background {
                                        if selected {
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .fill(SettingsTokens.activeTabFill)
                                                .matchedGeometryEffect(id: "statsScopePill", in: scopeNamespace)
                                        }
                                    }
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                        }
                    }
                    .padding(2)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.045)))
                }

                HStack(spacing: 0) {
                    let cols = scope == .today ? todayCols : weekCols
                    ForEach(0..<cols.count, id: \.self) { idx in
                        if idx > 0 { verticalHairline }
                        metricColumn(value: cols[idx].0, label: cols[idx].1, sublabel: cols[idx].2, isWarning: cols[idx].3)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    private func metricColumn(value: String, label: String, sublabel: String, isWarning: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(isWarning ? .orange : Color(nsColor: .labelColor))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            Text(sublabel)
                .font(.system(size: 10))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 0.5, height: 34)
    }

    // MARK: - 卡片 2A：今日 08:00 至 23:00 呼吸节律时间轴

    private func todayRhythmCard(events: [BreakEventRecord], now: Date) -> some View {
        let headerDetail: String = {
            if let ev = hoveredEvent {
                let t = formatHourMinute(ev.timestamp)
                return ev.wasSkipped ? "\(t) · 已跳过" : "\(t) · 休息 \(formatDuration(ev.breakSeconds))"
            }
            if events.isEmpty { return "暂无记录" }
            let completed = events.filter { !$0.wasSkipped }.count
            return "已完成 \(completed) 次 · 悬停看明细"
        }()

        return SettingsCardContainer {
            VStack(spacing: 6) {
                HStack {
                    Text("今日节律")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    Spacer()
                    Text(headerDetail)
                        .font(.system(size: 10.5))
                        .foregroundColor(hoveredEvent != nil ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
                        .monospacedDigit()
                }

                VStack(spacing: 5) {
                    GeometryReader { geo in
                        let width = max(1, geo.size.width)
                        let midY = geo.size.height / 2

                        ZStack {
                            // 水平时间轨道
                            Capsule()
                                .fill(Color.primary.opacity(0.07))
                                .frame(height: 3)
                                .position(x: width / 2, y: midY)

                            // 当前时刻柔和游标
                            if let nowRatio = timelineRatio(for: now) {
                                Circle()
                                    .fill(Color.primary.opacity(0.32))
                                    .frame(width: 5, height: 5)
                                    .position(x: nowRatio * width, y: midY)
                            }

                            // 每次完成休息 = 主题色亮竖条；主动跳过 = 淡橙小圆点
                            ForEach(events) { event in
                                let eventDate = Date(timeIntervalSince1970: event.timestamp)
                                let ratio = clampedTimelineRatio(for: eventDate)
                                let isHovered = hoveredEvent?.id == event.id

                                Group {
                                    if event.wasSkipped {
                                        Circle()
                                            .fill(Color.orange.opacity(isHovered ? 1.0 : 0.72))
                                            .frame(width: isHovered ? 9 : 6.5, height: isHovered ? 9 : 6.5)
                                    } else {
                                        Capsule()
                                            .fill(Color.accentColor.opacity(isHovered ? 1.0 : 0.85))
                                            .frame(width: isHovered ? 6 : 4.5, height: isHovered ? 28 : 22)
                                    }
                                }
                                .padding(4)
                                .contentShape(Rectangle())
                                .position(x: max(6, min(width - 6, ratio * width)), y: midY)
                                .onHover { hovering in
                                    hoveredEvent = hovering ? event : (hoveredEvent?.id == event.id ? nil : hoveredEvent)
                                }
                            }
                        }
                    }
                    .frame(height: 40)

                    // 时刻刻度（08 - 23）
                    HStack {
                        ForEach(["08", "12", "16", "20", "23"], id: \.self) { label in
                            Text(label)
                                .font(.system(size: 9.5, design: .rounded))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .monospacedDigit()
                            if label != "23" { Spacer() }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    // MARK: - 卡片 2B：近 7 日休息时长胶囊柱状图

    private func weeklyBarChartCard(buckets: [DailyStatsBucket]) -> some View {
        let maxSec = max(buckets.map(\.totalBreakSeconds).max() ?? 0, 120)
        let avgSec = buckets.isEmpty ? 0 : buckets.reduce(0) { $0 + $1.totalBreakSeconds } / buckets.count

        let headerDetail: String = {
            if let b = hoveredWeekBucket {
                let dateStr = formatMonthDay(b.date)
                return b.completedCount > 0
                    ? "\(dateStr) · 休 \(b.completedCount) 次 · \(formatDuration(b.totalBreakSeconds))"
                    : "\(dateStr) · 暂无休息记录"
            }
            return avgSec > 0 ? "日均 \(formatDuration(avgSec))" : "近 7 日暂无记录"
        }()

        return SettingsCardContainer {
            VStack(spacing: 6) {
                HStack {
                    Text("近 7 日趋势")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    Spacer()
                    Text(headerDetail)
                        .font(.system(size: 10.5))
                        .foregroundColor(hoveredWeekBucket != nil ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
                        .monospacedDigit()
                }

                ZStack(alignment: .bottom) {
                    // 日均参考虚线
                    if avgSec > 0 {
                        let avgRatio = min(1.0, CGFloat(avgSec) / CGFloat(maxSec))
                        let barMaxH: CGFloat = 38
                        GeometryReader { geo in
                            Path { path in
                                let y = barMaxH * (1.0 - avgRatio)
                                path.move(to: CGPoint(x: 4, y: y))
                                path.addLine(to: CGPoint(x: geo.size.width - 4, y: y))
                            }
                            .stroke(Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: 0.7, dash: [3, 3]))
                        }
                        .frame(height: 38)
                        .padding(.bottom, 16)
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(buckets.enumerated()), id: \.element.id) { idx, bucket in
                            let isToday = idx == buckets.count - 1
                            let isHovered = hoveredWeekBucket?.id == bucket.id
                            let ratio = CGFloat(bucket.totalBreakSeconds) / CGFloat(maxSec)
                            let barHeight: CGFloat = bucket.totalBreakSeconds > 0 ? max(5, ratio * 38) : 3

                            VStack(spacing: 4) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .fill(
                                        bucket.totalBreakSeconds == 0
                                            ? Color.primary.opacity(0.07)
                                            : Color.accentColor.opacity(isToday || isHovered ? 0.95 : 0.52)
                                    )
                                    .frame(width: 18, height: barHeight)

                                Text(bucket.weekdayShort)
                                    .font(.system(size: 9.5, weight: isToday ? .semibold : .regular))
                                    .foregroundColor(isToday ? Color(nsColor: .labelColor) : Color(nsColor: .tertiaryLabelColor))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                hoveredWeekBucket = hovering ? bucket : (hoveredWeekBucket?.id == bucket.id ? nil : hoveredWeekBucket)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    // MARK: - 卡片 3：近 16 周（112 天）GitHub 风格主题色热力方格

    private func heatmapCard(buckets: [DailyStatsBucket]) -> some View {
        let weeks = chunkIntoWeeks(buckets, rows: 7)
        let todayKey = buckets.last?.dayKey ?? ""

        let headerDetail: String = {
            if let b = hoveredHeatBucket {
                let d = formatMonthDay(b.date)
                return b.completedCount > 0
                    ? "\(d) · 休 \(b.completedCount) 次 · \(formatDuration(b.totalBreakSeconds))"
                    : "\(d) · 暂无休息"
            }
            let activeDays = buckets.filter { $0.completedCount > 0 }.count
            return activeDays > 0 ? "已点亮 \(activeDays) 天" : "每次完成休息自动点亮"
        }()

        return SettingsCardContainer {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text("近 16 周热力")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))

                    Spacer()

                    Text(headerDetail)
                        .font(.system(size: 10.5))
                        .foregroundColor(hoveredHeatBucket != nil ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
                        .monospacedDigit()

                    // 极简 4 档图例
                    HStack(spacing: 2) {
                        ForEach([0, 2, 4, 7], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(heatColor(forCount: level))
                                .frame(width: 7, height: 7)
                        }
                    }
                }

                HStack(alignment: .center, spacing: 6) {
                    // 极简星期参考列
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { row in
                            Text(row == 0 ? "一" : (row == 3 ? "四" : (row == 6 ? "日" : "")))
                                .font(.system(size: 8.5))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .frame(width: 11, height: 11)
                        }
                    }

                    // 16 列 × 7 行微圆角方格
                    HStack(spacing: 3.5) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, col in
                            VStack(spacing: 3) {
                                ForEach(col) { bucket in
                                    let isToday = bucket.dayKey == todayKey
                                    let isHovered = hoveredHeatBucket?.id == bucket.id
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(heatColor(forCount: bucket.completedCount))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                                .stroke(
                                                    isHovered
                                                        ? Color(nsColor: .labelColor).opacity(0.65)
                                                        : (isToday ? Color.accentColor.opacity(0.75) : Color.clear),
                                                    lineWidth: isHovered ? 1.0 : 0.8
                                                )
                                        )
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 11)
                                        .onHover { hovering in
                                            hoveredHeatBucket = hovering ? bucket : (hoveredHeatBucket?.id == bucket.id ? nil : hoveredHeatBucket)
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    // MARK: - 格式化与布局辅助

    private static let hourMinuteFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "M月d日"; return f
    }()

    private func heatColor(forCount count: Int) -> Color {
        switch count {
        case ...0: return Color.primary.opacity(0.055)
        case 1...2: return Color.accentColor.opacity(0.28)
        case 3...4: return Color.accentColor.opacity(0.52)
        case 5...6: return Color.accentColor.opacity(0.76)
        default: return Color.accentColor
        }
    }

    private func chunkIntoWeeks(_ buckets: [DailyStatsBucket], rows: Int) -> [[DailyStatsBucket]] {
        guard rows > 0 else { return [] }
        return stride(from: 0, to: buckets.count, by: rows).map {
            Array(buckets[$0..<min($0 + rows, buckets.count)])
        }
    }

    private func timelineRatio(for date: Date) -> CGFloat? {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let mins = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        guard mins >= 480 && mins <= 1380 else { return nil }
        return CGFloat((mins - 480) / 900)
    }

    private func clampedTimelineRatio(for date: Date) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let mins = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        return CGFloat(min(1.0, max(0.0, (mins - 480) / 900)))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s == 0 { return "0分" }
        if s < 60 { return "\(s)秒" }
        let mins = s / 60
        return mins >= 60 ? String(format: "%.1fh", Double(mins) / 60.0) : "\(mins)分"
    }

    private func formatFocusHours(_ seconds: Int) -> String {
        let mins = max(0, seconds) / 60
        return mins < 60 ? "\(mins)分" : String(format: "%.1fh", Double(mins) / 60.0)
    }

    private func formatHourMinute(_ timestamp: TimeInterval) -> String {
        Self.hourMinuteFormatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    private func formatMonthDay(_ date: Date) -> String {
        Self.monthDayFormatter.string(from: date)
    }
}
