//
//  MinecraftLaunchTask.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/2/5.
//

import Foundation
import Core
import AppKit

/// Minecraft 启动任务生成器。
public enum MinecraftLaunchTask {
    private typealias SubTask = MyTask<Model>.SubTask
    
    /// 创建 Minecraft 启动任务。
    /// - Parameters:
    ///   - instance: 启动的 Minecraft 实例。
    ///   - account: 启动时使用的账号。
    ///   - repository: 实例所在的游戏仓库。
    public static func create(
        for instance: MinecraftInstance,
        using account: Account,
        in repository: MinecraftRepository,
        onProcessStarted: @escaping (MinecraftLauncher, Process) -> Void
    ) -> MyTask<Model> {
        return .init(
            name: "启动游戏 - \(instance.name)",
            model: .init(instance: instance, account: account, repository: repository, onProcessStarted: onProcessStarted),
            .init(0, "检查 Java", checkJava(task:model:)),
            .init(1, "刷新账号", refreshAccount(task:model:)),
            .init(2, "预检查", precheck(task:model:)),
            .init(3, "检查资源完整性", checkResources(task:model:)),
            .init(4, "检查 Authlib Injector", checkAuthlibInjector(task:model:)),
            .init(5, "启动游戏", launch(task:model:)),
            .init(6, "等待游戏窗口出现", display: false, waitForWindow(task:model:))
        )
    }
    
    private static func checkJava(task: SubTask, model: Model) async throws {
        var javaRuntime: JavaRuntime? = model.instance.config.javaURL.flatMap { try? JavaSearcher.load(from: $0) }
        let minMajorVersion = model.instance.manifest.javaVersion.majorVersion
        
        let systemArch = Architecture.systemArchitecture()
        let requiredArch: Architecture? = model.instance.version < .init("1.7.2") ? .x64 : (systemArch == .x64 ? .x64 : nil)
        let recommendedArch = requiredArch ?? systemArch
        
        log("当前 Java 信息：\(javaRuntime?.description ?? "未配置")")
        log("当前实例需要 Java \(minMajorVersion) \(requiredArch?.description ?? "任意架构")，推荐架构：\(recommendedArch)")
        
        guard let bestMatch = JavaSearcher.pick(for: model.instance) else {
            warn("未找到符合要求的 Java")
            if await MessageBoxManager.shared.showTextAsync(
                title: "没有可用的 Java",
                content: "这个实例需要\(requiredArch?.description ?? "任意")架构的 Java \(minMajorVersion) 才能启动，但你的电脑上没有安装！\n\n点击下方按钮可以跳转到安装页面。",
                level: .error,
                .no(),
                .yes(label: "安装")
            ) == 1 {
                await AppRouter.shared.setRoot(.settings)
                await AppRouter.shared.append(.javaSettings)
            }
            try task.cancel()
            return
        }
        log("最佳 Java 搜索结果：\(bestMatch)")
        
        var bestMatchIssues: [String] = []
        
        if bestMatch.architecture != recommendedArch {
            warn("最佳结果架构与推荐架构不一致")
            bestMatchIssues.append("它需要通过 Rosetta 2 转译运行，这会导致性能下降，并大幅降低游戏体验。")
        }
        
        func showSwitchMessageBox(_ title: String, _ reason: String, force: Bool) async throws {
            var buttons: [MessageBoxModel.Button] = [.no(), .yes(label: "切换", type: .highlight)]
            buttons.insert(.init(id: 2, label: "继续启动", type: .red), at: 1)
            
            let issueText: String
            if bestMatchIssues.isEmpty { issueText = "" }
            else if bestMatchIssues.count == 1 {
                issueText = "但是\(bestMatchIssues[0])\n"
            } else {
                issueText = "但是：\n" + bestMatchIssues.map { " · " + $0 }.joined(separator: "\n") + "\n\n"
            }
            
            let result = await MessageBoxManager.shared.showTextAsync(
                title: title,
                content: "\(reason)\n\nPCL.Mac 找到了一个可用的 Java：\(bestMatch)，\(issueText)是否切换并继续启动？",
                level: force ? .error : .info,
                buttons: buttons
            )
            if result == 0 { try task.cancel() }
            
            if result == 1 {
                javaRuntime = bestMatch
            }
        }
        
        if javaRuntime == nil {
            if bestMatchIssues.isEmpty {
                log("已将当前 Java 设为最佳结果")
                javaRuntime = bestMatch
            } else {
                try await showSwitchMessageBox("没有配置 Java", "你还没有为这个实例设置 Java！", force: true)
            }
        } else if javaRuntime != bestMatch {
            var runtime: JavaRuntime! = javaRuntime
            log("正在检查当前 Java")
            // 只显示一个问题，避免信息过多
            var currentJavaIssue: String?
            
            if runtime.majorVersion < minMajorVersion {
                currentJavaIssue = "这个实例需要 Java \(minMajorVersion) 才能启动，但你当前选择的是 Java \(runtime.majorVersion)。"
            } else if let requiredArch, runtime.architecture != requiredArch {
                currentJavaIssue = "这个实例需要 \(requiredArch) 架构的 Java \(minMajorVersion) 才能启动，但你当前选择的 Java 是 \(runtime.architecture) 架构的。"
            }
            
            if let currentJavaIssue {
                try await showSwitchMessageBox("当前 Java 不满足要求", currentJavaIssue, force: true)
                runtime = javaRuntime
            }
            
            if runtime.architecture != recommendedArch && bestMatch.architecture == recommendedArch {
                try await showSwitchMessageBox("当前 Java 会导致性能下降", "当前实例设置的 Java（\(runtime!)）需要通过 Rosetta 2 转译运行，这会导致性能下降，并大幅降低游戏体验。", force: false)
            }
        }
        
        if let javaRuntime {
            model.instance.config.javaURL = javaRuntime.executableURL
            model.instance.markDirty()
            model.options.javaRuntime = javaRuntime
            model.manifest = NativesMapper.map(model.manifest, to: javaRuntime.architecture)
        } else {
            warn("javaRuntime 未被设置，但启动任务没有被取消")
            try task.cancel()
        }
    }
    
