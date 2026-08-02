//
//  UpdateManager.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/26.
//

import Foundation
import AppKit
import Core
import ZIPFoundation

class UpdateManager {
    public static let shared: UpdateManager = .init(URL(string: "https://cylorine.studio/meta/PCL.Mac/update.json")!)
    
    private let updateMetadataURL: URL
    
    private init(_ updateMetadataURL: URL) {
        self.updateMetadataURL = updateMetadataURL
    }
    
    public func checkUpdates() async throws -> UpdateModel.Version? {
        if Metadata.debugMode || Metadata.bundleVersion == 0 { return nil }
        let model: UpdateModel = try await HTTPClient.shared.get(updateMetadataURL, revalidate: true).decode(UpdateModel.self)
        return Metadata.bundleVersion >= model.latestVersion.bundleVersion ? nil : model.latestVersion
    }
    
    public func installUpdate(_ version: UpdateModel.Version, useMirror: Bool = true) async throws {
        let destination: URL = URLConstants.tempURL.appending(path: "launcher-update-\(version.bundleVersion)")
        let downloadItem: DownloadItem = .init(
            url: useMirror ? version.downloads.mirror : version.downloads.github,
            destination: destination,
            sha1: version.downloads.sha1
        )
        defer { try? FileManager.default.removeItem(at: destination) }
        try await FileDownloader.shared.download(downloadItem)
        try FileManager.default.unzipItem(at: destination, to: destination.deletingLastPathComponent())
        let newBundle: URL = URLConstants.tempURL.appending(path: "PCL.Mac.app")
        if !FileManager.default.fileExists(atPath: newBundle.path) {
            throw SimpleError("更新包格式错误，请手动安装更新。")
        }
        _ = try FileManager.default.replaceItemAt(
            Bundle.main.bundleURL,
            withItemAt: newBundle,
            backupItemName: "PCL.Mac.app.backup",
            options: [.usingNewMetadataOnly]
        )
        
        log("App Bundle 替换完成，正在重启")
        // 使用 /usr/bin/open 延迟开启新进程，确保同时只有一个进程存在
        let process: Process = .init()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        try process.run()
        await NSApplication.shared.terminate(nil)
    }
}
