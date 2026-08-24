//
//  MinecraftLauncher.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/26.
//

import Foundation

public class MinecraftLauncher {
    private static let gameLogQueue: DispatchQueue = .init(label: "PCL.Mac.GameLog")
    public let options: LaunchOptions
    public let logURL: URL
    private let manifest: ClientManifest
    private let runningDirectory: URL
    private let librariesURL: URL
    private var values: [String: String]
    
    public init(options: LaunchOptions) {
        self.manifest = options.manifest
        self.runningDirectory = options.runningDirectory
        self.librariesURL = options.repository.librariesDirectory
        self.options = options
        self.logURL = URLConstants.tempURL.appending(path: "game-log-\(UUID().uuidString.lowercased()).log")
        self.values = [
            "natives_directory": runningDirectory.appending(path: "natives").path,
            "launcher_name": "PCL.Mac",
            "launcher_version": Metadata.appVersion,
            "classpath_separator": ":",
            "library_directory": librariesURL.path,
            
            "auth_player_name": options.profile.name,
            "version_name": options.runningDirectory.lastPathComponent,
            "game_directory": runningDirectory.path,
            "assets_root": librariesURL.deletingLastPathComponent().appending(path: "assets").path,
            "assets_index_name": manifest.assetIndex?.id ?? manifest.assets ?? "legacy",
            "auth_uuid": UUIDUtils.string(of: options.profile.id, withHyphens: false),
            "auth_access_token": options.accessToken,
            "auth_session": options.accessToken,
            "user_type": "msa",
            "version_type": "PCL.Mac",
            "user_properties": "{}"
        ]
    }
    
    /// 启动 Minecraft。
    /// - Returns: 游戏进程。
    public func launch() throws -> Process {
        values["classpath"] = buildClasspath()
        let process: Process = .init()
        process.executableURL = options.javaRuntime.executableURL
        process.currentDirectoryURL = runningDirectory
        
        var arguments: [String] = []
        arguments.append("-Xmx\(options.memory)m")
        arguments.append(contentsOf: manifest.jvmArguments.flatMap { $0.rules.allSatisfy { $0.test(with: options) } ? $0.value : [] })
        arguments.append(contentsOf: options.extraJvmArguments)
        if let authlibInjectorPath = options.authlibInjectorPath,
           let authServerURL = options.authServerURL,
           let prefetchedMeta = options.prefetchedMeta {
            arguments.append("-javaagent:\(authlibInjectorPath)=\(authServerURL)")
            arguments.append("-Dauthlibinjector.yggdrasil.prefetched=\(prefetchedMeta)")
            log("已添加 Authlib Injector 参数")
        }
        arguments.append(options.mainClass)
        arguments.append(contentsOf: manifest.gameArguments.flatMap { $0.rules.allSatisfy { $0.test(with: options) } ? $0.value : [] })
        arguments = arguments.map { $0.replacingPlaceholders(with: values) }
        process.arguments = arguments
        
        let pipe: Pipe = .init()
        process.standardOutput = pipe
        process.standardError = pipe
        
        log("正在使用以下参数启动 Minecraft：\(arguments.map { $0 == options.accessToken ? "🥚" : $0 })")
        try process.run()
        Self.gameLogQueue.async {
            FileManager.default.createFile(atPath: self.logURL.path, contents: nil)
            let handle: FileHandle?
            do {
                handle = try .init(forWritingTo: self.logURL)
            } catch {
                err("开启日志 FileHandle 失败：\(error.localizedDescription)")
                handle = nil
            }
            defer { try? handle?.close() }
            
            while process.isRunning {
                let data: Data = pipe.fileHandleForReading.availableData
                if data.isEmpty { break }
                try? handle?.write(contentsOf: data)
            }
        }
        return process
    }
    
    private func buildClasspath() -> String {
        var urls: [URL] = []
        for library in manifest.getLibraries() {
            if let artifact = library.artifact {
                urls.append(librariesURL.appending(path: artifact.path))
            }
        }
        urls.append(runningDirectory.appending(path: "\(runningDirectory.lastPathComponent).jar"))
        return urls.map(\.path).joined(separator: ":")
    }
}
