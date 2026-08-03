//
//  ResourceInstallViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/19.
//

import Foundation
import Core
import ZIPFoundation

class ResourceInstallViewModel: ObservableObject {
    public typealias VersionGroup = (VersionMapKey, [ProjectVersionModel])
    public typealias VersionList = [VersionGroup]
    
    @Published public var versionList: VersionList?
    @Published public var selectedVersionGroup: VersionGroup?
    @Published public var loaded: Bool = false
    
    public let project: ProjectListItemModel
    public let loadingVM: MyLoadingViewModel = .init(text: "加载中")
    
    public init(project: ProjectListItemModel) {
        self.project = project
    }
    
    public func load(selectedInstance: MinecraftInstance? = nil) async throws {
        let selectedInstanceKey: VersionMapKey? = project.type == .modpack ? nil : selectedInstance.map { .init(loader: $0.modLoader, version: $0.version) }
        let selectedVersionType: MinecraftVersion.VersionType? = (selectedInstance?.version).flatMap { VersionManifest.shared?.version(for: $0.id) }?.type
        var selectedVersionGroup: VersionGroup? = selectedInstanceKey.map { ($0, []) }
        
        if let selected = selectedVersionGroup, project.type != .mod {
            selectedVersionGroup?.0 = .init(loader: nil, version: selected.0.version)
        }
        
        let versions: [ModrinthVersion] = try await ModrinthAPIClient.shared.versions(ofProject: project.id, revalidate: true)
        
        var versionMap: [VersionMapKey: [ProjectVersionModel]] = [:]
        for version in versions {
            var dependencies: [ProjectVersionModel.Dependency] = []
            for dependency in version.dependencies {
                guard let projectId: String = dependency.projectId,
                      dependency.isRequired else {
                    continue
                }
                if let project = try await ModrinthAPIClient.shared.project(projectId) {
                    dependencies.append(.init(versionId: dependency.id, projectId: projectId, project: .init(project)))
                } else {
                    warn("依赖 \(projectId) 在 Modrinth 上已不存在")
                    debug(version)
                }
            }
            
            var keys: [VersionMapKey] = []
            for gameVersion in version.gameVersions {
                if let type = VersionManifest.shared?.version(for: gameVersion)?.type,
                   !(type == .release || project.onlySupportsSnapshot || selectedVersionType.map { $0 != .release } ?? false) {
                    continue
                }
                if version.loaders.isEmpty && project.type != .mod {
                    keys.append(.init(loader: nil, version: .init(gameVersion)))
                    continue
                }
                for loader in version.loaders {
                    keys.append(.init(loader: loader, version: .init(gameVersion)))
                }
            }
            for key in keys {
                let value: ProjectVersionModel = .init(
                    id: version.id,
                    name: version.name,
                    version: version.versionNumber,
                    downloads: ProjectListItemModel.formatDownloads(version.downloads),
                    datePublished: ProjectListItemModel.formatLastUpdate(version.datePublished),
                    requiredDependencies: dependencies,
                    type: version.type,
                    primaryFile: version.files.filter(\.primary).first,
                    gameVersion: key.version.id,
                    loader: key.loader
                )
                
                if let selectedInstanceKey, selectedInstanceKey.compatible(with: key) {
                    selectedVersionGroup?.1.append(value)
                } else {
                    versionMap[key, default: []].append(value)
                }
            }
        }
        
        let versionList: VersionList = versionMap.map { ($0, $1) }.sorted(by: { $0.0 > $1.0 })
        let finalSelectedGroup: VersionGroup? = selectedVersionGroup?.1.isEmpty == true ? nil : selectedVersionGroup
        await MainActor.run {
            self.versionList = versionList
            self.selectedVersionGroup = finalSelectedGroup
            self.loaded = true
        }
    }
    
    /// 检查实例是否可以安装某个版本。
    /// - Parameters:
    ///   - instance: 当前实例。
    ///   - version: 选择的版本。
    /// - Throws: 如果不能安装，抛出 `InstanceCheckError`。
    public func checkInstance(_ instance: MinecraftInstance, withVersion version: ProjectVersionModel) throws {
        if project.type == .mod, let requiredLoader: ModLoader = version.loader {
            guard let loader: ModLoader = instance.modLoader else {
                throw InstanceCheckError.modLoaderMissing(name: requiredLoader)
            }
            if loader != requiredLoader {
                throw InstanceCheckError.modLoaderMismatch(required: requiredLoader, found: loader)
            }
        }
        if version.gameVersion != instance.version.id {
            throw InstanceCheckError.versionUnsupported(supported: version.gameVersion, found: instance.version.id)
        }
    }
    
