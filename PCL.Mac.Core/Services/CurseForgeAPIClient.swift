//
//  CurseForgeAPIClient.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/5/4.
//

import Foundation
import SwiftyJSON

public class CurseForgeAPIClient {
    private let semaphore: AsyncSemaphore = .init(value: 8)
    private let apiRoot: URL
    private let apiKey: String?

    private static let officialAPIRoot = URL(string: "https://api.curseforge.com")!
    private static let mirrorAPIRoot = URL(string: "https://mod.mcimirror.top/curseforge")!
    
    /// 配置 API Key 时使用 CurseForge 官方接口，否则使用无需 Key 的 MCIM 兼容接口。
    public init(apiRoot: URL? = nil, apiKey: String? = nil) {
        let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = apiKey?.isEmpty == false ? apiKey : nil
        self.apiRoot = apiRoot ?? (self.apiKey == nil ? Self.mirrorAPIRoot : Self.officialAPIRoot)
    }
    
    public func mod(id modId: Int) async throws -> CurseForgeMod? {
        let response = try await request("/v1/mods/\(modId)")
        if response.statusCode == 404 { return nil }
        return try response.decode(Response<CurseForgeMod>.self).data
    }
    
    public func modFile(modId: Int, fileId: Int) async throws -> CurseForgeModFile? {
        let response = try await request("/v1/mods/\(modId)/files/\(fileId)")
        if response.statusCode == 404 { return nil }
        return try response.decode(Response<CurseForgeModFile>.self).data
    }

    public func search(
        type: ResourceType,
        query: String?,
        gameVersion: String? = nil,
        loader: ModLoader? = nil,
        pageIndex: Int = 0,
        pageSize: Int = 40
    ) async throws -> SearchResponse {
        var params: [String: String?] = [
            "gameId": "432",
            "classId": String(type.curseForgeClassId),
            "sortField": "2",
            "sortOrder": "desc",
            "pageSize": String(pageSize),
            "index": String(pageIndex * pageSize),
            "searchFilter": query?.isEmpty == true ? nil : query
        ]
        if let gameVersion { params["gameVersion"] = gameVersion }
        if let loader { params["modLoaderType"] = String(loader.curseForgeType) }

        let response = try await request("/v1/mods/search", params: params)
        return try response.decode(SearchResponse.self)
    }

    public func files(
        ofMod modId: Int,
        gameVersion: String? = nil,
        loader: ModLoader? = nil,
        pageSize: Int = 100
    ) async throws -> [CurseForgeModFile] {
        let firstPage = try await filePage(
            ofMod: modId,
            gameVersion: gameVersion,
            loader: loader,
            index: 0,
            pageSize: pageSize
        )
        guard let pagination = firstPage.pagination,
              let totalCount = pagination.totalCount,
              firstPage.data.count < totalCount else {
            return firstPage.data
        }

        let effectivePageSize = max(pagination.pageSize ?? pageSize, 1)
        let nextIndex = (pagination.index ?? 0) + firstPage.data.count
        let remainingPages = try await withThrowingTaskGroup(
            of: (Int, [CurseForgeModFile]).self,
            returning: [(Int, [CurseForgeModFile])].self
        ) { group in
            for index in stride(from: nextIndex, to: totalCount, by: effectivePageSize) {
                group.addTask { [self] in
                    let page = try await filePage(
                        ofMod: modId,
                        gameVersion: gameVersion,
                        loader: loader,
                        index: index,
                        pageSize: effectivePageSize
                    )
                    return (index, page.data)
                }
            }

            var pages: [(Int, [CurseForgeModFile])] = []
            for try await page in group {
                pages.append(page)
            }
            return pages.sorted { $0.0 < $1.0 }
        }
        return firstPage.data + remainingPages.flatMap(\.1)
    }

    public func files(ids: [Int]) async throws -> [CurseForgeModFile] {
        guard !ids.isEmpty else { return [] }
        let response = try await request(
            "/v1/mods/files",
            method: "POST",
            body: ["fileIds": ids] as [String: Any]
        )
        return try response.decode(Response<[CurseForgeModFile]>.self).data
    }

    public func mods(ids: [Int]) async throws -> [CurseForgeMod] {
        guard !ids.isEmpty else { return [] }
        let response = try await request(
            "/v1/mods",
            method: "POST",
            body: ["modIds": ids] as [String: Any]
        )
        return try response.decode(Response<[CurseForgeMod]>.self).data
    }
    
    private func request(
        _ path: String,
        method: String = "GET",
        headers: [String: String?] = [:],
        body: [String: Any]? = nil
    ) async throws -> HTTPClient.Response {
        await semaphore.wait()
        defer { Task { await semaphore.signal() } }
        var headers: [String: String?] = headers
        if let apiKey {
            headers["x-api-key"] = apiKey
        }
        
        let response = try await HTTPClient.shared.request(
            url: apiRoot.appending(path: path),
            method: method,
            headers: headers,
            body: body,
            using: .json,
            revalidate: true,
            timeout: 30
        )
        
        return response
    }

    private func request(_ path: String, params: [String: String?]) async throws -> HTTPClient.Response {
        var url = apiRoot.appending(path: path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = params.compactMap { key, value in
            value.map { URLQueryItem(name: key, value: $0) }
        }
        url = components.url!
        await semaphore.wait()
        defer { Task { await semaphore.signal() } }
        let headers: [String: String?] = apiKey.map { ["x-api-key": $0] } ?? [:]
        return try await HTTPClient.shared.get(
            url,
            headers: headers,
            revalidate: true,
            timeout: 30
        )
    }

    private func filePage(
        ofMod modId: Int,
        gameVersion: String?,
        loader: ModLoader?,
        index: Int,
        pageSize: Int
    ) async throws -> ResponseWithPagination<[CurseForgeModFile]> {
        let response = try await request("/v1/mods/\(modId)/files", params: [
            "gameVersion": gameVersion,
            "modLoaderType": loader.map { String($0.curseForgeType) },
            "index": String(index),
            "pageSize": String(pageSize)
        ])
        return try response.decode(ResponseWithPagination<[CurseForgeModFile]>.self)
    }
    
    public struct Response<Body: Codable>: Codable {
        public let data: Body
    }

    public struct ResponseWithPagination<Body: Codable>: Codable {
        public let data: Body
        public let pagination: Pagination?
    }

    public struct Pagination: Codable {
        public let index: Int?
        public let pageSize: Int?
        public let resultCount: Int?
        public let totalCount: Int?

        private enum CodingKeys: String, CodingKey {
            case index, pageSize, resultCount, totalCount
        }
    }

    public struct SearchResponse: Codable {
        public let hits: [CurseForgeMod]
        public let offset: Int
        public let limit: Int
        public let totalHits: Int

        private enum CodingKeys: String, CodingKey {
            case data, pagination
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            hits = try container.decode([CurseForgeMod].self, forKey: .data)
            let pagination = try container.decodeIfPresent(Pagination.self, forKey: .pagination)
            offset = pagination?.index ?? 0
            limit = pagination?.pageSize ?? hits.count
            totalHits = pagination?.totalCount ?? hits.count
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(hits, forKey: .data)
        }
    }
}

private extension ResourceType {
    var curseForgeClassId: Int {
        switch self {
        case .mod: 6
        case .modpack: 4471
        case .resourcepack: 12
        case .shader: 6552
        }
    }
}

private extension ModLoader {
    var curseForgeType: Int {
        switch self {
        case .forge: 1
        case .fabric: 4
        case .neoforge: 6
        }
    }
}
