//
//  CurseForgeMod.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/5/4.
//

import Foundation

public struct CurseForgeMod: Codable {
    public let id: Int32
    public let slug: String?
    public let name: String
    public let summary: String
    public let logo: CurseForgeModAsset?
    public let classId: Int?
    public let downloadCount: Int
    public let dateModified: Date
    public let categories: [String]
    public let latestFiles: [CurseForgeModFile]

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, summary, logo, classId, downloadCount, dateModified, categories, latestFiles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int32.self, forKey: .id)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        logo = try container.decodeIfPresent(CurseForgeModAsset.self, forKey: .logo)
        classId = try container.decodeIfPresent(Int.self, forKey: .classId)
        downloadCount = try container.decodeIfPresent(Int.self, forKey: .downloadCount) ?? 0
        if let value = try container.decodeIfPresent(String.self, forKey: .dateModified) {
            dateModified = Self.parseDate(value) ?? .distantPast
        } else {
            dateModified = .distantPast
        }
        categories = try container.decodeIfPresent([CurseForgeCategory].self, forKey: .categories)?.map(\.name) ?? []
        latestFiles = try container.decodeIfPresent([CurseForgeModFile].self, forKey: .latestFiles) ?? []
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
    
    public var projectType: ResourceType? {
        switch classId {
        case 12: .resourcepack
        case 6: .mod
        case 4471: .modpack
        case 6552: .shader
        default: nil
        }
    }
}

public struct CurseForgeCategory: Codable {
    public let name: String
}

public struct CurseForgeModAsset: Codable {
    public let id: Int32
    public let title: String
    public let url: URL?
    public let thumbnailURL: URL?
    
    private enum CodingKeys: String, CodingKey {
        case id, title, url, thumbnailURL = "thumbnailUrl"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int32.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try? container.decode(URL.self, forKey: .url)
        self.thumbnailURL = try? container.decode(URL.self, forKey: .thumbnailURL)
    }
}

public struct CurseForgeModFile: Codable {
    public struct FileHash: Codable {
        public let value: String
        public let algo: Int
    }

    public struct Dependency: Codable {
        public let modId: Int
        public let relationType: Int

        public var isRequired: Bool { relationType == 3 }
    }
    
    public let id: Int32
    public let modId: Int32
    public let available: Bool
    public let fileName: String
    public let displayName: String
    public let fileDate: Date
    public let downloadCount: Int
    public let gameVersions: [String]
    public let modLoaderType: Int?
    public let releaseType: Int
    public let dependencies: [Dependency]
    public let hashes: [FileHash]
    public let downloadURL: URL
    
    public var checksums: [String: String] {
        return hashes.reduce(into: [:]) { result, hash in
            switch hash.algo {
            case 1: result["sha1"] = hash.value
            case 2: result["md5"] = hash.value
            default: break
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, modId, fileName, displayName, fileDate, downloadCount, gameVersions, modLoaderType, releaseType, dependencies, hashes
        case available = "isAvailable", downloadURL = "downloadUrl"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int32.self, forKey: .id)
        self.modId = try container.decode(Int32.self, forKey: .modId)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? fileName
        self.fileDate = Self.parseDate(try container.decodeIfPresent(String.self, forKey: .fileDate)) ?? .distantPast
        self.downloadCount = try container.decodeIfPresent(Int.self, forKey: .downloadCount) ?? 0
        self.gameVersions = try container.decodeIfPresent([String].self, forKey: .gameVersions) ?? []
        self.modLoaderType = try container.decodeIfPresent(Int.self, forKey: .modLoaderType)
        self.releaseType = try container.decodeIfPresent(Int.self, forKey: .releaseType) ?? 1
        self.dependencies = try container.decodeIfPresent([Dependency].self, forKey: .dependencies) ?? []
        self.hashes = try container.decodeIfPresent([CurseForgeModFile.FileHash].self, forKey: .hashes) ?? []
        self.available = try container.decodeIfPresent(Bool.self, forKey: .available) ?? true
        self.downloadURL = try container.decodeIfPresent(URL.self, forKey: .downloadURL) ?? .init(string: "https://edge.forgecdn.net/files/\(id / 1000)/\(id % 1000)/\(fileName)")!
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
}
