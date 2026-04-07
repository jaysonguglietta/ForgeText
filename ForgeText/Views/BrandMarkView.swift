import SwiftUI

struct BrandMarkView: View {
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.18),
                            Color(red: 0.22, green: 0.25, blue: 0.30),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

            pageShape
                .fill(Color(red: 0.96, green: 0.93, blue: 0.88))
                .shadow(color: .black.opacity(0.15), radius: size * 0.05, x: 0, y: size * 0.02)

            caretShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.50, blue: 0.27),
                            Color(red: 0.96, green: 0.28, blue: 0.16),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Rectangle()
                .fill(Color(red: 1.0, green: 0.50, blue: 0.27))
                .frame(width: size * 0.17, height: size * 0.09)
                .offset(x: -size * 0.03, y: -size * 0.1)
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

