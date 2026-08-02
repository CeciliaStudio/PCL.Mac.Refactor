//
//  JavaInstallTask.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/11.
//

import Foundation

public enum JavaInstallTask {
    public static func create(
        download: MojangJavaList.JavaDownload
    ) -> MyTask<Model> {
        let tempDirectory: URL = URLConstants.tempURL.appending(path: "JavaInstall-\(UUID().uuidString)")
        let bundleDestination: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Java/JavaVirtualMachines/mojang-\(download.version).bundle")
        return .init(
            name: "Java 安装 - \(download.version)", model: .init(),
            .init(0, "获取 Java 清单") { _, model in
                if FileManager.default.fileExists(atPath: bundleDestination.path) {
                    throw SimpleError("已存在版本相同的 Mojang Java！")
                }
                model.manifest = try await HTTPClient.shared.get(download.manifestURL).decode(MojangJavaManifest.self)
            },
            .init(1, "下载文件") { task, model in
                try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                var downloadItems: [DownloadItem] = []
                for (path, file) in model.manifest.files {
                    switch file {
                    case .directory:
                        try FileManager.default.createDirectory(at: tempDirectory.appending(path: path), withIntermediateDirectories: true)
                    case .file(let url, let sha1, _, let executable):
                        downloadItems.append(.init(url: url, destination: tempDirectory.appending(path: path), sha1: sha1, executable: executable))
                    case .link(let target):
                        let parent: URL = tempDirectory.appending(path: path).deletingLastPathComponent()
                        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                        try FileManager.default.createSymbolicLink(at: tempDirectory.appending(path: path), withDestinationURL: parent.appending(path: target).standardized)
                    }
                }
                try await FileDownloader.shared.download(files: downloadItems, progressHandler: task.setProgress(_:))
            },
            .init(2, "__completion", display: false) { _, model in
                let bundleRoot: URL = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)[0]
                try FileManager.default.createDirectory(at: bundleDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: bundleRoot, to: bundleDestination)
                try await JavaManager.shared.research()
            }
        ) { _ in
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    public class Model: TaskModel {
        public var manifest: MojangJavaManifest!
        
        public init() {}
    }
}
