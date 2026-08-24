//
//  InstanceViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/4/16.
//

import Foundation
import Core
import Combine

@MainActor
class InstanceViewModel: ObservableObject {
    @Published public private(set) var repositories: [MinecraftRepository]
    @Published public private(set) var currentRepositoryId: UUID
    @Published public private(set) var loading: Bool
    public var currentInstance: MinecraftInstance? { instanceManager.currentInstance }
    public var currentRepository: MinecraftRepository { instanceManager.currentRepository }
    
    private let instanceManager: InstanceManager
    private var cancellables: Set<AnyCancellable> = []
    private var currentRepositoryCancellable: AnyCancellable?
    
    public init(instanceManager: InstanceManager) {
        self.instanceManager = instanceManager
        
        self.repositories = Array(instanceManager.repositories.values).sorted(by: Self.compareRepository(lhs:rhs:))
        self.currentRepositoryId = instanceManager.currentRepositoryId
        self.loading = instanceManager.loadTask != nil
        
        instanceManager.$repositories
            .map { Array($0.values).sorted(by: Self.compareRepository(lhs:rhs:)) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.repositories, on: self)
            .store(in: &cancellables)
        instanceManager.$currentRepositoryId
            .receive(on: DispatchQueue.main)
            .sink { currentRepositoryId in
                self.currentRepositoryId = currentRepositoryId
                self.observeCurrentRepository()
            }
            .store(in: &cancellables)
        instanceManager.$loadTask
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .assign(to: \.loading, on: self)
            .store(in: &cancellables)
        
        observeCurrentRepository()
    }
    
    public func switchInstance(to instance: MinecraftInstance, in repository: MinecraftRepository) {
        instanceManager.switchInstance(to: instance, in: repository)
    }
    
    public func deleteInstance(_ instance: MinecraftInstance, in repository: MinecraftRepository? = nil) throws {
        let repository = repository ?? currentRepository
        try repository.removeInstance(instance)
    }
    
    public func switchRepository(to repository: MinecraftRepository) {
        instanceManager.switchRepository(to: repository)
    }
    
    public func addRepository(name: String, url: URL) {
        instanceManager.addRepository(.init(name: name, url: url))
    }
    
    public func reload(repository: MinecraftRepository) {
        instanceManager.startLoad(repository: repository)
    }
    
    private static func compareRepository(lhs: MinecraftRepository, rhs: MinecraftRepository) -> Bool {
        lhs.dateCreated < rhs.dateCreated
    }
    
    private func observeCurrentRepository() {
        currentRepositoryCancellable = instanceManager.currentRepository.objectWillChange
            .sink(receiveValue: objectWillChange.send)
    }
}
