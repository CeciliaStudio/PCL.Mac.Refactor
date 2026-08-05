//
//  ForgeInstallService.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/2/15.
//

import Foundation
import ZIPFoundation
import SwiftyJSON

public class ForgeInstallService {
    public init(
        minecraftVersion: MinecraftVersion,
        version: String,
        repository: MinecraftRepository,
        manifest: ClientManifest,
        runningDirectory: URL
    ) {
        self.minecraftVersion = minecraftVersion
        self.version = version
        self.repository = repository
        self.manifest = manifest
        self.runningDirectory = runningDirectory
        self.tempDirectory = URLConstants.tempURL.appending(path: "forge-install-\(UUID().uuidString.lowercased())")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    deinit {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            do {
                try FileManager.default.removeItem(at: tempDirectory)
            } catch {
                err("删除临时目录失败：\(error.localizedDescription)")
            }
        }
    }
    
    internal let minecraftVersion: MinecraftVersion
    internal let version: String
    private let repository: MinecraftRepository
    private let manifest: ClientManifest
    private let runningDirectory: URL
    private let tempDirectory: URL
    private var installProfile: ForgeInstallProfile!
    private var values: [String: String]!
    
    private lazy var installerURL: URL = tempDirectory.appending(path: "installer")
    private lazy var librariesURL: URL = repository.librariesDirectory
    
    /// 下载安装器及其所需文件。
    /// - Parameter progressHandler: 进度回调。
    public func downloadFiles(progressHandler: @MainActor @escaping (Double) -> Void) async throws {
        let progressHandler: ConcurrentProgressHandler = await .init(totalHandler: progressHandler)
        await progressHandler.startCalculate()
        guard try await downloadInstaller(progressHandler: progressHandler.handler(withMultiplier: 0.3)) else {
            await progressHandler.stopCalculate()
            return
        }
        try copyLibraries()
        try await downloadInstallerDependencies(progressHandler: progressHandler.handler(withMultiplier: 0.7))
        self.values = makeValueDict()
        await progressHandler.stopCalculate()
    }
    
    /// 执行安装器。
    /// - Parameter progressHandler: 进度回调。
    public func executeProcessors(progressHandler: @MainActor @escaping (Double) -> Void) async throws {
        guard let installProfile else {
            await progressHandler(1)
            return
        }
        let processors: [ForgeInstallProfile.Processor] = installProfile.processors.filter { $0.sides?.contains(.client) ?? true }
        var progress: Double = 0
        let progressStep: Double = 1.0 / Double(processors.count)
        for processor in processors {
            if processor.args.contains("DOWNLOAD_MOJMAPS") {
                guard let destination: URL = values["MOJMAPS"].map(URL.init(fileURLWithPath:)) else {
                    throw SimpleError("下载混淆表失败：未找到混淆表下载项。")
                }
                try await downloadMojmaps(to: destination)
            } else {
                try executeProcessor(processor)
            }
            progress += progressStep
            await progressHandler(progress)
        }
        await progressHandler(1)
    }
    
    /// 下载安装器本体并解析。
    /// - Returns: 是否是新版本安装器，且需要继续执行后续步骤。
    private func downloadInstaller(progressHandler: @MainActor @escaping (Double) -> Void) async throws -> Bool {
        let destination = tempDirectory.appending(path: "installer.jar")
        let item = DownloadItem(
            urls: installerDownloadURLs(),
            destination: destination,
            checksums: nil
        )
        try await FileDownloader.shared.download(item, progressHandler: progressHandler)
        _ = try FileManager.default.unzipItem(at: destination, to: installerURL)
        
        // 处理客户端清单
        let manifestURL: URL = runningDirectory.appending(path: "\(runningDirectory.lastPathComponent).json")
        let parentURL: URL = runningDirectory.appending(path: ".parent/\(minecraftVersion).json")
        if !FileManager.default.fileExists(atPath: parentURL.path) {
            try FileManager.default.createDirectory(at: runningDirectory.appending(path: ".parent"), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: manifestURL, to: parentURL)
        }
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            try FileManager.default.removeItem(at: manifestURL)
        }
        // 此时 manifestURL 上没有文件
        
