//
//  CurseForgeAPIClientTests.swift
//  PCL.Mac.Tests
//

import Foundation
import Core
import Testing

struct CurseForgeAPIClientTests {
    @Test func decodesSearchResponse() throws {
        let json = """
        {
          "data": [{
            "id": 238222,
            "slug": "jei",
            "name": "Just Enough Items",
            "summary": "View items and recipes",
            "classId": 6,
            "downloadCount": 1000,
            "dateModified": "2026-08-20T10:00:00Z",
            "logo": null,
            "categories": [{"name": "Map and Information"}],
            "latestFiles": []
          }],
          "pagination": {"index": 0, "pageSize": 40, "resultCount": 1, "totalCount": 10}
        }
        """

        let response = try JSONDecoder.shared.decode(
            CurseForgeAPIClient.SearchResponse.self,
            from: Data(json.utf8)
        )

        #expect(response.hits.count == 1)
        #expect(response.hits[0].projectType == .mod)
        #expect(response.hits[0].categories == ["Map and Information"])
        #expect(response.totalHits == 10)
    }

    @Test func buildsFallbackDownloadURLAndChecksums() throws {
        let json = """
        {
          "id": 1234567,
          "modId": 238222,
          "isAvailable": true,
          "fileName": "example mod.jar",
          "displayName": "Example Mod",
          "fileDate": "2026-08-20T10:00:00Z",
          "downloadCount": 25,
          "gameVersions": ["1.21.1", "NeoForge"],
          "modLoaderType": 6,
          "releaseType": 1,
          "hashes": [{"value": "abc", "algo": 1}],
          "downloadUrl": null
        }
        """

        let file = try JSONDecoder.shared.decode(CurseForgeModFile.self, from: Data(json.utf8))

        #expect(file.downloadURL.absoluteString.contains("/files/1234/567/"))
        #expect(file.checksums["sha1"] == "abc")
        #expect(file.modLoaderType == 6)
    }
}
