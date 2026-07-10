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
            ZStack {
                backgroundColor
                ForEach(template.layers) { layer in
                    render(layer, in: proxy.size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .aspectRatio(CGFloat(canvasSize.width) / CGFloat(canvasSize.height), contentMode: .fit)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var backgroundColor: Color {
        palette.paper
    }

    private var palette: CardPalette {
        CardPalette(theme: content.theme)
    }

    @ViewBuilder
    private func render(_ layer: TemplateLayer, in size: CGSize) -> some View {
        let rect = CGRect(
            x: size.width * layer.frame.x,
            y: size.height * layer.frame.y,
            width: size.width * layer.frame.width,
            height: size.height * layer.frame.height
        )

        switch layer.type {
        case .text:
            text(for: layer)
                .frame(width: rect.width, height: rect.height, alignment: .topLeading)
                .position(x: rect.midX, y: rect.midY)
        case .image:
            imagePlaceholder(for: layer)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .avatar:
            avatar(for: layer, rect: rect)
        case .qr:
            QRPlaceholder()
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .metrics:
            metrics(for: layer)
                .frame(width: rect.width, height: rect.height, alignment: .leading)
                .position(x: rect.midX, y: rect.midY)
        case .shape:
            RoundedRectangle(cornerRadius: layer.style.double("radius", default: 18), style: .continuous)
                .fill(fillColor(for: layer))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private func text(for layer: TemplateLayer) -> some View {
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
            value = ""
        }

        let size = layer.style.double("font_size", default: 24)
        let weight = layer.style.string("weight", default: "regular")

        return Text(value)
            .font(.system(size: size, weight: weight == "bold" ? .bold : .regular, design: .default))
            .foregroundStyle(textColor(for: layer))
            .lineLimit(layer.maxLines)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(.leading)
    }

    private func textColor(for layer: TemplateLayer) -> Color {
        switch layer.style.string("color", default: "ink") {
        case "muted":
            return content.theme == .ink ? .white.opacity(0.72) : .cardifyMuted
        case "paper":
            return .white
        default:
            return content.theme == .ink ? .white : .cardifyInk
        }
    }

    private func fillColor(for layer: TemplateLayer) -> Color {
        switch layer.style.string("fill", default: "paper") {
        case "paper": return palette.paper
        case "mint": return palette.accent
        case "sky": return palette.secondary
        case "pink": return palette.highlight
        case "ink": return Color.cardifyInk
        default:
            return Color(hex: layer.style.string("fill", default: "#FFFFFF")) ?? palette.paper
        }
    }

    private func imagePlaceholder(for layer: TemplateLayer) -> some View {
        ZStack(alignment: .bottomTrailing) {
            coverImage
                .clipShape(RoundedRectangle(cornerRadius: layer.style.double("radius", default: 26), style: .continuous))

            Text("共3张")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.35), in: Capsule())
                .foregroundStyle(.white)
                .padding(12)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        #if canImport(UIKit)
        if let data = content.coverImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            coverPlaceholder
        }
        #else
        coverPlaceholder
        #endif
    }

    private var coverPlaceholder: some View {
        LinearGradient(
            colors: [palette.accent, palette.secondary, palette.highlight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .bottomLeading) {
            Text(template.tokens.string("category", default: "Cardify"))
                .font(.caption.weight(.bold))
                .foregroundStyle(content.theme == .ink ? Color.white.opacity(0.72) : Color.cardifyInk.opacity(0.62))
                .padding(16)
        }
    }

    @ViewBuilder
    private func avatar(for layer: TemplateLayer, rect: CGRect) -> some View {
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
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.cardifyInk)
                }
                #else
                Text(String(content.authorName.prefix(1)))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.cardifyInk)
                #endif
            }
            .clipShape(Circle())
            .frame(width: size, height: size)
            .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    private func metrics(for layer: TemplateLayer) -> some View {
        if layer.style.string("orientation", default: "horizontal") == "vertical" {
            VStack(spacing: 12) {
                metricText("赞", value: content.metrics["likes"])
                metricText("评", value: content.metrics["comments"])
                metricText("藏", value: content.metrics["favorites"])
            }
            .foregroundStyle(.white)
        } else {
            HStack(spacing: 14) {
                metricText("赞", value: content.metrics["likes"])
                metricText("藏", value: content.metrics["favorites"])
                metricText("评", value: content.metrics["comments"])
            }
            .foregroundStyle(Color.cardifyMuted)
        }
    }

    private func metricText(_ label: String, value: Int?) -> some View {
        Text("\(label) \(value ?? 0)")
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct CardPalette {
    let paper: Color
    let accent: Color
    let secondary: Color
    let highlight: Color

    init(theme: CardTheme) {
        switch theme {
        case .mint:
            paper = .cardifyPaper
            accent = .cardifyMint
            secondary = .cardifySky
            highlight = .cardifyPink
        case .sky:
            paper = Color(red: 0.98, green: 0.99, blue: 1)
            accent = Color(red: 0.82, green: 0.92, blue: 1)
            secondary = Color(red: 0.87, green: 0.96, blue: 1)
            highlight = Color(red: 0.92, green: 0.91, blue: 1)
        case .blush:
            paper = Color(red: 1, green: 0.99, blue: 0.99)
            accent = Color(red: 1, green: 0.87, blue: 0.9)
            secondary = Color(red: 1, green: 0.94, blue: 0.84)
            highlight = Color(red: 0.98, green: 0.9, blue: 0.95)
        case .gold:
            paper = Color(red: 1, green: 0.99, blue: 0.95)
            accent = Color(red: 0.95, green: 0.88, blue: 0.67)
            secondary = Color(red: 0.91, green: 0.95, blue: 0.86)
            highlight = Color(red: 1, green: 0.92, blue: 0.84)
        case .ink:
            paper = Color(red: 0.09, green: 0.14, blue: 0.12)
            accent = Color(red: 0.25, green: 0.54, blue: 0.43)
            secondary = Color(red: 0.17, green: 0.28, blue: 0.25)
            highlight = Color(red: 0.79, green: 0.72, blue: 0.42)
        }
    }
}

private struct QRPlaceholder: View {
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
        .padding(8)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

public extension Color {
    static let cardifyInk = Color(red: 0.08, green: 0.14, blue: 0.12)
    static let cardifyMuted = Color(red: 0.44, green: 0.50, blue: 0.48)
    static let cardifyPaper = Color(red: 1, green: 1, blue: 0.99)
    static let cardifyMint = Color(red: 0.87, green: 0.97, blue: 0.92)
    static let cardifySky = Color(red: 0.92, green: 0.97, blue: 1)
    static let cardifyPink = Color(red: 1, green: 0.94, blue: 0.96)

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
