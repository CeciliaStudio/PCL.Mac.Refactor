//
//  LaunchViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/4/17.
//

import Foundation
import Core
import Combine

class LaunchViewModel: ObservableObject {
    @Published public private(set) var isLaunching: Bool
    @Published public private(set) var isRunning: Bool
    @Published public private(set) var progress: Double
    @Published public private(set) var currentStage: String?
    @Published public private(set) var instanceName: String?
    public let loadingViewModel: MyLoadingViewModel
    
    private let launchManager: MinecraftLaunchManager
    private var cancellables: Set<AnyCancellable> = []
    
    public init(launchManager: MinecraftLaunchManager = .shared) {
        self.launchManager = launchManager
        
        self.isLaunching = launchManager.isLaunching
        self.isRunning = launchManager.isRunning
        self.progress = launchManager.progress
        self.currentStage = launchManager.currentStage
        self.instanceName = launchManager.instanceName
        self.loadingViewModel = launchManager.loadingViewModel
        
        launchManager.$isLaunching
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLaunching, on: self)
            .store(in: &cancellables)
        launchManager.$gameProcess
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRunning, on: self)
            .store(in: &cancellables)
        launchManager.$progress
            .receive(on: DispatchQueue.main)
            .assign(to: \.progress, on: self)
            .store(in: &cancellables)
        launchManager.$currentStage
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentStage, on: self)
            .store(in: &cancellables)
        launchManager.$instanceName
            .receive(on: DispatchQueue.main)
            .assign(to: \.instanceName, on: self)
            .store(in: &cancellables)
    }
    
    @MainActor
    public func launch(_ instance: MinecraftInstance, in repository: MinecraftRepository, using account: Account) {
        launchManager.launch(instance, using: account, in: repository)
    }
    
    public func cancel() {
        launchManager.cancel()
    }
}
