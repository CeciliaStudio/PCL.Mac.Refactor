//
//  JavaManager.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/2/2.
//

import Foundation

public final class JavaManager: ObservableObject {
    public static var shared: JavaManager!
    
    @Published public private(set) var javaRuntimes: [JavaRuntime]
    private var customJavaRuntimes: [URL]
    
    @MainActor
    public func research() throws {
        self.javaRuntimes = try JavaSearcher.search(customJavaRuntimes: customJavaRuntimes)
    }
    
    public init(customJavaRuntimes: [URL]) {
        self.customJavaRuntimes = customJavaRuntimes
        do {
            self.javaRuntimes = try JavaSearcher.search(customJavaRuntimes: customJavaRuntimes)
            log("Java 搜索完成，共 \(javaRuntimes.count) 个：")
            for javaRuntime in javaRuntimes {
                let type: String = .init(describing: javaRuntime.type).padding(toLength: 4, withPad: " ", startingAt: 0)
                let version: String = .init(describing: javaRuntime.version).padding(toLength: 10, withPad: " ", startingAt: 0)
                let arch: String = .init(describing: javaRuntime.architecture).padding(toLength: 8, withPad: " ", startingAt: 0)
                let impl: String = (javaRuntime.implementor ?? "").padding(toLength: 24, withPad: " ", startingAt: 0)
                log("\(type) \(version)\t\(arch)\t\(impl)\t\(javaRuntime.executableURL.path)")
            }
        } catch {
            err("搜索 Java 失败：\(error.localizedDescription)")
            self.javaRuntimes = []
        }
    }
    
    @MainActor
    public func addCustomRuntime(_ runtime: JavaRuntime) -> Bool {
        if javaRuntimes.contains(runtime) { return false }
        javaRuntimes.append(runtime)
        customJavaRuntimes.append(runtime.executableURL)
        return true
    }
    
    @MainActor
    @discardableResult
    public func removeCustomRuntime(_ executableURL: URL) -> Bool {
        guard let index = javaRuntimes.firstIndex(where: { $0.executableURL == executableURL }) else {
            return false
        }
        javaRuntimes.remove(at: index)
        customJavaRuntimes.removeAll(where: { $0 == executableURL })
        return true
    }
}
