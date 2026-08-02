//
//  MinecraftVersionTests.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/24.
//

import Testing
import Foundation
import Core

struct MinecraftVersionTests {
    @Test func test() async throws {
        VersionManifest.shared = try await HTTPClient.shared.get("https://launchermeta.mojang.com/mc/game/version_manifest.json").decode(VersionManifest.self)
        #expect(MinecraftVersion("1.21.10") == MinecraftVersion("1.21.10"))
        #expect(MinecraftVersion("1.21.10") < MinecraftVersion("1.21.11-pre2"))
        #expect(MinecraftVersion("1.21") > MinecraftVersion("1.20.6"))
    }
}
