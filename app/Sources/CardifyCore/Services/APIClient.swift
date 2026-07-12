import Foundation

public struct APIClient: Sendable {
    public var baseURL: URL
    public var session: URLSession
    public var accessToken: String?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        baseURL: URL? = nil,
        session: URLSession = .shared,
        accessToken: String? = nil
    ) {
        self.baseURL = baseURL ?? Self.defaultBaseURL
        self.session = session
        self.accessToken = accessToken
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func listTemplates() async throws -> [TemplateSummary] {
        let response: TemplateListResponse = try await request(path: "/templates")
        return response.items
    }

    public func getTemplate(id: String) async throws -> TemplateSummary {
        try await request(path: "/templates/\(id)")
    }

    public func createGeneration(inputText: String, templateId: String?) async throws -> GenerationTask {
        try await request(
            path: "/generations",
            method: "POST",
            body: GenerationCreateRequest(inputText: inputText, templateId: templateId)
        )
    }

    public func getGeneration(id: String) async throws -> GenerationTask {
        try await request(path: "/generations/\(id)")
    }

    public func loginWithApple(_ payload: AppleLoginRequest) async throws -> AuthSession {
        try await request(path: "/auth/apple/login", method: "POST", body: payload)
    }

    public func createWork(_ payload: WorkCreateRequest) async throws -> WorkRecord {
        try await request(path: "/works", method: "POST", body: payload)
    }

    public func saveWorkExport(workId: String, filename: String, imageData: Data) async throws -> WorkRecord {
        try await request(
            path: "/works/\(workId)/export",
            method: "POST",
            body: ExportImageRequest(
                filename: filename,
                imageBase64: imageData.base64EncodedString()
            )
        )
    }

    public func saveWorkAsset(
        workId: String,
        kind: WorkAssetKind,
        filename: String,
        imageData: Data
    ) async throws -> WorkRecord {
        try await request(
            path: "/works/\(workId)/assets",
            method: "POST",
            body: WorkAssetRequest(
                kind: kind,
                filename: filename,
                imageBase64: imageData.base64EncodedString()
            )
        )
    }

    public func fetchWorkAsset(workId: String, kind: WorkAssetKind) async throws -> Data {
        var request = URLRequest(url: url(for: "/works/\(workId)/assets/\(kind.rawValue)"))
        authorize(&request)
        let (data, urlResponse) = try await send(request)
        try validate(urlResponse, data: data)
        return data
    }

    public func deleteWorkAsset(workId: String, kind: WorkAssetKind) async throws {
        let _: EmptyResponse = try await request(path: "/works/\(workId)/assets/\(kind.rawValue)", method: "DELETE")
    }

    public func updateWork(id: String, payload: WorkCreateRequest) async throws -> WorkRecord {
        try await request(path: "/works/\(id)", method: "PATCH", body: payload)
    }

    public func listWorks() async throws -> [WorkRecord] {
        let response: WorkListResponse = try await request(path: "/works")
        return response.items
    }

    public func deleteWork(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/works/\(id)", method: "DELETE")
    }

    private func request<Response: Decodable>(path: String, method: String = "GET") async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method
        authorize(&request)
        let (data, urlResponse) = try await send(request)
        try validate(urlResponse, data: data)
        return try decoder.decode(Response.self, from: data)
    }

    private func request<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)
        request.httpBody = try encoder.encode(body)

        let (data, urlResponse) = try await send(request)
        try validate(urlResponse, data: data)
        return try decoder.decode(Response.self, from: data)
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.server(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is URLError {
            throw APIError.connection(baseURL)
        }
    }

    private func url(for path: String) -> URL {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/\(cleanPath)")!
    }

    private func authorize(_ request: inout URLRequest) {
        guard let accessToken else { return }
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }

    private static var defaultBaseURL: URL {
        if let configuredURL = Bundle.main.object(forInfoDictionaryKey: "CARDIFY_API_URL") as? String,
           let url = URL(string: configuredURL),
           url.scheme != nil,
           url.host != nil {
            return url
        }
        return URL(string: "https://www.cardify.notenap.com")!
    }
}

public struct EmptyResponse: Decodable, Sendable {}

public enum APIError: Error, Equatable, LocalizedError {
    case invalidResponse
    case connection(URL)
    case server(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器返回了无效响应"
        case .connection(let url):
            return "无法连接后端服务：\(url.absoluteString)"
        case .server(let statusCode, let message):
            return "服务器错误（\(statusCode)）：\(message)"
        }
    }
}
