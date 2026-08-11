//
//  CrashAnalyzer.swift
//  PCL.Mac
//
//  Created by yuanmu on 2026/8/11.
//

import Foundation

/// Minecraft 崩溃原因分析器。
///
/// 分析流程：
/// 1. 先屏蔽无害规则其命中的文本行
/// 2. 执行诊断规则，收集命中结果
/// 3. 根据配置进行分级展示
public enum CrashAnalyzer {
    /// 弱提示最大展示条数
    static let maxPossibleResults: Int = 2
    /// 证据行数上限
    static let maxEvidenceLines: Int = 3
    /// 单行证据长度上限
    static let maxEvidenceLineLength: Int = 200
    /// 读取游戏日志的字节数上限，只读取末尾部分
    static let maxGameLogBytes: UInt64 = 262_144
    /// 单个条件收集的命中行数上限
    static let maxMatchedLines: Int = 50

    public static func analyze(_ context: CrashContext, rules: [CrashRule] = CrashRule.loadDefaultRules()) -> [CrashAnalysisResult] {
        let sorted: [CrashRule] = rules.sorted {
            $0.priority != $1.priority ? $0.priority > $1.priority : $0.id < $1.id
        }
        let masked: CrashContext = mask(context, with: sorted.filter { $0.level == .harmless })
        let hits: [CrashAnalysisResult] = sorted
            .filter { $0.level != .harmless }
            .compactMap { evaluate($0, in: masked) }
        let certain: [CrashAnalysisResult] = hits.filter { $0.level == .certain }
        if !certain.isEmpty { return certain }
        return Array(hits.prefix(maxPossibleResults))
    }

    public static func matches(_ rule: CrashRule, in context: CrashContext) -> Bool {
        rule.level == .harmless ? !harmlessLines(of: rule, in: context).isEmpty : evaluate(rule, in: context) != nil
    }

    private static func evaluate(_ rule: CrashRule, in context: CrashContext) -> CrashAnalysisResult? {
        guard let output = rule.output else { return nil }
        var outcome: CrashConditionOutcome = .init(matched: true)
        if let match = rule.match {
            outcome = match.evaluate(in: context)
            guard outcome.matched else { return nil }
        }
        var scriptOutput: CrashRuleScriptRunner.Output?
        if let script = rule.script {
            guard let result = CrashRuleScriptRunner.run(script, ruleID: rule.id, context: context, captures: outcome.captures) else { return nil }
            scriptOutput = result
        }
        var variables: [String: String] = [:]
        for (name, value) in outcome.captures { variables["capture.\(name)"] = value }
        for (name, value) in scriptOutput?.values ?? [:] { variables["script.\(name)"] = value }
        return .init(
            ruleID: rule.id,
            level: rule.level,
            detected: render(output.detected, variables: variables, context: context),
            suggestion: output.suggestion.map { render($0, variables: variables, context: context) },
            evidence: (outcome.matchedLines + (scriptOutput?.evidence ?? []))
                .prefix(maxEvidenceLines)
                .map { $0.count > maxEvidenceLineLength ? String($0.prefix(maxEvidenceLineLength)) + "……" : $0 }
        )
    }

    private static func mask(_ context: CrashContext, with harmlessRules: [CrashRule]) -> CrashContext {
        var lines: Set<String> = []
        for rule in harmlessRules {
            lines.formUnion(harmlessLines(of: rule, in: context))
        }
        return lines.isEmpty ? context : context.masking(lines: lines)
    }

    private static func harmlessLines(of rule: CrashRule, in context: CrashContext) -> [String] {
        var outcome: CrashConditionOutcome = .init(matched: true)
        if let match = rule.match {
            outcome = match.evaluate(in: context)
            guard outcome.matched else { return [] }
        }
        if let script = rule.script {
            guard let output = CrashRuleScriptRunner.run(script, ruleID: rule.id, context: context, captures: outcome.captures) else { return [] }
            return outcome.matchedLines + output.evidence
        }
        return outcome.matchedLines
    }

    private static func render(_ template: String, variables: [String: String], context: CrashContext) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{([\w.]+)\}"#) else { return template }
        var result: String = ""
        var lastIndex: String.Index = template.startIndex
        regex.enumerateMatches(in: template, range: NSRange(template.startIndex..., in: template)) { match, _, _ in
            guard let match, let range = Range(match.range, in: template), let nameRange = Range(match.range(at: 1), in: template) else { return }
            result += template[lastIndex..<range.lowerBound]
            result += value(of: String(template[nameRange]), variables: variables, context: context) ?? String(template[range])
            lastIndex = range.upperBound
        }
        result += template[lastIndex...]
        return result
    }

    private static func value(of variable: String, variables: [String: String], context: CrashContext) -> String? {
        if let value = variables[variable] { return value }
        return switch variable {
        case "java.version": context.javaVersion
        case "java.major": context.javaMajor.map { String($0) }
        case "java.architecture": context.javaArchitecture
        case "memory": String(context.memory)
        case "exitCode": String(context.exitCode)
        default: nil
        }
    }
}

// 上下文加载
extension CrashAnalyzer {
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
            memory: options.memory
        )
    }

    public static func latestCrashReport(in runningDirectory: URL, since: Date? = nil) -> URL? {
        latestFile(in: runningDirectory.appending(path: "crash-reports"), since: since) {
            $0.lastPathComponent.hasPrefix("crash-") && ["txt", "log"].contains($0.pathExtension)
        }
    }

    public static func latestHsErrLog(in runningDirectory: URL, since: Date? = nil) -> URL? {
        latestFile(in: runningDirectory, since: since) {
            $0.lastPathComponent.hasPrefix("hs_err_pid") && $0.pathExtension == "log"
        }
    }

    private static func tail(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > maxGameLogBytes ? size - maxGameLogBytes : 0)
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
