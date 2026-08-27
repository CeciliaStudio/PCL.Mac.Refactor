//
//  ModpackViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/23.
//

import Foundation
import Core

class ModpackViewModel: ObservableObject {
    private let instanceManager: InstanceManager
    
    init(instanceManager: InstanceManager) {
        self.instanceManager = instanceManager
    }
    
    @MainActor
    public func importModpack(at url: URL, repository: MinecraftRepository) async {
        let curseforgeClient = CurseForgeAPIClient(apiKey: Secrets.shared.curseforgeApiKey)
        let service = ModpackImportService(curseforgeClient: curseforgeClient, modpackURL: url)
        
        let handleUnknownError: (Error) -> Void = { (error: Error) in
            MessageBoxManager.shared.showText(
                title: "发生未知错误",
                content: "\(error.localizedDescription)\n\n若要寻求帮助，请将完整日志报告发送给他人，而不是发送关于此页面的图片。",
                level: .error
            )
        }
        
        do {
            let index = try service.load()
            guard await MessageBoxManager.shared.showTextAsync(
                title: "整合包信息",
                content: "格式：\(index.format)\n名称：\(index.name)\n版本：\(index.version)\n作者：\(index.author ?? "未知")\n描述：\(index.description ?? "空")\n依赖：\(index.dependencyInfo)\n\n是否继续安装？",
                level: .info,
                .no(),
                .yes(label: "继续")
            ) == 1 else { return }
            
            guard let name = await MessageBoxManager.shared.showInputAsync(
                title: "导入整合包 - 输入实例名",
                initialContent: index.name
            ) else { return }
            
            
            let completion: @MainActor (MinecraftInstance) -> Void = { instance in
                self.instanceManager.switchInstance(to: instance, in: repository)
            }
            
            if index.format == .simple {
                let task = try service.createSimpleImportTask(name: name, repository: repository, completion: completion)
                TaskManager.shared.execute(task: task)
            } else {
                let task = try service.createImportTask(name: name, repository: repository, completion: completion)
                TaskManager.shared.execute(task: task)
            }
            
            AppRouter.shared.append(.tasks)
        } catch let error as ModpackImportService.LoadError {
            switch error {
            case .extractFailed(_):
                MessageBoxManager.shared.showText(
                    title: "解压整合包失败",
                    content: "\(error.localizedDescription)",
                    level: .error
                )
            case .unsupportedModLoader(let name):
                MessageBoxManager.shared.showText(
                    title: "不支持的模组加载器",
                    content: "很抱歉，PCL.Mac 暂时不支持安装这个整合包使用的 \(name) 加载器……",
                    level: .error
                )
            case .unknownFormat:
                MessageBoxManager.shared.showText(
                    title: "不支持的整合包格式",
                    content: "很抱歉，PCL.Mac 目前只支持导入 Modrinth、CurseForge、MCBBS 和普通压缩包格式的整合包，不支持这个整合包使用的格式……",
                    level: .error
                )
            default:
                handleUnknownError(error)
            }
        } catch let error as ModpackImportService.ImportError {
            switch error {
            case .invalidName(let underlying):
                hint("该名称无效：\(underlying.localizedDescription)", type: .critical)
            case .extractFailed(_):
                MessageBoxManager.shared.showText(
                    title: "解压整合包失败",
                    content: "\(error.localizedDescription)",
                    level: .error
                )
            default:
                handleUnknownError(error)
            }
        } catch {} // 不知道为什么必须加个 catch 兜底，上面的两个 catch 明明已经覆盖到所有声明了
    }
}
