//
//  CrashRuleCondition.swift
//  PCL.Mac
//
//  Created by yuanmu on 2026/8/11.
//

import Foundation

public enum CrashTextSource: String, Decodable, CaseIterable {
    case crashReport, hsErrLog, gameLog
}

/// 崩溃分析规则的匹配条件树
public indirect enum CrashRuleCondition: Decodable {
    case contains(keyword: String, sources: [CrashTextSource]?)
    case regex(pattern: String, capture: String?, sources: [CrashTextSource]?)
    case all([CrashRuleCondition])
    case any([CrashRuleCondition])
    case not(CrashRuleCondition)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sources: [CrashTextSource]? = try container.decodeIfPresent([CrashTextSource].self, forKey: .in)
        if let keyword = try container.decodeIfPresent(String.self, forKey: .contains) {
            self = .contains(keyword: keyword, sources: sources)
        } else if let pattern = try container.decodeIfPresent(String.self, forKey: .regex) {
            self = .regex(pattern: pattern, capture: try container.decodeIfPresent(String.self, forKey: .capture), sources: sources)
        } else if let children = try container.decodeIfPresent([CrashRuleCondition].self, forKey: .all) {
            self = .all(children)
        } else if let children = try container.decodeIfPresent([CrashRuleCondition].self, forKey: .any) {
            self = .any(children)
        } else if let child = try container.decodeIfPresent(CrashRuleCondition.self, forKey: .not) {
            self = .not(child)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "无法识别的匹配条件"))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case contains, regex, capture, all, any, not, `in`
    }
}

struct CrashConditionOutcome {
    var matched: Bool
    var captures: [String: String] = [:]
    var matchedLines: [String] = []
}

extension CrashRuleCondition {
    func evaluate(in context: CrashContext) -> CrashConditionOutcome {
        switch self {
        case .contains(let keyword, let sources):
            let lines: [String] = Self.search(sources, in: context) { Self.lines(containing: keyword, in: $0) }
            return .init(matched: !lines.isEmpty, matchedLines: lines)
        case .regex(let pattern, let capture, let sources):
            var firstCapture: String?
            let lines: [String] = Self.search(sources, in: context) { text in
                let (lines, capture) = Self.lines(matching: pattern, in: text)
                if firstCapture == nil { firstCapture = capture }
                return lines
            }
            var outcome: CrashConditionOutcome = .init(matched: !lines.isEmpty, matchedLines: lines)
            if outcome.matched, let capture, let firstCapture {
                outcome.captures[capture] = firstCapture
            }
            return outcome
        case .all(let children):
            var outcome: CrashConditionOutcome = .init(matched: true)
            for child in children {
                let childOutcome: CrashConditionOutcome = child.evaluate(in: context)
                guard childOutcome.matched else { return .init(matched: false) }
                outcome.captures.merge(childOutcome.captures) { current, _ in current }
                outcome.matchedLines.append(contentsOf: childOutcome.matchedLines)
            }
            return outcome
        case .any(let children):
            for child in children {
                let childOutcome: CrashConditionOutcome = child.evaluate(in: context)
                if childOutcome.matched { return childOutcome }
            }
            return .init(matched: false)
        case .not(let child):
            return .init(matched: !child.evaluate(in: context).matched)
        }
    }

    private static func search(_ sources: [CrashTextSource]?, in context: CrashContext, using finder: (String) -> [String]) -> [String] {
        var lines: [String] = []
        var seen: Set<String> = []
        for source in sources ?? CrashTextSource.allCases {
            guard let text = context.text(for: source) else { continue }
            for line in finder(text) where seen.insert(line).inserted {
                lines.append(line)
            }
        }
        return lines
    }

    private static func lines(containing keyword: String, in text: String) -> [String] {
        var lines: [String] = []
        var searchRange: Range<String.Index> = text.startIndex..<text.endIndex
        while lines.count < CrashAnalyzer.maxMatchedLines, let range = text.range(of: keyword, range: searchRange) {
            let lineRange: Range<String.Index> = text.lineRange(for: range)
            lines.append(String(text[lineRange]).trimmingCharacters(in: .whitespacesAndNewlines))
            searchRange = lineRange.upperBound..<text.endIndex
        }
        return lines
    }

    private static func lines(matching pattern: String, in text: String) -> (lines: [String], firstCapture: String?) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return ([], nil) }
        var lines: [String] = []
        var firstCapture: String?
        regex.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { match, _, stop in
            guard let match, let range = Range(match.range, in: text) else { return }
            lines.append(String(text[text.lineRange(for: range)]).trimmingCharacters(in: .whitespacesAndNewlines))
            if firstCapture == nil, match.numberOfRanges > 1, let captureRange = Range(match.range(at: 1), in: text) {
                firstCapture = String(text[captureRange]).trimmingCharacters(in: .whitespaces)
            }
            if lines.count >= CrashAnalyzer.maxMatchedLines { stop.pointee = true }
        }
        return (lines, firstCapture)
    }
}
