//
//  ProjectListItemModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/18.
//

import Foundation
import Core

struct ProjectListItemModel: Identifiable, Equatable, Hashable {
    enum Source: Hashable {
        case modrinth
        case curseforge
    }

    public let id: String
    public let source: Source
    public let curseforgeId: Int?
    public let curseforgeSlug: String?
    public let title: String
    public let description: String
    public let type: ResourceType
    public let iconURL: URL?
    public let tags: [String]
    public let supportDescription: String
    public let onlySupportsSnapshot: Bool
    public let downloads: String
    public let lastUpdate: String
    
    public init(id: String, title: String, description: String, type: ResourceType, iconURL: URL?, tags: [String], supportDescription: String, onlySupportsSnapshot: Bool, downloads: String, lastUpdate: String) {
        self.id = id
        self.source = .modrinth
        self.curseforgeId = nil
        self.curseforgeSlug = nil
        self.title = title
        self.description = description
        self.type = type
        self.iconURL = iconURL
        self.tags = tags
        self.supportDescription = supportDescription
        self.onlySupportsSnapshot = onlySupportsSnapshot
        self.downloads = downloads
        self.lastUpdate = lastUpdate
    }

    init(_ project: CurseForgeMod) {
        let versions = Set(project.latestFiles.flatMap { $0.gameVersions }.filter { $0.contains(".") })
        self.id = "curseforge:\(project.id)"
        self.source = .curseforge
        self.curseforgeId = Int(project.id)
        self.curseforgeSlug = project.slug
        self.title = project.name
        self.description = project.summary
        self.type = project.projectType ?? .mod
        self.iconURL = project.logo?.thumbnailURL
        self.tags = project.categories.map { $0 }
        self.supportDescription = versions.sorted().reversed().prefix(3).joined(separator: ", ")
        self.onlySupportsSnapshot = false
        self.downloads = Self.formatDownloads(project.downloadCount)
        self.lastUpdate = Self.formatLastUpdate(project.dateModified)
    }
    
    public init(_ project: ModrinthProject) {
        let (supportDescription, onlySupportsSnapshot) = Self.generateSupportDescription(for: project)
        
        self.init(
            id: project.id,
            title: project.title,
            description: project.description,
            type: project.type,
            iconURL: project.iconURL,
            tags: project.categories.compactMap(Self.localizeTag(_:)),
            supportDescription: supportDescription,
            onlySupportsSnapshot: onlySupportsSnapshot,
            downloads: Self.formatDownloads(project.downloads),
            lastUpdate: Self.formatLastUpdate(project.lastUpdate)
        )
    }
    
    public static func formatLastUpdate(_ lastUpdate: Date) -> String {
        let formatter: RelativeDateTimeFormatter = .init()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastUpdate, relativeTo: Date())
            .replacingOccurrences(of: "(\\d+)", with: " $1 ", options: .regularExpression)
    }
    
    public static func formatDownloads(_ downloads: Int) -> String {
        if downloads > 10000 * 10000 {
            return String(format: "%.2f 亿", Double(downloads) / 10000 / 10000)
        } else if downloads > 10000 {
            return "\(downloads / 10000) 万"
        } else {
            return downloads.description
        }
    }
    
    public static func localizeTag(_ key: String) -> String? {
        let key = "category.modrinth.\(key)"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? nil : localized
    }
    
    private static func generateSupportDescription(for project: ModrinthProject) -> (String, Bool) {
        guard let versionManifest = VersionManifest.shared else { return ("", false) }
        
        var description: String = ""
        
        let modLoaders: [ModLoader] = project.categories.compactMap(ModLoader.init(rawValue:))
        if modLoaders.count == 1 {
            description += "仅 \(modLoaders.first!.description)"
        } else if modLoaders.count < 3 {
            description += modLoaders.map(\.description).joined(separator: " / ")
        }
        if !description.isEmpty { description += " " }
        
        guard let gameVersions = project.gameVersions else {
            return (description + "未知", false)
        }
        let releaseVersions: [String] = gameVersions.filter { versionManifest.version(for: $0)?.type == .release }
        guard !releaseVersions.isEmpty else {
            return (description + (modLoaders.count == 1 ? "" : "仅") + "快照版本", true)
        }
        description += generateGameVersionDescription(releaseVersions, latestVersion: versionManifest.latestRelease)
        
        return (description, false)
    }
    
    private static func generateGameVersionDescription(_ gameVersions: [String], latestVersion: String) -> String {
        guard gameVersions.count > 1 else {
            return gameVersions.isEmpty ? "" : gameVersions[0]
        }
        guard let latestPair: VersionPair = .init(latestVersion) else {
            return "错误"
        }
        
        func rangeDescription(start: VersionPair, end: VersionPair) -> String {
            if start == end {
                return start.description
            } else if end == latestPair {
                return "\(start)+"
            } else {
                return "\(start)~\(end)"
            }
        }
        
        let versionPairs: [VersionPair] = Array(Set(gameVersions.compactMap(VersionPair.init))).sorted()
        
        var ranges: [String] = []
        var start: VersionPair = versionPairs[0]
        var end: VersionPair = start
        for pair in versionPairs.dropFirst() {
            if pair.isNext(to: end) {
                end = pair
            } else {
                ranges.append(rangeDescription(start: start, end: end))
                start = pair
                end = pair
            }
        }
        ranges.append(rangeDescription(start: start, end: end))
        return ranges.reversed().joined(separator: ", ")
    }
    
    private struct VersionPair: Hashable, Equatable, Comparable, CustomStringConvertible {
        public let major: Int
        public let minor: Int
        private let rawVersion: String
        
        public init?(_ version: String) {
            let parts: [Int] = version.split(separator: ".").compactMap { Int($0) }
            guard parts.count >= 2 else { return nil }
            self.major = parts[0]
            self.minor = parts[1]
            self.rawVersion = version
        }
        
        public func isNext(to another: VersionPair) -> Bool {
            if self == another { return false }
            // 确保版本号格式相同
            if (self.major == 1 && another.major != 1) || (another.major == 1 && self.major != 1) {
                let boundaryVersions: [String] = ["1.21", "26.1"]
                return boundaryVersions.contains(self.rawVersion) && boundaryVersions.contains(another.rawVersion)
            }
            
            if self.major == another.major {
                return abs(self.minor - another.minor) == 1
            } else {
                if self.minor == 1 {
                    return another.major == self.major - 1 && another.isYearlyLatest()
                } else if another.minor == 1 {
                    return self.major == another.major - 1 && self.isYearlyLatest()
                } else {
                    return false
                }
            }
        }
        
        /// 检查当前版本是不是该年份（26）的最后一个版本（正式更新，例如 26.4）。
        /// 在该版本号的格式为旧版格式时，此函数一定会返回 `false`。
        public func isYearlyLatest() -> Bool {
            guard let manifest = VersionManifest.shared else { return false }
            if major == 1 { return false }
            let yearlyLatest: VersionPair? = manifest.versions
                .filter { $0.type == .release && $0.id.starts(with: "\(major).") }
                .first.flatMap { VersionPair($0.id) }
            return self == yearlyLatest
            
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(major)
            hasher.combine(minor)
            // 忽略 rawVersion
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.major == rhs.major && lhs.minor == rhs.minor // 忽略 rawVersion
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.major != rhs.major {
                return lhs.major < rhs.major
            }
            return lhs.minor < rhs.minor
        }
        
        public var description: String {
            "\(major).\(minor)"
        }
    }
}
