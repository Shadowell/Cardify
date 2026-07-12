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

#if canImport(StoreKit)
import StoreKit
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
    @State private var selectedTab: AppTab = .creation
    @State private var creationMode: CreationMode = .input

    var body: some View {
        TabView(selection: $selectedTab) {
            CreationFlowView(mode: $creationMode)
                .tabItem {
                    Label("创作", systemImage: "wand.and.sparkles")
                }
                .tag(AppTab.creation)
            TemplateListView()
                .tabItem {
                    Label("模板库", systemImage: "square.grid.2x2")
                }
                .tag(AppTab.templates)
            WorksView {
                creationMode = .editing
                selectedTab = .creation
            }
                .tabItem {
                    Label("作品", systemImage: "rectangle.stack")
                }
                .tag(AppTab.works)
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
        }
        .tint(Color(red: 0.12, green: 0.60, blue: 0.45))
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CardifyTabBar(selection: $selectedTab)
        }
        .task {
            await viewModel.loadTemplates()
            await viewModel.syncLocalDraftsNow(showEmptyState: false)
            await viewModel.loadWorks()
            await viewModel.loadMembership()
        }
    }
}

private enum AppTab: Hashable, CaseIterable, Identifiable {
    case creation
    case templates
    case works
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .creation: return "创作"
        case .templates: return "模板库"
        case .works: return "作品"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .creation: return "wand.and.sparkles"
        case .templates: return "square.grid.2x2"
        case .works: return "rectangle.stack"
        case .profile: return "person.crop.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .creation: return "wand.and.sparkles"
        case .templates: return "square.grid.2x2.fill"
        case .works: return "rectangle.stack.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }

}

private enum CreationMode {
    case input
    case editing
}

private struct CreationFlowView: View {
    @Binding var mode: CreationMode

    var body: some View {
        switch mode {
        case .input:
            HomeView {
                mode = .editing
            }
        case .editing:
            EditorView {
                mode = .input
            }
        }
    }
}

private struct CardifyTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = selection == tab
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 24, height: 24)
                        Text(tab.title)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(isSelected ? Color.cardifyNavActive : Color.cardifyNavInactive)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 3)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.cardifyInk.opacity(0.07))
                .frame(height: 0.5)
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    let onGenerated: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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

                    HomeTemplatePicker()

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
                        Label(generationButtonTitle, systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading || !canGenerate)

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("创作")
            .cardifyInlineNavigationTitle()
        }
    }

    private var canGenerate: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.selectedTemplate != nil
    }

    private var generationButtonTitle: String {
        if viewModel.isLoading {
            return "生成中"
        }
        if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "先输入文字"
        }
        if viewModel.selectedTemplate == nil {
            return "选择模板后生成"
        }
        return "生成魔卡"
    }
}

private struct HomeTemplatePicker: View {
    @EnvironmentObject private var viewModel: CardifyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("选择模板")
                    .font(.headline)
                    .foregroundStyle(Color.cardifyInk)
                Text(viewModel.selectedTemplate == nil ? "请选择一张版式" : "已选择")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if viewModel.isLoading && viewModel.templates.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在加载模板")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 96)
            } else if viewModel.templates.isEmpty {
                Button {
                    Task { await viewModel.loadTemplates() }
                } label: {
                    Label("重新加载模板", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 96)
                }
                .buttonStyle(.bordered)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(viewModel.templates) { template in
                            TemplateSelectionCard(
                                template: template,
                                isSelected: viewModel.selectedTemplate?.id == template.id
                            ) {
                                viewModel.selectTemplate(template)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct TemplateSelectionCard: View {
    let template: TemplateSummary
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    TemplateThumbnail(template: template)
                        .frame(width: 78, height: 102)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Color.cardifyNavActive)
                            .padding(5)
                            .background(.white, in: Circle())
                            .padding(4)
                    }
                }

                Text(template.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cardifyInk)
                    .lineLimit(2)
                    .frame(width: 88, alignment: .leading)
            }
            .padding(6)
            .background(
                Color.cardifyPaper,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.cardifyNavActive : Color.cardifyMint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
        .accessibilityValue(isSelected ? "已选中" : "未选中")
        .accessibilityHint("选择此模板用于生成魔卡")
    }
}

