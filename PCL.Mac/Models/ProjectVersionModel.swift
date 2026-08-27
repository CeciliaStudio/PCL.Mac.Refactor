//
//  ProjectVersionModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/19.
//

import Foundation
import Core

struct ProjectVersionModel: Identifiable {
    struct Dependency: Identifiable {
        public let id: UUID = .init()
        public let versionId: String?
        public let projectId: String
        public let project: ProjectListItemModel
    }
    
    public let id: String
    public let source: ProjectListItemModel.Source
    public let name: String
    public let version: String
    public let downloads: String
    public let datePublished: String
    public let requiredDependencies: [Dependency]
    public let type: ModrinthVersion.VersionType
    public let primaryFile: ModrinthVersion.File?
    public let curseforgeFile: CurseForgeModFile?
    public let gameVersion: String
    public let loader: ModLoader?

    init(
        id: String,
        name: String,
        version: String,
        downloads: String,
        datePublished: String,
        requiredDependencies: [Dependency],
        type: ModrinthVersion.VersionType,
        primaryFile: ModrinthVersion.File?,
        gameVersion: String,
        loader: ModLoader?
    ) {
        self.id = id
        self.source = .modrinth
        self.name = name
        self.version = version
        self.downloads = downloads
        self.datePublished = datePublished
        self.requiredDependencies = requiredDependencies
        self.type = type
        self.primaryFile = primaryFile
        self.curseforgeFile = nil
        self.gameVersion = gameVersion
        self.loader = loader
    }

    init(
        id: String,
        name: String,
        version: String,
        downloads: String,
        datePublished: String,
        type: ModrinthVersion.VersionType,
        curseforgeFile: CurseForgeModFile,
        requiredDependencies: [Dependency] = [],
        gameVersion: String,
        loader: ModLoader?,
        source: ProjectListItemModel.Source = .curseforge
    ) {
        self.id = id
        self.source = source
        self.name = name
        self.version = version
        self.downloads = downloads
        self.datePublished = datePublished
        self.requiredDependencies = requiredDependencies
        self.type = type
        self.primaryFile = nil
        self.curseforgeFile = curseforgeFile
        self.gameVersion = gameVersion
        self.loader = loader
    }
}
