import SwiftUI

/// 多张并排模式单张卡片（204×272 严格 3:4 缩略图 + 部位角标 + 动作要点，点击放大为单张详情）
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
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                }

                VStack(spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(exercise.steps.joined(separator: "；"))
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: 200, height: 34, alignment: .top)
                }
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
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("点击放大查看「\(exercise.name)」")
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
