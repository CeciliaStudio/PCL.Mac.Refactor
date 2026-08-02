//
//  VersionManifest.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/12/2.
//

import Foundation
import SwiftyJSON

/// https://zh.minecraft.wiki/w/Version_manifest.json#JSON格式
public struct VersionManifest: Decodable, Equatable {
    public static var shared: VersionManifest?
    public let latestRelease: String
    public let latestSnapshot: String?
    public let versions: [Version]
    private let versionMap: [String: Version]
    
    private enum CodingKeys: String, CodingKey {
        case latest, versions
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latest: Latest = try container.decode(Latest.self, forKey: .latest)
        self.latestRelease = latest.release
        self.latestSnapshot = latest.release == latest.snapshot ? nil : latest.snapshot
        self.versions = try container.decode([Version].self, forKey: .versions)
        self.versionMap = versions.reduce(into: [:]) { $0[$1.id] = $1 }
    }
    
    public struct Version: Decodable, Hashable {
        private static let aprilFoolVersions: [String] = ["15w14a", "1.rv-pre1", "3d shareware v1.34", "20w14infinite", "22w13oneblockatatime", "23w13a_or_b", "24w14potato", "25w14craftmine"]
        private static let calendar: Calendar? = {
            var calendar: Calendar = .init(identifier: .gregorian)
            guard let timeZome: TimeZone = .init(identifier: "Europe/Stockholm") else {
                err("创建 Europe/Stockholm 时区失败")
                return nil
            }
            calendar.timeZone = timeZome
            return calendar
        }()
        
        public let id: String
        public let type: MinecraftVersion.VersionType
        public let url: URL
        public let time: Date
        public let releaseTime: Date
        
        private enum CodingKeys: CodingKey {
            case id, type, url, time, releaseTime
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(String.self, forKey: .id)
                .replacingOccurrences(of: " Pre-Release ", with: "-pre")
            self.releaseTime = try container.decode(Date.self, forKey: .releaseTime)
            var type: MinecraftVersion.VersionType = try container.decode(MinecraftVersion.VersionType.self, forKey: .type)
            if type == .snapshot && Self.isAprilFoolVersion(id: id, releaseTime: releaseTime) {
                type = .aprilFool
            }
            self.type = type
            self.url = try container.decode(URL.self, forKey: .url)
            self.time = try container.decode(Date.self, forKey: .time)
        }
        
        private static func isAprilFoolVersion(id: String, releaseTime: Date) -> Bool {
            if aprilFoolVersions.contains(id.lowercased()) { return true }
            
            if let calendar {
                let components: DateComponents = calendar.dateComponents([.month, .day], from: releaseTime)
                if let month = components.month, let day = components.day {
                    return month == 4 && day == 1
                }
            }
            
            return !(id.count == 6 && Array(id)[2] == "w" && !id.starts(with: "26")) // 不是标准快照版本号格式 (如 23w33a)
            && id.rangeOfCharacter(from: .letters) != nil // 至少有一个字母 (筛掉 1.x 与 1.x.x)
            && !id.contains("-pre") && !id.contains("-rc") // 不是 Pre Release 或 Release Candidate
            && !id.contains("snapshot") // 不是新版本号格式的快照（如 26.1-snapshot-1）
        }
    }
    
    /// 获取版本号对应的 `Version` 对象。
    /// - Parameter id: 版本号。
    /// - Returns: `Version` 对象。
    public func version(for id: String) -> Version? { versionMap[id] }
    
    /// 获取版本清单中是否包含带有指定 `id` 的版本。
    public func contains(_ id: String) -> Bool { versionMap[id] != nil }
    
    // MARK: - Decodables
    
    private struct Latest: Decodable {
        public let release: String
        public let snapshot: String
    }
}

public extension VersionManifest {
    @discardableResult
    static func load(revalidate: Bool = false) async throws -> VersionManifest {
        let cacheURL = URLConstants.cacheURL.appending(path: "version_manifest.json")
        let url = DownloadSourceManager.shared.versionManifestURL()!

        let response = try await HTTPClient.shared.get(url, revalidate: revalidate)
        let manifest = try response.decode(VersionManifest.self)
        if Self.shared == nil || Self.shared != manifest {
            log("刷新版本清单成功")
            Self.shared = manifest
            do {
                try response.data.write(to: cacheURL)
            } catch {
                err("保存版本列表缓存失败：\(error.localizedDescription)")
            }
        }
        return manifest
    }
}
