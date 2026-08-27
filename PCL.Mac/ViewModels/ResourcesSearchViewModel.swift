//
//  ResourcesSearchViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/16.
//

import Foundation
import Core

class ResourcesSearchViewModel: ObservableObject {
    enum SearchSource: String, CaseIterable {
        case modrinth = "Modrinth"
        case curseforge = "CurseForge"
    }

    @Published public var searchResults: [ProjectListItemModel]?
    @Published public var query: String = ""
    @Published public var source: SearchSource = .modrinth
    public let type: ResourceType
    public let loadingVM: MyLoadingViewModel = .init(text: "加载中")
    private var totalResultCount: Int = 0
    private let pageSize: Int = 40
    
    public var totalPages: Int {
        Int(ceil(Double(totalResultCount) / Double(pageSize)))
    }
    
    public init(type: ResourceType) {
        self.type = type
    }
    
    public func search(_ query: String, pageIndex: Int = 0) async throws {
        await MainActor.run {
            self.query = query
            loadingVM.reset()
            searchResults = nil
        }
        switch source {
        case .modrinth:
            let response = try await ModrinthAPIClient.shared.search(type: type, query, forVersion: nil, pageIndex: pageIndex, limit: pageSize)
            await MainActor.run {
                totalResultCount = response.totalHits
                searchResults = response.hits.filter { $0.clientCompatibility != .unsupported }.map(ProjectListItemModel.init(_:))
            }
        case .curseforge:
            let response = try await CurseForgeAPIClient(apiKey: Secrets.shared.curseforgeApiKey)
                .search(type: type, query: query, pageIndex: pageIndex, pageSize: pageSize)
            await MainActor.run {
                totalResultCount = response.totalHits
                searchResults = response.hits.map(ProjectListItemModel.init(_:))
            }
        }
    }
    
    public func changePage(_ page: Int) async throws {
        try await search(query, pageIndex: page)
    }
}
