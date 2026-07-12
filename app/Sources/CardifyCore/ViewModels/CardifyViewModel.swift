import Foundation

#if canImport(Security)
import Security
#endif

@MainActor
public final class CardifyViewModel: ObservableObject {
    @Published public var inputText: String = ""
    @Published public private(set) var templates: [TemplateSummary] = []
    @Published public private(set) var works: [WorkRecord] = []
    @Published public private(set) var localDrafts: [LocalDraftRecord] = []
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
    private var activeDraftId: String?

    public init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        localDrafts = LocalDraftStore.load()
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

    public func syncLocalDraftsNow(showEmptyState: Bool = true) async {
        guard currentUser != nil else {
            return
        }

        let pendingDraftCount = localDrafts.count
        guard pendingDraftCount > 0 else {
            if showEmptyState {
                successMessage = "没有需要同步的本机草稿"
            }
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        let syncedDraftCount = await syncLocalDrafts()
        await loadWorks()
        if syncedDraftCount > 0 {
            successMessage = "已同步 \(syncedDraftCount) 个本机草稿"
        } else {
            errorMessage = "暂时无法同步草稿，请检查网络后重试"
        }
    }

    public func selectTemplate(_ template: TemplateSummary) {
        selectedTemplate = template
        selectedCanvasSizeId = template.defaultSizeId
        activeWorkId = nil
        activeDraftId = nil
    }

    public func switchTemplateInEditor(_ template: TemplateSummary) {
        let currentCanvasSizeId = selectedCanvasSizeId
        selectedTemplate = template
        if template.schema.canvasSizes.contains(where: { $0.id == currentCanvasSizeId }) {
            selectedCanvasSizeId = currentCanvasSizeId
        } else {
            selectedCanvasSizeId = template.defaultSizeId
        }
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
                activeDraftId = nil
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
        guard let selectedTemplate else {
            errorMessage = "请先选择模板"
            return false
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        guard currentUser != nil else {
            saveLocalDraft(for: selectedTemplate, success: "草稿已保存在本机")
            return true
        }

        do {
            let work = try await persistCurrentWork(for: selectedTemplate)
            activeWorkId = work.id
            try await syncCurrentAssets(to: work.id)
            removeActiveLocalDraft()
            await loadWorks()
            successMessage = "作品已保存"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func saveCurrentWorkExport(imageData: Data, filename: String) async -> Bool {
        guard let selectedTemplate else {
            errorMessage = "请先选择模板"
            return false
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        guard currentUser != nil else {
            saveLocalDraft(for: selectedTemplate, success: "图片已导出，草稿已保存在本机")
            return true
        }

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
            try await syncCurrentAssets(to: workId)
            _ = try await apiClient.saveWorkExport(workId: workId, filename: filename, imageData: imageData)
            removeActiveLocalDraft()
            await loadWorks()
            successMessage = "图片已导出并同步"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func workPayload(for template: TemplateSummary) -> WorkCreateRequest {
        return WorkCreateRequest(
            templateId: template.id,
            title: generatedContent.title,
            inputText: inputText.isEmpty ? generatedContent.summary : inputText,
            renderParams: renderParams(for: template)
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
            let pendingDraftCount = localDrafts.count
            let syncedDraftCount = await syncLocalDrafts()
            await loadWorks()
            if syncedDraftCount > 0 {
                successMessage = "已登录，已同步 \(syncedDraftCount) 个本机草稿"
            } else if pendingDraftCount > 0 {
                successMessage = "已登录，本机草稿仍保留在本机，请稍后重新登录同步"
            } else {
                successMessage = "已通过 Apple 登录"
            }
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
        activeDraftId = nil
        apiClient.accessToken = nil
        LoginSessionStore.clear()
        successMessage = "已退出登录"
    }

    public func reopenWork(_ work: WorkRecord) async -> Bool {
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
        activeDraftId = nil
        await restoreAssets(for: work)
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

    public func reopenLocalDraft(_ draft: LocalDraftRecord) -> Bool {
        guard let template = templates.first(where: { $0.id == draft.templateId }) else {
            errorMessage = "模板已不可用，暂时无法打开该草稿"
            return false
        }

        selectedTemplate = template
        selectedCanvasSizeId = draft.renderParams.string("canvas_size_id", default: template.defaultSizeId)
        generatedContent = CardContent(
            renderParams: draft.renderParams,
            fallbackTitle: "未命名草稿",
            fallbackSummary: draft.inputText
        )
        generatedContent.coverImageData = draft.coverImageData
        generatedContent.avatarImageData = draft.avatarImageData
        inputText = draft.inputText
        activeWorkId = nil
        activeDraftId = draft.id
        successMessage = "已打开本机草稿"
        return true
    }

    public func deleteLocalDraft(_ draft: LocalDraftRecord) {
        localDrafts.removeAll { $0.id == draft.id }
        if activeDraftId == draft.id {
            activeDraftId = nil
        }
        LocalDraftStore.save(localDrafts)
        successMessage = "本机草稿已删除"
    }

    private func persistCurrentWork(for template: TemplateSummary) async throws -> WorkRecord {
        if let activeWorkId {
            return try await apiClient.updateWork(id: activeWorkId, payload: workPayload(for: template))
        }
        return try await apiClient.createWork(workPayload(for: template))
    }

    private func saveLocalDraft(for template: TemplateSummary, success: String) {
        let now = Date()
        let existing = localDrafts.first { $0.id == activeDraftId }
        let draft = LocalDraftRecord(
            id: existing?.id ?? UUID().uuidString,
            templateId: template.id,
            inputText: inputText.isEmpty ? generatedContent.summary : inputText,
            renderParams: renderParams(for: template),
            coverImageData: generatedContent.coverImageData,
            avatarImageData: generatedContent.avatarImageData,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
        activeDraftId = draft.id
        localDrafts.removeAll { $0.id == draft.id }
        localDrafts.insert(draft, at: 0)
        LocalDraftStore.save(localDrafts)
        successMessage = success
    }

    private func removeActiveLocalDraft() {
        guard let activeDraftId else { return }
        localDrafts.removeAll { $0.id == activeDraftId }
        self.activeDraftId = nil
        LocalDraftStore.save(localDrafts)
    }

    private func renderParams(for template: TemplateSummary) -> [String: JSONValue] {
        var renderParams = generatedContent.renderParams
        renderParams["canvas_size_id"] = .string(selectedCanvasSizeId)
        renderParams["schema_version"] = .string(template.schema.schemaVersion)
        return renderParams
    }

    private func syncLocalDrafts() async -> Int {
        guard currentUser != nil else { return 0 }
        var syncedDraftIDs: Set<String> = []

        for draft in localDrafts {
            let content = CardContent(
                renderParams: draft.renderParams,
                fallbackTitle: "未命名草稿",
                fallbackSummary: draft.inputText
            )
            let payload = WorkCreateRequest(
                templateId: draft.templateId,
                title: content.title,
                inputText: draft.inputText,
                renderParams: draft.renderParams
            )

            do {
                let work = try await apiClient.createWork(payload)
                try await syncDraftAssets(draft, to: work.id)
                syncedDraftIDs.insert(draft.id)
            } catch {
                continue
            }
        }

        guard !syncedDraftIDs.isEmpty else { return 0 }
        localDrafts.removeAll { syncedDraftIDs.contains($0.id) }
        LocalDraftStore.save(localDrafts)
        return syncedDraftIDs.count
    }

    private func syncCurrentAssets(to workId: String) async throws {
        try await syncAsset(
            kind: .cover,
            imageData: generatedContent.coverImageData,
            workId: workId,
            filename: "cover.jpg"
        )
        try await syncAsset(
            kind: .avatar,
            imageData: generatedContent.avatarImageData,
            workId: workId,
            filename: "avatar.jpg"
        )
    }

    private func syncDraftAssets(_ draft: LocalDraftRecord, to workId: String) async throws {
        try await syncAsset(kind: .cover, imageData: draft.coverImageData, workId: workId, filename: "cover.jpg")
        try await syncAsset(kind: .avatar, imageData: draft.avatarImageData, workId: workId, filename: "avatar.jpg")
    }

    private func syncAsset(
        kind: WorkAssetKind,
        imageData: Data?,
        workId: String,
        filename: String
    ) async throws {
        if let imageData {
            _ = try await apiClient.saveWorkAsset(
                workId: workId,
                kind: kind,
                filename: filename,
                imageData: imageData
            )
        } else {
            try await apiClient.deleteWorkAsset(workId: workId, kind: kind)
        }
    }

    private func restoreAssets(for work: WorkRecord) async {
        async let cover = try? apiClient.fetchWorkAsset(workId: work.id, kind: .cover)
        async let avatar = try? apiClient.fetchWorkAsset(workId: work.id, kind: .avatar)
        generatedContent.coverImageData = await cover
        generatedContent.avatarImageData = await avatar
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

private enum LocalDraftStore {
    private static let directoryName = "Cardify"
    private static let fileName = "local-drafts.json"

    static func load() -> [LocalDraftRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let drafts = try? JSONDecoder().decode([LocalDraftRecord].self, from: data) else {
            return []
        }
        return drafts.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func save(_ drafts: [LocalDraftRecord]) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(drafts)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        } catch {
            return
        }
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(directoryName, isDirectory: true).appendingPathComponent(fileName)
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
