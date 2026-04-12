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
    static let mutedInk = Color(red: 0.24, green: 0.30, blue: 0.40)
    static let railFill = Color(red: 0.91, green: 0.89, blue: 0.80)
    static let paperLine = Color(red: 0.26, green: 0.36, blue: 0.55).opacity(0.08)
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
                    colors: [RetroPalette.chromeBlue, RetroPalette.chromeTeal, RetroPalette.chromeCyan.opacity(0.88)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 84)

                Spacer(minLength: 0)
            }

            Canvas { context, size in
                let dotColor = GraphicsContext.Shading.color(RetroPalette.chromeBlue.opacity(0.045))
                for x in stride(from: 12.0, through: size.width, by: 22.0) {
                    for y in stride(from: 102.0, through: size.height, by: 22.0) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: dotColor)
                    }
                }
            }

            Canvas { context, size in
                let lineColor = GraphicsContext.Shading.color(RetroPalette.paperLine)
                for y in stride(from: 98.0, through: size.height, by: 28.0) {
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: lineColor)
                }
            }

            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Rectangle().fill(RetroPalette.chromeGold.opacity(0.92))
                    Rectangle().fill(RetroPalette.chromePink.opacity(0.86))
                    Rectangle().fill(RetroPalette.chromeCyan.opacity(0.86))
                    Rectangle().fill(RetroPalette.chromeGold.opacity(0.92))
                    Rectangle().fill(RetroPalette.chromePink.opacity(0.86))
                }
                .frame(height: 5)

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
        .shadow(color: .black.opacity(inset ? 0.0 : 0.10), radius: 0, x: 1, y: 1)
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
            .padding(.vertical, 7)
            .frame(minHeight: 28)
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
                pressed ? RetroPalette.panelFillMuted : RetroPalette.panelFillMuted,
                RetroPalette.chromeTeal,
                RetroPalette.ink
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
            .padding(.vertical, 7)
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

struct RetroSectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var accent: Color = RetroPalette.chromeBlue

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
            }

            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(RetroPalette.ink)

            Rectangle()
                .fill(accent.opacity(0.75))
                .frame(height: 2)

            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .retroPanel(fill: RetroPalette.panelFill, accent: accent)
    }
}

struct RetroIconButtonStyle: ButtonStyle {
    var accent: Color = RetroPalette.chromeTeal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.ink)
            .padding(6)
            .background(
                RetroPanelBackground(
                    fill: configuration.isPressed ? RetroPalette.panelFillMuted : RetroPalette.fieldFill,
                    accent: accent,
                    inset: configuration.isPressed
                )
            )
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
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
