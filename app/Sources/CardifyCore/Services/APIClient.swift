import Foundation

public struct APIClient: Sendable {
    public var baseURL: URL
    public var session: URLSession
    public var accessToken: String?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:8000")!,
        session: URLSession = .shared,
        accessToken: String? = nil
    ) {
        self.baseURL = baseURL
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
        let (data, urlResponse) = try await session.data(for: request)
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

        let (data, urlResponse) = try await session.data(for: request)
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

    private func url(for path: String) -> URL {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/\(cleanPath)")!
    }

    private func authorize(_ request: inout URLRequest) {
        guard let accessToken else { return }
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
}

public struct EmptyResponse: Decodable, Sendable {}

public enum APIError: Error, Equatable {
    case invalidResponse
    case server(statusCode: Int, message: String)
}