private struct EditorTemplateSwitcher: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    let currentTemplate: TemplateSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cardifyNavActive)
                Text("模板")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cardifyInk)
                Text(currentTemplate.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.cardifyMuted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            if !viewModel.templates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 9) {
                        ForEach(viewModel.templates) { template in
                            EditorTemplateChip(
                                template: template,
                                isSelected: template.id == currentTemplate.id
                            ) {
                                viewModel.switchTemplateInEditor(template)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct EditorTemplateChip: View {
    let template: TemplateSummary
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                TemplateMiniThumbnail(template: template)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.cardifyInk)
                        .lineLimit(1)
                    Text(template.category)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.cardifyMuted)
                        .lineLimit(1)
                }
                .frame(width: 64, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.cardifyNavActive)
                }
            }
            .frame(width: 142, height: 66, alignment: .leading)
            .padding(.horizontal, 8)
            .background(
                isSelected ? Color.cardifyMint.opacity(0.75) : Color.cardifyInk.opacity(0.025),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.cardifyNavActive.opacity(0.28) : Color.cardifyInk.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
        .accessibilityValue(isSelected ? "当前模板" : template.category)
        .accessibilityHint("切换到此模板")
    }
}

private struct TemplateMiniThumbnail: View {
    let template: TemplateSummary

    private var sampleContent: CardContent {
        CardContent(
            title: template.name,
            summary: "清晰重点",
            tags: ["#Cardify"],
            authorName: "Cardify",
            theme: .mint
        )
    }

    var body: some View {
        TemplateCanvasView(
            template: template.schema,
            content: sampleContent,
            canvasSizeId: template.defaultSizeId
        )
        .frame(width: 40, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .accessibilityHidden(true)
    }
}

private struct TemplateListView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    @State private var selectedCategory = "全部"
    @State private var previewTemplate: TemplateSummary?

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
                            .tint(selectedCategory == category ? Color.cardifyNavActive : Color.cardifyMuted)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }

                List(visibleTemplates) { template in
                    Button {
                        previewTemplate = template
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
                            Image(systemName: "eye")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.cardifyNavActive)
                        }
                    }
                    .accessibilityHint("预览此模板")
                }
                .listStyle(.plain)
            }
            .navigationTitle("模板库")
            .sheet(item: $previewTemplate) { template in
                TemplatePreviewSheet(template: template)
            }
        }
    }
}

