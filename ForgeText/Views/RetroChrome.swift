import SwiftUI

enum RetroPalette {
    static let pageCream = Color(red: 0.96, green: 0.94, blue: 0.82)
    static let pageTan = Color(red: 0.90, green: 0.86, blue: 0.72)
    static let chromeBlue = Color(red: 0.05, green: 0.23, blue: 0.48)
    static let chromeTeal = Color(red: 0.00, green: 0.53, blue: 0.53)
    static let chromeCyan = Color(red: 0.09, green: 0.74, blue: 0.90)
    static let chromePink = Color(red: 0.86, green: 0.17, blue: 0.47)
    static let chromeGold = Color(red: 0.99, green: 0.78, blue: 0.18)
    static let panelFill = Color(red: 0.93, green: 0.91, blue: 0.83)
    static let panelFillMuted = Color(red: 0.88, green: 0.86, blue: 0.79)
    static let fieldFill = Color.white.opacity(0.92)
    static let pressedFill = Color(red: 0.79, green: 0.82, blue: 0.86)
    static let ink = Color(red: 0.06, green: 0.11, blue: 0.24)
    static let shadow = Color(red: 0.18, green: 0.22, blue: 0.32)
    static let brightEdge = Color.white.opacity(0.92)
    static let darkEdge = Color.black.opacity(0.45)
    static let link = Color(red: 0.00, green: 0.20, blue: 0.66)
    static let visited = Color(red: 0.42, green: 0.12, blue: 0.53)
    static let success = Color(red: 0.08, green: 0.49, blue: 0.22)
    static let warning = Color(red: 0.74, green: 0.42, blue: 0.02)
    static let danger = Color(red: 0.67, green: 0.13, blue: 0.19)
}

struct RetroBackdropView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RetroPalette.pageCream, RetroPalette.pageTan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [RetroPalette.chromeBlue, RetroPalette.chromeTeal, RetroPalette.chromeCyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 118)

                Spacer(minLength: 0)
            }

            Canvas { context, size in
                let dotColor = GraphicsContext.Shading.color(RetroPalette.chromeBlue.opacity(0.07))
                for x in stride(from: 10.0, through: size.width, by: 18.0) {
                    for y in stride(from: 136.0, through: size.height, by: 18.0) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: dotColor)
                    }
                }
            }

            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Rectangle().fill(RetroPalette.chromeGold)
                    Rectangle().fill(RetroPalette.chromePink)
                    Rectangle().fill(RetroPalette.chromeCyan)
                    Rectangle().fill(RetroPalette.chromeGold)
                    Rectangle().fill(RetroPalette.chromePink)
                }
                .frame(height: 6)

                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea()
    }
}

struct RetroPanelBackground: View {
    var fill: Color = RetroPalette.panelFill
    var accent: Color = RetroPalette.chromeBlue
    var inset: Bool = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(fill)

            Rectangle()
                .stroke(accent.opacity(0.82), lineWidth: 1)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(inset ? RetroPalette.darkEdge : RetroPalette.brightEdge)
                    .frame(height: 1)
                Spacer(minLength: 0)
                Rectangle()
                    .fill(inset ? RetroPalette.brightEdge : RetroPalette.darkEdge)
                    .frame(height: 1)
            }

            HStack(spacing: 0) {
                Rectangle()
                    .fill(inset ? RetroPalette.darkEdge : RetroPalette.brightEdge)
                    .frame(width: 1)
                Spacer(minLength: 0)
                Rectangle()
                    .fill(inset ? RetroPalette.brightEdge : RetroPalette.darkEdge)
                    .frame(width: 1)
            }
        }
        .shadow(color: .black.opacity(inset ? 0.0 : 0.12), radius: 0, x: 2, y: 2)
    }
}

struct RetroActionButtonStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
        case accent
        case danger
    }

    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        let palette = palette(for: tone, pressed: configuration.isPressed)

        return configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(palette.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 30)
            .background(
                RetroPanelBackground(
                    fill: palette.fill,
                    accent: palette.accent,
                    inset: configuration.isPressed
                )
            )
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
    }

    private func palette(for tone: Tone, pressed: Bool) -> (fill: Color, accent: Color, text: Color) {
        switch tone {
        case .primary:
            return (
                pressed ? RetroPalette.pressedFill : RetroPalette.panelFill,
                RetroPalette.chromeBlue,
                RetroPalette.ink
            )
        case .secondary:
            return (
                pressed ? RetroPalette.panelFillMuted : RetroPalette.fieldFill,
                RetroPalette.chromeTeal,
                RetroPalette.link
            )
        case .accent:
            return (
                pressed ? RetroPalette.chromeBlue.opacity(0.78) : RetroPalette.chromeCyan.opacity(0.78),
                RetroPalette.chromeBlue,
                Color.white
            )
        case .danger:
            return (
                pressed ? RetroPalette.danger.opacity(0.90) : RetroPalette.danger.opacity(0.78),
                RetroPalette.shadow,
                Color.white
            )
        }
    }
}

struct RetroTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RetroPanelBackground(
                    fill: RetroPalette.fieldFill,
                    accent: RetroPalette.chromeTeal,
                    inset: true
                )
            )
            .foregroundStyle(RetroPalette.ink)
    }
}

struct RetroCapsuleLabel: View {
    let text: String
    var accent: Color = RetroPalette.chromePink

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RetroPanelBackground(
                    fill: RetroPalette.fieldFill,
                    accent: accent,
                    inset: true
                )
            )
    }
}

struct RetroRule: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [RetroPalette.chromePink, RetroPalette.chromeGold, RetroPalette.chromeCyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 3)
    }
}

extension View {
    func retroPanel(fill: Color = RetroPalette.panelFill, accent: Color = RetroPalette.chromeBlue) -> some View {
        background(RetroPanelBackground(fill: fill, accent: accent))
    }

    func retroInsetPanel(fill: Color = RetroPalette.fieldFill, accent: Color = RetroPalette.chromeTeal) -> some View {
        background(RetroPanelBackground(fill: fill, accent: accent, inset: true))
    }

    func retroTextField() -> some View {
        modifier(RetroTextFieldModifier())
    }

    func retroDialogScaffold() -> some View {
        ZStack {
            RetroBackdropView()
            self
                .padding(24)
        }
    }
}
