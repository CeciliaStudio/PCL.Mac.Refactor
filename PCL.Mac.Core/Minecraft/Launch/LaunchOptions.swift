//
//  LaunchOptions.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/21.
//

import Foundation

public struct LaunchOptions {
    public var profile: PlayerProfile!
    public var accessToken: String!
    public var javaRuntime: JavaRuntime!
    public var runningDirectory: URL!
    public var manifest: ClientManifest!
    public var repository: MinecraftRepository!
    public var memory: UInt64 = 4096
    public var mainClass: String!
    public var extraJvmArguments: [String] = []
    public var demo: Bool = false
    
    // Authlib Injector
    public var authlibInjectorPath: String?
    public var authServerURL: URL?
    public var prefetchedMeta: String?
    
    public func validate() throws {
        if profile == nil || accessToken == nil { throw LaunchError.missingAccount }
        if javaRuntime == nil { throw LaunchError.missingJava }
        if runningDirectory == nil { throw LaunchError.missingRunningDirectory }
        if manifest == nil { throw LaunchError.missingManifest }
        if repository == nil { throw LaunchError.missingRepository }
        if mainClass == nil { throw LaunchError.missingMainClass}
    }
    
    public init() {}
}
