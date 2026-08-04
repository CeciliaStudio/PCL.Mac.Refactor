//
//  DownloadSource.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/7/5.
//

import Foundation

public struct DownloadCandidate: Hashable {
    public let url: URL
    public let headers: [String: String]?

    public init(url: URL, headers: [String: String]? = nil) {
        self.url = url
        self.headers = headers
    }
}

public protocol DownloadSource {
    /// 版本清单 URL。
    func versionManifestURL() -> URL?
    /// Forge 版本列表 URL。
    func forgeVersionListURL(for minecraftVersion: String) -> URL?
    /// NeoForge 版本列表 URL。
    func neoforgeVersionListURL(for minecraftVersion: String) -> URL?
    /// Fabric 版本列表 URL。
    func fabricVersionListURL(for minecraftVersion: String) -> URL?

    /// 为指定 URL 生成在该下载源下的下载候选项。
    func candidate(for url: URL) -> DownloadCandidate?
}

/// 官方下载源，在中国大陆地区可能不稳定。
public struct OfficialDownloadSource: DownloadSource {
    public static let shared: OfficialDownloadSource = .init()

    public var curseforgeApiKey: String?

    public func versionManifestURL() -> URL? {
        URL(string: "https://launchermeta.mojang.com/mc/game/version_manifest.json")
    }

    public func forgeVersionListURL(for minecraftVersion: String) -> URL? { nil }

    public func neoforgeVersionListURL(for minecraftVersion: String) -> URL? { nil }

    public func fabricVersionListURL(for minecraftVersion: String) -> URL? {
        URL(string: "https://meta.fabricmc.net/v2/versions/loader/\(minecraftVersion)")
    }

    public func candidate(for url: URL) -> DownloadCandidate? {
        var headers: [String: String]? = nil
        if url.matches(hosts: "edge.forgecdn.net"), let key = curseforgeApiKey {
            headers = ["x-api-key": key]
        }
        return DownloadCandidate(url: url, headers: headers)
    }
}

/// BMCLAPI / MCIM 中国镜像下载源。
public struct MirrorDownloadSource: DownloadSource {
    public static let shared: MirrorDownloadSource = .init()

    private let bmclapiBaseURL = URL(string: "https://bmclapi2.bangbang93.com")!
    private let mcimBaseURL = URL(string: "https://mod.mcimirror.top")!

    public func versionManifestURL() -> URL? {
        bmclapiBaseURL.appending(path: "mc/game/version_manifest.json")
    }

    public func forgeVersionListURL(for minecraftVersion: String) -> URL? {
        bmclapiBaseURL.appending(path: "forge/minecraft/\(minecraftVersion)")
    }

    public func neoforgeVersionListURL(for minecraftVersion: String) -> URL? {
        bmclapiBaseURL.appending(path: "neoforge/list/\(minecraftVersion)")
    }

    public func fabricVersionListURL(for minecraftVersion: String) -> URL? {
        bmclapiBaseURL.appending(path: "fabric-meta/v2/versions/loader/\(minecraftVersion)")
    }

    public func candidate(for url: URL) -> DownloadCandidate? {
        return mirrorURL(for: url).map { DownloadCandidate(url: $0) }
    }
    

    private func mirrorURL(for url: URL) -> URL? {
        if url.matches(hosts: "piston-meta.mojang.com", "piston-data.mojang.com",
                       "launchermeta.mojang.com", "launcher.mojang.com") {
            return bmclapiBaseURL.appending(path: url.path)
        }
        
        if url.matches(hosts: "resources.download.minecraft.net") {
            return bmclapiBaseURL.appending(path: "assets").appending(path: url.path)
        }
        
        if url.matches(
            prefixes: "files.minecraftforge.net/maven", "maven.neoforged.net/releases",
            hosts: "libraries.minecraft.net", "maven.fabricmc.net", "maven.minecraftforge.net"
        ) {
            return bmclapiBaseURL.appending(path: "maven").appending(path: resolveMavenPath(url))
        }
        
        if url.matches(hosts: "meta.fabricmc.net") {
            return bmclapiBaseURL.appending(path: "fabric-meta").appending(path: url.path)
        }

        if url.matches(hosts: "cdn.modrinth.com", "edge.forgecdn.net") {
            return mcimBaseURL.appending(path: url.path)
        }

        return nil
    }

    private func resolveMavenPath(_ url: URL) -> String {
        if url.pathComponents.count == 0 { return "" }
        var pathComponents = url.pathComponents
        if pathComponents[0] == "/" { pathComponents.removeFirst() }
        
        let prefix = pathComponents.first
        if prefix == "maven" || prefix == "releases" {
            return pathComponents.dropFirst().joined(separator: "/")
        }
        return url.path
    }
}


private extension URL {
    func matches(prefixes: String..., hosts: String...) -> Bool {
        guard let scheme, let host else { return false }
        let urlWithoutScheme = absoluteString.dropFirst(scheme.count + "://".count)
        return hosts.contains(host) || prefixes.contains(where: { urlWithoutScheme.hasPrefix($0) })
    }
}
