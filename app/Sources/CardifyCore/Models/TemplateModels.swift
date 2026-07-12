import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String, default defaultValue: String) -> String {
        if case .string(let value)? = self[key] {
            return value
        }
        return defaultValue
    }

    func double(_ key: String, default defaultValue: Double) -> Double {
        if case .double(let value)? = self[key] {
            return value
        }
        return defaultValue
    }

    func int(_ key: String, default defaultValue: Int) -> Int {
        if case .double(let value)? = self[key] {
            return Int(value)
        }
        return defaultValue
    }

    func bool(_ key: String, default defaultValue: Bool) -> Bool {
        if case .bool(let value)? = self[key] {
            return value
        }
        return defaultValue
    }

    func object(_ key: String) -> [String: JSONValue]? {
        if case .object(let value)? = self[key] {
            return value
        }
        return nil
    }
}

public struct CanvasSize: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let ratioLabel: String
    public let width: Int
    public let height: Int
    public let usage: String

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case ratioLabel = "ratio_label"
        case width
        case height
        case usage
    }
}

public struct TemplateFrame: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

public enum TemplateLayerType: String, Codable, Sendable {
    case text
    case image
    case avatar
    case qr
    case metrics
    case shape
}

public struct TemplateLayer: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let type: TemplateLayerType
    public let frame: TemplateFrame
    public let role: String
    public let maxLines: Int?
    public let style: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case frame
        case role
        case maxLines = "max_lines"
        case style
    }
}

public struct TemplateDocument: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let canvasSizes: [CanvasSize]
    public let defaultCanvasSizeId: String
    public let safeArea: [String: Double]
    public let layers: [TemplateLayer]
    public let tokens: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case canvasSizes = "canvas_sizes"
        case defaultCanvasSizeId = "default_canvas_size_id"
        case safeArea = "safe_area"
        case layers
        case tokens
    }

    public var defaultCanvasSize: CanvasSize {
        canvasSizes.first(where: { $0.id == defaultCanvasSizeId }) ?? canvasSizes[0]
    }

    public func validateFrames() throws {
        guard !canvasSizes.isEmpty else {
            throw TemplateValidationError.missingCanvasSizes
        }
        guard canvasSizes.contains(where: { $0.id == defaultCanvasSizeId }) else {
            throw TemplateValidationError.invalidDefaultSize
        }
        for layer in layers {
            guard layer.frame.x >= 0, layer.frame.y >= 0 else {
                throw TemplateValidationError.invalidFrame(layer.id)
            }
            guard layer.frame.x + layer.frame.width <= 1.01,
                  layer.frame.y + layer.frame.height <= 1.01 else {
                throw TemplateValidationError.invalidFrame(layer.id)
            }
        }
    }
}

public enum TemplateValidationError: Error, Equatable {
    case missingCanvasSizes
    case invalidDefaultSize
    case invalidFrame(String)
}

public struct TemplateSummary: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let defaultSizeId: String
    public let version: Int
    public let schema: TemplateDocument

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case defaultSizeId = "default_size_id"
        case version
        case schema
    }
}

public struct TemplateListResponse: Codable, Sendable {
    public let items: [TemplateSummary]
}

public enum CardTheme: String, CaseIterable, Identifiable, Sendable {
    case mint
    case sky
    case blush
    case gold
    case ink

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .mint: return "薄荷"
        case .sky: return "海蓝"
        case .blush: return "浅粉"
        case .gold: return "柔金"
        case .ink: return "墨绿"
        }
    }
}

public struct CardContent: Equatable, Sendable {
    public var title: String
    public var summary: String
    public var tags: [String]
    public var authorName: String
    public var metrics: [String: Int]
    public var theme: CardTheme
    public var coverImageData: Data?
    public var avatarImageData: Data?

    public init(
        title: String = "把文字变成值得分享的卡片",
        summary: String = "输入标题和正文后，即可生成可分享的卡片。",
        tags: [String] = [],
        authorName: String = "Cardify",
        metrics: [String: Int] = ["likes": 4263, "favorites": 791, "comments": 120],
        theme: CardTheme = .mint,
        coverImageData: Data? = nil,
        avatarImageData: Data? = nil
    ) {
        self.title = title
        self.summary = summary
        self.tags = tags
        self.authorName = authorName
        self.metrics = metrics
        self.theme = theme
        self.coverImageData = coverImageData
        self.avatarImageData = avatarImageData
    }

    public init(renderParams: [String: JSONValue], fallbackTitle: String, fallbackSummary: String) {
        let content = renderParams.object("card_content") ?? [:]
        let metrics = content.object("metrics") ?? [:]
        self.init(
            title: content.string("title", default: fallbackTitle),
            summary: content.string("summary", default: fallbackSummary),
            tags: content.string("tags", default: "#Cardify")
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init),
            authorName: content.string("author_name", default: "Cardify"),
            metrics: [
                "likes": metrics.int("likes", default: 0),
                "favorites": metrics.int("favorites", default: 0),
                "comments": metrics.int("comments", default: 0)
            ],
            theme: CardTheme(rawValue: content.string("theme", default: CardTheme.mint.rawValue)) ?? .mint
        )
    }

    public var renderParams: [String: JSONValue] {
        [
            "card_content": .object([
                "title": .string(title),
                "summary": .string(summary),
                "tags": .string(tags.joined(separator: " ")),
                "author_name": .string(authorName),
                "theme": .string(theme.rawValue),
                "metrics": .object(metrics.mapValues { .double(Double($0)) })
            ])
        ]
    }
}
