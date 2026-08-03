//
//  ResourceRemoteLookupService.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/6/7.
//

import Foundation

public class ResourceRemoteLookupService {
    private let modrinthClient: ModrinthAPIClient
    private let curseforgeClient: CurseForgeAPIClient
    
    public init(modrinthClient: ModrinthAPIClient = .shared, curseforgeClient: CurseForgeAPIClient) {
        self.modrinthClient = modrinthClient
        self.curseforgeClient = curseforgeClient
    }
    
    /// 根据 SHA-1 哈希值查询单个资源。
    public func lookup(hash: String) async throws -> RemoteResourceInfo? {
        if let modrinthVersion = try await modrinthClient.version(ofHash: hash),
           let project = try await modrinthClient.project(modrinthVersion.projectId, revalidate: true) {
            return RemoteResourceInfo(project, version: modrinthVersion)
        }
        
        // TODO: CurseForge
        
        return nil
    }
    
    /// 根据 SHA-1 哈希值查询多个资源。
    public func lookup(hashes: [String]) async throws -> [String: RemoteResourceInfo] {
        var result: [String: RemoteResourceInfo] = [:]
        result.reserveCapacity(hashes.count)
        
        do {
            let versions: [String: ModrinthVersion] = try await modrinthClient.versions(ofHashes: hashes)
            let projectIds = Array(Set(versions.values.map(\.projectId)))
            let projects: [String: ModrinthProject] = try await modrinthClient.projects(projectIds, revalidate: true)
                .reduce(into: [:]) { $0[$1.id] = $1 }
            
            for (hash, version) in versions {
                guard let project = projects[version.projectId] else { continue }
                result[hash] = .init(project, version: version)
            }
        }
        
        // TODO: CurseForge
        
        return result
    }
    
    public struct RemoteResourceInfo {
        public let name: String
        public let version: String
        public let description: String
        public let tags: [String]
        public let icon: URL?
        public let source: Resource.Source
        
        public init(name: String, version: String, description: String, tags: [String], icon: URL?, source: Resource.Source) {
            self.name = name
            self.version = version
            self.description = description
            self.tags = tags
            self.icon = icon
            self.source = source
        }
        
        public init(_ modrinthProject: ModrinthProject, version modrinthVersion: ModrinthVersion) {
            self.init(
                name: modrinthProject.title,
                version: modrinthVersion.versionNumber,
                description: modrinthProject.description,
                tags: modrinthProject.categories,
                icon: modrinthProject.iconURL,
                source: .modrinth(projectId: modrinthProject.id)
            )
        }
        
        public init(_ curseforgeMod: CurseForgeMod, file curseforgeModFile: CurseForgeModFile) {
            self.init(
                name: curseforgeMod.name,
                version: "not implemented",
                description: curseforgeMod.summary,
                tags: [],
                icon: curseforgeMod.logo.thumbnailURL,
                source: .curseforge(id: curseforgeMod.id)
            )
        }
    }
}
