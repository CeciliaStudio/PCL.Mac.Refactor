//
//  DownloadTests.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/24.
//

import Testing
import Foundation
import Core
import SwiftyJSON

struct DownloadTests {
    @Test func singleFileDownloadTest() async throws {
        let item: DownloadItem = .init(
            url: URL(string: "https://piston-meta.mojang.com/v1/packages/b8ac7ed26100bd79830df1de207fbeefe7fab62f/1.21.10.json")!,
            destination: URLConstants.tempURL.appending(path: "singleFileDownloadTest"),
            sha1: "b8ac7ed26100bd79830df1de207fbeefe7fab62f"
        )
        
        try await FileDownloader.shared.download(item)
        
        await #expect(throws: DownloadError.checksumMismatch) {
            try await FileDownloader.shared.download(
                .init(
                    url: item.url,
                    destination: item.destination,
                    sha1: "da39a3ee5e6b4b0d3255bfef95601890afd80709"
                )
            )
        }
        
        await #expect(throws: DownloadError.badStatusCode(code: 404)) {
            try await FileDownloader.shared.download(
                .init(
                    url: URL(string: "https://bmclapi2.bangbang93.com/version/11.45.14/json")!,
                    destination: item.destination,
                    sha1: nil
                )
            )
        }
    }
    
    @Test func multiFileDownloadTest() async throws {
        if ProcessInfo.processInfo.environment["GITHUB_ENV"] != nil {
            print("当前环境为 GitHub Actions，跳过多文件下载测试")
            return
        }
        let data: Data = try await URLSession.shared.data(from: URL(string: "https://piston-meta.mojang.com/v1/packages/48fc0ab195b88bc562d672cdcf7997de42fe9d51/27.json").unwrap()).0
        let assetIndex: AssetIndex = try JSONDecoder.shared.decode(AssetIndex.self, from: data)
        let tempDirectory: URL = URLConstants.tempURL.appending(path: "multiFileDownloadTest")
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: false)
        let root: URL = try URL(string: "https://resources.download.minecraft.net").unwrap()
        let items: [DownloadItem] = assetIndex.objects.map { .init(
            url: root.appending(path: "\($0.hash.prefix(2))/\($0.hash)"), destination: tempDirectory.appending(path: $0.hash), sha1: $0.hash)
        }
        try await FileDownloader.shared.download(files: Array(items.prefix(128))) { print($0 * 100) }
        try FileManager.default.removeItem(at: tempDirectory)
    }
    
    @Test func mirrorURLTest() {
        let bmclapiRoot = URL(string: "https://bmclapi2.bangbang93.com/")!
        let bmclapiMavenRoot = bmclapiRoot.appending(path: "maven")
        
        let mojangMetaRoot = URL(string: "https://piston-meta.mojang.com/")!
        let mojangDataRoot = URL(string: "https://piston-data.mojang.com/")!
        
        let forgeMavenRoot = URL(string: "https://files.minecraftforge.net/maven")!
        
        let manifestPath = "v1/packages/3457237902814cca3f5c6f20b0c5db1b1f341512/26.2.json"
        #expect(MirrorDownloadSource.shared.candidate(for: mojangMetaRoot.appending(path: manifestPath))?.url
                == bmclapiRoot.appending(path: manifestPath))
        
        let jarPath = "v1/objects/2dc72797acbc1b63fc16a11c4ac393605f453754/client.jar"
        #expect(MirrorDownloadSource.shared.candidate(for: mojangDataRoot.appending(path: jarPath))?.url
                == bmclapiRoot.appending(path: jarPath))
        
        let installerPath = "net/minecraftforge/forge/1.20.1-47.4.22/forge-1.20.1-47.4.22-installer.jar"
        #expect(MirrorDownloadSource.shared.candidate(for: forgeMavenRoot.appending(path: installerPath))?.url
                == bmclapiMavenRoot.appending(path: installerPath))
        
        #expect(MirrorDownloadSource.shared.candidate(for: URL(string: "https://libraries.minecraft.net/")!)?.url == bmclapiMavenRoot)
    }
}
