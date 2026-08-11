//
//  CrashRuleScriptRunner.swift
//  PCL.Mac
//
//  Created by yuanmu on 2026/8/11.
//

import Foundation
import JavaScriptCore

/// 脚本的执行器
enum CrashRuleScriptRunner {
    struct Output {
        let evidence: [String]
        let values: [String: String]
    }

    static func run(_ script: String, ruleID: String, context: CrashContext, captures: [String: String]) -> Output? {
        guard let jsContext = JSContext() else { return nil }
        jsContext.exceptionHandler = { _, exception in
            err("崩溃分析规则 \(ruleID) 的脚本执行出错：\(exception?.toString() ?? "未知错误")")
        }
        jsContext.evaluateScript(script)
        guard let function = jsContext.objectForKeyedSubscript("match"), function.isObject else {
            err("崩溃分析规则 \(ruleID) 的脚本未定义 match 函数")
            return nil
        }

        var scriptContext: [String: Any] = [
            "exitCode": Int(context.exitCode),
            "memory": Int(context.memory),
            "captures": captures
        ]
        scriptContext["gameLog"] = context.gameLog
        scriptContext["crashReport"] = context.crashReport
        scriptContext["hsErrLog"] = context.hsErrLog
        scriptContext["javaVersion"] = context.javaVersion
        scriptContext["javaMajor"] = context.javaMajor
        scriptContext["javaArchitecture"] = context.javaArchitecture

        guard let result = function.call(withArguments: [scriptContext]), !result.isNull, !result.isUndefined else { return nil }
        return .init(evidence: evidence(of: result), values: values(of: result))
    }

    private static func evidence(of result: JSValue) -> [String] {
        guard let property = result.objectForKeyedSubscript("evidence") else { return [] }
        if property.isString, let string = property.toString() { return [string] }
        if property.isArray, let array = property.toArray() { return array.compactMap { $0 as? String } }
        return []
    }

    private static func values(of result: JSValue) -> [String: String] {
        guard let dictionary = result.toDictionary() as? [String: Any] else { return [:] }
        return dictionary.reduce(into: [:]) { values, entry in
            guard entry.key != "evidence" else { return }
            switch entry.value {
            case let string as String: values[entry.key] = string
            case let number as NSNumber: values[entry.key] = number.stringValue
            default: break
            }
        }
    }
}