private struct TemplatePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: TemplateSummary

    private var sampleContent: CardContent {
        CardContent(
            title: template.name,
            summary: "为内容留出清晰重点，让信息更容易阅读和分享。",
            tags: ["#Cardify", "#内容创作"],
            authorName: "Cardify",
            theme: .mint
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TemplateCanvasView(
                        template: template.schema,
                        content: sampleContent,
                        canvasSizeId: template.defaultSizeId
                    )
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.1), radius: 14, y: 8)

                    HStack {
                        Label(template.category, systemImage: "tag")
                        Spacer()
                        Text("\(template.schema.defaultCanvasSize.label) · \(template.schema.defaultCanvasSize.ratioLabel)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(template.name)
            .cardifyInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
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
            theme: .mint
        )
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
    let onBackToInput: () -> Void
    @State private var isCanvasSizePickerPresented = false
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

                    EditorTemplateSwitcher(currentTemplate: template)
                        .padding(.horizontal)
                        .padding(.bottom, 2)

                    VStack(alignment: .leading, spacing: 20) {
                        Button {
                            isCanvasSizePickerPresented = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "aspectratio")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Color.cardifyNavActive)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("画布尺寸")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(selectedCanvasSize(for: template).label)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.cardifyInk)
                                }

                                Spacer()

                                Text(selectedCanvasSize(for: template).ratioLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.cardifyNavActive)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 52)
                            .background(
                                Color.cardifyInk.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.cardifyInk.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("画布尺寸")
                        .accessibilityValue(
                            "\(selectedCanvasSize(for: template).label) \(selectedCanvasSize(for: template).ratioLabel)"
                        )
                        .popover(
                            isPresented: $isCanvasSizePickerPresented,
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .top
                        ) {
                            CanvasSizeQuickPicker(
                                canvasSizes: template.schema.canvasSizes,
                                selectedSizeId: $viewModel.selectedCanvasSizeId
                            ) {
                                isCanvasSizePickerPresented = false
                            }
                            .presentationCompactAdaptation(.popover)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("内容")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.cardifyInk)

                            VStack(alignment: .leading, spacing: 7) {
                                EditorFieldLabel("标题")
                                TextField("输入卡片标题", text: $viewModel.generatedContent.title, axis: .vertical)
                                    .lineLimit(1...3)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .cardifyEditorFieldSurface()
                            }

                            VStack(alignment: .leading, spacing: 7) {
                                EditorFieldLabel("正文")
                                TextField("输入正文", text: $viewModel.generatedContent.summary, axis: .vertical)
                                    .lineLimit(4...8)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .cardifyEditorFieldSurface()
                                    .accessibilityLabel("正文")
                            }

                            VStack(alignment: .leading, spacing: 7) {
                                EditorFieldLabel("标签")
                                TextField("使用空格分隔标签", text: tagsBinding)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .cardifyEditorFieldSurface()
                            }
                        }

                        Divider()
                            .overlay(Color.cardifyInk.opacity(0.08))

                        DisclosureGroup {
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

                                VStack(alignment: .leading, spacing: 7) {
                                    EditorFieldLabel("作者昵称")
                                    TextField("输入作者昵称", text: $viewModel.generatedContent.authorName)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .cardifyEditorFieldSurface()
                                }

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
                        } label: {
                            Label("素材与数据", systemImage: "slider.horizontal.3")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.cardifyInk)
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
                        Task { _ = await viewModel.saveCurrentWork() }
                    } label: {
                        Label(
                            viewModel.isSaving ? "保存中" : (viewModel.currentUser == nil ? "保存草稿" : "保存作品"),
                            systemImage: "tray.and.arrow.down"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSaving)
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
                        .disabled(isExporting)

                        Button {
                            Task { await export(template: template, saveToPhotoLibrary: false) }
                        } label: {
                            Label("系统分享", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isExporting)
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

                    Color.clear
                        .frame(height: 96)
                        .accessibilityHidden(true)
                } else {
                    ContentUnavailableView("暂无模板", systemImage: "square.grid.2x2", description: Text("启动后会从后端拉取模板"))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("预览与编辑")
            .cardifyInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onBackToInput()
                    } label: {
                        Label("返回创作", systemImage: "chevron.left")
                    }
                }
            }
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

    private func selectedCanvasSize(for template: TemplateSummary) -> CanvasSize {
        template.schema.canvasSizes
            .first(where: { $0.id == viewModel.selectedCanvasSizeId })
            ?? template.schema.defaultCanvasSize
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
            let synced = await viewModel.saveCurrentWorkExport(imageData: imageData, filename: filename)
            if !synced {
                exportError = saveToPhotoLibrary
                    ? "图片已保存到相册，但作品同步失败，请稍后重试"
                    : "图片可以分享，但作品同步失败，请稍后重试"
            }

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

private struct EditorFieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.cardifyMuted)
    }
}

