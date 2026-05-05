import SwiftUI

private struct RetroChromeStyleKey: EnvironmentKey {
    static let defaultValue: AppChromeStyle = .studio
}

private struct RetroDensityKey: EnvironmentKey {
    static let defaultValue: InterfaceDensity = .compact
}

extension EnvironmentValues {
    var retroChromeStyle: AppChromeStyle {
        get { self[RetroChromeStyleKey.self] }
        set { self[RetroChromeStyleKey.self] = newValue }
    }

    var retroDensity: InterfaceDensity {
        get { self[RetroDensityKey.self] }
        set { self[RetroDensityKey.self] = newValue }
    }
}

struct RetroMetrics {
    let panelPadding: CGFloat
    let controlHorizontalPadding: CGFloat
    let controlVerticalPadding: CGFloat
    let sectionSpacing: CGFloat

    static func metrics(for density: InterfaceDensity) -> RetroMetrics {
        switch density {
        case .comfortable:
            return RetroMetrics(panelPadding: 16, controlHorizontalPadding: 12, controlVerticalPadding: 7, sectionSpacing: 16)
        case .compact:
            return RetroMetrics(panelPadding: 12, controlHorizontalPadding: 10, controlVerticalPadding: 6, sectionSpacing: 12)
        case .dense:
            return RetroMetrics(panelPadding: 9, controlHorizontalPadding: 8, controlVerticalPadding: 4, sectionSpacing: 8)
        }
    }
}

enum RetroPalette {
    static let studioCanvas = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let studioCanvasMuted = Color(red: 0.91, green: 0.93, blue: 0.96)
    static let studioRail = Color(red: 0.88, green: 0.90, blue: 0.94)
    static let studioPanel = Color(red: 0.97, green: 0.98, blue: 0.99)
    static let studioPanelMuted = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let studioField = Color.white
    static let studioBorder = Color(red: 0.79, green: 0.82, blue: 0.88)
    static let studioDivider = Color(red: 0.82, green: 0.85, blue: 0.90)
    static let studioAccent = Color(red: 0.11, green: 0.38, blue: 0.78)
    static let studioAccentMuted = Color(red: 0.34, green: 0.50, blue: 0.79)
    static let pageCream = Color(red: 0.95, green: 0.93, blue: 0.84)
    static let pageTan = Color(red: 0.88, green: 0.85, blue: 0.75)
    static let chromeBlue = Color(red: 0.07, green: 0.20, blue: 0.38)
    static let chromeTeal = Color(red: 0.05, green: 0.42, blue: 0.43)
    static let chromeCyan = Color(red: 0.13, green: 0.58, blue: 0.68)
    static let chromePink = Color(red: 0.60, green: 0.18, blue: 0.34)
    static let chromeGold = Color(red: 0.80, green: 0.62, blue: 0.20)
    static let panelFill = Color(red: 0.91, green: 0.89, blue: 0.81)
    static let panelFillMuted = Color(red: 0.86, green: 0.84, blue: 0.77)
    static let fieldFill = Color(red: 0.98, green: 0.97, blue: 0.92)
    static let pressedFill = Color(red: 0.79, green: 0.82, blue: 0.86)
    static let ink = Color(red: 0.06, green: 0.11, blue: 0.24)
    static let shadow = Color(red: 0.18, green: 0.22, blue: 0.32)
    static let brightEdge = Color.white.opacity(0.70)
    static let darkEdge = Color.black.opacity(0.28)
    static let link = Color(red: 0.04, green: 0.22, blue: 0.52)
    static let visited = Color(red: 0.32, green: 0.18, blue: 0.44)
    static let success = Color(red: 0.08, green: 0.49, blue: 0.22)
    static let warning = Color(red: 0.74, green: 0.42, blue: 0.02)
    static let danger = Color(red: 0.67, green: 0.13, blue: 0.19)
    static let mutedInk = Color(red: 0.24, green: 0.30, blue: 0.40)
    static let railFill = Color(red: 0.88, green: 0.86, blue: 0.78)
    static let paperLine = Color(red: 0.26, green: 0.36, blue: 0.55).opacity(0.035)
}