    private static func refreshAccount(task: SubTask, model: Model) async throws {
        let shouldRefresh: Bool
        do {
            shouldRefresh = try await model.account.shouldRefresh()
        } catch {
            err("验证令牌有效性失败：\(error.localizedDescription)")
            if await MessageBoxManager.shared.showTextAsync(
                title: "验证令牌有效性失败",
                content: "在验证访问令牌有效性时发生错误：\(error.localizedDescription)\n\n如果继续启动，可能会导致无法加入部分需要验证的服务器！\n是否继续启动？\n\n若要寻求帮助，请将完整日志发送给他人，而不是发送此页面相关的图片。",
                level: .error,
                .no(),
                .yes(label: "继续", type: .red)
            ) == 0 {
                try task.cancel()
            }
            model.options.accessToken = model.account.accessToken
            return
        }
        if shouldRefresh {
            do {
                try await model.account.refresh()
                log("刷新 accessToken 成功")
            } catch let error where error.isCancellationError {
            } catch {
                err("刷新 accessToken 失败：\(error.localizedDescription)")
                if await MessageBoxManager.shared.showTextAsync(
                    title: "刷新访问令牌失败",
                    content: "在刷新访问令牌时发生错误：\(error.localizedDescription)\n\n如果继续启动，可能会导致无法加入部分需要验证的服务器！\n是否继续启动？\n\n若要寻求帮助，请将完整日志发送给他人，而不是发送此页面相关的图片。",
                    level: .error,
                    .no(),
                    .yes(label: "继续", type: .red)
                ) == 0 {
                    try task.cancel()
                }
            }
        }
        model.options.accessToken = model.account.accessToken
    }
    