private struct CanvasSizeQuickPicker: View {
    let canvasSizes: [CanvasSize]
    @Binding var selectedSizeId: String
    let onSelection: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(canvasSizes) { size in
                Button {
                    selectedSizeId = size.id
                    onSelection()
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(size.ratioLabel)
                                .font(.headline.weight(.semibold))
                            Text(size.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if selectedSizeId == size.id {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.cardifyInk)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(
                        selectedSizeId == size.id ? Color.cardifyMint : Color.cardifyPaper,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selectedSizeId == size.id ? Color.cardifyInk.opacity(0.18) : Color.cardifyMint, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(size.label) \(size.ratioLabel)")
                .accessibilityValue(selectedSizeId == size.id ? "已选中" : "未选中")
                .accessibilityHint("点按后立即应用画布比例")
            }
        }
        .padding(12)
        .frame(width: 320)
        .background(Color.cardifyPaper)
    }
}

private struct MetricField: View {
    let label: String
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", text: $value)
                .cardifyNumericKeyboard()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .cardifyEditorFieldSurface()
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

private struct WorksView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    let onOpenWork: () -> Void
    @State private var isSignInPresented = false
    @State private var scope: WorkLibraryScope = .all
    @State private var searchText = ""
    @State private var templateFilterID: String?
    @State private var exportFilter: WorkExportFilter = .all
    @State private var pendingDeletion: PendingLibraryDeletion?

    private let gridColumns = [
        GridItem(.flexible(minimum: 144), spacing: 12),
        GridItem(.flexible(minimum: 144), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    WorkLibrarySummary(
                        workCount: viewModel.currentUser == nil ? 0 : viewModel.worksTotal,
                        draftCount: filteredDrafts.count,
                        isSignedIn: viewModel.currentUser != nil
                    )

                    Picker("作品范围", selection: $scope) {
                        ForEach(WorkLibraryScope.available(isSignedIn: viewModel.currentUser != nil)) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    WorkLibraryFilters(
                        templates: viewModel.templates,
                        selectedTemplateID: $templateFilterID,
                        exportFilter: $exportFilter,
                        showsExportFilter: scope != .drafts && viewModel.currentUser != nil
                    )

                    if let message = viewModel.worksErrorMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isCompletelyEmpty {
                        WorkLibraryEmptyState(isSignedIn: viewModel.currentUser != nil) {
                            isSignInPresented = true
                        }
                    } else {
                        if showsWorks {
                            workSection
                        }

                        if showsDrafts {
                            draftsSection
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.cardifyPaper)
            .navigationTitle("作品")
            .searchable(text: $searchText, prompt: "搜索标题或内容")
            .onSubmit(of: .search) {
                Task { await reloadWorks() }
            }
            .onChange(of: searchText) { _, value in
                if value.isEmpty {
                    Task { await reloadWorks() }
                }
            }
            .onChange(of: templateFilterID) { _, _ in
                Task { await reloadWorks() }
            }
            .onChange(of: exportFilter) { _, _ in
                Task { await reloadWorks() }
            }
            .onChange(of: viewModel.currentUser?.id) { _, userID in
                if userID == nil {
                    scope = .all
                }
                Task { await reloadWorks() }
            }
            .toolbar {
                Button {
                    Task { await reloadWorks() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("刷新作品")
            }
            .task {
                await reloadWorks()
            }
            .refreshable {
                await reloadWorks()
            }
            .sheet(isPresented: $isSignInPresented) {
                AccountSignInSheet()
            }
            .alert("删除此内容？", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )) {
                Button("取消", role: .cancel) {
                    pendingDeletion = nil
                }
                Button("删除", role: .destructive) {
                    deletePendingItem()
                }
            } message: {
                Text(pendingDeletion?.message ?? "删除后无法恢复。")
            }
        }
    }

    @ViewBuilder
    private var workSection: some View {
        WorkLibrarySectionHeader(
            title: "云端作品",
            detail: "\(viewModel.worksTotal) 个"
        )

        if viewModel.isLoadingWorks && viewModel.works.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                Text("正在整理作品库")
                    .font(.subheadline)
                    .foregroundStyle(Color.cardifyMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else if viewModel.currentUser == nil {
            WorkLibrarySignInPrompt {
                isSignInPresented = true
            }
        } else if viewModel.works.isEmpty {
            WorkLibraryNoResults(title: "没有找到作品", detail: "换个关键词或筛选条件试试")
        } else {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.works) { work in
                    WorkLibraryCard(
                        title: work.title,
                        content: CardContent(
                            renderParams: work.renderParams,
                            fallbackTitle: work.title,
                            fallbackSummary: work.inputText
                        ),
                        template: template(for: work.templateId),
                        canvasSizeID: work.renderParams.string(
                            "canvas_size_id",
                            default: template(for: work.templateId)?.defaultSizeId ?? "xhs-3-4"
                        ),
                        templateName: template(for: work.templateId)?.name ?? "已归档模板",
                        status: work.exportPath == nil ? "未导出" : "已导出",
                        statusIcon: work.exportPath == nil ? "square.and.pencil" : "checkmark.circle.fill",
                        date: work.updatedAt,
                        onOpen: {
                            Task {
                                if await viewModel.reopenWork(work) {
                                    onOpenWork()
                                }
                            }
                        },
                        onDelete: {
                            pendingDeletion = .work(work)
                        }
                    )
                }
            }

            if viewModel.hasMoreWorks {
                Button("加载更多作品", systemImage: "arrow.down") {
                    Task { await viewModel.loadMoreWorks() }
                }
                .buttonStyle(.bordered)
                .tint(Color.cardifyNavActive)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isLoadingWorks)
            }
        }
    }

    @ViewBuilder
    private var draftsSection: some View {
        WorkLibrarySectionHeader(
            title: "本机草稿",
            detail: "\(filteredDrafts.count) 个"
        )

        if filteredDrafts.isEmpty {
            WorkLibraryNoResults(title: "没有本机草稿", detail: "保存草稿后，可以随时回到这里继续编辑")
        } else {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(filteredDrafts) { draft in
                    WorkLibraryCard(
                        title: CardContent(
                            renderParams: draft.renderParams,
                            fallbackTitle: "未命名草稿",
                            fallbackSummary: draft.inputText
                        ).title,
                        content: draftContent(draft),
                        template: template(for: draft.templateId),
                        canvasSizeID: draft.renderParams.string(
                            "canvas_size_id",
                            default: template(for: draft.templateId)?.defaultSizeId ?? "xhs-3-4"
                        ),
                        templateName: template(for: draft.templateId)?.name ?? "已归档模板",
                        status: "本机草稿",
                        statusIcon: "internaldrive",
                        date: draft.updatedAt,
                        onOpen: {
                            if viewModel.reopenLocalDraft(draft) {
                                onOpenWork()
                            }
                        },
                        onDelete: {
                            pendingDeletion = .draft(draft)
                        }
                    )
                }
            }

            if viewModel.currentUser != nil {
                Button("同步本机草稿", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await viewModel.syncLocalDraftsNow() }
                }
                .buttonStyle(.bordered)
                .tint(Color.cardifyNavActive)
                .disabled(viewModel.isSaving)
            }
        }
    }

