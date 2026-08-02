//
//  CurseForgeAPIClient.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/5/4.
//

import Foundation
import SwiftyJSON

public class CurseForgeAPIClient {
    private let semaphore: AsyncSemaphore = .init(value: 8)
    private let apiRoot: URL
    private let apiKey: String
    
    public init(apiRoot: URL = .init(string: "https://api.curseforge.com")!, apiKey: String) {
        self.apiRoot = apiRoot
        self.apiKey = apiKey
    }
    
    public func mod(id modId: Int) async throws -> CurseForgeMod? {
        let response = try await request("/v1/mods/\(modId)")
        if response.statusCode == 404 { return nil }
        return try response.decode(Response<CurseForgeMod>.self).data
    }
    
    public func modFile(modId: Int, fileId: Int) async throws -> CurseForgeModFile? {
        let response = try await request("/v1/mods/\(modId)/files/\(fileId)")
        if response.statusCode == 404 { return nil }
        return try response.decode(Response<CurseForgeModFile>.self).data
    }
    
    private func request(
        _ path: String,
        method: String = "GET",
        headers: [String: String?] = [:],
        body: [String: Any]? = nil
    ) async throws -> HTTPClient.Response {
        await semaphore.wait()
        defer { Task { await semaphore.signal() } }
        var headers: [String: String?] = headers
        headers["x-api-key"] = apiKey
        
        let response = try await HTTPClient.shared.request(
            url: apiRoot.appending(path: path),
            method: method,
            headers: headers,
            body: body,
            revalidate: true,
            timeout: 30
        )
        
        return response
    }
    
    public struct Response<Body: Codable>: Codable {
        public let data: Body
    }
}
