//
//  ResourcesSearchPage.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/16.
//

import SwiftUI
import Core

struct ResourcesSearchPage: View {
    @StateObject private var viewModel: ResourcesSearchViewModel
    @State private var currentPage: Int = 0
    
    init(type: ResourceType) {
        self._viewModel = StateObject(wrappedValue: .init(type: type))
    }
    
    var body: some View {
        CardContainer {
            if viewModel.type == .shader {
                MyTip(text: "光影包需要搭配光影加载器使用。\n详细教程：https://cylorine.studio/helps/shader", theme: .blue)
                    .onTapGesture {
                        NSWorkspace.shared.open(URL(string: "https://cylorine.studio/helps/shader")!)
                    }
            }
            MySearchBox(placeholder: "搜索\(viewModel.type.localizedName)") { query in
                currentPage = 0
                Task {
                    do {
                        try await viewModel.search(query)
                    } catch let error where error.isCancellationError {
                    } catch {
                        err("搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)")
                        await MainActor.run {
                            viewModel.loadingVM.fail(with: "搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)")
                        }
                    }
                }
            }

            Picker("来源", selection: $viewModel.source) {
                ForEach(ResourcesSearchViewModel.SearchSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.source) { _ in
                currentPage = 0
                Task {
                    do {
                        try await viewModel.search(viewModel.query)
                    } catch {
                        await MainActor.run {
                            viewModel.loadingVM.fail(with: "搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)")
                        }
                    }
                }
            }
            
            if let searchResults = viewModel.searchResults {
                PaginatedContainer(currentPage: $currentPage, pageCount: viewModel.totalPages) { _ in
                    MyCard(nil) {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults) { project in
                                ProjectListItemView(project: project)
                                    .onTapGesture {
                                        AppRouter.shared.append(.projectInstall(project: project))
                                    }
                            }
                        }
                    }
                }
                .onChange(of: currentPage) { newValue in
                    Task {
                        do {
                            try await viewModel.changePage(newValue)
                        } catch let error where error.isCancellationError {
                        } catch {
                            err("搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)")
                            await MainActor.run {
                                viewModel.loadingVM.fail(with: "搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)")
                            }
                        }
                    }
                }
            } else {
                MyLoading(viewModel: viewModel.loadingVM)
            }
        }
        .task {
            do {
                try await viewModel.search("")
            } catch let error where error.isCancellationError {
            } catch {
                err("搜索\(viewModel.type.localizedName)失败：\(error)")
                await MainActor.run {
                    viewModel.loadingVM.fail(with: "搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)")
                }
            }
        }
    }
}

struct ProjectListItemView: View {
    private let project: ProjectListItemModel
    private let isTagRowSeparated: Bool
    
    init(project: ProjectListItemModel, primary: Bool = false) {
        self.project = project
        self.isTagRowSeparated = primary && project.tags.count > 3
    }
    
    var body: some View {
        MyListItem {
            HStack {
                Group {
                    if let iconURL: URL = project.iconURL {
                        NetworkImage(url: iconURL)
                    } else {
                        Image(.iconModLogo)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 48, height: 48)
                .padding(.leading, 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    MyText(project.title, size: 16)
                        .lineLimit(1)
                    
                    if isTagRowSeparated {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(project.tags, id: \.self) { tag in
                                    MyTag(tag, labelColor: .colorGray2, backgroundColor: .init(0x000000, alpha: 17 / 255), size: 12)
                                }
                            }
                        }
                        
                        MyText(project.description, color: .colorGray3)
                    } else {
                        HStack {
                            ForEach(project.tags.prefix(3), id: \.self) { tag in
                                MyTag(tag, labelColor: .colorGray2, backgroundColor: .init(0x000000, alpha: 17 / 255), size: 12)
                            }
                            MyText(project.description, color: .colorGray3)
                                .lineLimit(1)
                        }
                    }
                    
                    HStack {
                        InformationView(icon: .iconSettingsPage, text: project.supportDescription, width: 200)
                        InformationView(icon: .iconDownloadPage, text: project.downloads, width: 150)
                        InformationView(icon: .iconUpload, text: project.lastUpdate, width: 150)
                        Spacer()
                    }
                    
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
        }
    }
    
    private struct InformationView: View {
        private let icon: ImageResource
        private let text: String
        private let width: CGFloat
        
        init(icon: ImageResource, text: String, width: CGFloat) {
            self.icon = icon
            self.text = text
            self.width = width
        }
        
        var body: some View {
            HStack(spacing: 6) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14)
                    .foregroundStyle(Color.colorGray3)
                MyText(text, size: 12, color: .colorGray3)
            }
            .frame(width: width, alignment: .leading)
        }
    }
}