    private var filteredDrafts: [LocalDraftRecord] {
        viewModel.localDrafts.filter { draft in
            let content = CardContent(
                renderParams: draft.renderParams,
                fallbackTitle: "未命名草稿",
                fallbackSummary: draft.inputText
            )
            let matchesSearch = searchText.isEmpty
                || content.title.localizedCaseInsensitiveContains(searchText)
                || draft.inputText.localizedCaseInsensitiveContains(searchText)
            let matchesTemplate = templateFilterID == nil || draft.templateId == templateFilterID
            return matchesSearch && matchesTemplate
        }
    }

    private var showsWorks: Bool {
        scope == .all || scope == .works
    }

    private var showsDrafts: Bool {
        scope == .all || scope == .drafts
    }

    private var isCompletelyEmpty: Bool {
        scope == .all
            && !viewModel.isLoadingWorks
            && filteredDrafts.isEmpty
            && (viewModel.currentUser == nil || viewModel.works.isEmpty)
    }

    private func template(for id: String) -> TemplateSummary? {
        viewModel.templates.first(where: { $0.id == id })
    }

    private func draftContent(_ draft: LocalDraftRecord) -> CardContent {
        var content = CardContent(
            renderParams: draft.renderParams,
            fallbackTitle: "未命名草稿",
            fallbackSummary: draft.inputText
        )
        content.coverImageData = draft.coverImageData
        content.avatarImageData = draft.avatarImageData
        return content
    }

