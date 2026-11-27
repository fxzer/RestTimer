import SwiftUI

/// 图片卡片底部向上渐隐的动作说明浮层（仅 Hover 时渐显，不额外占用卡片外部高度）
struct ExerciseStepsOverlay: View {
    let steps: [String]
    var fontSize: CGFloat = 11.5
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(steps, id: \.self) { step in
                Text(step)
                    .font(.system(size: fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.96))
                    .shadow(color: Color.black.opacity(0.42), radius: 2.5, x: 0, y: 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, verticalPadding + 16)
        .padding(.bottom, verticalPadding)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.0), location: 0.0),
                    .init(color: Color.black.opacity(0.24), location: 0.28),
                    .init(color: Color.black.opacity(0.46), location: 0.64),
                    .init(color: Color.black.opacity(0.58), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
    }
}

/// 多张并排模式单张卡片（204×272 严格 3:4 缩略图 + 部位角标，Hover 时在图底浮现动作要点，点击放大为单张详情）
struct BreakExerciseBatchCard: View {
    let exercise: StretchExercise
    let positionText: String
    let isActive: Bool
    let accentColor: Color
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                ZStack(alignment: .topLeading) {
                    switch exercise.visual {
                    case .fitgateIllustration(let assetName):
                        let thumbnail = ExerciseImageLoader.shared.loadThumbnail(named: assetName)
                        (thumbnail != nil ? Image(nsImage: thumbnail!) : Image(assetName))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 204, height: 272)
                    }

                    HStack(spacing: 4) {
                        if isActive {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 6, height: 6)
                        }
                        Text("\(positionText) · \(exercise.badgeText)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(8)

                    if isHovering, !exercise.steps.isEmpty {
                        VStack {
                            Spacer()
                            ExerciseStepsOverlay(
                                steps: exercise.steps,
                                fontSize: 10.5,
                                horizontalPadding: 10,
                                verticalPadding: 7
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(width: 204, height: 272)
                .compositingGroup()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(exercise.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.16 : (isActive ? 0.13 : 0.07)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                Color.white.opacity(isHovering ? 0.56 : (isActive ? 0.42 : 0.14)),
                                lineWidth: isActive || isHovering ? 1.1 : 0.6
                            )
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.16), value: isHovering)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("点击放大查看「\(exercise.name)」")
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
