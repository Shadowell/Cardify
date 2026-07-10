#if canImport(CardifyCore)
import CardifyCore
#endif
import SwiftUI

#if canImport(UIKit)
import Photos
import UIKit
#endif

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

@main
struct CardifyApp: App {
    @StateObject private var viewModel = CardifyViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView {
                selectedTab = .editor
            }
                .tabItem { Label("首页", systemImage: "house") }
                .tag(AppTab.home)
            TemplateListView()
                .tabItem { Label("模板", systemImage: "square.grid.2x2") }
                .tag(AppTab.templates)
            EditorView()
                .tabItem { Label("编辑", systemImage: "paintbrush") }
                .tag(AppTab.editor)
            ProfileView {
                selectedTab = .editor
            }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .task {
            await viewModel.loadTemplates()
            await viewModel.loadWorks()
        }
    }
}

private enum AppTab: Hashable {
    case home
    case templates
    case editor
    case profile
}

private struct HomeView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    let onGenerated: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.inputText)
                            .frame(height: 120)
                            .padding(10)
                            .scrollContentBackground(.hidden)

                        if viewModel.inputText.isEmpty {
                            Text("粘贴一段文字，Cardify 会整理成标题、摘要和标签")
                                .foregroundStyle(Color.cardifyMuted)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(Color.cardifyPaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.cardifyMint, lineWidth: 1)
                    )

                    Button {
                        viewModel.useSampleInput()
                    } label: {
                        Label("试用示例", systemImage: "wand.and.sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            if await viewModel.generate() {
                                await MainActor.run {
                                    onGenerated()
                                }
                            }
                        }
                    } label: {
                        Label(viewModel.isLoading ? "生成中" : "生成魔卡", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .safeAreaPadding(.bottom, 88)
            .navigationTitle("Cardify")
            .cardifyInlineNavigationTitle()
        }
    }
}

