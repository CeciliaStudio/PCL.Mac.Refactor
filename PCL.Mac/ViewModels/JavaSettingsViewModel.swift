//
//  JavaSettingsViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/6.
//

import Foundation
import Core
import Combine

class JavaSettingsViewModel: ObservableObject {
    private static let javaDownloadIds: [String] = ["java-runtime-epsilon", "java-runtime-delta", "java-runtime-gamma"]
    private static let dateFormatter: DateFormatter = {
        let formatter: DateFormatter = .init()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()
    
    @Published public var javaList: [ListItem] = []
    
    private var cancellables: [AnyCancellable] = []
    
    init() {
        JavaManager.shared.$javaRuntimes
            .map { $0.sorted { $0.version > $1.version }.map { ListItem(name: $0.description, description: $0.executableURL.path) } }
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
}
