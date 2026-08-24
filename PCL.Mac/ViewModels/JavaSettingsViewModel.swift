//
//  JavaSettingsViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/6.
//

import Foundation
import Core
import Combine

@MainActor
class JavaSettingsViewModel: ObservableObject {
    private static let javaDownloadIds: [String] = ["java-runtime-epsilon", "java-runtime-delta", "java-runtime-gamma"]
    private static let dateFormatter: DateFormatter = {
        let formatter: DateFormatter = .init()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()
    
    @Published public var javaList: [JavaListItem] = []
    
    private var cancellables: [AnyCancellable] = []
    
    init() {
        JavaManager.shared.$javaRuntimes
            .map { $0.sorted { $0.version > $1.version }.map(JavaListItem.init) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.javaList, on: self)
            .store(in: &cancellables)
    }
    
    public func javaDownloads(forArchitecture architecture: Architecture = .systemArchitecture()) async throws -> [MojangJavaList.JavaDownload] {
        let list: MojangJavaList = try await HTTPClient.shared.get("https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json").decode(MojangJavaList.self)
        return (list.entries[architecture == .arm64 ? "mac-os-arm64" : "mac-os"] ?? [:])
            .map { ($0.key, $0.value) }
            .filter { Self.javaDownloadIds.contains($0.0) }
            .sorted(by: { (Self.javaDownloadIds.firstIndex(of: $0.0) ?? 0) < (Self.javaDownloadIds.firstIndex(of: $1.0) ?? 0) })
            .compactMap(\.1.first)
    }
    
    public func listItem(forJavaDownload javaDownload: MojangJavaList.JavaDownload) -> ListItem {
        return .init(name: javaDownload.version, description: "更新于 \(Self.dateFormatter.string(from: javaDownload.releaseTime))")
    }
    
    public func addCustomRuntime(at url: URL) throws -> JavaRuntime {
        let runtime: JavaRuntime
        do {
            runtime = try JavaSearcher.load(from: url, isCustom: true)
            if !JavaManager.shared.addCustomRuntime(runtime) {
                throw SimpleError("该 Java 已在 Java 列表中！")
            }
        } catch {
            err("添加 Java 失败：\(error)")
            throw error
        }
        
        LauncherConfig.shared.customJavaRuntimes.append(runtime.executableURL)
        return runtime
    }
    
    public func removeCustomRuntime(at url: URL) {
        JavaManager.shared.removeCustomRuntime(url)
        LauncherConfig.shared.customJavaRuntimes.removeAll(where: { $0 == url })
    }
    
    struct JavaListItem {
        let name: String
        let url: URL
        let isCustom: Bool
        
        init(_ javaRuntime: JavaRuntime) {
            self.name = javaRuntime.description
            self.url = javaRuntime.executableURL
            self.isCustom = javaRuntime.isCustom
        }
    }
}
