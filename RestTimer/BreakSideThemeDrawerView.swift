import SwiftUI

/// 休息界面左侧边缘 Hover 竖排主题抽屉：默认仅留极淡竖条提示，滑入后展开「自动轮换 + 12 款主题」
struct BreakSideThemeDrawerView: View {
    @Binding var selectedThemeSetting: BreakGradientTheme
    let displayedTheme: BreakGradientTheme
    let onSelectAutoRotation: () -> Void
    let onSelectTheme: (BreakGradientTheme) -> Void

    @State private var isExpanded = false
    @State private var collapseWorkItem: DispatchWorkItem?
    @State private var isHoveringAuto = false
    @State private var hoveredTheme: BreakGradientTheme?

    private var isAutoRotationEnabled: Bool {
        selectedThemeSetting == .autoDayNight
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // 左侧常驻隐形热区 + 极淡竖条提示，避免多屏边缘一滑即穿或找不到入口
            HStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(isExpanded ? 0.0 : 0.22))
                    .frame(width: 3, height: 38)
                    .padding(.leading, 8)
                Spacer(minLength: 0)
            }
            .frame(width: 38, height: 460)
            .contentShape(Rectangle())
            .onHover(perform: updateHover)

            if isExpanded {
                VStack(alignment: .leading, spacing: 5) {
                    autoRotationRow

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 78, height: 0.5)
                        .padding(.leading, 12)
                        .padding(.vertical, 4)

                    ForEach(BreakGradientTheme.concreteThemes, id: \.self) { theme in
                        themeRow(theme)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
                .shadow(color: Color.black.opacity(0.24), radius: 5, x: 0, y: 1)
                .padding(.leading, 20)
                .onHover(perform: updateHover)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            }
        }
        .onDisappear {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
        }
    }

    private var autoRotationRow: some View {
        Button {
            selectedThemeSetting = .autoDayNight
            onSelectAutoRotation()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 14)
                Text(BreakGradientTheme.autoDayNight.displayName)
                    .font(.system(size: 13.5, weight: isAutoRotationEnabled ? .semibold : .medium))
            }
            .foregroundColor(isAutoRotationEnabled ? .white : Color.white.opacity(isHoveringAuto ? 0.92 : 0.64))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isAutoRotationEnabled ? 0.16 : (isHoveringAuto ? 0.09 : 0.0)))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("开启自动轮换，并预览下一款主题")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHoveringAuto = hovering
            }
        }
    }

    private func themeRow(_ theme: BreakGradientTheme) -> some View {
        let isPinned = !isAutoRotationEnabled && selectedThemeSetting == theme
        let isCurrentDisplayed = displayedTheme == theme
        let isHovered = hoveredTheme == theme && !isPinned

        return Button {
            selectedThemeSetting = theme
            onSelectTheme(theme)
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(theme.palette.orb1)
                        .frame(width: 9, height: 9)
                    if isAutoRotationEnabled && isCurrentDisplayed {
                        Circle()
                            .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                            .frame(width: 13.5, height: 13.5)
                    }
                }
                .frame(width: 14, height: 14)

                Text(theme.displayName)
                    .font(.system(size: 13.5, weight: isPinned ? .semibold : .medium))
            }
            .foregroundColor(
                isPinned
                    ? .white
                    : Color.white.opacity(isHovered || (isAutoRotationEnabled && isCurrentDisplayed) ? 0.92 : 0.62)
            )
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(
                        Color.white.opacity(
                            isPinned ? 0.16 : (isHovered ? 0.09 : (isAutoRotationEnabled && isCurrentDisplayed ? 0.07 : 0.0))
                        )
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredTheme = hovering ? theme : (hoveredTheme == theme ? nil : hoveredTheme)
            }
        }
    }

    private func updateHover(_ hovering: Bool) {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil

        if hovering {
            if !isExpanded {
                withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.22)) {
                    isExpanded = true
                }
            }
        } else {
            let item = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.18)) {
                    isExpanded = false
                }
            }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: item)
        }
    }
}