    private func reloadWorks() async {
        await viewModel.loadWorks(
            query: searchText,
            templateId: templateFilterID,
            exported: exportFilter.apiValue
        )
    }

    private func deletePendingItem() {
        guard let pendingDeletion else { return }
        self.pendingDeletion = nil
        switch pendingDeletion {
        case .work(let work):
            Task { await viewModel.deleteWork(work) }
        case .draft(let draft):
            viewModel.deleteLocalDraft(draft)
        }
    }
}

private enum WorkLibraryScope: String, CaseIterable, Identifiable {
    case all
    case works
    case drafts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .works: return "作品"
        case .drafts: return "草稿"
        }
    }

    static func available(isSignedIn: Bool) -> [WorkLibraryScope] {
        isSignedIn ? allCases : [.all, .drafts]
    }
}

private enum WorkExportFilter: String, CaseIterable, Identifiable {
    case all
    case exported
    case pending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部状态"
        case .exported: return "已导出"
        case .pending: return "未导出"
        }
    }

    var apiValue: Bool? {
        switch self {
        case .all: return nil
        case .exported: return true
        case .pending: return false
        }
    }
}

private enum PendingLibraryDeletion {
    case work(WorkRecord)
    case draft(LocalDraftRecord)

    var message: String {
        switch self {
        case .work: return "作品和已保存的图片将从当前账户移除，无法恢复。"
        case .draft: return "本机草稿将从这台设备移除，无法恢复。"
        }
    }
}

private struct WorkLibrarySummary: View {
    let workCount: Int
    let draftCount: Int
    let isSignedIn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "rectangle.stack.fill")
                .font(.title2)
                .foregroundStyle(Color.cardifyNavActive)
                .frame(width: 42, height: 42)
                .background(Color.cardifyPaper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(isSignedIn ? "\(workCount) 个云端作品" : "本机创作档案")
                    .font(.headline)
                    .foregroundStyle(Color.cardifyInk)
                Text("\(draftCount) 个本机草稿 · 最近编辑优先")
                    .font(.caption)
                    .foregroundStyle(Color.cardifyMuted)
            }
            Spacer(minLength: 8)
        }
        .padding(14)
        .background(Color.cardifyMint)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WorkLibraryFilters: View {
    let templates: [TemplateSummary]
    @Binding var selectedTemplateID: String?
    @Binding var exportFilter: WorkExportFilter
    let showsExportFilter: Bool

    private var selectedTemplateName: String {
        templates.first(where: { $0.id == selectedTemplateID })?.name ?? "全部模板"
    }

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Button("全部模板") { selectedTemplateID = nil }
                Divider()
                ForEach(templates) { template in
                    Button(template.name) { selectedTemplateID = template.id }
                }
            } label: {
                Label(selectedTemplateName, systemImage: "square.grid.2x2")
                    .font(.subheadline)
                    .foregroundStyle(Color.cardifyInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if showsExportFilter {
                Menu {
                    ForEach(WorkExportFilter.allCases) { filter in
                        Button(filter.title) { exportFilter = filter }
                    }
                } label: {
                    Label(exportFilter.title, systemImage: "arrow.down.doc")
                        .font(.subheadline)
                        .foregroundStyle(Color.cardifyInk)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct WorkLibrarySectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.cardifyInk)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.cardifyMuted)
        }
        .padding(.top, 2)
    }
}

private struct WorkLibraryCard: View {
    let title: String
    let content: CardContent
    let template: TemplateSummary?
    let canvasSizeID: String
    let templateName: String
    let status: String
    let statusIcon: String
    let date: Date
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                preview

