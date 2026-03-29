import LayoutRecallKit
import SwiftUI

private struct IconGrid {
    let rect: CGRect

    private var side: CGFloat {
        min(rect.width, rect.height)
    }

    private var origin: CGPoint {
        CGPoint(
            x: rect.midX - (side / 2),
            y: rect.midY - (side / 2)
        )
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + ((x / 20) * side),
            y: origin.y + ((y / 20) * side)
        )
    }

    func length(_ value: CGFloat) -> CGFloat {
        (value / 20) * side
    }

    func frame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            origin: point(x, y),
            size: CGSize(width: length(width), height: length(height))
        )
    }
}

private struct BackDisplayShape: Shape {
    func path(in rect: CGRect) -> Path {
        let grid = IconGrid(rect: rect)
        return Path(
            roundedRect: grid.frame(x: 8.8, y: 3.8, width: 7.6, height: 5.8),
            cornerRadius: grid.length(1.7)
        )
    }
}

private struct FrontDisplayShape: Shape {
    func path(in rect: CGRect) -> Path {
        let grid = IconGrid(rect: rect)
        return Path(
            roundedRect: grid.frame(x: 2.6, y: 8.9, width: 10.4, height: 7.0),
            cornerRadius: grid.length(2.05)
        )
    }
}

private struct FrontDisplayDetailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let grid = IconGrid(rect: rect)
        var path = Path()
        path.move(to: grid.point(5.3, 10.7))
        path.addLine(to: grid.point(9.7, 10.7))
        return path
    }
}

private struct RecallCornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let grid = IconGrid(rect: rect)
        var path = Path()
        path.move(to: grid.point(4.9, 7.1))
        path.addLine(to: grid.point(4.9, 2.5))
        path.addLine(to: grid.point(11.0, 2.5))
        return path
    }
}

private struct RecallNodeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let grid = IconGrid(rect: rect)
        return Path(
            ellipseIn: CGRect(
                x: grid.point(3.85, 1.45).x,
                y: grid.point(3.85, 1.45).y,
                width: grid.length(2.1),
                height: grid.length(2.1)
            )
        )
    }
}

private enum IconPalette {
    static let ink = Color(red: 0.03, green: 0.07, blue: 0.10)
    static let slate = Color(red: 0.09, green: 0.16, blue: 0.23)
    static let cyan = Color(red: 0.35, green: 0.85, blue: 1.00)
    static let teal = Color(red: 0.14, green: 0.67, blue: 0.77)
    static let amber = Color(red: 1.00, green: 0.73, blue: 0.24)
    static let cream = Color(red: 0.96, green: 0.98, blue: 1.00)
}

struct LayoutRecallSymbol: View {
    enum Tone {
        case template
        case brand
    }

    var tone: Tone = .template
    var lineWidth: CGFloat = 2

    private var frontFill: AnyShapeStyle {
        switch tone {
        case .template:
            return AnyShapeStyle(Color.primary.opacity(0.04))
        case .brand:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        IconPalette.slate.opacity(0.88),
                        IconPalette.ink.opacity(0.74)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var frontStroke: Color {
        switch tone {
        case .template:
            return .primary
        case .brand:
            return IconPalette.cream.opacity(0.98)
        }
    }

    private var backFill: AnyShapeStyle {
        switch tone {
        case .template:
            return AnyShapeStyle(Color.primary.opacity(0.16))
        case .brand:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        IconPalette.cyan.opacity(0.34),
                        IconPalette.teal.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var backStroke: Color {
        switch tone {
        case .template:
            return Color.primary.opacity(0.56)
        case .brand:
            return Color.white.opacity(0.36)
        }
    }

    private var accentColor: Color {
        switch tone {
        case .template:
            return .primary
        case .brand:
            return IconPalette.amber
        }
    }

    private var detailColor: Color {
        switch tone {
        case .template:
            return Color.clear
        case .brand:
            return Color.white.opacity(0.14)
        }
    }

    private var displayStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }

    private var accentStrokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: lineWidth * 1.18,
            lineCap: .round,
            lineJoin: .round
        )
    }

    var body: some View {
        ZStack {
            BackDisplayShape()
                .fill(backFill)
                .shadow(
                    color: tone == .brand ? IconPalette.cyan.opacity(0.12) : .clear,
                    radius: tone == .brand ? lineWidth * 1.6 : 0
                )

            BackDisplayShape()
                .stroke(backStroke, style: displayStrokeStyle)

            FrontDisplayShape()
                .fill(frontFill)
                .shadow(
                    color: tone == .brand ? Color.black.opacity(0.22) : .clear,
                    radius: tone == .brand ? lineWidth * 1.4 : 0,
                    y: tone == .brand ? lineWidth * 0.45 : 0
                )

            FrontDisplayShape()
                .stroke(frontStroke, style: displayStrokeStyle)

            FrontDisplayDetailShape()
                .stroke(detailColor, style: StrokeStyle(lineWidth: lineWidth * 0.8, lineCap: .round))

            RecallCornerShape()
                .stroke(accentColor, style: accentStrokeStyle)

            RecallNodeShape()
                .fill(accentColor)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct LayoutRecallMenuBarIcon: View {
    var body: some View {
        LayoutRecallSymbol(tone: .template, lineWidth: 1.75)
            .frame(width: 18, height: 18)
            .accessibilityLabel(L10n.t("app.name"))
    }
}

struct LayoutRecallHeaderIcon: View {
    var dimension: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: dimension * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            IconPalette.slate,
                            IconPalette.ink
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: dimension * 0.32, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    IconPalette.cyan.opacity(0.38),
                                    .clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: dimension * 0.8
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: dimension * 0.32, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    IconPalette.amber.opacity(0.12),
                                    .clear
                                ],
                                center: .bottomTrailing,
                                startRadius: 0,
                                endRadius: dimension * 0.6
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: dimension * 0.32, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: dimension * 0.2, y: dimension * 0.08)

            LayoutRecallSymbol(tone: .brand, lineWidth: max(1.8, dimension * 0.065))
                .padding(dimension * 0.16)
        }
        .frame(width: dimension, height: dimension)
    }
}
