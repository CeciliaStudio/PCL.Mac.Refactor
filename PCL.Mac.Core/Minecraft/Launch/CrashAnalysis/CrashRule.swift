//
//  CrashRule.swift
//  PCL.Mac
//
//  Created by yuanmu on 2026/8/11.
//

import Foundation

/// 优先级
public enum CrashRuleLevel: String, Decodable {
    /// 强提示
    case certain
    /// 弱提示
    case possible
    /// 排除无害
    case harmless
}

public struct CrashRule: Decodable {
    public static let supportedSchema: Int = 1

    public let schema: Int
    public let id: String
    public let version: Int
    public let author: String?
    public let level: CrashRuleLevel
    public let priority: Int
    public let match: CrashRuleCondition?
    public let script: String?
    public let output: Output?

    public struct Output: Decodable {
        public let detected: String
        public let suggestion: String?
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schema = try container.decode(Int.self, forKey: .schema)
        guard schema == Self.supportedSchema else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "不支持的规则格式版本：\(schema)"))
        }
        self.id = try container.decode(String.self, forKey: .id)
        self.version = try container.decode(Int.self, forKey: .version)
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
        self.level = try container.decode(CrashRuleLevel.self, forKey: .level)
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        self.match = try container.decodeIfPresent(CrashRuleCondition.self, forKey: .match)
        self.script = try container.decodeIfPresent(String.self, forKey: .script)
        self.output = try container.decodeIfPresent(Output.self, forKey: .output)
        guard match != nil || script != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "规则 \(id) 须提供 match 或 script"))
        }
        guard level == .harmless || output != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "规则 \(id) 须提供 output"))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schema, id, version, author, level, priority, match, script, output
    }
}

/// 分析结果
public struct CrashAnalysisResult {
    public let ruleID: String
    public let level: CrashRuleLevel
    public let detected: String
    public let suggestion: String?
    public let evidence: [String]
}

// 规则加载
extension CrashRule {
    public static let userDirectoryURL: URL = URLConstants.applicationSupportURL.appending(path: "CrashRules")

    public static func loadDefaultRules() -> [CrashRule] {
        merge(loadBundledRules(), load(from: [userDirectoryURL]))
    }

    public static func loadBundledRules() -> [CrashRule] {
        decode(Bundle(for: BundleToken.self).urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
    }

    public static func load(from directories: [URL]) -> [CrashRule] {
        directories.reduce(into: [CrashRule]()) { rules, directory in
            let urls: [URL] = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            rules = merge(rules, decode(urls.filter { $0.pathExtension == "json" }))
        }
    }

    private static func decode(_ urls: [URL]) -> [CrashRule] {
        urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { url in
            do {
                return try JSONDecoder.shared.decode(CrashRule.self, from: Data(contentsOf: url))
            } catch {
                err("加载崩溃分析规则 \(url.lastPathComponent) 失败：\(error.localizedDescription)")
                return nil
            }
        }
    }

    /// 合并规则列表，后者中的同 id 规则覆盖前者。
    private static func merge(_ base: [CrashRule], _ override: [CrashRule]) -> [CrashRule] {
        let overriddenIDs: Set<String> = .init(override.map(\.id))
        return base.filter { !overriddenIDs.contains($0.id) } + override
    }

    private final class BundleToken {}
}
