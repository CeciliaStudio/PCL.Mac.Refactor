//
//  JavaSearcher.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/8.
//

import Foundation

public enum JavaSearcher {
    /// 内部可能存在 Java 目录（如 `zulu-21.jdk`）的目录
    private static let javaDirectories: [URL] = {
        let homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Library/Java/JavaVirtualMachines"),
            homeDirectory.appending(path: "Library/Java/JavaVirtualMachines"),
            homeDirectory.appending(path: ".jdks"),                          // IntelliJ IDEA
            homeDirectory.appending(path: ".sdkman/candidates/java"),        // SDKMAN!
            homeDirectory.appending(path: ".asdf/installs/java"),            // asdf
            homeDirectory.appending(path: ".local/share/mise/installs/java"), // mise
            homeDirectory.appending(path: ".jenv/versions"),                 // jEnv
            homeDirectory.appending(path: ".jabba/jdk"),                     // Jabba
            homeDirectory.appending(path: ".gradle/jdks")                    // Gradle 工具链
        ]
    }()

    /// Homebrew 的 openjdk 安装目录，分别对应 Apple Silicon 与 Intel。
    private static let homebrewDirectories: [URL] = [
        URL(fileURLWithPath: "/opt/homebrew/opt"),
        URL(fileURLWithPath: "/usr/local/opt")
    ]

    /// 搜索当前环境中安装的 Java（不包含 `/usr/bin/java`）。
    /// - Parameter customJavaRuntimes: 自定义 Java 列表。
    /// - Returns: 当前环境中安装的 Java 列表。
    public static func search(customJavaRuntimes: [URL] = []) throws -> [JavaRuntime] {
        var runtimes: [JavaRuntime] = []
        var isCustom = false
        for urls in [findJavaHomes(), customJavaRuntimes] {
            for url in urls {
                do {
                    let runtime = try load(from: url, isCustom: isCustom)
                    runtimes.append(runtime)
                } catch {
                    err("加载 Java 失败：\(error)")
                    debug("url：\(url.path)")
                }
            }
            isCustom = true
        }
        
        return runtimes
    }
    
    /// 加载磁盘上的 Java 运行时。
    /// - Parameters:
    ///   - url: 运行时的 `URL`，位于 Java 主目录内即可（如 `bin/java`）。
    ///   - isCustom: 是否为手动添加的 Java。
    public static func load(from url: URL, isCustom: Bool = false) throws -> JavaRuntime {
        var url = url
        while !isJavaHome(url) {
            if url.path == "/" {
                throw JavaError.invalidURL
            }
            url = url.deletingLastPathComponent()
        }
        let homeDirectory: URL = url
        // 解析 release 文件
        let release: [String: String]
        do {
            release = try PropertiesLoader.load(at: homeDirectory.appending(path: "release"))
        } catch {
            throw JavaError.failedToParseReleaseFile
        }
        guard let javaVersion = release["JAVA_VERSION"] else {
            throw JavaError.failedToParseReleaseFile
        }
        guard let versionMajor: Int = parseVersionNumber(javaVersion) else {
            throw JavaError.failedToParseVersionNumber(version: javaVersion)
        }
        let implementor: String?
        if homeDirectory.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent.starts(with: "mojang") {
            implementor = "Microsoft"
        } else {
            implementor = release["IMPLEMENTOR"]
        }
        
        // 类型判断
        var type: JavaRuntime.JavaType?
        var executableURL: URL?
        var architecture: Architecture?
        for path in ["bin/java", "jre/bin/java"] {
            let url: URL = homeDirectory.appending(path: path)
            let arch: Architecture = .architecture(of: url)
            if arch != .unknown {
                let javacURL: URL = url.deletingLastPathComponent().appending(path: "javac")
                type = FileManager.default.fileExists(atPath: javacURL.path) ? .jdk : .jre
                executableURL = url
                architecture = arch
                break
            }
        }
        guard let type, let executableURL, let architecture else {
            throw JavaError.missingExecutableFile
        }
        return JavaRuntime(
            version: javaVersion,
            majorVersion: versionMajor,
            type: type,
            architecture: architecture,
            implementor: implementor,
            executableURL: executableURL,
            isCustom: isCustom
        )
    }
    
    private static func parseVersionNumber(_ version: String) -> Int? {
        let components: [String] = version.split(separator: ".").map(String.init)
        if components.count == 1 {
            return Int(components[0])
        } else if components.count > 1 {
            if components[0] == "1" {
                return Int(components[1])
            } else {
                return Int(components[0])
            }
        }
        return nil
    }
    
    private static func findJavaHomes() -> [URL] {
        var homeDirectories: [URL] = javaDirectories.flatMap { contents(of: $0).compactMap(javaHome(at:)) }
        homeDirectories += homebrewDirectories.flatMap {
            contents(of: $0)
                .filter { $0.lastPathComponent.starts(with: "openjdk") }
                .compactMap(javaHome(at:))
        }
        
        var visited: Set<String> = []
        return homeDirectories.filter { visited.insert($0.resolvingSymlinksInPath().path).inserted }
    }

    /// 解析一个可能的 Java 安装目录，兼容 macOS 的 `.jdk` 包、Homebrew 与直接解压的 Java 目录。
    /// - Returns: Java 主目录，若该目录不是 Java 安装目录则返回 `nil`。
    private static func javaHome(at url: URL) -> URL? {
        [
            url,                                            // SDKMAN、asdf、mise 等直接解压的目录
            url.appending(path: "Contents/Home"),           // macOS 的 .jdk / .bundle 包
            url.appending(path: "libexec/openjdk.jdk/Contents/Home") // Homebrew
        ].first(where: isJavaHome)
    }

    /// 判断目录是否为 Java 主目录。
    private static func isJavaHome(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appending(path: "release").path)
    }

    private static func contents(of directory: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        do {
            return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .sorted { $0.path < $1.path }
        } catch {
            err("搜索 \(directory.path) 失败：\(error.localizedDescription)")
            return []
        }
    }
}
