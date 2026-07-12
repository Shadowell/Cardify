import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct TemplateCanvasView: View {
    private let template: TemplateDocument
    private let content: CardContent
    private let canvasSize: CanvasSize

    public init(template: TemplateDocument, content: CardContent, canvasSizeId: String? = nil) {
        self.template = template
        self.content = content
        self.canvasSize = template.canvasSizes.first(where: { $0.id == canvasSizeId }) ?? template.defaultCanvasSize
    }

    public var body: some View {
        GeometryReader { proxy in
            let scale = renderScale(in: proxy.size)
            ZStack {
                backgroundColor
                ForEach(template.layers) { layer in
                    render(layer, in: proxy.size, scale: scale)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: max(4, 18 * scale), style: .continuous))
        }
        .aspectRatio(CGFloat(canvasSize.width) / CGFloat(canvasSize.height), contentMode: .fit)
    }

    private var backgroundColor: Color {
        palette.paper
    }

    private var palette: CardPalette {
        CardPalette(theme: content.theme, tokens: template.tokens)
    }

    private func renderScale(in size: CGSize) -> CGFloat {
        min(
            size.width / CGFloat(canvasSize.width),
            size.height / CGFloat(canvasSize.height)
        )
    }

    @ViewBuilder
    private func render(_ layer: TemplateLayer, in size: CGSize, scale: CGFloat) -> some View {
        let rect = CGRect(
            x: size.width * layer.frame.x,
            y: size.height * layer.frame.y,
            width: size.width * layer.frame.width,
            height: size.height * layer.frame.height
        )

        switch layer.type {
        case .text:
            if !(layer.style.bool("hide_without_cover", default: false) && content.coverImageData == nil) {
                text(for: layer, scale: scale)
                    .frame(width: rect.width, height: rect.height, alignment: frameAlignment(for: layer))
                    .position(x: rect.midX, y: rect.midY)
            }
        case .image:
            imagePlaceholder(for: layer, scale: scale)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .avatar:
            avatar(for: layer, rect: rect, scale: scale)
        case .qr:
            QRPlaceholder(scale: scale)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .metrics:
            metrics(for: layer, scale: scale)
                .frame(width: rect.width, height: rect.height, alignment: .leading)
                .position(x: rect.midX, y: rect.midY)
        case .shape:
            shape(for: layer, scale: scale)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private func shape(for layer: TemplateLayer, scale: CGFloat) -> some View {
        let radius = layer.style.double("radius", default: 18) * scale
        let fillOpacity = layer.style.double("fill_opacity", default: 1)
        let pattern = layer.style.string("pattern", default: "")
        let patternColor = Color(hex: layer.style.string("pattern_color", default: "#000000")) ?? palette.ink
        let patternOpacity = layer.style.double("pattern_opacity", default: 0.1)
        let patternSpacing = layer.style.double("pattern_spacing", default: 36) * scale
        let stroke = layer.style.string("stroke", default: "")
        let strokeColor = Color(hex: stroke) ?? .clear
        let strokeWidth = layer.style.double("stroke_width", default: 1) * scale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return shape
            .fill(fillColor(for: layer).opacity(fillOpacity))
            .overlay {
                if !pattern.isEmpty {
                    TemplatePattern(
                        kind: pattern,
                        color: patternColor,
                        opacity: patternOpacity,
                        spacing: max(8, patternSpacing)
                    )
                    .clipShape(shape)
                }
            }
            .overlay {
                if !stroke.isEmpty {
                    shape.stroke(strokeColor, lineWidth: max(0.5, strokeWidth))
                }
            }
    }

    private func text(for layer: TemplateLayer, scale: CGFloat) -> some View {
        let value: String
        switch layer.role {
        case "title":
            value = content.title
        case "summary":
            value = content.summary
        case "tags":
            value = content.tags.joined(separator: " ")
        case "author_name":
            value = content.authorName
        default:
            value = layer.style.string("text", default: "")
        }

        let size = max(1, layer.style.double("font_size", default: 24) * scale)

        return Text(value)
            .font(.system(size: size, weight: fontWeight(for: layer), design: .default))
            .foregroundStyle(textColor(for: layer))
            .lineLimit(layer.maxLines)
            .minimumScaleFactor(0.72)
            .lineSpacing(max(0, (layer.style.double("line_height", default: 1.22) - 1) * size))
            .multilineTextAlignment(textAlignment(for: layer))
    }

    private func fontWeight(for layer: TemplateLayer) -> Font.Weight {
        switch layer.style.string("weight", default: "regular") {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        default: return .regular
        }
    }

    private func frameAlignment(for layer: TemplateLayer) -> Alignment {
        switch layer.style.string("alignment", default: "leading") {
        case "center": return .center
        case "trailing": return .topTrailing
        default: return .topLeading
        }
    }

    private func textAlignment(for layer: TemplateLayer) -> TextAlignment {
        switch layer.style.string("alignment", default: "leading") {
        case "center": return .center
        case "trailing": return .trailing
        default: return .leading
        }
    }

    private func textColor(for layer: TemplateLayer) -> Color {
        switch layer.style.string("color", default: "ink") {
        case "muted":
            return palette.muted
        case "paper":
            return .white
        default:
            let color = layer.style.string("color", default: "ink")
            return Color(hex: color) ?? palette.ink
        }
    }

    private func fillColor(for layer: TemplateLayer) -> Color {
        switch layer.style.string("fill", default: "paper") {
        case "paper": return palette.paper
        case "mint": return palette.accent
        case "sky": return palette.secondary
        case "pink": return palette.highlight
        case "gold": return palette.highlight
        case "ink": return palette.ink
        default:
            return Color(hex: layer.style.string("fill", default: "#FFFFFF")) ?? palette.paper
        }
    }

    private func imagePlaceholder(for layer: TemplateLayer, scale: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            coverImage(for: layer, scale: scale)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: layer.style.double("radius", default: 26) * scale,
                        style: .continuous
                    )
                )

            let badge = layer.style.string("badge", default: "")
            if !badge.isEmpty {
                Text(badge)
                    .font(.system(size: max(1, 12 * scale), weight: .semibold))
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 6 * scale)
                    .background(.black.opacity(0.35), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(12 * scale)
            }
        }
    }

    @ViewBuilder
    private func coverImage(for layer: TemplateLayer, scale: CGFloat) -> some View {
        #if canImport(UIKit)
        if let data = content.coverImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            coverPlaceholder(for: layer, scale: scale)
        }
        #else
        coverPlaceholder(for: layer, scale: scale)
        #endif
    }

    private func coverPlaceholder(for layer: TemplateLayer, scale: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            palette.secondary.opacity(0.74)

            TemplatePattern(
                kind: coverPattern,
                color: palette.paper,
                opacity: 0.58,
                spacing: max(12, 30 * scale)
            )

            VStack(alignment: .leading, spacing: 10 * scale) {
                Rectangle()
                    .fill(palette.highlight.opacity(0.9))
                    .frame(width: 42 * scale, height: 6 * scale)
                    .clipShape(Capsule())

                if layer.style.bool("content_title_when_empty", default: false) {
                    Text(content.title)
                        .font(.system(size: max(1, 36 * scale), weight: .bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(4)
                        .minimumScaleFactor(0.58)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(18 * scale)
        }
    }

    private var coverPattern: String {
        switch template.tokens.string("category", default: "") {
        case "知识卡": return "blueprint"
        case "分享卡": return "confetti"
        case "育儿": return "playful"
        case "营销": return "rays"
        case "视频卡": return "scanlines"
        case "旅行": return "contours"
        case "探店": return "checker"
        default: return "waves"
        }
    }

    @ViewBuilder
    private func avatar(for layer: TemplateLayer, rect: CGRect, scale: CGFloat) -> some View {
        let size = min(rect.width, rect.height)
        Circle()
            .fill(palette.accent)
            .overlay {
                #if canImport(UIKit)
                if let data = content.avatarImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(String(content.authorName.prefix(1)))
                        .font(.system(size: max(1, 17 * scale), weight: .bold))
                        .foregroundStyle(palette.ink)
                }
                #else
                Text(String(content.authorName.prefix(1)))
                    .font(.system(size: max(1, 17 * scale), weight: .bold))
                    .foregroundStyle(palette.ink)
                #endif
            }
            .clipShape(Circle())
            .frame(width: size, height: size)
            .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    private func metrics(for layer: TemplateLayer, scale: CGFloat) -> some View {
        if layer.style.string("orientation", default: "horizontal") == "vertical" {
            VStack(spacing: 12 * scale) {
                metricText("赞", value: content.metrics["likes"], scale: scale)
                metricText("评", value: content.metrics["comments"], scale: scale)
                metricText("藏", value: content.metrics["favorites"], scale: scale)
            }
            .foregroundStyle(.white)
        } else {
            HStack(spacing: 14 * scale) {
                metricText("赞", value: content.metrics["likes"], scale: scale)
                metricText("藏", value: content.metrics["favorites"], scale: scale)
                metricText("评", value: content.metrics["comments"], scale: scale)
            }
            .foregroundStyle(palette.muted)
        }
    }

    private func metricText(_ label: String, value: Int?, scale: CGFloat) -> some View {
        Text("\(label) \(value ?? 0)")
            .font(.system(size: max(1, 12 * scale), weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct CardPalette {
    let paper: Color
    let ink: Color
    let muted: Color
    let accent: Color
    let secondary: Color
    let highlight: Color

    init(theme: CardTheme, tokens: [String: JSONValue]) {
        if theme == .mint, let values = tokens.object("palette") {
            paper = Color(hex: values.string("paper", default: "#FFFFFD")) ?? .cardifyPaper
            ink = Color(hex: values.string("ink", default: "#14231F")) ?? .cardifyInk
            muted = Color(hex: values.string("muted", default: "#6F8079")) ?? .cardifyMuted
            accent = Color(hex: values.string("mint", default: "#DFF8EC")) ?? .cardifyMint
            secondary = Color(hex: values.string("sky", default: "#EAF7FF")) ?? .cardifySky
            highlight = Color(hex: values.string("pink", default: "#FFF0F3")) ?? .cardifyPink
            return
        }

        switch theme {
        case .mint:
            paper = .cardifyPaper
            ink = .cardifyInk
            muted = .cardifyMuted
            accent = .cardifyMint
            secondary = .cardifySky
            highlight = .cardifyPink
        case .sky:
            paper = Color(red: 0.98, green: 0.99, blue: 1)
            ink = .cardifyInk
            muted = .cardifyMuted
            accent = Color(red: 0.82, green: 0.92, blue: 1)
            secondary = Color(red: 0.87, green: 0.96, blue: 1)
            highlight = Color(red: 0.92, green: 0.91, blue: 1)
        case .blush:
            paper = Color(red: 1, green: 0.99, blue: 0.99)
            ink = .cardifyInk
            muted = .cardifyMuted
            accent = Color(red: 1, green: 0.87, blue: 0.9)
            secondary = Color(red: 1, green: 0.94, blue: 0.84)
            highlight = Color(red: 0.98, green: 0.9, blue: 0.95)
        case .gold:
            paper = Color(red: 1, green: 0.99, blue: 0.95)
            ink = .cardifyInk
            muted = .cardifyMuted
            accent = Color(red: 0.95, green: 0.88, blue: 0.67)
            secondary = Color(red: 0.91, green: 0.95, blue: 0.86)
            highlight = Color(red: 1, green: 0.92, blue: 0.84)
        case .ink:
            paper = Color(red: 0.09, green: 0.14, blue: 0.12)
            ink = .white
            muted = .white.opacity(0.72)
            accent = Color(red: 0.25, green: 0.54, blue: 0.43)
            secondary = Color(red: 0.17, green: 0.28, blue: 0.25)
            highlight = Color(red: 0.79, green: 0.72, blue: 0.42)
        }
    }
}

private struct TemplatePattern: View {
    let kind: String
    let color: Color
    let opacity: Double
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            switch kind {
            case "blueprint":
                drawGrid(context: context, size: size, lineColor: color.opacity(opacity), spacing: spacing)
                var y = spacing
                while y < size.height {
                    var x = spacing
                    while x < size.width {
                        let arm = max(2, spacing * 0.07)
                        var mark = Path()
                        mark.move(to: CGPoint(x: x - arm, y: y))
                        mark.addLine(to: CGPoint(x: x + arm, y: y))
                        mark.move(to: CGPoint(x: x, y: y - arm))
                        mark.addLine(to: CGPoint(x: x, y: y + arm))
                        context.stroke(mark, with: .color(color.opacity(opacity * 1.35)), lineWidth: 1)
                        x += spacing * 2
                    }
                    y += spacing * 2
                }
            case "confetti":
                var row: CGFloat = 0
                while row < size.height + spacing {
                    var column: CGFloat = 0
                    while column < size.width + spacing {
                        let offset = Int(row / spacing).isMultiple(of: 2) ? spacing * 0.22 : spacing * 0.58
                        let x = column + offset
                        let y = row + spacing * 0.35
                        var slash = Path()
                        slash.move(to: CGPoint(x: x - spacing * 0.09, y: y + spacing * 0.08))
                        slash.addLine(to: CGPoint(x: x + spacing * 0.1, y: y - spacing * 0.1))
                        context.stroke(slash, with: .color(color.opacity(opacity)), lineWidth: max(1, spacing * 0.035))
                        let dot = CGRect(x: x + spacing * 0.2, y: y - spacing * 0.12, width: max(2, spacing * 0.08), height: max(2, spacing * 0.08))
                        context.fill(Path(ellipseIn: dot), with: .color(color.opacity(opacity * 1.15)))
                        column += spacing
                    }
                    row += spacing
                }
            case "playful":
                var y = spacing * 0.4
                while y < size.height {
                    var x = spacing * 0.4
                    while x < size.width {
                        let tile = CGRect(x: x, y: y, width: spacing * 0.34, height: spacing * 0.22)
                        context.fill(
                            Path(roundedRect: tile, cornerRadius: spacing * 0.09),
                            with: .color(color.opacity(opacity * 0.75))
                        )
                        let center = CGPoint(x: x + spacing * 0.52, y: y + spacing * 0.12)
                        let arm = spacing * 0.09
                        var plus = Path()
                        plus.move(to: CGPoint(x: center.x - arm, y: center.y))
                        plus.addLine(to: CGPoint(x: center.x + arm, y: center.y))
                        plus.move(to: CGPoint(x: center.x, y: center.y - arm))
                        plus.addLine(to: CGPoint(x: center.x, y: center.y + arm))
                        context.stroke(plus, with: .color(color.opacity(opacity)), lineWidth: max(1, spacing * 0.025))
                        x += spacing
                    }
                    y += spacing
                }
            case "rays":
                let origin = CGPoint(x: size.width * 0.92, y: size.height * 0.12)
                let length = hypot(size.width, size.height) * 1.3
                var angle = -Double.pi * 0.95
                while angle < Double.pi * 0.7 {
                    let start = CGPoint(
                        x: origin.x + CGFloat(cos(angle - 0.03)) * length,
                        y: origin.y + CGFloat(sin(angle - 0.03)) * length
                    )
                    let end = CGPoint(
                        x: origin.x + CGFloat(cos(angle + 0.03)) * length,
                        y: origin.y + CGFloat(sin(angle + 0.03)) * length
                    )
                    var ray = Path()
                    ray.move(to: origin)
                    ray.addLine(to: start)
                    ray.addLine(to: end)
                    ray.closeSubpath()
                    context.fill(ray, with: .color(color.opacity(opacity * 0.55)))
                    angle += 0.2
                }
            case "scanlines":
                var y: CGFloat = 0
                while y < size.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(color.opacity(opacity)), lineWidth: 1)
                    y += max(4, spacing * 0.18)
                }
                var x = spacing * 0.5
                while x < size.width {
                    let marker = CGRect(x: x, y: spacing * 0.36, width: spacing * 0.3, height: max(2, spacing * 0.06))
                    context.fill(Path(roundedRect: marker, cornerRadius: 2), with: .color(color.opacity(opacity * 1.25)))
                    x += spacing * 1.55
                }
            case "contours":
                var baseline = -spacing * 0.2
                while baseline < size.height + spacing {
                    var line = Path()
                    line.move(to: CGPoint(x: -spacing, y: baseline))
                    var x = -spacing
                    while x < size.width + spacing {
                        let nextX = x + spacing * 0.5
                        let controlY = baseline + (Int((x + baseline) / spacing).isMultiple(of: 2) ? -spacing * 0.24 : spacing * 0.24)
                        line.addQuadCurve(to: CGPoint(x: nextX, y: baseline), control: CGPoint(x: x + spacing * 0.25, y: controlY))
                        x = nextX
                    }
                    context.stroke(line, with: .color(color.opacity(opacity)), lineWidth: 1)
                    baseline += spacing * 0.52
                }
            case "checker":
                let cell = max(10, spacing * 0.48)
                var row = 0
                var y: CGFloat = 0
                while y < size.height {
                    var column = 0
                    var x: CGFloat = 0
                    while x < size.width {
                        if (row + column).isMultiple(of: 2) {
                            context.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color(color.opacity(opacity * 0.78)))
                        }
                        column += 1
                        x += cell
                    }
                    row += 1
                    y += cell
                }
            case "waves":
                var baseline = spacing * 0.3
                while baseline < size.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: baseline))
                    var x: CGFloat = 0
                    while x < size.width {
                        let nextX = x + spacing
                        line.addCurve(
                            to: CGPoint(x: nextX, y: baseline),
                            control1: CGPoint(x: x + spacing * 0.25, y: baseline - spacing * 0.18),
                            control2: CGPoint(x: x + spacing * 0.75, y: baseline + spacing * 0.18)
                        )
                        x = nextX
                    }
                    context.stroke(line, with: .color(color.opacity(opacity)), lineWidth: max(1, spacing * 0.022))
                    baseline += spacing * 0.64
                }
            case "dots":
                var y: CGFloat = spacing / 2
                while y < size.height {
                    var x: CGFloat = spacing / 2
                    while x < size.width {
                        let dot = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                        context.fill(Path(ellipseIn: dot), with: .color(color.opacity(opacity)))
                        x += spacing
                    }
                    y += spacing
                }
            case "diagonal":
                var x = -size.height
                while x < size.width {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    context.stroke(line, with: .color(color.opacity(opacity)), lineWidth: 1)
                    x += spacing
                }
            default:
                drawGrid(context: context, size: size, lineColor: color.opacity(opacity), spacing: spacing)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, lineColor: Color, spacing: CGFloat) {
        var x: CGFloat = spacing
        while x < size.width {
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(lineColor), lineWidth: 1)
            x += spacing
        }
        var y: CGFloat = spacing
        while y < size.height {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(lineColor), lineWidth: 1)
            y += spacing
        }
    }
}