    private static func precheck(task: SubTask, model: Model) async throws {
        model.options.manifest = model.manifest
        try model.options.validate()
        let entries: [LaunchPrecheck.Entry] = LaunchPrecheck.check(for: model.instance, with: model.options, hasMicrosoftAccount: LauncherConfig.shared.hasMicrosoftAccount)
        log("共 \(entries.count) 个问题：\(entries)")
        for entry in entries {
            switch entry {
            case .javaVersionTooLow(let min):
                _ = await MessageBoxManager.shared.showTextAsync(
                    title: "Java 版本过低",
                    content: "你正在使用 Java \(model.options.javaRuntime.majorVersion) 启动游戏，但这个版本需要 \(min)！",
                    level: .error
                )
                try task.cancel()
            case .noMicrosoftAccount:
                if AccountViewModel().accounts.reduce(false, { $0 || ($1.type == .microsoft) }) {
                    LauncherConfig.shared.hasMicrosoftAccount = true
                    continue
                }
                // https://github.com/Meloong-Git/PCL/blob/73bdc533097cfd36867b9249416cd681ec0b5a28/Plain%20Craft%20Launcher%202/Modules/Minecraft/ModLaunch.vb#L263-L285
                if await LocaleUtils.isInChinaMainland(strict: false) {
                    if [3, 8, 15, 30, 50, 70, 90, 110, 130, 180, 220, 280, 330, 380, 450, 550, 660, 750, 880, 950, 1100, 1300, 1500, 1700, 1900]
                        .contains(LauncherConfig.shared.launchCount) {
                        Task {
                            if await MessageBoxManager.shared.showTextAsync(
                                title: "考虑一下正版？",
                                content: "你已经启动了 \(LauncherConfig.shared.launchCount) 次 Minecraft 啦！\n如果觉得 Minecraft 还不错，可以购买正版支持一下，毕竟开发游戏也真的很不容易……不要一直白嫖啦。\n\n在登录一次正版账号后，就不会再出现这个提示了！",
                                level: .info,
                                .yes(label: "支持正版游戏！", type: .highlight),
                                .no(label: "下次一定")
                            ) == 1 {
                                NSWorkspace.shared.open(URL(string: "https://www.xbox.com/zh-cn/games/store/minecraft-java-bedrock-edition-for-pc/9nxp44l49shj")!)
                            }
                        }
                    }
                } else {
                    let result: Int = await MessageBoxManager.shared.showTextAsync(
                        title: "正版验证",
                        content: "你必须先登录正版账号，才能进行离线登录！",
                        level: .info,
                        .init(id: 0, label: "购买正版", type: .highlight),
                        .yes(label: "试玩"),
                        .init(id: 2, label: "返回", type: .normal)
                    )
                    switch result {
                    case 0:
                        NSWorkspace.shared.open(URL(string: "https://www.xbox.com/zh-cn/games/store/minecraft-java-bedrock-edition-for-pc/9nxp44l49shj")!)
                        try task.cancel()
                    case 1:
                        hint("游戏将以试玩模式启动！", type: .critical)
                        model.options.demo = true
                    case 2:
                        try task.cancel()
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private static func checkResources(task: SubTask, model: Model) async throws {
        // 防止本地库架构与 Java 架构不同，先清除本地库
        let nativesDirectory: URL = model.instance.url.appending(path: "natives")
        if FileManager.default.fileExists(atPath: nativesDirectory.path) {
            do {
                try FileManager.default.removeItem(at: nativesDirectory)
                log("删除本地库目录成功")
            } catch {
                err("删除本地库目录失败：\(error.localizedDescription)")
            }
        }
        
        try await MinecraftInstallTask.completeResources(
            runningDirectory: model.instance.url,
            manifest: model.manifest,
            repository: model.repository,
            progressHandler: task.setProgress(_:)
        )
    }
    
    private static func checkAuthlibInjector(task: SubTask, model: Model) async throws {
        guard let yggdrasilAccount = model.account as? YggdrasilAccount else {
            return
        }
        let authlibInjectorURL = URLConstants.authlibInjectorURL
        
        model.options.authlibInjectorPath = authlibInjectorURL.path
        model.options.authServerURL = yggdrasilAccount.authServerURL
        do {
            model.options.prefetchedMeta = try await yggdrasilAccount.fetchMetadata()
        } catch {
            err("获取验证服务器元数据失败：\(error.localizedDescription)")
            guard let cachedMetadata = yggdrasilAccount.cachedMetadata else {
                throw SimpleError("获取验证服务器元数据失败：\(error.localizedDescription)")
            }
            log("正在使用本地缓存")
            model.options.prefetchedMeta = cachedMetadata
        }
        
        do {
            log("正在获取 Authlib Injector 版本列表")
            let artifacts: AuthlibInjectorArtifacts = try await HTTPClient.shared.get("https://authlib-injector.yushi.moe/artifacts.json").decode(AuthlibInjectorArtifacts.self)
            guard let buildNumber = artifacts.artifacts.max(by: { $0.buildNumber < $1.buildNumber })?.buildNumber else {
                throw SimpleError("获取 Authlib Injector 最新版本失败：找不到任何有效版本。")
            }
            let latestArtifact: AuthlibInjectorArtifact = try await HTTPClient.shared.get("https://authlib-injector.yushi.moe/artifact/\(buildNumber).json").decode(AuthlibInjectorArtifact.self)
            let downloadItem: DownloadItem = .init(
                url: latestArtifact.downloadURL,
                destination: authlibInjectorURL,
                checksums: latestArtifact.checksums,
                executable: false
            )
            if FileManager.default.fileExists(atPath: authlibInjectorURL.path) {
                if (try? FileUtils.check(downloadItem)) != true {
                    try FileManager.default.removeItem(at: authlibInjectorURL)
                    log("正在更新 Authlib Injector \(latestArtifact.version)")
                } else {
                    log("本地 Authlib Injector 有效")
                    return
                }
            } else {
                log("正在下载 Authlib Injector \(latestArtifact.version)")
            }
            try await FileDownloader.shared.download(downloadItem, progressHandler: task.setProgress(_:))
        } catch let error as URLError where error.code == .notConnectedToInternet {
            log("似乎已断开与互联网的连接")
            if FileManager.default.fileExists(atPath: authlibInjectorURL.path) {
                log("尝试使用本地缓存的 Authlib Injector")
            } else {
                err("本地缓存中没有 Authlib Injector")
                throw error
            }
        }
    }
    
    private static func launch(task: SubTask, model: Model) async throws {
        LauncherConfig.shared.launchCount += 1
        let launcher: MinecraftLauncher = .init(options: model.options)
        model.launcher = launcher
        do {
            let process: Process = try launcher.launch()
            model.process = process
            await MainActor.run {
                model.onProcessStarted(launcher, process)
            }
        } catch let error where error.isCancellationError {
        } catch {
            err("启动游戏失败：\(error.localizedDescription)")
            _ = await MessageBoxManager.shared.showTextAsync(
                title: "启动游戏失败",
                content: "启动游戏时发生错误：\(error.localizedDescription)",
                level: .error
            )
        }
    }
    
    private static func waitForWindow(task: SubTask, model: Model) async throws {
        guard let process = model.process else {
            err("model.process 为 nil")
            return
        }
        try await withTaskCancellationHandler {
            while true {
                try Task.checkCancellation()
                if !process.isRunning {
                    log("进程已被关闭，停止检测窗口")
                    break
                }
                if checkWindows(for: process) {
                    break
                }
                try await Task.sleep(seconds: 1)
            }
        } onCancel: {
            process.terminate()
        }
    }
    
    private static func checkWindows(for process: Process) -> Bool {
        let option: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(option, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in infoList {
            if let windowPID: Int = info[kCGWindowOwnerPID as String] as? Int,
               windowPID == process.processIdentifier {
                return true
            }
        }
        return false
    }
    
    public class Model: TaskModel {
        public let instance: MinecraftInstance
        public let account: Account
        public let repository: MinecraftRepository
        public let onProcessStarted: (MinecraftLauncher, Process) -> Void
        public var manifest: ClientManifest
        public var launcher: MinecraftLauncher?
        public var options: LaunchOptions
        public var process: Process?
        
        init(instance: MinecraftInstance, account: Account, repository: MinecraftRepository, onProcessStarted: @escaping (MinecraftLauncher, Process) -> Void) {
            self.instance = instance
            self.account = account
            self.repository = repository
            self.onProcessStarted = onProcessStarted
            self.manifest = instance.manifest
            self.options = .init()
            
            self.options.profile = account.profile
            self.options.runningDirectory = instance.url
            self.options.repository = repository
            self.options.memory = instance.config.jvmHeapSize
        }
    }
}
