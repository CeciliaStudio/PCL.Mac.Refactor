//
//  JavaSearcher.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import Foundation

public class JavaSearcher {
    /// 内部可能存在 Java 目录（如 `zulu-21.jdk`）的目录
    private static let javaDirectories: [URL] = [
        URL(filePath: "/Library/Java/JavaVirtualMachines"),
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Java/JavaVirtualMachines")
    ]
    
    /// 搜索当前环境中安装的 Java（不包含 `/usr/bin/java`）。
    /// - Returns: 当前环境中安装的 Java 列表。
    public static func search() throws -> [JavaRuntime] {
        var runtimes: [JavaRuntime] = []
        let bundles: [URL] = try findJavaBundles()
        for bundle in bundles {
            let homeDirectory: URL = bundle.appending(path: "Contents/Home")
            guard let releaseData: Data = FileManager.default.contents(atPath: homeDirectory.appending(path: "release").path),
                  let releaseContent = String(data: releaseData, encoding: .utf8) else { continue }
            // 解析 release 文件
            let pattern: Regex = /^(JAVA_VERSION|IMPLEMENTOR)="([^"]*)"/
            
            var javaVersion: String?
            var implementor: String?
            
            for line in releaseContent.split(separator: "\n") {
                if let match = try? pattern.firstMatch(in: String(line)) {
                    let key: String = String(match.1)
                    let value: String = String(match.2)
                    if key == "JAVA_VERSION" {
                        javaVersion = value
                    } else if key == "IMPLEMENTOR" {
                        implementor = value
                    }
                }
            }
            guard let javaVersion, let implementor else { continue }
            // 判断 Java 类型并获取可执行文件路径
            var type: JavaRuntime.JavaType = .jdk
            var executableURL: URL!
            if FileManager.default.fileExists(atPath: homeDirectory.appending(path: "jre/bin/java").path) {
                type = .jre
                executableURL = homeDirectory.appending(path: "jre/bin/java")
            } else if FileManager.default.fileExists(atPath: homeDirectory.appending(path: "bin/java").path) {
                executableURL = homeDirectory.appending(path: "bin/java")
            } else {
                continue
            }
            runtimes.append(
                JavaRuntime(
                    version: javaVersion,
                    versionNumber: parseVersionNumber(javaVersion),
                    type: type,
                    architecture: .getFileArchitecture(executableURL),
                    implementor: implementor,
                    executableURL: executableURL
                )
            )
        }
        return runtimes
    }
    
    private static func parseVersionNumber(_ version: String) -> Int {
        let components: [Substring] = version.split(separator: ".")
        if let first: Substring = components.first, first == "1", components.count > 1 {
            return Int(components[1]) ?? 0
        } else if let first: Substring = components.first {
            return Int(first) ?? 0
        }
        return 0
    }
    
    private static func findJavaBundles() throws -> [URL] {
        var bundleDirectories: [URL] = []
        
        for directory in javaDirectories {
            bundleDirectories.append(contentsOf: try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))
        }
        // Homebrew
        let homebrewDirectories: [URL] = try FileManager.default.contentsOfDirectory(at: URL(filePath: "/opt/homebrew/opt"), includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.starts(with: "openjdk@") }
        for directory in homebrewDirectories {
            bundleDirectories.append(directory.appending(path: "libexec").appending(path: "openjdk.jdk"))
        }
        return bundleDirectories.filter { FileManager.default.fileExists(atPath: $0.appending(path: "Contents/Home/release").path) }
    }
}
