import SwiftUI
import ServiceManagement

private enum SettingsTab: String, CaseIterable, Identifiable {
    case clockAndRhythm = "时间"
    case smartDelay = "防打断"
    case appearanceAndGeneral = "通用"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .clockAndRhythm:
            return "clock"
        case .smartDelay:
            return "hand.raised"
        case .appearanceAndGeneral:
            return "gearshape"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var timerManager: TimerManager
    @Namespace private var tabSelectionNamespace

    @State private var activeTab: SettingsTab = .clockAndRhythm
    @State private var launchAtLogin: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let presets = TimePreset.defaults
    private let breakOptions: [(label: String, seconds: Int)] = [
        ("1分", 60),
        ("2分", 120),
        ("3分", 180),
        ("5分", 300),
        ("10分", 600)
    ]

    init() {
        if #available(macOS 13.0, *) {
            _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        }
    }

    private var currentWorkMinutes: Int {
        min(60, max(1, timerManager.settings.workDurationMinutes))
    }

    private var currentEarlyMinutes: Int {
        timerManager.settings.earlyNotifyMinutes
    }

    private var currentBreakTotalSeconds: Int {
        max(60, timerManager.settings.breakTotalSeconds)
    }

    var body: some View {
        VStack(spacing: 12) {
            tabBar

            ZStack(alignment: .top) {
                switch activeTab {
                case .clockAndRhythm:
                    clockAndRhythmTab
                        .transition(.opacity)
                case .smartDelay:
                    smartDelayTab
                        .transition(.opacity)
                case .appearanceAndGeneral:
                    appearanceAndGeneralTab
                        .transition(.opacity)
                }
            }
            .frame(height: SettingsTokens.tabContentHeight, alignment: .top)
            .clipped()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: SettingsTokens.windowWidth, height: SettingsTokens.windowHeight, alignment: .top)
        .onAppear {
            syncLaunchAtLoginStatus()
        }
        .alert("设置提示", isPresented: $showAlert) {
            Button("确定", action: {})
                .buttonStyle(.borderedProminent)
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - NexWan 风格固定 Tab 栏

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                let selected = activeTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        activeTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))

                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selected ? .semibold : .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(selected ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(SettingsTokens.activeTabFill)
                                .matchedGeometryEffect(id: "activeTabIndicator", in: tabSelectionNamespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: SettingsTokens.cornerRadius, style: .continuous)
                .fill(SettingsTokens.tabBarFill)
        )
    }

    // MARK: - Tab 1: 时间

    private var clockAndRhythmTab: some View {
        VStack(spacing: 10) {
            SettingsCardContainer {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(presets) { preset in
                            let isSelected = currentWorkMinutes == preset.workMinutes
                                && currentEarlyMinutes == preset.earlyMinutes
                                && currentBreakTotalSeconds == preset.breakSeconds

                            SettingsPillButton(
                                title: preset.title,
                                isSelected: isSelected
                            ) {
                                applyTime(
                                    workMinutes: preset.workMinutes,
                                    earlyMinutes: preset.earlyMinutes,
                                    breakTotalSeconds: preset.breakSeconds
                                )
                            }
                        }
                    }

                    FocusClockDialView(
                        workMinutes: currentWorkMinutes,
                        earlyNotifyMinutes: currentEarlyMinutes,
                        onWorkMinutesChanged: { newWorkMin in
                            let safeEarly = min(currentEarlyMinutes, max(0, newWorkMin - 1))
                            applyTime(
                                workMinutes: newWorkMin,
                                earlyMinutes: safeEarly,
                                breakTotalSeconds: currentBreakTotalSeconds
                            )
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(12)
            }

            SettingsCardContainer {
                HStack(spacing: 8) {
                    Text("提前提醒")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 56, alignment: .leading)

                    HStack(spacing: 4) {
                        ForEach([0, 1, 2, 3, 5], id: \.self) { minutes in
                            let isDisabled = minutes >= currentWorkMinutes && minutes > 0
                            SettingsPillButton(
                                title: minutes == 0 ? "关闭" : "\(minutes)分",
                                isSelected: currentEarlyMinutes == minutes,
                                isDisabled: isDisabled
                            ) {
                                applyTime(workMinutes: currentWorkMinutes, earlyMinutes: minutes, breakTotalSeconds: currentBreakTotalSeconds)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                SettingsHairlineDivider()

                HStack(spacing: 8) {
                    Text("休息时长")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 56, alignment: .leading)

                    HStack(spacing: 4) {
                        ForEach(breakOptions, id: \.seconds) { item in
                            SettingsPillButton(
                                title: item.label,
                                isSelected: currentBreakTotalSeconds == item.seconds
                            ) {
                                applyTime(workMinutes: currentWorkMinutes, earlyMinutes: currentEarlyMinutes, breakTotalSeconds: item.seconds)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
        }
    }

    // MARK: - Tab 2: 防打断（极简一行一配置）

    private var smartDelayTab: some View {
        VStack(spacing: 10) {
            SettingsCardContainer {
                settingsToggleRow(
                    icon: "hand.raised",
                    title: "活动顺延",
                    isOn: $timerManager.settings.smartDelayEnabled
                )

                SettingsHairlineDivider()

                HStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.accentColor)
                        .frame(width: 18)

                    Text("监测输入")
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    HStack(spacing: 6) {
                        SettingsPillButton(
                            title: "键盘",
                            isSelected: timerManager.settings.monitorKeyboard
                        ) {
                            if timerManager.settings.monitorKeyboard && !timerManager.settings.monitorMouse { return }
                            timerManager.settings.monitorKeyboard.toggle()
                        }
                        .frame(width: 54)

                        SettingsPillButton(
                            title: "鼠标",
                            isSelected: timerManager.settings.monitorMouse
                        ) {
                            if timerManager.settings.monitorMouse && !timerManager.settings.monitorKeyboard { return }
                            timerManager.settings.monitorMouse.toggle()
                        }
                        .frame(width: 54)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .disabled(!timerManager.settings.smartDelayEnabled)
                .opacity(timerManager.settings.smartDelayEnabled ? 1.0 : 0.45)

                SettingsHairlineDivider()

                HStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.accentColor)
                        .frame(width: 18)

                    Text("空闲触发")
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach([(5, "5秒"), (10, "10秒"), (30, "30秒")], id: \.0) { seconds, label in
                            SettingsPillButton(
                                title: label,
                                isSelected: timerManager.settings.idleDelaySeconds == seconds
                            ) {
                                timerManager.settings.idleDelaySeconds = seconds
                            }
                            .frame(width: 54)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .disabled(!timerManager.settings.smartDelayEnabled)
                .opacity(timerManager.settings.smartDelayEnabled ? 1.0 : 0.45)

                SettingsHairlineDivider()

                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.accentColor)
                        .frame(width: 18)

                    Text("最长顺延")
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach([(3, "3分"), (5, "5分"), (10, "10分")], id: \.0) { value, title in
                            SettingsPillButton(
                                title: title,
                                isSelected: timerManager.settings.maxDelayMinutes == value
                            ) {
                                timerManager.settings.maxDelayMinutes = value
                            }
                            .frame(width: 54)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .disabled(!timerManager.settings.smartDelayEnabled)
                .opacity(timerManager.settings.smartDelayEnabled ? 1.0 : 0.45)
            }

            SettingsCardContainer {
                settingsToggleRow(
                    icon: "video.slash",
                    title: "会议/通话免打扰",
                    isOn: $timerManager.settings.dndOnMeetingOrCall
                )

                SettingsHairlineDivider()

                settingsToggleRow(
                    icon: "play.rectangle",
                    title: "全屏演示/视频免打扰",
                    isOn: $timerManager.settings.dndOnFullscreenMedia
                )
            }

            SettingsCardContainer {
                settingsToggleRow(
                    icon: "pause.circle",
                    title: "休息时暂停媒体",
                    isOn: $timerManager.settings.pauseMediaOnBreak
                )

                SettingsHairlineDivider()

                settingsToggleRow(
                    icon: "headphones",
                    title: "耳机在位自动续播",
                    isOn: $timerManager.settings.resumeMediaWithHeadphones
                )
                .disabled(!timerManager.settings.pauseMediaOnBreak)
                .opacity(timerManager.settings.pauseMediaOnBreak ? 1.0 : 0.45)
            }
        }
    }

    // MARK: - Tab 3: 通用

    private var appearanceAndGeneralTab: some View {
        VStack(spacing: 10) {
            SettingsCardContainer {
                settingsToggleRow(
                    icon: "power",
                    title: "开机自启动",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { applyLaunchAtLogin(enabled: $0) }
                    )
                )

                SettingsHairlineDivider()

                settingsToggleRow(
                    icon: "dock.rectangle",
                    title: "显示程序坞图标",
                    isOn: $timerManager.settings.showDockIcon
                )

                SettingsHairlineDivider()

                settingsToggleRow(
                    icon: "forward.end",
                    title: "显示跳过按钮",
                    isOn: $timerManager.settings.showSkipButton
                )

                SettingsHairlineDivider()

                settingsToggleRow(
                    icon: "figure.cooldown",
                    title: "休息拉伸引导",
                    isOn: $timerManager.settings.enableBreakExerciseGuide
                )
            }

            SettingsCardContainer {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "swatchpalette")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.accentColor)
                            .frame(width: 18)

                        Text("主题预览")
                            .font(.system(size: 12, weight: .medium))

                        Text("点击卡片即刻预览")
                            .font(.system(size: 11))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))

                        Spacer()

                        SettingsPillButton(
                            title: BreakGradientTheme.autoDayNight.displayName,
                            isSelected: timerManager.settings.breakGradientTheme == .autoDayNight
                        ) {
                            timerManager.settings.breakGradientTheme = .autoDayNight
                        }
                        .frame(width: 68)
                    }

                    // 3 列 × 3 行矩形可视化主题预览矩阵（极淡静音系 -> 柔和护眼系 -> 静谧深色系）
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
                        spacing: 7
                    ) {
                        ForEach(BreakGradientTheme.concreteThemes, id: \.self) { theme in
                            BreakThemePreviewCardView(
                                theme: theme,
                                isSelected: timerManager.settings.breakGradientTheme == theme
                            ) {
                                timerManager.settings.breakGradientTheme = theme
                                timerManager.startBreakPreview()
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - NexWan 极简设置行

    private func settingsToggleRow(
        icon: String,
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.accentColor)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(nsColor: .labelColor))

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func applyTime(workMinutes: Int, earlyMinutes: Int, breakTotalSeconds: Int) {
        let clampedWork = min(60, max(1, workMinutes))
        let safeEarly = min(earlyMinutes, max(0, clampedWork - 1))
        _ = timerManager.updateTimeSettings(
            workMinutes: clampedWork,
            workSeconds: 0,
            breakMinutes: breakTotalSeconds / 60,
            breakSeconds: breakTotalSeconds % 60,
            earlyMinutes: safeEarly,
            earlySeconds: 0
        )
    }

    private func syncLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func applyLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLogin = SMAppService.mainApp.status == .enabled
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
                alertMessage = "切换开机自启动失败: \(error.localizedDescription)"
                showAlert = true
            }
        } else {
            let success = SMLoginItemSetEnabled("fxzer.top.RestTimer" as CFString, enabled)
            if success {
                launchAtLogin = enabled
            }
        }
    }
}