        let profileURL: URL = installerURL.appending(path: "install_profile.json")
        let data: Data = try .init(contentsOf: profileURL)
        let json: JSON = try .init(data: data)
        if json["install"].exists() { // 旧版本安装器，只需拷贝一个文件即可完成安装
            let forgeURL: URL = installerURL.appending(path: json["install"]["filePath"].stringValue)
            let forgeDestination: URL = repository.librariesDirectory.appending(path: MavenCoordinateUtils.path(of: json["install"]["path"].stringValue))
            if !FileManager.default.fileExists(atPath: forgeDestination.path) {
                try FileManager.default.createDirectory(at: forgeDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: forgeURL, to: forgeDestination)
            }
            
            try json["versionInfo"].rawData().write(to: manifestURL)
            return false
        } else {
            self.installProfile = try JSONDecoder.shared.decode(ForgeInstallProfile.self, from: data)
            try FileManager.default.moveItem(at: installerURL.appending(path: "version.json"), to: manifestURL)
            return true
        }
    }
    
    internal func installerDownloadURLs() -> [URL] {
        let root = URL(string: "https://files.minecraftforge.net/maven")!
        let paths = [
            "net/minecraftforge/forge/\(minecraftVersion)-\(version)/forge-\(minecraftVersion)-\(version)-installer.jar",
            "net/minecraftforge/forge/\(minecraftVersion)-\(version)-\(minecraftVersion)/forge-\(minecraftVersion)-\(version)-\(minecraftVersion)-installer.jar"
        ]
        
        return paths.map(root.appending(path:))
    }
    
    private func makeValueDict() -> [String: String] {
        let values: [String: String] = [
            "SIDE": "client",
            "INSTALLER": tempDirectory.appending(path: "installer.jar").path,
            "MINECRAFT_JAR": runningDirectory.appending(path: "\(runningDirectory.lastPathComponent).jar").path,
            "MINECRAFT_VERSION": minecraftVersion.id,
            "ROOT": repository.url.path,
            "LIBRARY_DIR": librariesURL.path
        ].merging(installProfile.data.mapValues { parseValue($0.client) }, uniquingKeysWith: { _, value in value })
        
        return values
    }
    
    
    private func parseValue(_ value: String) -> String {
        if value.starts(with: "/") {
            return installerURL.appending(path: value).path
        } else if value.starts(with: "[") && value.hasSuffix("]") {
            let path: String = MavenCoordinateUtils.path(of: String(value.dropFirst().dropLast()))
            return librariesURL.appending(path: path).path
        } else if value.starts(with: "'") && value.hasSuffix("'") {
            return String(value.dropFirst().dropLast())
        } else {
            return value
        }
    }
    
    private func copyLibraries() throws {
        let sourceDirectory: URL = installerURL.appending(path: "maven")
        guard FileManager.default.fileExists(atPath: sourceDirectory.path) else {
            return
        }
        let baseComponents: [String] = sourceDirectory.pathComponents
        
        guard let enumerator: FileManager.DirectoryEnumerator = FileManager.default.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            throw SimpleError("创建 enumerator 失败。")
        }
        
        for case let url as URL in enumerator {
            guard let isRegularFile: Bool = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                  isRegularFile else {
                continue
            }
            let components: [String] = url.pathComponents
            guard components.starts(with: baseComponents) else { continue }
            let relativePath: String = components.dropFirst(baseComponents.count).joined(separator: "/")
            let destination: URL = repository.librariesDirectory.appending(path: relativePath)
            if FileManager.default.fileExists(atPath: destination.path) { continue }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: url, to: destination)
        }
    }
    
    /// 下载安装器所需的依赖项。
    private func downloadInstallerDependencies(progressHandler: @MainActor @escaping (Double) -> Void) async throws {
        let libraries: [ForgeInstallProfile.Library] = installProfile.libraries
        let downloadItems: [DownloadItem] = libraries.compactMap { $0.artifact.downloadItem(destinationDirectory: librariesURL) }
        try await FileDownloader.shared.download(files: downloadItems, progressHandler: progressHandler)
    }
    
    private func parseMavenCoord(coord: String) -> String {
        return librariesURL.appending(path: MavenCoordinateUtils.path(of: coord)).path
    }
    
    private func executeProcessor(_ processor: ForgeInstallProfile.Processor) throws {
        let classpath: String = (processor.classpath + [processor.jar]).map(parseMavenCoord(coord:)).joined(separator: ":")
        let mainClass: String = try JarUtils.mainClass(of: librariesURL.appending(path: MavenCoordinateUtils.path(of: processor.jar)))
        let arguments: [String] = ["-cp", classpath, mainClass] + processor.args.map { parseValue($0).replacingPlaceholders(with: values, dollarPrefix: false) }
        let process: Process = .init()
        process.arguments = arguments
        process.executableURL = URL(fileURLWithPath: "/usr/bin/java")
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw SimpleError("Forge 安装器 \(processor.jar) 执行失败。")
        }
    }
    
    private func downloadMojmaps(to destination: URL) async throws {
        guard let url: URL = manifest.downloads?.clientMappings?.url else {
            throw SimpleError("下载混淆表失败：未找到混淆表下载项。")
        }
        try await FileDownloader.shared.download(url: url, destination: destination)
    }
}
