//
//  CLAPIClient.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/2/25.
//

import Foundation
import SwiftyJSON

public class CLAPIClient {
    public static let shared: CLAPIClient = .init()
    
    private let apiRoot: URL = .init(string: "https://api.cylorine.studio")!
    private let iso8601DateFormatter: ISO8601DateFormatter = .init()
    
    public func getCaveMessages() async throws -> [String] {
        try await get("/cave").arrayValue.map(\.stringValue)
    }
    
    public func getEasyTierStatus() async throws -> EasyTierStatus {
        let json: JSON = try await get("/easytier/status")
        if json["available"].boolValue {
            return .available
        } else {
            guard let date: Date = iso8601DateFormatter.date(from: json["time"].stringValue) else {
                throw Error.responseFormatError
            }
            return .unavailable(message: json["message"].string ?? "无", date: date)
        }
    }
    
    public func getEasyTierPeers() async throws -> [String] {
        try await get("/easytier/peers").arrayValue.map(\.stringValue)
    }
    
    private init() {}
    
    private func request(path: String, method: String, body: [String: Any]?) async throws -> Response {
        let json: JSON = try await HTTPClient.shared.request(
            url: apiRoot.appending(path: path),
            method: method,
            body: body,
            throwOnError: true,
            timeout: 30
        ).json()
        return .init(json: json)
    }
    
    private func get(_ path: String) async throws -> JSON {
        let response: Response = try await request(path: path, method: "GET", body: [:])
        guard response.code == 0 else { throw Error.apiError(code: response.code, message: response.msg) }
        guard let data: JSON = response.data else { throw Error.missingData }
        return data
    }
    
    private struct Response {
        public let code: Int
        public let msg: String
        public let data: JSON?
        
        public init(json: JSON) {
            self.code = json["code"].intValue
            self.msg = json["msg"].stringValue
            self.data = json["data"].exists() ? json["data"] : nil
        }
    }
    
    public enum Error: LocalizedError {
        case apiError(code: Int, message: String)
        case missingData
        case responseFormatError
        
        public var errorDescription: String? {
            switch self {
            case .apiError(let code, let message):
                "调用 API 失败：(\(code)) \(message)"
            case .missingData:
                "API 未返回需要的数据。"
            case .responseFormatError:
                "API 响应格式错误。"
            }
        }
    }
    
    public enum EasyTierStatus {
        case available, unavailable(message: String, date: Date)
    }
}
