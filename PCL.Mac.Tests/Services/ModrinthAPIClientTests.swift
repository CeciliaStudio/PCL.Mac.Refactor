//
//  ModrinthAPIClientTests.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/16.
//

import Foundation
import Core
import Testing

struct ModrinthAPIClientTests {
    @Test func test() async throws {
        let response: ModrinthAPIClient.SearchResponse = try await ModrinthAPIClient.shared.search(type: .mod, "Tweakeroo", forVersion: nil)
        print("Total hits: \(response.totalHits), limit: \(response.limit)")
        for hit in response.hits {
            print(hit.title)
        }
        
        _ = try await ModrinthAPIClient.shared.search(type: .mod, "Fabric API", forVersion: "1.21.11")
        _ = try await ModrinthAPIClient.shared.search(type: .mod, "", forVersion: nil)
        
        let sodium: ModrinthProject = try await ModrinthAPIClient.shared.project("sodium").unwrap()
        print(sodium)
        _ = try await ModrinthAPIClient.shared.versions(ofProject: sodium)
        let version: ModrinthVersion = try await ModrinthAPIClient.shared.version(sodium.versions![0]).unwrap()
        print(version)
        
        let hashes: [String] = [
            "666a30970020ff45f90cd7c96781e62ca99193ae",
            "12b1c41872fea2287793bbcae3b1f73c212d76eb",
            "55994722875c4b071b31dcb6f3c9cba8818f3391"
        ]
        #expect(try await ModrinthAPIClient.shared.version(ofHash: hashes[0])?.projectId == "P7dR8mSH")
        #expect(try await ModrinthAPIClient.shared.version(ofHash: "5e1fc24d2b9c3bf9343afa0509382bc377c350c0") == nil)
        _ = try await ModrinthAPIClient.shared.versions(ofHashes: hashes)
    }
}
