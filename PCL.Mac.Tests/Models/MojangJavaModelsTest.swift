//
//  MojangJavaModelsTest.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/11.
//

import Foundation
import Testing
import Core

struct MojangJavaModelsTest {
    @Test func testParse() async throws {
        let javaList: MojangJavaList = try await HTTPClient.shared.get("https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json").decode(MojangJavaList.self)
        guard let entryURL: URL = javaList.entries["mac-os-arm64"]?["java-runtime-epsilon"]?.first?.manifestURL else {
            assertionFailure()
            return
        }
        _ = try await HTTPClient.shared.get(entryURL).decode(MojangJavaManifest.self)
    }
}
