import SwiftUI

struct BrandMarkView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle

    var size: CGFloat = 36

    var body: some View {
        ZStack {
            if chromeStyle == .studio {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [RetroPalette.studioPanel, RetroPalette.studioCanvasMuted],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                            .stroke(RetroPalette.studioBorder, lineWidth: 1)
                    )

                pageShape
                    .fill(Color.white)

                caretShape
                    .fill(
                        LinearGradient(
                            colors: [RetroPalette.studioAccent, RetroPalette.studioAccentMuted],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Rectangle()
                    .fill(RetroPalette.studioAccent)
                    .frame(width: size * 0.17, height: size * 0.09)
                    .offset(x: -size * 0.03, y: -size * 0.1)
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                RetroPalette.chromeBlue,
                                RetroPalette.chromeTeal,
                                RetroPalette.chromeCyan,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Rectangle()
                    .stroke(RetroPalette.chromeGold, lineWidth: 1)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Rectangle().fill(RetroPalette.chromeGold)
                        Rectangle().fill(RetroPalette.chromePink)
                        Rectangle().fill(RetroPalette.chromeGold)
                    }
                    .frame(height: size * 0.08)
                    Spacer(minLength: 0)
                }

                pageShape
                    .fill(Color(red: 0.98, green: 0.96, blue: 0.88))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: size * 0.04, y: size * 0.04)

                caretShape
                    .fill(
                        LinearGradient(
                            colors: [
                                RetroPalette.chromePink,
                                RetroPalette.chromeGold,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Rectangle()
                    .fill(RetroPalette.chromePink)
                    .frame(width: size * 0.17, height: size * 0.09)
                    .offset(x: -size * 0.03, y: -size * 0.1)
            }
        }
        .frame(width: size, height: size)
    }

    private var pageShape: some Shape {
        Path { path in
            let width = size * 0.58
            let height = size * 0.68
            let originX = size * 0.23
            let originY = size * 0.16
            let corner = size * 0.08
            let fold = size * 0.14

            path.move(to: CGPoint(x: originX + corner, y: originY))
            path.addLine(to: CGPoint(x: originX + width - fold, y: originY))
            path.addLine(to: CGPoint(x: originX + width, y: originY + fold))
            path.addLine(to: CGPoint(x: originX + width, y: originY + height - corner))
            path.addQuadCurve(
                to: CGPoint(x: originX + width - corner, y: originY + height),
                control: CGPoint(x: originX + width, y: originY + height)
            )
            path.addLine(to: CGPoint(x: originX + corner, y: originY + height))
            path.addQuadCurve(
                to: CGPoint(x: originX, y: originY + height - corner),
                control: CGPoint(x: originX, y: originY + height)
            )
            path.addLine(to: CGPoint(x: originX, y: originY + corner))
            path.addQuadCurve(
                to: CGPoint(x: originX + corner, y: originY),
                control: CGPoint(x: originX, y: originY)
            )

            path.move(to: CGPoint(x: originX + width - fold, y: originY))
            path.addLine(to: CGPoint(x: originX + width - fold, y: originY + fold))
            path.addLine(to: CGPoint(x: originX + width, y: originY + fold))
        }
    }

    private var caretShape: some Shape {
        Path { path in
            let width = size * 0.10
            let height = size * 0.43
            let x = size * 0.47
            let y = size * 0.28

            path.addRoundedRect(
                in: CGRect(x: x, y: y, width: width, height: height),
                cornerSize: CGSize(width: width / 2, height: width / 2)
            )
        }
    }
}
