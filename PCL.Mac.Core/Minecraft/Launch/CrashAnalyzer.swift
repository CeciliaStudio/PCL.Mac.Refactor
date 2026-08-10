//
//  CrashAnalyzer.swift
//  PCL.Mac
//
//  Created by yuanmua on 2026/8/10.
//

import Foundation

/// 崩溃分析的输入上下文，聚合了分析所需的全部信息。
public struct CrashContext {
    /// 游戏进程的输出日志（stdout 与 stderr 合并）。日志过大时只包含末尾部分。
    public let gameLog: String?
    /// 最新的游戏崩溃报告（`crash-reports/crash-*.txt`）内容。
    public let crashReport: String?
    /// 最新的 JVM 致命错误日志（`hs_err_pid*.log`）内容。
    public let hsErrLog: String?
    /// 游戏进程的退出代码。
    public let exitCode: Int32
    /// 启动游戏使用的 Java 运行时。
    public let javaRuntime: JavaRuntime?
    /// 启动游戏时分配的内存大小（MB）。
    public let memory: UInt64
    /// 用户设置的额外 JVM 参数。
    public let extraJvmArguments: [String]
    /// 启动游戏使用的玩家名。
    public let playerName: String
    /// 游戏运行目录的路径。
    public let gameDirectory: String

    public init(
        gameLog: String? = nil,
        crashReport: String? = nil,
        hsErrLog: String? = nil,
        exitCode: Int32 = 1,
        javaRuntime: JavaRuntime? = nil,
        memory: UInt64 = 4096,
        extraJvmArguments: [String] = [],
        playerName: String = "",
        gameDirectory: String = ""
    ) {
        self.gameLog = gameLog
        self.crashReport = crashReport
        self.hsErrLog = hsErrLog
        self.exitCode = exitCode
        self.javaRuntime = javaRuntime
        self.memory = memory
        self.extraJvmArguments = extraJvmArguments
        self.playerName = playerName
        self.gameDirectory = gameDirectory
    }

    /// 参与匹配的全部文本，按可信度排序：崩溃报告 > JVM 错误日志 > 游戏日志。
    public var allTexts: [String] { [crashReport, hsErrLog, gameLog].compactMap { $0 } }

    /// 判断任意输入文本中是否包含指定关键字。
    /// - Parameter keyword: 关键字。
    /// - Returns: 是否包含。
    public func contains(_ keyword: String) -> Bool {
        allTexts.contains { $0.contains(keyword) }
    }

    /// 判断任意输入文本中是否包含任意一个关键字。
    /// - Parameter keywords: 关键字列表。
    /// - Returns: 是否包含。
    public func contains(anyOf keywords: [String]) -> Bool {
        keywords.contains { contains($0) }
    }

    /// 判断崩溃报告或 JVM 错误日志中是否包含任意一个关键字。
    ///
    /// 游戏日志中充斥着不会导致崩溃的 `ERROR` 行（如联机验证失败、皮肤加载失败、mod 自身的警告），
    /// 而崩溃报告与 JVM 错误日志只在游戏确实崩溃时产生。对于那些既可能是崩溃原因、
    /// 又经常作为噪声出现在游戏日志中的特征，应当只在这些权威文本中匹配。
    /// - Parameter keywords: 关键字列表。
    /// - Returns: 是否包含。没有崩溃报告与 JVM 错误日志时返回 `false`。
    public func crashReportContains(anyOf keywords: [String]) -> Bool {
        let texts: [String] = [crashReport, hsErrLog].compactMap { $0 }
        return keywords.contains { keyword in texts.contains { $0.contains(keyword) } }
    }

    /// 在全部输入文本中查找正则表达式的第一个匹配。
    /// - Parameter pattern: 正则表达式。
    /// - Returns: 第一个捕获组的内容；若无捕获组，返回整个匹配。未匹配时返回 `nil`。
    public func firstMatch(of pattern: String) -> String? {
        matches(of: pattern, limit: 1).first
    }

    /// 在全部输入文本中查找正则表达式的匹配。
    /// - Parameters:
    ///   - pattern: 正则表达式，`^` 与 `$` 匹配行首与行尾。
    ///   - limit: 返回的匹配数量上限。
    /// - Returns: 每个匹配的第一个捕获组（若无捕获组则为整个匹配），去除首尾空白，最多 `limit` 个。
    public func matches(of pattern: String, limit: Int) -> [String] {
        var results: [String] = []
        for text in allTexts {
            results.append(contentsOf: text.regexMatches(of: pattern, limit: limit - results.count))
            if results.count >= limit { break }
        }
        return results
    }
}

/// 单条崩溃分析结果。
public struct CrashAnalysisResult {
    /// 崩溃原因描述。
    public let cause: String
    /// 给用户的解决建议，只使用玩家能看懂的说法。
    public let suggestion: String
    /// 从日志中提取的技术信息，供向他人求助时参考。没有可提取的信息时为 `nil`。
    public let details: String?

    public init(cause: String, suggestion: String, details: String? = nil) {
        self.cause = cause
        self.suggestion = suggestion
        self.details = details
    }
}

