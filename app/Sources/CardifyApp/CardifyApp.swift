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
            await viewModel.loadWorks()
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
                                TextEditor(text: $viewModel.generatedContent.summary)
                                    .font(.body)
                                    .frame(height: 104)
                                    .padding(8)
                                    .scrollContentBackground(.hidden)
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

    var body: some View {
        NavigationStack {
            List {
                if viewModel.works.isEmpty {
                    ContentUnavailableView(
                        "还没有作品",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("完成并保存一张魔卡后，它会出现在这里")
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
            .navigationTitle("作品")
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

private struct ProfileView: View {
    @EnvironmentObject private var viewModel: CardifyViewModel

    var body: some View {
        NavigationStack {
            List {
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
