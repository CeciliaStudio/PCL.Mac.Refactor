//
//  InstalledResourcesViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/6/7.
//

import Foundation
import Core
import Combine

@MainActor
class InstalledResourcesViewModel: ObservableObject {
    @Published public var resources: [ResourceDisplayModel]?
    @Published public var supportMods: Bool = true
    @Published public var currentRepositoryId: UUID
    @Published public var currentPage: Int = 0
    @Published public var pageCount: Int = 0
    
    public let type: ResourceType
    public var hasSearchKeyword: Bool { !searchKeyword.isEmpty }
    private var cancellables: Set<AnyCancellable> = []
    private var loadResult: [(URL, Resource)]?
    private var convertTask: Task<Void, Never>?
    private var searchKeyword: String = ""
    private let instance: MinecraftInstance?
    private let id: String
    private let entriesPerPage: Int = 20
    
    private let service: ResourceLoadService
    
    init(instanceManager: InstanceManager, id: String, type: ResourceType) {
        self.instance = instanceManager.currentRepository.instance(named: id)
        self.id = id
        self.type = type
        self.currentRepositoryId = instanceManager.currentRepositoryId
        self.service = .init(
            preferredType: type,
            remoteLookupService: .init(curseforgeClient: .init(apiKey: Secrets.shared.curseforgeApiKey ?? "")),
            cache: .shared
        )
        
        instanceManager.$currentRepositoryId
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentRepositoryId, on: self)
            .store(in: &cancellables)
    }
    
    func load(resetPage: Bool = true) async throws {
        guard let instance else { throw SimpleError("实例不存在。") }
        
        if type == .mod && instance.modLoader == nil {
            supportMods = false
            return
        }
        
        let result: [(URL, Resource)] = try await service.loadResources(in: directory()!)
            .map { ($0, $1) }
            .sorted { $0.1.name.compare($1.1.name, options: .literal) == .orderedAscending }
        
        self.loadResult = result
        if resetPage {
            self.currentPage = 0
        }
        self.updateResources()
    }
    
    func updateResources() {
        if let convertTask {
            convertTask.cancel()
            self.convertTask = nil
        }
        guard let loadResult else { return }
        
        let validResources: [(URL, Resource)] = loadResult.lazy
            .filter {
                searchKeyword.isEmpty
                || $0.1.name.contains(searchKeyword)
                || $0.1.description?.contains(searchKeyword) == true
            }
        
        self.pageCount = validResources.isEmpty ? 0 : Int(ceil(Double(validResources.count) / Double(entriesPerPage)))
        if pageCount == 0 {
            self.resources = []
            return
        } else {
            currentPage = min(pageCount - 1, currentPage)
        }
        
        let start = currentPage * entriesPerPage
        let end = min(start + entriesPerPage, validResources.count)
        self.resources = nil
        convertTask = .detached {
            do {
                let resources = try validResources[start..<end]
                    .map {
                        try Task.checkCancellation()
                        return ResourceDisplayModel($0.0, $0.1)
                    }
                await MainActor.run {
                    self.resources = resources
                }
            } catch let error where error.isCancellationError {
            } catch {
                err("刷新资源列表失败：\(error.localizedDescription)")
            }
            await MainActor.run {
                self.convertTask = nil
            }
        }
    }
    
    func setSearchKeyword(_ keyword: String) {
        searchKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        updateResources()
    }
    
    func toggleDisabled(_ resource: ResourceDisplayModel) throws {
        let newURL: URL
        if resource.disabled {
            newURL = resource.url.deletingPathExtension()
            log("正在启用资源 \(resource.fileName)")
        } else {
            newURL = resource.url.appendingPathExtension("disabled")
            log("正在禁用资源 \(resource.fileName)")
        }
        try FileManager.default.moveItem(at: resource.url, to: newURL)
        resource.disabled.toggle()
        resource.url = newURL
    }
    
    func loadInfo(for resource: ResourceDisplayModel) async throws -> ProjectListItemModel? {
        for source in resource.sources {
            if case .modrinth(let projectId) = source {
                do {
                    guard let project = try await ModrinthAPIClient.shared.project(projectId) else {
                        warn("记录了 \(resource.fileName) 对应的 Modrinth projectId（\(projectId)），但它在 Modrinth 上已不存在")
                        return nil
                    }
                    return .init(project)
                } catch {
                    throw SimpleError("查询 Modrinth Project 失败：\(error.localizedDescription)")
                }
            }
        }
        return nil
    }
    
    func directory() -> URL? {
        guard let instance else { return nil }
        
        let directoryName = type.saveDirectory ?? ""
        let url = instance.url.appending(path: directoryName)
        
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        return url
    }
}