/// Minecraft 崩溃原因分析器。
/// 根据游戏日志、崩溃报告与 JVM 致命错误日志，按规则表匹配常见崩溃原因。
public enum CrashAnalyzer {
    /// 分析崩溃原因。
    /// - Parameter context: 崩溃上下文。
    /// - Returns: 命中的分析结果，按规则优先级从高到低排列。
    /// 只有在没有任何具体规则命中时，才会尝试兜底规则。未能分析出原因时为空数组。
    public static func analyze(_ context: CrashContext) -> [CrashAnalysisResult] {
        let results: [CrashAnalysisResult] = match(rules: CrashRules.all.filter { !$0.isFallback }, with: context)
        if !results.isEmpty { return results }
        return match(rules: CrashRules.all.filter(\.isFallback), with: context)
    }

    private static func match(rules: [CrashRule], with context: CrashContext) -> [CrashAnalysisResult] {
        var results: [CrashAnalysisResult] = []
        for rule in rules {
            if let match = rule.match(context) {
                results.append(.init(cause: rule.cause, suggestion: match.suggestion, details: match.details))
            }
        }
        return results
    }

    /// 从磁盘加载崩溃上下文。
    /// - Parameters:
    ///   - logURL: 游戏输出日志文件 URL。
    ///   - runningDirectory: 游戏运行目录。
    ///   - exitCode: 游戏进程的退出代码。
    ///   - options: 启动游戏使用的选项。
    ///   - since: 只采用该时间之后修改的崩溃报告与 JVM 错误日志，避免误用历史崩溃产生的文件。
    /// - Returns: 聚合完成的崩溃上下文。
    public static func loadContext(
        logURL: URL,
        runningDirectory: URL,
        exitCode: Int32,
        options: LaunchOptions,
        since: Date
    ) -> CrashContext {
        .init(
            gameLog: tail(of: logURL),
            crashReport: latestCrashReport(in: runningDirectory, since: since).flatMap(read),
            hsErrLog: latestHsErrLog(in: runningDirectory, since: since).flatMap(read),
            exitCode: exitCode,
            javaRuntime: options.javaRuntime,
            memory: options.memory,
            extraJvmArguments: options.extraJvmArguments,
            playerName: options.profile?.name ?? "",
            gameDirectory: runningDirectory.path
        )
    }

    /// 获取最新的游戏崩溃报告文件。
    /// - Parameters:
    ///   - runningDirectory: 游戏运行目录。
    ///   - since: 若不为 `nil`，只考虑该时间之后修改的文件。
    /// - Returns: 最新的崩溃报告文件 URL。不存在时返回 `nil`。
    public static func latestCrashReport(in runningDirectory: URL, since: Date? = nil) -> URL? {
        latestFile(in: runningDirectory.appending(path: "crash-reports"), since: since) {
            $0.lastPathComponent.hasPrefix("crash-") && ["txt", "log"].contains($0.pathExtension)
        }
    }

    /// 获取最新的 JVM 致命错误日志文件。
    /// - Parameters:
    ///   - runningDirectory: 游戏运行目录。
    ///   - since: 若不为 `nil`，只考虑该时间之后修改的文件。
    /// - Returns: 最新的 JVM 致命错误日志文件 URL。不存在时返回 `nil`。
    public static func latestHsErrLog(in runningDirectory: URL, since: Date? = nil) -> URL? {
        latestFile(in: runningDirectory, since: since) {
            $0.lastPathComponent.hasPrefix("hs_err_pid") && $0.pathExtension == "log"
        }
    }

    /// 读取文件末尾内容，避免超大日志拖慢分析，并去除干扰匹配的 ANSI 颜色转义序列。
    private static func tail(of url: URL, maxBytes: UInt64 = 262_144) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > maxBytes ? size - maxBytes : 0)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return nil }
        return String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: #"\x{1B}\[[0-9;]*m"#, with: "", options: .regularExpression)
    }

    private static func read(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func latestFile(in directory: URL, since: Date?, where predicate: (URL) -> Bool) -> URL? {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
        ) else { return nil }
        return urls
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false }
            .filter(predicate)
            .compactMap { url -> (url: URL, date: Date)? in
                guard let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return nil }
                return (url, date)
            }
            .filter { candidate in since.map { candidate.date >= $0 } ?? true }
            .max { $0.date < $1.date }?
            .url
    }
}

private extension String {
    /// 查找正则表达式的匹配。
    /// - Parameters:
    ///   - pattern: 正则表达式，`^` 与 `$` 匹配行首与行尾。
    ///   - limit: 返回的匹配数量上限。
    /// - Returns: 每个匹配的第一个捕获组（若无捕获组则为整个匹配），去除首尾空白，最多 `limit` 个。
    func regexMatches(of pattern: String, limit: Int) -> [String] {
        guard limit > 0, let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        var results: [String] = []
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, stop in
            guard let match else { return }
            let nsRange: NSRange = match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range
            if let range = Range(nsRange, in: self) {
                results.append(String(self[range]).trimmingCharacters(in: .whitespaces))
            }
            if results.count >= limit { stop.pointee = true }
        }
        return results
    }
}
