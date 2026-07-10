import Foundation

#if canImport(Security)
import Security
#endif

@MainActor
public final class CardifyViewModel: ObservableObject {
    @Published public var inputText: String = ""
    @Published public private(set) var templates: [TemplateSummary] = []
    @Published public private(set) var works: [WorkRecord] = []
    @Published public private(set) var currentUser: UserRecord?
    @Published public var selectedTemplate: TemplateSummary?
    @Published public var generatedContent = CardContent()
    @Published public var selectedCanvasSizeId: String = "xhs-3-4"
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var isAuthenticating = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var successMessage: String?

    private var apiClient: APIClient
    private var activeWorkId: String?

    public init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        if let storedSession = LoginSessionStore.load() {
            currentUser = storedSession.user
            self.apiClient.accessToken = storedSession.accessToken
        }
    }

    public func loadTemplates() async {
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await apiClient.listTemplates()
            if selectedTemplate == nil, let first = templates.first {
                selectTemplate(first)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadWorks() async {
        guard currentUser != nil else {
            works = []
            return
        }
        do {
            works = try await apiClient.listWorks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func selectTemplate(_ template: TemplateSummary) {
        selectedTemplate = template
        selectedCanvasSizeId = template.defaultSizeId
        activeWorkId = nil
    }

    public func useSampleInput() {
        inputText = "孩子英语启蒙不需要一开始就背单词。每天 15 分钟，把英文儿歌、绘本和日常对话放进固定场景里，孩子会更容易建立语感，也更愿意开口。"
    }

    public func generate() async -> Bool {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "请输入要生成卡片的文字"
            return false
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let task = try await apiClient.createGeneration(inputText: text, templateId: selectedTemplate?.id)
            let finalTask = try await waitForGeneration(task)
            if let output = finalTask.output {
                generatedContent = output.cardContent
                activeWorkId = nil
                return true
            }
            errorMessage = finalTask.error ?? "生成失败，请稍后再试"
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func saveCurrentWork() async -> Bool {
        guard currentUser != nil else {
            errorMessage = "请先通过 Apple 登录后再保存作品"
            return false
        }
        guard let selectedTemplate else {
            errorMessage = "请先选择模板"
            return false
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        do {
            let work = try await persistCurrentWork(for: selectedTemplate)
            activeWorkId = work.id
            await loadWorks()
            successMessage = "作品已保存"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func saveCurrentWorkExport(imageData: Data, filename: String) async -> Bool {
        guard currentUser != nil else {
            errorMessage = "请先通过 Apple 登录后再导出作品"
            return false
        }
        guard let selectedTemplate else {
            errorMessage = "请先选择模板"
            return false
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        do {
            let workId: String
            if let activeWorkId {
                _ = try await apiClient.updateWork(id: activeWorkId, payload: workPayload(for: selectedTemplate))
                workId = activeWorkId
            } else {
                let work = try await apiClient.createWork(workPayload(for: selectedTemplate))
                workId = work.id
                activeWorkId = work.id
            }
            _ = try await apiClient.saveWorkExport(workId: workId, filename: filename, imageData: imageData)
            await loadWorks()
            successMessage = "图片已导出并同步"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func workPayload(for template: TemplateSummary) -> WorkCreateRequest {
        var renderParams = generatedContent.renderParams
        renderParams["canvas_size_id"] = .string(selectedCanvasSizeId)
        renderParams["schema_version"] = .string(template.schema.schemaVersion)

        return WorkCreateRequest(
            templateId: template.id,
            title: generatedContent.title,
            inputText: inputText.isEmpty ? generatedContent.summary : inputText,
            renderParams: renderParams
        )
    }

    public func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        displayName: String?
    ) async -> Bool {
        isAuthenticating = true
        errorMessage = nil
        successMessage = nil
        defer { isAuthenticating = false }

        do {
            let session = try await apiClient.loginWithApple(
                AppleLoginRequest(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    displayName: displayName
                )
            )
            currentUser = session.user
            apiClient.accessToken = session.accessToken
            LoginSessionStore.save(session)
            await loadWorks()
            successMessage = "已通过 Apple 登录"
            return true
        } catch {
            errorMessage = "登录失败，请稍后重试"
            return false
        }
    }

    public func reportAppleSignInFailure(_ error: Error) {
        errorMessage = "Apple 登录未完成：\(error.localizedDescription)"
    }

    public func signOut() {
        currentUser = nil
        works = []
        activeWorkId = nil
        apiClient.accessToken = nil
        LoginSessionStore.clear()
        successMessage = "已退出登录"
    }

    public func reopenWork(_ work: WorkRecord) -> Bool {
        guard let template = templates.first(where: { $0.id == work.templateId }) else {
            errorMessage = "模板已不可用，暂时无法打开该作品"
            return false
        }

        selectedTemplate = template
        selectedCanvasSizeId = work.renderParams.string("canvas_size_id", default: template.defaultSizeId)
        generatedContent = CardContent(
            renderParams: work.renderParams,
            fallbackTitle: work.title,
            fallbackSummary: work.inputText
        )
        inputText = work.inputText
        activeWorkId = work.id
        successMessage = "已打开作品"
        return true
    }

    public func deleteWork(_ work: WorkRecord) async -> Bool {
        errorMessage = nil
        successMessage = nil
        do {
            try await apiClient.deleteWork(id: work.id)
            works.removeAll { $0.id == work.id }
            if activeWorkId == work.id {
                activeWorkId = nil
            }
            successMessage = "作品已删除"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func persistCurrentWork(for template: TemplateSummary) async throws -> WorkRecord {
        if let activeWorkId {
            return try await apiClient.updateWork(id: activeWorkId, payload: workPayload(for: template))
        }
        return try await apiClient.createWork(workPayload(for: template))
    }

    private func waitForGeneration(_ initialTask: GenerationTask) async throws -> GenerationTask {
        var task = initialTask
        for _ in 0..<12 {
            if task.status == .succeeded || task.status == .failed {
                return task
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            task = try await apiClient.getGeneration(id: task.id)
        }
        return task
    }
}

private enum LoginSessionStore {
    private static let service = "com.jiefeng.cardify"
    private static let account = "cardify-auth-session"

    static func save(_ session: AuthSession) {
        guard let data = try? encoded(session) else { return }
        #if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData] = data
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
        #endif
    }

    static func load() -> AuthSession? {
        #if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return try? decoded(data)
        #else
        return nil
        #endif
    }

    static func clear() {
        #if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
        #endif
    }

    private static func encoded(_ session: AuthSession) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(session)
    }

    private static func decoded(_ data: Data) throws -> AuthSession {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthSession.self, from: data)
    }
}