private struct TemplateListView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    @State private var selectedCategory = "全部"

    private var categories: [String] {
        ["全部"] + Array(Set(viewModel.templates.map(\.category))).sorted()
    }

    private var visibleTemplates: [TemplateSummary] {
        if selectedCategory == "全部" {
            return viewModel.templates
        }
        return viewModel.templates.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(selectedCategory == category ? .cardifyInk : .cardifyMuted)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }

                List(visibleTemplates) { template in
                    Button {
                        viewModel.selectTemplate(template)
                    } label: {
                        HStack(spacing: 14) {
                            TemplateThumbnail(template: template)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundStyle(Color.cardifyInk)
                                Text("\(template.category) · \(template.schema.defaultCanvasSize.ratioLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(template.schema.defaultCanvasSize.usage)
                                    .font(.caption2)
                                    .foregroundStyle(Color.cardifyMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if viewModel.selectedTemplate?.id == template.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
            .navigationTitle("模板")
        }
    }
}

private struct TemplateThumbnail: View {
    let template: TemplateSummary

    private var sampleContent: CardContent {
        CardContent(
            title: template.name,
            summary: "为内容留出清晰重点",
            tags: ["#Cardify"],
            authorName: "Cardify",
            theme: theme
        )
    }

    private var theme: CardTheme {
        switch template.category {
        case "营销", "探店": return .gold
        case "旅行", "视频卡": return .sky
        case "分享卡": return .blush
        default: return .mint
        }
    }

    var body: some View {
        TemplateCanvasView(
            template: template.schema,
            content: sampleContent,
            canvasSizeId: template.defaultSizeId
        )
        .frame(width: 68, height: 88)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .accessibilityHidden(true)
    }
}

private struct EditorView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    #if canImport(PhotosUI)
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedAvatarPhoto: PhotosPickerItem?
    #endif
    #if canImport(UIKit)
    @State private var exportedImage: UIImage?
    @State private var isShareSheetPresented = false
    @State private var exportError: String?
    @State private var isExporting = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                if let template = viewModel.selectedTemplate {
                    TemplateCanvasView(
                        template: template.schema,
                        content: viewModel.generatedContent,
                        canvasSizeId: viewModel.selectedCanvasSizeId
                    )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .shadow(color: .black.opacity(0.12), radius: 18, y: 12)

                    VStack(alignment: .leading, spacing: 14) {
                        Picker("画布尺寸", selection: $viewModel.selectedCanvasSizeId) {
                            ForEach(template.schema.canvasSizes) { size in
                                Text("\(size.label) \(size.ratioLabel)").tag(size.id)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("标题", text: $viewModel.generatedContent.title, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...3)

                        TextEditor(text: $viewModel.generatedContent.summary)
                            .frame(height: 92)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color.cardifyPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.cardifyMint, lineWidth: 1)
                            )

                        TextField("标签", text: tagsBinding)
                            .textFieldStyle(.roundedBorder)

                        DisclosureGroup("卡片素材") {
                            VStack(alignment: .leading, spacing: 14) {
                                #if canImport(PhotosUI)
                                HStack(spacing: 12) {
                                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                                        Label("封面", systemImage: "photo.on.rectangle")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)

                                    PhotosPicker(selection: $selectedAvatarPhoto, matching: .images) {
                                        Label("头像", systemImage: "person.crop.circle")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)

                                    if viewModel.generatedContent.coverImageData != nil || viewModel.generatedContent.avatarImageData != nil {
                                        Button("清除", systemImage: "xmark") {
                                            viewModel.generatedContent.coverImageData = nil
                                            viewModel.generatedContent.avatarImageData = nil
                                            selectedCoverPhoto = nil
                                            selectedAvatarPhoto = nil
                                        }
                                        .labelStyle(.iconOnly)
                                        .buttonStyle(.bordered)
                                        .accessibilityLabel("清除图片")
                                    }
                                }
                                #endif

                                TextField("作者昵称", text: $viewModel.generatedContent.authorName)
                                    .textFieldStyle(.roundedBorder)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("色系")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 12) {
                                        ForEach(CardTheme.allCases) { theme in
                                            Button {
                                                viewModel.generatedContent.theme = theme
                                            } label: {
                                                Circle()
                                                    .fill(theme.swatchColor)
                                                    .frame(width: 28, height: 28)
                                                    .overlay {
                                                        if viewModel.generatedContent.theme == theme {
                                                            Image(systemName: "checkmark")
                                                                .font(.caption.bold())
                                                                .foregroundStyle(theme == .ink ? .white : Color.cardifyInk)
                                                        }
                                                    }
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(theme.label)
                                        }
                                    }
                                }

                                HStack(spacing: 10) {
                                    MetricField(label: "赞", value: metricBinding("likes"))
                                    MetricField(label: "藏", value: metricBinding("favorites"))
                                    MetricField(label: "评", value: metricBinding("comments"))
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal)
                    #if canImport(PhotosUI)
                    .onChange(of: selectedCoverPhoto) { _, item in
                        loadImage(item) { data in
                            viewModel.generatedContent.coverImageData = data
                        }
                    }
                    .onChange(of: selectedAvatarPhoto) { _, item in
                        loadImage(item) { data in
                            viewModel.generatedContent.avatarImageData = data
                        }
                    }
                    #endif

                    Button {
                        Task { await viewModel.saveCurrentWork() }
                    } label: {
                        Label(
                            viewModel.isSaving ? "保存中" : (viewModel.currentUser == nil ? "登录后保存" : "保存作品"),
                            systemImage: "tray.and.arrow.down"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSaving || viewModel.currentUser == nil)
                    .padding(.horizontal)
                    .padding(.top, 10)

                    #if canImport(UIKit)
                    HStack(spacing: 12) {
                        Button {
                            Task { await export(template: template, saveToPhotoLibrary: true) }
                        } label: {
                            Label(isExporting ? "导出中" : "保存相册", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isExporting || viewModel.currentUser == nil)

                        Button {
                            Task { await export(template: template, saveToPhotoLibrary: false) }
                        } label: {
                            Label("系统分享", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isExporting || viewModel.currentUser == nil)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .sheet(isPresented: $isShareSheetPresented) {
                        if let exportedImage {
                            SystemShareSheet(image: exportedImage)
                        }
                    }

                    if let exportError {
                        Text(exportError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }
                    #endif

                    if let message = viewModel.successMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .padding(.top, 4)
                    }

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }
                } else {
                    ContentUnavailableView("暂无模板", systemImage: "square.grid.2x2", description: Text("启动后会从后端拉取模板"))
                }
            }
            .navigationTitle("编辑")
            .cardifyInlineNavigationTitle()
        }
    }

    private var tagsBinding: Binding<String> {
        Binding {
            viewModel.generatedContent.tags.joined(separator: " ")
        } set: { value in
            viewModel.generatedContent.tags = value
                .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "，" })
                .map(String.init)
        }
    }

    private func metricBinding(_ key: String) -> Binding<String> {
        Binding {
            String(viewModel.generatedContent.metrics[key] ?? 0)
        } set: { value in
            viewModel.generatedContent.metrics[key] = Int(value) ?? 0
        }
    }

    #if canImport(PhotosUI)
    private func loadImage(_ item: PhotosPickerItem?, assign: @escaping (Data) -> Void) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                assign(data)
            }
        }
    }
    #endif

    #if canImport(UIKit)
    @MainActor
    private func export(template: TemplateSummary, saveToPhotoLibrary: Bool) async {
        guard let image = CardImageRenderer.render(
            template: template.schema,
            content: viewModel.generatedContent,
            canvasSizeId: viewModel.selectedCanvasSizeId
        ), let imageData = image.pngData() else {
            exportError = "图片导出失败，请重试"
            return
        }

        isExporting = true
        exportError = nil
        defer { isExporting = false }

        do {
            if saveToPhotoLibrary {
                try await PhotoLibrarySaver.save(image)
            }

            let filename = "cardify-\(template.id)-\(viewModel.selectedCanvasSizeId).png"
            _ = await viewModel.saveCurrentWorkExport(imageData: imageData, filename: filename)

            if !saveToPhotoLibrary {
                exportedImage = image
                isShareSheetPresented = true
            }
        } catch {
            exportError = "无法保存到相册：\(error.localizedDescription)"
        }
    }
    #endif
}

