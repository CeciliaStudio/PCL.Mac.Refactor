//
//  InstalledResourcesPage.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/6/7.
//

import SwiftUI
import Core

struct InstalledResourcesPage: View {
    @StateObject private var viewModel: InstalledResourcesViewModel
    @StateObject private var loadingVM: MyLoadingViewModel
    
    init(instanceManager: InstanceManager, id: String, type: ResourceType) {
        self._viewModel = .init(wrappedValue: .init(instanceManager: instanceManager, id: id, type: type))
        self._loadingVM = .init(wrappedValue: MyLoadingViewModel(text: "加载中"))
    }
    
    var body: some View {
        Group {
            if !viewModel.supportMods {
                MyCard(nil) {
                    VStack(spacing: 10) {
                        MyText("该实例不可使用 Mod", size: 19, color: .color3)
                        
                        Rectangle()
                            .fill(Color.color3)
                            .frame(height: 2)
                        
                        MyText("你需要先安装 Forge、Fabric 等 Mod 加载器才能使用 Mod，请在安装实例时选择这些加载器。\n如果你已经安装了 Mod 加载器，那么你很可能选择了错误的实例，请点击实例选择按钮切换实例。")
                            .padding(.vertical, 5)
                        
                        HStack(spacing: 20) {
                            MyButton("转到下载页面", type: .highlight) {
                                AppRouter.shared.setRoot(.download)
                            }
                            .frame(width: 140)
                            MyButton("实例选择") {
                                AppRouter.shared.setRoot(.launch)
                                AppRouter.shared.append(.instanceList(repositoryId: viewModel.currentRepositoryId))
                            }
                            .frame(width: 140)
                        }
                        .frame(height: 35)
                    }
                    .padding(10)
                }
                .padding(40)
            } else {
                CardContainer {
                    if viewModel.type == .shader {
                        MyTip(text: "光影包需要搭配光影加载器使用。\n详细教程：https://cylorine.studio/helps/shader", theme: .blue)
                            .onTapGesture {
                                NSWorkspace.shared.open(URL(string: "https://cylorine.studio/helps/shader")!)
                            }
                    }
                    
                    MySearchBox(placeholder: "搜索\(viewModel.type.localizedName)") { keyword in
                        viewModel.setSearchKeyword(keyword)
                    }
                    
                    MyCard(nil) {
                        HStack {
                            MyButton("打开文件夹") {
                                if let directory = viewModel.directory() {
                                    NSWorkspace.shared.open(directory)
                                }
                            }
                            .frame(width: 120)
                            Spacer(minLength: 0)
                        }
                        .frame(height: 40)
                    }
                    .cardIndex(1)
                    
                    if let resources = viewModel.resources, !resources.isEmpty {
                        PaginatedContainer(currentPage: $viewModel.currentPage, pageCount: viewModel.pageCount) { currentPage in
                            MyCard(nil) {
                                VStack(spacing: 0) {
                                    ForEach(resources, id: \.id) { resource in
                                        ResourceListItem(viewModel: viewModel, resource: resource)
                                    }
                                }
                            }
                            .onChange(of: currentPage) { _ in
                                viewModel.updateResources()
                            }
                        }
                    } else {
                        MyLoading(viewModel: loadingVM)
                    }
                }
            }
        }
        .task {
            loadingVM.reset()
            do {
                try await viewModel.load()
            } catch {
                err("加载资源列表失败：\(error.localizedDescription)")
                loadingVM.fail(with: "加载资源列表失败：\(error.localizedDescription)")
            }
        }
        .onChange(of: viewModel.resources) { newValue in
            if let newValue, newValue.isEmpty {
                if viewModel.hasSearchKeyword {
                    loadingVM.fail(with: "没有匹配的结果")
                } else {
                    loadingVM.fail(with: "这个实例没有安装任何\(viewModel.type.localizedName)！")
                }
            }
        }
        .onDisappear {
            viewModel.resources = nil
        }
    }
}

private struct ResourceListItem: View {
    @ObservedObject private var viewModel: InstalledResourcesViewModel
    @ObservedObject private var resource: ResourceDisplayModel
    
    init(viewModel: InstalledResourcesViewModel, resource: ResourceDisplayModel) {
        self.viewModel = viewModel
        self.resource = resource
    }
    
    var body: some View {
        MyListItem { hovered in
            HStack {
                resource.icon.makeView()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(Color.color1)
                
                VStack(alignment: .leading) {
                    HStack(alignment: .center, spacing: 0) {
                        Group {
                            if #available(macOS 13, *) {
                                MyText(resource.name)
                                    .strikethrough(resource.disabled)
                            } else {
                                MyText((resource.disabled ? "（已禁用）" : "") + resource.name)
                            }
                        }
                        .animation(.easeInOut(duration: 0.1), value: resource.disabled)
                        
                        MyText(" | \(resource.fileName)", size: 12, color: .colorGray3)
                        HStack(spacing: 3) {
                            ForEach(resource.tags, id: \.self) { tag in
                                MyTag(tag, labelColor: .colorGray2, backgroundColor: .black.opacity(0.05), size: 12)
                            }
                        }
                        .padding(.leading, 3)
                    }
                    HStack(spacing: 0) {
                        if let version = resource.version {
                            MyText("\(version) | ", size: 12, color: .colorGray3)
                        }
                        MyText(resource.description, size: 12, color: .colorGray3)
                    }
                }
                .lineLimit(1)
                .textSelection(.enabled)
                
                Spacer(minLength: 0)
                
                HStack {
                    ListItemButton(.resource(.btnOpen), scale: 0.8) {
                        NSWorkspace.shared.activateFileViewerSelecting([resource.url])
                    }
                    if !resource.sources.isEmpty {
                        ListItemButton(.resource(.iconAbout), clickPerform: viewInfo)
                    }
                    ListItemButton(.resource(resource.disabled ? .btnEnable : .btnDisable), clickPerform: toggleDisabled)
                        .animation(.easeInOut(duration: 0.1), value: resource.disabled)
                }
                .padding(.horizontal, 4)
                .allowsHitTesting(hovered)
                .opacity(hovered ? 1 : 0)
            }
        }
    }
    
    private func viewInfo() {
        Task {
            do {
                guard let info = try await viewModel.loadInfo(for: resource) else {
                    hint("未找到 \(resource.fileName) 对应的远端资源信息！", type: .critical)
                    return
                }
                AppRouter.shared.append(.projectInstall(project: info))
            } catch {
                err("获取资源信息失败：\(error.localizedDescription)")
                hint("获取资源信息失败：\(error.localizedDescription)", type: .critical)
            }
        }
    }
    
    private func toggleDisabled() {
        do {
            try viewModel.toggleDisabled(resource)
        } catch {
            let type = resource.disabled ? "启用" : "禁用"
            err("\(type)资源失败：\(error.localizedDescription)")
            hint("\(type)资源失败：\(error.localizedDescription)", type: .critical)
        }
    }
}
