//
//  JavaRuntime.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import Foundation

public struct JavaRuntime {
    /// Java 版本号，如 `21.0.8`、`1.8.0_462`。
    public let version: String
    /// Java 主版本号，如 `21`、`8`。
    public let versionNumber: Int
    /// Java 类型。
    public let type: JavaType
    /// Java 架构。
    public let architecture: Architecture
    /// Java 实现者，如 `Azul Systems, Inc.`。
    public let implementor: String
    /// `java` 可执行文件 URL。
    public let executableURL: URL
    
    public enum JavaType {
        case jdk, jre
    }
}