private struct MetricField: View {
    let label: String
    @Binding var value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", text: $value)
                .cardifyNumericKeyboard()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
        }
    }
}

private extension CardTheme {
    var swatchColor: Color {
        switch self {
        case .mint: return Color(red: 0.5, green: 0.84, blue: 0.67)
        case .sky: return Color(red: 0.48, green: 0.72, blue: 0.94)
        case .blush: return Color(red: 0.94, green: 0.57, blue: 0.67)
        case .gold: return Color(red: 0.84, green: 0.65, blue: 0.26)
        case .ink: return Color.cardifyInk
        }
    }
}

#if canImport(UIKit)
private enum PhotoLibrarySaver {
    static func save(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotoLibrarySaveError.failed)
                }
            }
        }
    }
}

private enum PhotoLibrarySaveError: LocalizedError {
    case failed

    var errorDescription: String? {
        "系统没有完成保存"
    }
}

private struct SystemShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct ProfileView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    let onOpenWork: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("我的作品") {
                    if viewModel.works.isEmpty {
                        ContentUnavailableView(
                            "还没有作品",
                            systemImage: "rectangle.stack.badge.plus",
                            description: Text("生成并保存一张卡片后，它会出现在这里")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.works) { work in
                            Button {
                                if viewModel.reopenWork(work) {
                                    onOpenWork()
                                }
                            } label: {
                                WorkRow(work: work, template: viewModel.templates.first(where: { $0.id == work.templateId }))
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteWork(work) }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("账户与订阅") {
                    if let user = viewModel.currentUser {
                        HStack {
                            Label(user.displayName ?? "已通过 Apple 登录", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Color.cardifyInk)
                            Spacer()
                            Button("退出", systemImage: "rectangle.portrait.and.arrow.right") {
                                viewModel.signOut()
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("退出登录")
                        }
                    } else {
                        AppleSignInControl()
                    }
                    Label("StoreKit 2 订阅", systemImage: "crown")
                    Label("加密会话", systemImage: "key.fill")
                }
            }
            .navigationTitle("我的")
            .toolbar {
                Button {
                    Task { await viewModel.loadWorks() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("刷新作品")
            }
            .task {
                await viewModel.loadWorks()
            }
        }
    }
}

private struct AppleSignInControl: View {
    @EnvironmentObject private var viewModel: CardifyViewModel

    var body: some View {
        #if canImport(AuthenticationServices)
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let identityToken = credential.identityToken,
                      let token = String(data: identityToken, encoding: .utf8) else {
                    viewModel.reportAppleSignInFailure(AppleSignInError.missingIdentityToken)
                    return
                }

                let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                let displayName = credential.fullName.flatMap { components in
                    let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
                    return name.isEmpty ? nil : name
                }
                Task {
                    await viewModel.signInWithApple(
                        identityToken: token,
                        authorizationCode: authorizationCode,
                        displayName: displayName
                    )
                }
            case .failure(let error):
                viewModel.reportAppleSignInFailure(error)
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 44)
        .disabled(viewModel.isAuthenticating)
        #else
        Label("此设备不支持 Apple 登录", systemImage: "apple.logo")
        #endif
    }
}

private enum AppleSignInError: LocalizedError {
    case missingIdentityToken

    var errorDescription: String? {
        "没有收到 Apple 身份令牌"
    }
}

private struct WorkRow: View {
    let work: WorkRecord
    let template: TemplateSummary?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: work.exportPath == nil ? "doc.text.image" : "photo.on.rectangle.angled")
                .font(.title3)
                .foregroundStyle(work.exportPath == nil ? Color.cardifyMuted : Color.cardifyInk)
                .frame(width: 30, height: 30)
                .background(Color.cardifyMint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(work.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cardifyInk)
                    .lineLimit(2)
                Text(template?.name ?? work.templateId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private extension View {
    @ViewBuilder
    func cardifyInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func cardifyNumericKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }
}
