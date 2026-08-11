//
//  CrashContext.swift
//  PCL.Mac
//
//  Created by yuanmu on 2026/8/11.
//

import Foundation

/// 崩溃分析的上下文，后面按需添加
public struct CrashContext {
    public let gameLog: String?
    public let crashReport: String?
    public let hsErrLog: String?
    public let exitCode: Int32
    public let javaVersion: String?
    public let javaMajor: Int?
    public let javaArchitecture: String?
    public let memory: UInt64

    public init(
        gameLog: String? = nil,
        crashReport: String? = nil,
        hsErrLog: String? = nil,
        exitCode: Int32 = 1,
        javaVersion: String? = nil,
        javaMajor: Int? = nil,
        javaArchitecture: String? = nil,
        memory: UInt64 = 4096
    ) {
        self.gameLog = gameLog
        self.crashReport = crashReport
        self.hsErrLog = hsErrLog
        self.exitCode = exitCode
        self.javaVersion = javaVersion
        self.javaMajor = javaMajor
        self.javaArchitecture = javaArchitecture
        self.memory = memory
    }

    public init(
        gameLog: String? = nil,
        crashReport: String? = nil,
        hsErrLog: String? = nil,
        exitCode: Int32 = 1,
        javaRuntime: JavaRuntime?,
        memory: UInt64 = 4096
    ) {
        self.init(
            gameLog: gameLog,
            crashReport: crashReport,
            hsErrLog: hsErrLog,
            exitCode: exitCode,
            javaVersion: javaRuntime?.version,
            javaMajor: javaRuntime?.majorVersion,
            javaArchitecture: javaRuntime?.architecture.description,
            memory: memory
        )
    }

    public func text(for source: CrashTextSource) -> String? {
        switch source {
        case .gameLog: gameLog
        case .crashReport: crashReport
        case .hsErrLog: hsErrLog
        }
    }

    func masking(lines: Set<String>) -> CrashContext {
        func filter(_ text: String?) -> String? {
            guard let text else { return nil }
            return text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !lines.contains($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .joined(separator: "\n")
        }
        return .init(
            gameLog: filter(gameLog),
            crashReport: filter(crashReport),
            hsErrLog: filter(hsErrLog),
            exitCode: exitCode,
            javaVersion: javaVersion,
            javaMajor: javaMajor,
            javaArchitecture: javaArchitecture,
            memory: memory
        )
    }
}