struct RetroBackdropView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle

    var body: some View {
        ZStack {
            backgroundGradient

            if chromeStyle == .studio {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: headerColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: headerHeight)

                    Rectangle()
                        .fill(RetroPalette.studioDivider)
                        .frame(height: 1)

                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: headerColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: headerHeight)

                    Spacer(minLength: 0)
                }
            }

            if chromeStyle == .retroClassic {
                Canvas { context, size in
                    let dotColor = GraphicsContext.Shading.color(RetroPalette.chromeBlue.opacity(dotOpacity))
                    for x in stride(from: 12.0, through: size.width, by: 22.0) {
                        for y in stride(from: 86.0, through: size.height, by: 28.0) {
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: dotColor)
                        }
                    }
                }
            }

            if chromeStyle == .retroClassic {
                Canvas { context, size in
                    let lineColor = GraphicsContext.Shading.color(RetroPalette.paperLine)
                    for y in stride(from: 86.0, through: size.height, by: 34.0) {
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: lineColor)
                    }
                }
            } else if chromeStyle != .studio {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(RetroPalette.chromeBlue.opacity(chromeStyle == .retroPro ? 0.10 : 0.06))
                        .frame(height: chromeStyle == .retroPro ? 1 : 0.5)
                    Spacer(minLength: 0)
                }

                VStack {
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [
                            Color.clear,
                            RetroPalette.chromeTeal.opacity(chromeStyle == .retroPro ? 0.035 : 0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: chromeStyle == .retroPro ? 160 : 110)
                }
            }

            if chromeStyle != .studio {
                VStack(spacing: 0) {
                    HStack(spacing: 7) {
                        Rectangle().fill(RetroPalette.chromeGold.opacity(0.54))
                        Rectangle().fill(RetroPalette.chromePink.opacity(chromeStyle == .retroClassic ? 0.68 : 0.42))
                        Rectangle().fill(RetroPalette.chromeCyan.opacity(0.46))
                    }
                    .frame(height: chromeStyle == .minimalPro ? 1 : 3)

                    Spacer(minLength: 0)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundGradient: LinearGradient {
        switch chromeStyle {
        case .studio:
            return LinearGradient(
                colors: [RetroPalette.studioCanvas, RetroPalette.studioCanvasMuted],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .retroClassic:
            return LinearGradient(colors: [RetroPalette.pageCream, RetroPalette.pageTan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .retroPro:
            return LinearGradient(colors: [RetroPalette.pageCream, RetroPalette.pageTan.opacity(0.86)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minimalPro:
            return LinearGradient(colors: [RetroPalette.pageCream.opacity(0.94), RetroPalette.panelFillMuted.opacity(0.86)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var headerColors: [Color] {
        switch chromeStyle {
        case .studio:
            return [RetroPalette.studioRail, RetroPalette.studioCanvasMuted]
        case .retroClassic:
            return [RetroPalette.chromeBlue, RetroPalette.chromeTeal, RetroPalette.chromeCyan.opacity(0.82)]
        case .retroPro:
            return [RetroPalette.chromeBlue.opacity(0.92), RetroPalette.chromeTeal.opacity(0.82)]
        case .minimalPro:
            return [RetroPalette.chromeBlue.opacity(0.44), RetroPalette.chromeTeal.opacity(0.32)]
        }
    }

    private var headerHeight: CGFloat {
        switch chromeStyle {
        case .studio:
            return 8
        case .retroClassic:
            return 74
        case .retroPro:
            return 56
        case .minimalPro:
            return 34
        }
    }

    private var dotOpacity: Double {
        chromeStyle == .retroClassic ? 0.05 : 0.022
    }
}

struct RetroPanelBackground: View {
    @Environment(\.retroChromeStyle) private var chromeStyle

    var fill: Color = RetroPalette.panelFill
    var accent: Color = RetroPalette.chromeBlue
    var inset: Bool = false

    var body: some View {
        Group {
            if chromeStyle == .studio {
                RoundedRectangle(cornerRadius: inset ? 8 : 10, style: .continuous)
                    .fill(inset ? RetroPalette.studioField : RetroPalette.studioPanel)
                    .overlay(
                        RoundedRectangle(cornerRadius: inset ? 8 : 10, style: .continuous)
                            .stroke(RetroPalette.studioBorder, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: inset ? 8 : 10, style: .continuous)
                            .stroke(accent.opacity(inset ? 0.18 : 0.10), lineWidth: 1)
                    )
            } else {
                ZStack {
                    Rectangle()
                        .fill(fill)

                    Rectangle()
                        .stroke(accent.opacity(borderOpacity), lineWidth: 1)

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
                .shadow(color: .black.opacity(inset ? 0.0 : shadowOpacity), radius: 0, x: 1, y: 1)
            }
        }
    }

    private var borderOpacity: Double {
        switch chromeStyle {
        case .studio:
            return 0.18
        case .retroClassic:
            return 0.82
        case .retroPro:
            return 0.44
        case .minimalPro:
            return inset ? 0.20 : 0.26
        }
    }

    private var shadowOpacity: Double {
        switch chromeStyle {
        case .studio:
            return 0.0
        case .retroClassic:
            return 0.10
        case .retroPro:
            return 0.045
        case .minimalPro:
            return 0.0
        }
    }
}

struct RetroActionButtonStyle: ButtonStyle {
    @Environment(\.retroDensity) private var density
    @Environment(\.retroChromeStyle) private var chromeStyle

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
            .tracking(0.2)
            .foregroundStyle(palette.text)
            .padding(.horizontal, RetroMetrics.metrics(for: density).controlHorizontalPadding)
            .padding(.vertical, RetroMetrics.metrics(for: density).controlVerticalPadding)
            .frame(minHeight: 26)
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
        if chromeStyle == .studio {
            switch tone {
            case .primary:
                return (
                    pressed ? RetroPalette.studioPanelMuted : RetroPalette.studioPanel,
                    RetroPalette.studioAccentMuted,
                    RetroPalette.ink
                )
            case .secondary:
                return (
                    pressed ? RetroPalette.studioPanelMuted : RetroPalette.studioField,
                    RetroPalette.studioDivider,
                    RetroPalette.ink
                )
            case .accent:
                return (
                    pressed ? RetroPalette.studioAccent.opacity(0.88) : RetroPalette.studioAccent,
                    RetroPalette.studioAccent,
                    Color.white
                )
            case .danger:
                return (
                    pressed ? RetroPalette.danger.opacity(0.90) : RetroPalette.danger.opacity(0.82),
                    RetroPalette.danger,
                    Color.white
                )
            }
        }

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
                pressed ? RetroPalette.chromeBlue.opacity(0.74) : RetroPalette.chromeTeal.opacity(0.72),
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
    @Environment(\.retroDensity) private var density
    @Environment(\.retroChromeStyle) private var chromeStyle

    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: chromeStyle == .studio ? .regular : .medium, design: .monospaced))
            .padding(.horizontal, RetroMetrics.metrics(for: density).controlHorizontalPadding)
            .padding(.vertical, RetroMetrics.metrics(for: density).controlVerticalPadding)
            .background(
                RetroPanelBackground(
                    fill: chromeStyle == .studio ? RetroPalette.studioField : RetroPalette.fieldFill,
                    accent: chromeStyle == .studio ? RetroPalette.studioAccentMuted : RetroPalette.chromeTeal,
                    inset: true
                )
            )
            .foregroundStyle(RetroPalette.ink)
    }
}

struct RetroCapsuleLabel: View {
    @Environment(\.retroDensity) private var density
    @Environment(\.retroChromeStyle) private var chromeStyle

    let text: String
    var accent: Color = RetroPalette.chromePink

    var body: some View {
        Text(chromeStyle == .studio ? text : text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(chromeStyle == .studio ? 0.1 : 0.35)
            .foregroundStyle(accent)
            .padding(.horizontal, max(6, RetroMetrics.metrics(for: density).controlHorizontalPadding - 2))
            .padding(.vertical, max(2, RetroMetrics.metrics(for: density).controlVerticalPadding - 3))
            .background(
                RetroPanelBackground(
                    fill: chromeStyle == .studio ? RetroPalette.studioField : RetroPalette.fieldFill,
                    accent: accent,
                    inset: true
                )
            )
    }
}

struct RetroRule: View {
    @Environment(\.retroChromeStyle) private var chromeStyle

    var body: some View {
        Rectangle()
            .fill(chromeStyle == .studio ? AnyShapeStyle(colors.first ?? RetroPalette.studioDivider) : AnyShapeStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            ))
            .frame(height: chromeStyle == .retroClassic ? 2 : 1)
    }

    private var colors: [Color] {
        switch chromeStyle {
        case .studio:
            return [RetroPalette.studioDivider]
        case .retroClassic:
            return [RetroPalette.chromePink.opacity(0.72), RetroPalette.chromeGold.opacity(0.72), RetroPalette.chromeCyan.opacity(0.72)]
        case .retroPro:
            return [RetroPalette.chromeBlue.opacity(0.28), RetroPalette.chromeTeal.opacity(0.24)]
        case .minimalPro:
            return [RetroPalette.chromeBlue.opacity(0.13), RetroPalette.chromeBlue.opacity(0.08)]
        }
    }
}

struct RetroSectionHeader: View {
    @Environment(\.retroDensity) private var density
    @Environment(\.retroChromeStyle) private var chromeStyle

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
                .tracking(chromeStyle == .studio ? 0.35 : 0.8)
                .foregroundStyle(RetroPalette.ink)

            Rectangle()
                .fill(accent.opacity(0.28))
                .frame(height: 1)
        }
        .padding(.horizontal, RetroMetrics.metrics(for: density).controlHorizontalPadding)
        .padding(.vertical, RetroMetrics.metrics(for: density).controlVerticalPadding)
        .retroPanel(
            fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted,
            accent: chromeStyle == .studio ? RetroPalette.studioAccentMuted : accent
        )
    }
}

struct RetroIconButtonStyle: ButtonStyle {
    @Environment(\.retroDensity) private var density
    @Environment(\.retroChromeStyle) private var chromeStyle

    var accent: Color = RetroPalette.chromeTeal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.ink)
            .padding(max(4, RetroMetrics.metrics(for: density).controlVerticalPadding))
            .background(
                RetroPanelBackground(
                    fill: chromeStyle == .studio
                        ? (configuration.isPressed ? RetroPalette.studioPanelMuted : RetroPalette.studioField)
                        : (configuration.isPressed ? RetroPalette.panelFillMuted : RetroPalette.fieldFill),
                    accent: chromeStyle == .studio ? RetroPalette.studioAccentMuted : accent,
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

    func retroChrome(style: AppChromeStyle, density: InterfaceDensity) -> some View {
        environment(\.retroChromeStyle, style)
            .environment(\.retroDensity, density)
    }
}
