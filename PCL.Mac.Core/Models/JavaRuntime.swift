//
//  JavaRuntime.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/8.
//

import Foundation

public struct JavaRuntime: CustomStringConvertible, Equatable {
    /// Java 版本号，如 `21.0.8`、`1.8.0_462`。
    public let version: String
    /// Java 主版本号，如 `21`、`8`。
    public let majorVersion: Int
    /// Java 类型。
    public let type: JavaType
    /// Java 架构。
    public let architecture: Architecture
    /// Java 实现商，如 `Azul Systems, Inc.`。
    public let implementor: String?
    /// `java` 可执行文件 URL。
    public let executableURL: URL
    /// 是否为手动添加的 Java。
    public let isCustom: Bool
    
    public enum JavaType: CustomStringConvertible {
        case jdk, jre
        
        public var description: String {
            switch self {
            case .jdk: "JDK"
            case .jre: "JRE"
            }
        }
    }
    
    public var description: String {
        if let implementor {
            return "\(type) \(version) \(architecture) (\(implementor))"
        }
        return "\(type) \(version) \(architecture)"
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.executableURL == rhs.executableURL }
}