    public func createInstallTask(forVersion version: ProjectVersionModel, to instance: MinecraftInstance) async throws -> MyTask<EmptyModel> {
        guard let primaryFile = version.primaryFile else {
            throw SimpleError("这个版本中没有主要文件！")
        }
        
        let saveDirectoryName = project.type.saveDirectory ?? ""
        let saveDirectoryURL = instance.url.appending(path: saveDirectoryName)
        
        return .init(
            name: "资源下载 - \(project.title) \(version.version)",
            .init(0, "下载文件") { task, model in
                try await FileDownloader.shared.download(
                    url: primaryFile.url,
                    destination: saveDirectoryURL.appending(path: primaryFile.name),
                    sha1: primaryFile.sha1,
                    progressHandler: task.setProgress(_:)
                )
            }
        )
    }
    
    public struct VersionMapKey: Hashable, Equatable, Comparable, Identifiable, CustomStringConvertible {
        public let id: UUID = .init()
        public let loader: ModLoader?
        public let version: MinecraftVersion
        
        public func compatible(with another: VersionMapKey) -> Bool {
            if another.loader != nil {
                return self.loader == another.loader && self.version == another.version
            }
            return self.version == another.version
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.version != rhs.version {
                return lhs.version < rhs.version
            } else {
                return (lhs.loader?.index ?? 0) < (rhs.loader?.index ?? 0)
            }
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(loader)
            hasher.combine(version)
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.loader == rhs.loader && lhs.version == rhs.version
        }
        
        public var description: String {
            if let loader {
                return "\(loader) \(version)"
            }
            return version.description
        }
    }
    
    public enum InstanceCheckError: LocalizedError {
        case modLoaderMissing(name: ModLoader)
        case modLoaderMismatch(required: ModLoader, found: ModLoader)
        case versionUnsupported(supported: String, found: String)
        
        public var errorDescription: String? {
            switch self {
            case .modLoaderMissing(let needed):
                "这个版本需要 \(needed) 加载器，但当前选择的实例没有安装！"
            case .modLoaderMismatch(let needed, let found):
                "这个版本需要 \(needed) 加载器，但当前选择的实例安装的是 \(found)！"
            case .versionUnsupported(let supported, let found):
                "这个版本只支持 Minecraft \(supported)，但当前选择的实例版本是 \(found)！"
            }
        }
    }
}


// MARK: - 整合包相关
extension ResourceInstallViewModel {
    public func createModpackDownloadTask(_ version: ProjectVersionModel) throws -> (MyTask<EmptyModel>, URL) {
        guard let primaryFile = version.primaryFile else {
            throw SimpleError("这个版本中没有主要文件！")
        }
        
        let destination: URL = URLConstants.tempURL.appending(path: "modpack-download-\(version.id)")
        let task: MyTask<EmptyModel> = .init(
            name: "下载整合包 - \(project.title) \(version.version)",
            .init(0, "下载文件") { task, _ in
                try await FileDownloader.shared.download(
                    url: primaryFile.url,
                    destination: destination,
                    sha1: primaryFile.sha1,
                    progressHandler: task.setProgress(_:)
                )
            }
        )
        return (task, destination)
    }
    
    public func loadIndex(_ url: URL) throws -> ModrinthModpackIndex {
        do {
            let archive: Archive = try .init(url: url, accessMode: .read)
            guard let entry: Entry = archive["modrinth.index.json"] else {
                throw SimpleError("未找到整合包索引文件。")
            }
            var data: Data = .init()
            _ = try archive.extract(entry, consumer: { data += $0 })
            let index: ModrinthModpackIndex = try JSONDecoder.shared.decode(ModrinthModpackIndex.self, from: data)
            return index
        } catch let error as Archive.ArchiveError where error == .unreadableArchive {
            throw ModpackInstallError.invalidModpackFormat(underlying: SimpleError("压缩文件格式错误。"))
        } catch {
            throw ModpackInstallError.invalidModpackFormat(underlying: error)
        }
    }
    
    public enum ModpackInstallError: LocalizedError {
        case invalidModpackFormat(underlying: Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidModpackFormat(let underlying):
                "整合包格式错误：\(underlying.localizedDescription)"
            }
        }
    }
}