                Menu {
                    Button("打开编辑", systemImage: "pencil", action: onOpen)
                    Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.cardifyInk.opacity(0.72))
                        .padding(8)
                }
                .accessibilityLabel("作品操作")
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cardifyInk)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(templateName)
                .font(.caption)
                .foregroundStyle(Color.cardifyMuted)
                .lineLimit(1)

            HStack(spacing: 6) {
                Label(status, systemImage: statusIcon)
                    .font(.caption2)
                    .foregroundStyle(status == "已导出" ? Color.cardifyNavActive : Color.cardifyMuted)
                Spacer(minLength: 4)
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(Color.cardifyMuted)
            }
        }
        .padding(8)
        .background(Color.cardifyPaper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.cardifyMint, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityHint("点按打开编辑")
    }

    @ViewBuilder
    private var preview: some View {
        if let template {
            TemplateCanvasView(template: template.schema, content: content, canvasSizeId: canvasSizeID)
                .frame(maxWidth: .infinity)
                .frame(height: 172)
                .background(Color.cardifySky, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.slash")
                    .font(.title3)
                Text("模板已归档")
                    .font(.caption)
            }
            .foregroundStyle(Color.cardifyMuted)
            .frame(maxWidth: .infinity, minHeight: 172)
            .background(Color.cardifySky, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

private struct WorkLibraryNoResults: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(Color.cardifyNavInactive)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cardifyInk)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.cardifyMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .padding(12)
    }
}

private struct WorkLibrarySignInPrompt: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.title2)
                .foregroundStyle(Color.cardifyNavActive)
            Text("登录后查看云端作品")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cardifyInk)
            Button("通过 Apple 登录", action: action)
                .buttonStyle(.bordered)
                .tint(Color.cardifyNavActive)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }
}

private struct WorkLibraryEmptyState: View {
    let isSignedIn: Bool
    let signInAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.cardifyNavInactive)
            Text("还没有创作内容")
                .font(.headline)
                .foregroundStyle(Color.cardifyInk)
            Text(isSignedIn ? "完成并保存一张魔卡后，它会出现在这里。" : "保存草稿后，可在这里继续编辑；登录后还能同步到其他设备。")
                .font(.subheadline)
                .foregroundStyle(Color.cardifyMuted)
                .multilineTextAlignment(.center)
            if !isSignedIn {
                Button("通过 Apple 登录", action: signInAction)
                    .buttonStyle(.bordered)
                    .tint(Color.cardifyNavActive)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.horizontal, 24)
    }
}

