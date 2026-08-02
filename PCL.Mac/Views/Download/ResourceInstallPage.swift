//
//  ResourceInstallPage.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/19.
//

import SwiftUI
import Core

struct ResourceInstallPage: View {
    @StateObject private var viewModel: ResourceInstallViewModel
    @StateObject private var instanceVM: InstanceViewModel
    @State private var currentPage: Int = 0
    
    init(instanceManager: InstanceManager, project: ProjectListItemModel) {
        self._viewModel = .init(wrappedValue: .init(project: project))
        self._instanceVM = .init(wrappedValue: InstanceViewModel(instanceManager: instanceManager))
    }
    
    var body: some View {
        CardContainer {
            MyCard(nil) {
                ProjectListItemView(project: viewModel.project, primary: true)
                HStack {
                    MyButton("Modrinth", type: .highlight) {
                        NSWorkspace.shared.open(URL(string: "https://modrinth.com/project/\(viewModel.project.id)")!)
                    }
                    .frame(width: 120)
                    Spacer(minLength: 0)
                }
                .frame(height: 35)
            }
            if viewModel.loaded, let versionList = viewModel.versionList {
                if currentPage == 0, let selectedVersionGroup = viewModel.selectedVersionGroup {
                    versionCard(versionGroup: selectedVersionGroup, isSelected: true, folded: false)
                }
                PaginatedContainer(versionList, id: \.0, currentPage: $currentPage, viewsPerPage: 10) { versionGroup in
                    versionCard(versionGroup: versionGroup, folded: versionList.count == 1 ? false : true)
                }
            } else {
                MyLoading(viewModel: viewModel.loadingVM)
                    .cardIndex(1)
            }
        }
        .task(id: viewModel.project) {
            do {
                try await viewModel.load(selectedInstance: instanceVM.currentInstance)
            } catch let error where error.isCancellationError {
            } catch {
                err("加载\(viewModel.project.type.localizedName) \(viewModel.project.title) 版本列表失败：\(error)")
                viewModel.loadingVM.fail(with: "加载版本列表失败：\(error.localizedDescription)")
            }
        }
    }
    
    private func onVersionTap(_ version: ProjectVersionModel) async throws {
        guard let instance: MinecraftInstance = instanceVM.currentInstance else {
            hint("请先安装并选择一个实例！", type: .critical)
            return
        }
        
        do {
            try viewModel.checkInstance(instance, withVersion: version)
        } catch let error as ResourceInstallViewModel.InstanceCheckError {
            log("当前实例不满足该版本要求：\(error.localizedDescription)")
            switch error {
            case .versionUnsupported:
                if await MessageBoxManager.shared.showTextAsync(
                    title: "当前实例不符合要求",
                    content: "\(error.localizedDescription)\n你可以选择继续安装，但游戏可能会发生崩溃或无法正常游玩。\n是否继续安装？",
                    level: .error,
                    .no(),
                    .yes(label: "继续", type: .red)
                ) != 1 {
                    return
                }
            default:
                _ = await MessageBoxManager.shared.showTextAsync(
                    title: "当前实例不符合要求",
                    content: error.localizedDescription,
                    level: .error
                )
                return
            }
        }
        
        if await MessageBoxManager.shared.showTextAsync(
            title: "确认",
            content: "确定要安装 \(viewModel.project.title) \(version.version) 吗？",
            level: .info,
            .no(),
            .yes(type: .highlight)
        ) == 1 {
            do {
                let task = try await viewModel.createInstallTask(forVersion: version, to: instance)
                TaskManager.shared.execute(task: task)
                AppRouter.shared.append(.tasks)
            }
        }
    }
    
    private func onModpackTap(_ version: ProjectVersionModel) async throws {
        let repository = instanceVM.currentRepository
        guard await MessageBoxManager.shared.showTextAsync(
            title: "确认",
            content: "确定要安装整合包 \(viewModel.project.title) \(version.version) 吗？",
            level: .info,
            .no(),
            .yes(type: .highlight)
        ) == 1 else { return }
        
        hint("开始下载整合包……")
        
        let (downloadTask, destination): (MyTask<EmptyModel>, URL)
        do {
            (downloadTask, destination) = try viewModel.createModpackDownloadTask(version)
        } catch {
            err("创建下载任务失败：\(error.localizedDescription)")
            hint("创建下载任务失败：\(error.localizedDescription)", type: .critical)
            return
        }
        
        let downloadExecutorTask: Task<Void, Error> = TaskManager.shared.execute(task: downloadTask)
        do {
            try await downloadExecutorTask.value
        } catch {
            err("下载整合包失败：\(error.localizedDescription)")
            hint("下载整合包失败：\(error.localizedDescription)", type: .critical)
            return
        }
        
        let service = ModpackImportService(modpackURL: destination)
        
        do {
            let index = try service.load()
            guard let name = await MessageBoxManager.shared.showInputAsync(
                title: "安装整合包 - 输入实例名",
                initialContent: index.name
            ) else { return }
            
            let task = try service.createImportTask(name: name, repository: repository) { instance in
                instanceVM.switchInstance(to: instance, in: repository)
            }
            TaskManager.shared.execute(task: task)
        } catch {
            err("安装整合包失败：\(error.localizedDescription)")
            hint("安装整合包失败：\(error.localizedDescription)", type: .critical)
        }
    }
    
    @ViewBuilder
    private func versionCard(versionGroup: ResourceInstallViewModel.VersionGroup, isSelected: Bool = false, folded: Bool = true) -> some View {
        MyCard((isSelected ? "最佳版本：" : "") + versionGroup.0.description, folded: folded) {
            let dependencies: [ProjectVersionModel.Dependency] = versionGroup.1[0].requiredDependencies
            if !dependencies.isEmpty {
                VStack(alignment: .leading) {
                    MyText("前置资源")
                    VStack(spacing: 0) {
                        ForEach(dependencies) { dependency in
                            ProjectListItemView(project: dependency.project)
                                .onTapGesture {
                                    AppRouter.shared.append(.projectInstall(project: dependency.project))
                                }
                        }
                    }
                    MyText("版本列表")
                }
            }
            VStack(spacing: 0) {
                ForEach(versionGroup.1) { version in
                    VersionListItemView(version: version)
                        .onTapGesture {
                            log("\(version.name) \(version.version) 被点击")
                            Task {
                                do {
                                    if viewModel.project.type == .modpack {
                                        try await onModpackTap(version)
                                    } else {
                                        try await onVersionTap(version)
                                    }
                                } catch {
                                    err("执行点击回调意外失败：\(error.localizedDescription)")
                                    hint("执行点击回调意外失败：\(error.localizedDescription)", type: .critical)
                                }
                            }
                        }
                }
            }
        }
    }
    
    private struct VersionListItemView: View {
        private let model: ListItem
        
        init(version: ProjectVersionModel) {
            self.model = .init(
                image: version.type.icon,
                name: version.name,
                description: "\(version.version)，更新于\(version.datePublished)，\(version.type.localizedName)"
            )
        }
        
        var body: some View {
            MyListItem(model)
        }
    }
}
