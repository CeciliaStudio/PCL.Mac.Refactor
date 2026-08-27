//
//  Secrets.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/5/4.
//

import Foundation
import Core

struct Secrets {
    public static let shared: Secrets = .init()
    
    public let curseforgeApiKey: String?
    
    private init() {
        let secrets: [String: String]?
        do {
            let secretsURL = URLConstants.resourcesURL.appending(path: "Secrets.properties")
            secrets = try PropertiesLoader.load(at: secretsURL)
        } catch {
            err("加载 Secrets.properties 失败：\(error.localizedDescription)")
            secrets = nil
        }
        
        curseforgeApiKey = Self.secret(key: "CURSE_FORGE_API_KEY", in: secrets)
    }
    
    private static func secret(key: String, in secrets: [String: String]?) -> String? {
        if let secret = ProcessInfo.processInfo.environment["PCLMAC_\(key)"] ?? secrets?[key] {
            return secret
        }
        return nil
    }
}
