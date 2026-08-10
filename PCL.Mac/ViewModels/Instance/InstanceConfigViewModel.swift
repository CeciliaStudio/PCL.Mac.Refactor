//
//  InstanceConfigViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/6.
//

import Foundation
import Core

@MainActor
class InstanceConfigViewModel: ObservableObject {
    @Published public var instance: MinecraftInstance
    @Published public var jvmHeapSize: String = ""
    @Published public var jvmArguments: String = ""
    @Published public var javaDescription: String = "无"
    
    public var description: String {
        if let modLoader: ModLoader = instance.modLoader {
            return "\(instance.version.description)，\(modLoader)"
        }
        return instance.version.description
    }
    
    public var icon: ImageResource {
        if let modLoader: ModLoader = instance.modLoader {
            return modLoader.icon
        }
        return .iconGrassBlock
    }
    
    public let id: String
    private let instanceManager: InstanceManager
    
    public init(instanceManager: InstanceManager, id: String) {
        self.instanceManager = instanceManager
        self.id = id
        self.instance = instanceManager.currentRepository.instance(named: id)! // TODO: 改为安全解包
        self.jvmHeapSize = instance.config.jvmHeapSize.description
        self.jvmArguments = instance.config.jvmArguments.joinedToArgumentLine()
        do {
            self.javaDescription = try instance.config.javaURL.map(JavaSearcher.load(from:))?.description ?? "无"
        } catch {}
    }
    
    public func javaList() -> [JavaRuntime] {
        return JavaManager.shared.javaRuntimes
            .filter { $0.executableURL != instance.config.javaURL }
            .sorted { $0.version > $1.version }
    }
    
    @MainActor
    public func setHeapSize(_ heapSize: UInt64) {
        instance.config.jvmHeapSize = heapSize
        instance.markDirty()
    }

    @MainActor
    public func setJvmArguments(_ arguments: String) {
        instance.config.jvmArguments = arguments.splitToArguments()
        instance.markDirty()
    }

    @MainActor
    public func switchJava(to runtime: JavaRuntime) throws {
        if runtime.majorVersion < instance.manifest.javaVersion.majorVersion {
            throw Error.invalidJavaVersion(min: instance.manifest.javaVersion.majorVersion)
        }
        instance.config.javaURL = runtime.executableURL
        instance.markDirty()
        javaDescription = runtime.description
    }
    
    public enum Error: Swift.Error {
        case invalidJavaVersion(min: Int)
    }
}
