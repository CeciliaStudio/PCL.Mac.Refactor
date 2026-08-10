//
//  MinecraftInstance.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/4/15.
//

import Foundation

public class MinecraftInstance: Hashable, Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let version: MinecraftVersion
    public let modLoader: ModLoader?
    public let manifest: ClientManifest
    
    public var config: Config
    
    public var dirty: Bool
    
    public var name: String { url.lastPathComponent }
    public var manifestURL: URL { url.appending(path: "\(name).json") }
    
    public init(id: UUID, url: URL, version: MinecraftVersion, modLoader: ModLoader?, manifest: ClientManifest, config: Config, dirty: Bool = false) {
        self.id = id
        self.url = url
        self.version = version
        self.modLoader = modLoader
        self.manifest = manifest
        self.config = config
        self.dirty = dirty
    }
    
    public func markDirty() { self.dirty = true }
    
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MinecraftInstance, rhs: MinecraftInstance) -> Bool {
        return lhs.id == rhs.id
    }
    
    public struct Config: Codable {
        public var jvmHeapSize: UInt64
        public var javaURL: URL?
        public var jvmArguments: [String] = ""

        public static let `default`: Config = .init(jvmHeapSize: 4096, javaURL: nil)
    }
}

public extension JavaSearcher {
    static func pick(for instance: MinecraftInstance) -> JavaRuntime? {
        let systemArch: Architecture = .systemArchitecture()
        let instanceNeedsX64 = instance.version < .init("1.7.2")
        
        func score(of javaRuntime: JavaRuntime) -> Int {
            var score = 0
            if javaRuntime.architecture == (instance.version > .init("1.7.2") ? systemArch : .x64) { score += 3 }
            if javaRuntime.majorVersion == instance.manifest.javaVersion.majorVersion { score += 2 }
            if javaRuntime.type == .jdk { score += 1 }
            return score
        }
        
        let javaRuntimes = JavaManager.shared.javaRuntimes.lazy
            .filter { $0.majorVersion >= instance.manifest.javaVersion.majorVersion && !(systemArch == .x64 && $0.architecture == .arm64) }
            .filter { !(instanceNeedsX64 && $0.architecture != .x64)  }
        
        return javaRuntimes.max(by: { score(of: $0) < score(of: $1) })
    }
}
