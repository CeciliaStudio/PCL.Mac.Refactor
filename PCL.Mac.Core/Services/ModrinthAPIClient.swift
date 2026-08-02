//
//  ModrinthAPIClient.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/16.
//

import Foundation

public class ModrinthAPIClient {
    public static let shared: ModrinthAPIClient = .init(apiRoot: URL(string: "https://api.modrinth.com")!)
    
    private let apiRoot: URL
    
    private init(apiRoot: URL) {
        self.apiRoot = apiRoot
    }
    
    /// 搜索 Modrinth 项目。
    /// - Parameters:
    ///   - type: 项目类型（`ResourceType`）。
    ///   - query: 搜索关键词。
    ///   - gameVersion: 过滤游戏版本。
    ///   - pageIndex: 页码，从 0 开始。
    ///   - limit: 返回结果数量上限。
    /// - Returns: 包含搜索结果和分页信息的 `SearchResponse`。
    public func search(
        type: ResourceType,
        _ query: String?,
        forVersion gameVersion: String?,
        pageIndex: Int = 0,
        limit: Int = 40
    ) async throws -> SearchResponse {
        var facets: [[String]] = [["project_type:\(type)"]]
        if let gameVersion {
            facets.append(["versions:\(gameVersion)"])
        }
        let facetsString: String = String(data: try JSONSerialization.data(withJSONObject: facets), encoding: .utf8)!
        
        let response = try await HTTPClient.shared.get(
            apiRoot.appending(path: "/v2/search"),
            params: [
                "query": query == "" ? nil : query,
                "facets": facetsString,
                "limit": String(describing: limit),
                "offset": String(describing: pageIndex * limit)
            ]
        )
        return try response.decode(SearchResponse.self)
    }
    
    /// 获取指定 id 或 slug 对应的 `ModrinthProject`。
    /// - Parameters:
    ///   - slug: 指定 id 或 slug。
    ///   - revalidate: 是否验证本地缓存有效性。
    /// - Returns: 对应的 `ModrinthProject`。
    public func project(_ slug: String, revalidate: Bool = false) async throws -> ModrinthProject {
        return try await HTTPClient.shared.get(apiRoot.appending(path: "/v2/project/\(slug)"), revalidate: revalidate).decode(ModrinthProject.self)
    }
    
    /// 批量获取指定 id 或 slug 对应的 `ModrinthProject`
    /// - Parameters:
    ///   - slugs: id 或 slug 列表。
    ///   - revalidate: 是否验证本地缓存有效性。
    /// - Returns: 对应的 `[ModrinthProject]`，长度可能与 `slugs` 不一致。
    public func projects(_ slugs: [String], revalidate: Bool = false) async throws -> [ModrinthProject] {
        let idsString = String(data: try JSONSerialization.data(withJSONObject: slugs), encoding: .utf8)!
        return try await HTTPClient.shared.get(
            apiRoot.appending(path: "/v2/projects"),
            params: ["ids": idsString],
            revalidate: revalidate
        ).decode([ModrinthProject].self)
    }
    
    /// 获取指定 project 的所有 `ModrinthVersion`。
    /// - Parameters:
    ///   - slug: 指定 project 的 id 或 slug。
    ///   - revalidate: 是否验证本地缓存有效性。
    /// - Returns: 该 project 的所有 `ModrinthVersion`（`[ModrinthVersion]`）。
    public func versions(ofProject slug: String, revalidate: Bool = false) async throws -> [ModrinthVersion] {
        return try await HTTPClient.shared.get(apiRoot.appending(path: "/v2/project/\(slug)/version"), revalidate: revalidate).decode([ModrinthVersion].self)
    }
    
    /// 获取指定 project 的所有 `ModrinthVersion`。
    /// - Parameters:
    ///   - slug: 指定 `ModrinthProject`。
    ///   - revalidate: 是否验证本地缓存有效性。
    /// - Returns: 该 project 的所有 `ModrinthVersion`（`[ModrinthVersion]`）。
    public func versions(ofProject project: ModrinthProject, revalidate: Bool = false) async throws -> [ModrinthVersion] {
        return try await versions(ofProject: project.slug, revalidate: revalidate)
    }
    
    /// 获取指定 id 对应的 `ModrinthVersion`。
    /// - Parameter slug: 指定 id。
    /// - Returns: 对应的 `ModrinthVersion`。
    public func version(_ id: String) async throws -> ModrinthVersion {
        return try await HTTPClient.shared.get(apiRoot.appending(path: "/v2/version/\(id)")).decode(ModrinthVersion.self)
    }
    
    /// 根据文件的 SHA-1 哈希值查询 `ModrinthVersion`。
    /// - Parameter hash: 文件的 SHA-1 哈希值。
    /// - Returns: 如果找到则返回对应的 `ModrinthVersion`，否则返回 `nil`。
    public func version(ofHash hash: String) async throws -> ModrinthVersion? {
        let response = try await HTTPClient.shared.get(apiRoot.appending(path: "/v2/version_file/\(hash)"))
        if response.statusCode == 404 { return nil }
        return try response.decode(ModrinthVersion.self)
    }
    
    /// 批量根据文件的 SHA-1 查询 `ModrinthVersion`。
    /// - Parameter hashes: 所有文件的 SHA-1 哈希值（`[String]`）。
    /// - Returns: 包含所有找到的 `ModrinthVersion` 的 dict。
    public func versions(ofHashes hashes: [String]) async throws -> [String: ModrinthVersion] {
        return try await HTTPClient.shared.post(
            apiRoot.appending(path: "/v2/version_files"),
            body: [
                "hashes": hashes,
                "algorithm": "sha1"
            ],
            using: .json
        ).decode([String: ModrinthVersion].self)
    }
    
    // MARK: - 数据模型
    
    public struct SearchResponse: Decodable {
        private enum CodingKeys: String, CodingKey {
            case hits, offset, limit, totalHits = "total_hits"
        }
        
        public let hits: [ModrinthProject]
        public let offset: Int
        public let limit: Int
        public let totalHits: Int
    }
}
