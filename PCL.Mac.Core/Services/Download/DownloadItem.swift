//
//  DownloadItem.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/22.
//

import Foundation

public struct DownloadItem: Hashable {
    public let urls: [URL]
    public let destination: URL
    public let checksums: [String: String]?
    public let executable: Bool
    
    public var url: URL { urls.first! }
    
    public init(urls: [URL], destination: URL, checksums: [String: String]?, executable: Bool = false) {
        guard !urls.isEmpty else {
            preconditionFailure("At least one URL must be provided for download.")
        }
        
        self.urls = urls
        self.destination = destination
        self.checksums = checksums
        self.executable = executable
    }
    
    public init(url: URL, destination: URL, checksums: [String: String]?, executable: Bool = false) {
        self.init(
            urls: [url],
            destination: destination,
            checksums: checksums,
            executable: executable
        )
    }
    
    public init(url: URL, destination: URL, sha1: String?, executable: Bool = false) {
        self.init(
            urls: [url],
            destination: destination,
            checksums: sha1.map { ["sha1": $0] },
            executable: executable
        )
    }
}

public enum ReplaceMethod {
    case replace, skip, `throw`
}
