import Foundation

public enum GenerationStatus: String, Codable, Sendable {
    case pending
    case running
    case succeeded
    case failed
}

public struct GenerationCreateRequest: Codable, Sendable {
    public let inputText: String
    public let templateId: String?

    public init(inputText: String, templateId: String? = nil) {
        self.inputText = inputText
        self.templateId = templateId
    }

    enum CodingKeys: String, CodingKey {
        case inputText = "input_text"
        case templateId = "template_id"
    }
}

public struct GenerationTask: Codable, Identifiable, Sendable {
    public let id: String
    public let status: GenerationStatus
    public let inputText: String
    public let templateId: String?
    public let output: GenerationOutput?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case inputText = "input_text"
        case templateId = "template_id"
        case output
        case error
    }
}

public struct GenerationOutput: Codable, Equatable, Sendable {
    public let title: String
    public let summary: String
    public let tags: [String]
    public let authorName: String?
    public let metrics: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case tags
        case authorName = "author_name"
        case metrics
    }

    public var cardContent: CardContent {
        CardContent(
            title: title,
            summary: summary,
            tags: tags,
            authorName: authorName ?? "Cardify",
            metrics: metrics ?? ["likes": 4263, "favorites": 791, "comments": 120]
        )
    }
}

public struct WorkCreateRequest: Codable, Sendable {
    public let templateId: String
    public let title: String
    public let inputText: String
    public let renderParams: [String: JSONValue]

    public init(templateId: String, title: String, inputText: String, renderParams: [String: JSONValue]) {
        self.templateId = templateId
        self.title = title
        self.inputText = inputText
        self.renderParams = renderParams
    }

    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case title
        case inputText = "input_text"
        case renderParams = "render_params"
    }
}

public struct AppleLoginRequest: Codable, Sendable {
    public let identityToken: String
    public let authorizationCode: String?
    public let displayName: String?

    public init(identityToken: String, authorizationCode: String?, displayName: String?) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case authorizationCode = "authorization_code"
        case displayName = "display_name"
    }
}

public struct UserRecord: Codable, Identifiable, Sendable {
    public let id: String
    public let appleSubject: String
    public let displayName: String?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case appleSubject = "apple_subject"
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

public struct AuthSession: Codable, Sendable {
    public let user: UserRecord
    public let accessToken: String
    public let tokenType: String

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

public struct WorkRecord: Codable, Identifiable, Sendable {
    public let id: String
    public let templateId: String
    public let title: String
    public let inputText: String
    public let renderParams: [String: JSONValue]
    public let exportPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case title
        case inputText = "input_text"
        case renderParams = "render_params"
        case exportPath = "export_path"
    }
}

public struct WorkListResponse: Codable, Sendable {
    public let items: [WorkRecord]
}

public struct ExportImageRequest: Codable, Sendable {
    public let filename: String
    public let imageBase64: String

    public init(filename: String, imageBase64: String) {
        self.filename = filename
        self.imageBase64 = imageBase64
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case imageBase64 = "image_base64"
    }
}

public enum WorkAssetKind: String, Codable, Sendable, CaseIterable {
    case cover
    case avatar
}

public struct WorkAssetRequest: Codable, Sendable {
    public let kind: WorkAssetKind
    public let filename: String
    public let imageBase64: String

    public init(kind: WorkAssetKind, filename: String, imageBase64: String) {
        self.kind = kind
        self.filename = filename
        self.imageBase64 = imageBase64
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case filename
        case imageBase64 = "image_base64"
    }
}