private struct QRPlaceholder: View {
    let scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height) / 7
            Canvas { context, _ in
                for row in 0..<7 {
                    for column in 0..<7 where (row + column) % 2 == 0 || row == 0 || column == 0 || row == 6 || column == 6 {
                        let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell * 0.72, height: cell * 0.72)
                        context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.1), with: .color(.cardifyInk))
                    }
                }
            }
        }
        .padding(8 * scale)
        .background(.white, in: RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
    }
}

public extension Color {
    static let cardifyInk = Color(red: 0.08, green: 0.14, blue: 0.12)
    static let cardifyMuted = Color(red: 0.44, green: 0.50, blue: 0.48)
    static let cardifyPaper = Color(red: 1, green: 1, blue: 0.99)
    static let cardifyMint = Color(red: 0.87, green: 0.97, blue: 0.92)
    static let cardifySky = Color(red: 0.92, green: 0.97, blue: 1)
    static let cardifyPink = Color(red: 1, green: 0.94, blue: 0.96)
    static let cardifyNavActive = Color(red: 0.12, green: 0.60, blue: 0.45)
    static let cardifyNavInactive = Color(red: 0.43, green: 0.52, blue: 0.49)

    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let integer = Int(value, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((integer >> 16) & 0xFF) / 255,
            green: Double((integer >> 8) & 0xFF) / 255,
            blue: Double(integer & 0xFF) / 255
        )
    }
}

#if canImport(UIKit)
public enum CardImageRenderer {
    @MainActor
    public static func render(
        template: TemplateDocument,
        content: CardContent,
        canvasSizeId: String
    ) -> UIImage? {
        guard let canvasSize = template.canvasSizes.first(where: { $0.id == canvasSizeId }) else {
            return nil
        }

        let view = TemplateCanvasView(
            template: template,
            content: content,
            canvasSizeId: canvasSize.id
        )
        .frame(width: CGFloat(canvasSize.width), height: CGFloat(canvasSize.height))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }
}
#endif