private struct AccountSignInSheet: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.cardifyNavActive)
                Text("登录后同步作品")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.cardifyInk)
                Text("本机草稿会在登录后同步到你的账户，方便继续创作与管理。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                AppleSignInControl()
                Spacer()
            }
            .padding(24)
            .navigationTitle("账户")
            .cardifyInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: viewModel.currentUser?.id) { _, userId in
                if userId != nil {
                    dismiss()
                }
            }
        }
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel
    @Environment(\.openURL) private var openURL
    @State private var isDeleteAccountConfirmationPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("账户") {
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
                    Label("加密会话", systemImage: "key.fill")
                }

                Section("Cardify Pro") {
                    MembershipStatusRow(status: viewModel.membershipStatus)

                    if viewModel.currentUser == nil {
                        Text("登录后即可开通会员，并在已登录设备之间同步权益。")
                            .font(.footnote)
                            .foregroundStyle(Color.cardifyMuted)
                    } else if viewModel.isMembershipLoading && viewModel.subscriptionProducts.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在获取会员方案")
                                .font(.subheadline)
                                .foregroundStyle(Color.cardifyMuted)
                        }
                    } else if viewModel.subscriptionProducts.isEmpty {
                        Button("重新加载会员方案", systemImage: "arrow.clockwise") {
                            Task { await viewModel.loadMembership() }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.cardifyNavActive)
                    } else {
                        ForEach(viewModel.subscriptionProducts) { product in
                            MembershipPlanRow(
                                product: product,
                                isRecommended: product.id == "com.jiefeng.cardify.pro.monthly"
                            ) {
                                Task { await viewModel.purchaseMembership(product) }
                            }
                            .disabled(viewModel.isPurchasingMembership)
                        }

                        Button("恢复购买", systemImage: "arrow.clockwise") {
                            Task { await viewModel.restoreMembershipPurchases() }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.cardifyNavActive)
                        .disabled(viewModel.isPurchasingMembership)
                    }

                    if let message = viewModel.membershipErrorMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("订阅价格与周期以 App Store 购买页面为准。订阅会自动续期，除非在当前周期结束前至少 24 小时取消。")
                        .font(.footnote)
                        .foregroundStyle(Color.cardifyMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("管理订阅", systemImage: "arrow.up.right.square") {
                        openURL(AppLegal.manageSubscriptionsURL)
                    }
                    .tint(Color.cardifyNavActive)
                }

                if viewModel.currentUser != nil {
                    Section("账户管理") {
                        Button("删除账户", systemImage: "trash", role: .destructive) {
                            isDeleteAccountConfirmationPresented = true
                        }
                        .disabled(viewModel.isDeletingAccount)

                        Text("删除后会永久移除云端账户、作品和图片。本机未同步草稿会保留在当前设备。")
                            .font(.footnote)
                            .foregroundStyle(Color.cardifyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("法律与支持") {
                    Link(destination: AppLegal.privacyPolicyURL) {
                        Label("隐私政策", systemImage: "hand.raised")
                    }
                    Link(destination: AppLegal.termsOfServiceURL) {
                        Label("服务条款", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("我的")
            .alert("确认删除账户？", isPresented: $isDeleteAccountConfirmationPresented) {
                Button("删除账户", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("云端作品、图片和账户资料将永久删除，无法恢复。Apple 订阅不会随账户删除而取消，请先在 App Store 管理订阅。")
            }
        }
    }
}

private enum AppLegal {
    static let privacyPolicyURL = URL(string: "https://www.cardify.notenap.com/legal/privacy")!
    static let termsOfServiceURL = URL(string: "https://www.cardify.notenap.com/legal/terms")!
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}

private struct MembershipStatusRow: View {
    let status: MembershipStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.isPro ? "crown.fill" : "crown")
                .font(.title3)
                .foregroundStyle(status.isPro ? Color.cardifyNavActive : Color.cardifyMuted)
                .frame(width: 30, height: 30)
                .background(Color.cardifyMint.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(status.isPro ? "Pro 已生效" : "未开通会员")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cardifyInk)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.cardifyMuted)
            }

            Spacer(minLength: 8)

            Text(status.isPro ? "已开通" : statusLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(status.isPro ? Color.cardifyNavActive : Color.cardifyMuted)
        }
        .padding(.vertical, 3)
    }

    private var detail: String {
        if let expiresAt = status.expiresAt {
            return "有效至 \(expiresAt.formatted(date: .abbreviated, time: .omitted))"
        }
        return status.isPro ? "权益已同步到当前账户" : "解锁更多创作权益"
    }

    private var statusLabel: String {
        switch status.status {
        case .expired: return "已到期"
        case .revoked: return "已失效"
        case .none, .active: return "免费版"
        }
    }
}

private struct MembershipPlanRow: View {
    let product: Product
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(product.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cardifyInk)
                if isRecommended {
                    Text("推荐")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.cardifyNavActive)
                }
                Spacer(minLength: 8)
                Text(product.displayPrice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cardifyInk)
            }

            if !product.description.isEmpty {
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(Color.cardifyMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isRecommended {
                Button("开通 Pro", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.cardifyNavActive)
                    .controlSize(.regular)
            } else {
                Button("选择此方案", action: action)
                    .buttonStyle(.bordered)
                    .tint(Color.cardifyNavActive)
                    .controlSize(.regular)
            }
        }
        .padding(.vertical, 5)
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

private extension View {
    func cardifyEditorFieldSurface() -> some View {
        background(
            Color.cardifyInk.opacity(0.028),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.cardifyInk.opacity(0.09), lineWidth: 1)
        )
    }

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
