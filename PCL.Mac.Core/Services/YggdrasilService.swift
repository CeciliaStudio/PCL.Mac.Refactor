//
//  YggdrasilService.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/4/7.
//

import Foundation
import SwiftyJSON

public class YggdrasilService {
    private var authServerURL: URL
    
    public init(authServerURL: URL) {
        self.authServerURL = authServerURL
    }
    
    /// 尝试将用户输入的地址解析为真正的 API 地址。
    ///
    /// 参见 [Yggdrasil 启动器技术规范#处理 API 地址指示（ALI）](https://github.com/yushijinhun/authlib-injector/wiki/启动器技术规范#处理-api-地址指示ali)
    /// - Returns: 解析后的 `URL`，可能与原 URL 相同（不包含 ALI 头）。
    public func resolveALI() async throws -> URL {
        let response = try await request("HEAD", "/")
        if let apiLocation: String = response.headers["x-authlib-injector-api-location"],
           let resolvedURL = URL(string: apiLocation) {
            if resolvedURL.scheme == "http" || resolvedURL.scheme == "https" {
                self.authServerURL = resolvedURL
                return resolvedURL
            } else {
                authServerURL = authServerURL.appending(path: apiLocation)
                return authServerURL
            }
        }
        return authServerURL
    }
    
    /// 使用密码进行身份验证，并分配一个新的令牌。
    ///
    /// 参见 [Yggdrasil 服务端技术规范#登录](https://github.com/yushijinhun/authlib-injector/wiki/Yggdrasil-服务端技术规范#登录)
    /// - Parameters:
    ///   - username: 邮箱或用户名。
    ///   - password: 密码。
    /// - Returns: 包含 `accessToken`、`clientToken` 和角色列表的 `AuthResponse`。
    public func authenticate(_ username: String, password: String) async throws -> AuthResponse {
        let response = try await request(
            "POST", "/authserver/authenticate",
            body: [
                "username": username,
                "password": password,
                "requestUser": true,
                "agent": [
                    "name": "Minecraft",
                    "version": 1
                ]
            ]
        )
        
        do {
            return try response.decode(AuthResponse.self)
        } catch let error as DecodingError {
            debug(error)
            throw Error.invalidResponseFormat(underlying: error)
        }
    }
    
    /// 检验令牌是否有效。
    ///
    /// 参见 [Yggdrasil 服务端技术规范#验证令牌](https://github.com/yushijinhun/authlib-injector/wiki/Yggdrasil-服务端技术规范#验证令牌)
    /// - Parameters:
    ///   - accessToken: 令牌的 `accessToken`。
    ///   - clientToken: 令牌的 `refreshToken`（可选）。
    /// - Returns: 一个 `Bool`，表示令牌是否有效。
    public func validateToken(_ accessToken: String, clientToken: String? = nil) async throws -> Bool {
        do {
            let response = try await request(
                "POST", "/authserver/validate",
                body: [
                    "accessToken": accessToken,
                    "clientToken": clientToken
                ]
            )
            return response.statusCode == 204
        } catch let error as Error {
            if case .apiError(let error, _, _) = error, error == "ForbiddenOperationException" {
                return false
            }
            throw error
        }
    }
    
    /// 吊销原令牌，并颁发一个新的令牌。
    ///
    /// 参见 [Yggdrasil 服务端技术规范#刷新](https://github.com/yushijinhun/authlib-injector/wiki/Yggdrasil-服务端技术规范#刷新)
    /// - Parameters:
    ///   - accessToken: 令牌的 `accessToken`。
    ///   - clientToken: 令牌的 `clientToken`（可选）。
    ///   - profile: 令牌绑定的角色。如果令牌处于无效状态，且此参数未被设置，将无法刷新。
    /// - Returns: 包含新 `accessToken` 和新角色档案（若发生变更）的 `RefreshResponse`。
    public func refresh(
        _ accessToken: String,
        clientToken: String? = nil,
        profile: PlayerProfile?
    ) async throws -> RefreshResponse {
        let response = try await request(
            "POST", "/authserver/refresh",
            body: [
                "accessToken": accessToken,
                "clientToken": clientToken,
                "requestUser": true,
                "selectedProfile": try profile?.toDictionary()
            ]
        )
        
        do {
            let refreshResponse = try response.decode(RefreshResponse.self)
            if let clientToken {
                guard refreshResponse.clientToken == clientToken else {
                    throw Error.invalidResponseFormat(underlying: SimpleError("颁发的新令牌的 clientToken 与原令牌的不同。"))
                }
            }
            return refreshResponse
        } catch let error as DecodingError {
            debug(error)
            throw Error.invalidResponseFormat(underlying: error)
        }
    }
    
    /// 获取 API 元数据。
    ///
    /// 参见：
    /// - [Yggdrasil 服务端技术规范#API 元数据获取](https://github.com/yushijinhun/authlib-injector/wiki/Yggdrasil-服务端技术规范#api-元数据获取)
    /// - [启动器技术规范#配置预获取](https://github.com/yushijinhun/authlib-injector/wiki/启动器技术规范#配置预获取)
    ///
    /// - Returns: 包含部分字段和 Base64 编码的元数据的 `ServerMetadata`。
    public func fetchMetadata() async throws -> ServerMetadata {
        do {
            let response = try await request("GET", "/")
            let json = try response.json()
            let meta: JSON = json["meta"]
            return .init(
                serverName: meta["serverName"].string,
                implementationName: meta["implementationName"].string,
                implementationVersion: meta["implementationVersion"].string,
                encoded: response.data.base64EncodedString()
            )
        } catch let error as DecodingError {
            debug(error)
            throw Error.invalidResponseFormat(underlying: error)
        }
    }
    
    /// 查询某个角色的完整 `PlayerProfile`（包括角色属性）。
    /// - Parameter uuid: 角色的 `UUID`。
    /// - Returns: 完整 `PlayerProfile`。
    public func fullProfile(for uuid: UUID) async throws -> PlayerProfile {
        do {
            let uuidString = UUIDUtils.string(of: uuid, withHyphens: false)
            return try await request(
                "GET", "/sessionserver/session/minecraft/profile/\(uuidString)",
                body: [
                    "unsigned": true
                ]
            )
            .decode(PlayerProfile.self)
        } catch let error as DecodingError {
            debug(error)
            throw Error.invalidResponseFormat(underlying: error)
        }
    }
    
    public enum Error: LocalizedError {
        case apiError(error: String, errorMessage: String, cause: String?)
        case internalError(description: String)
        case invalidResponseFormat(underlying: Swift.Error)
        
        public var errorDescription: String? {
            switch self {
            case .apiError(let error, let errorMessage, let cause):
                "调用 API 失败：(\(error)) \(errorMessage)" + (cause.map { "，原因：\($0)" } ?? "")
            case .internalError(let description):
                "发生内部错误：\(description)"
            case .invalidResponseFormat(let underlying):
                "响应格式错误：\(underlying.localizedDescription)"
            }
        }
    }
    
    public struct AuthResponse: Codable {
        public let accessToken: String
        public let clientToken: String
        public let availableProfiles: [PlayerProfile]
        public let selectedProfile: PlayerProfile?
    }
    
    public struct RefreshResponse: Codable {
        public let accessToken: String
        public let clientToken: String
        public let selectedProfile: PlayerProfile?
    }
    
    public struct ServerMetadata {
        public let serverName: String?
        public let implementationName: String?
        public let implementationVersion: String?
        
        /// 经过 Base64 编码后的字符串。
        public let encoded: String
    }
    
    private func request(
        _ method: String,
        _ path: String,
        headers: [String: String]? = nil,
        body: [String: Any?]? = nil
    ) async throws -> HTTPClient.Response {
        let response = try await HTTPClient.shared.request(url: authServerURL.appending(path: path), method: method, headers: headers, body: body, using: .json, revalidate: false, timeout: 30)
        if !(200..<300).contains(response.statusCode) {
            if let json: JSON = try? response.json(),
               let error: String = json["error"].string {
                let errorMessage: String = json["errorMessage"].stringValue
                let cause: String? = json["cause"].string
                throw Error.apiError(error: error, errorMessage: errorMessage, cause: cause)
            }
            
            guard let string = String(data: response.data, encoding: .utf8) else {
                throw Error.internalError(description: "解码响应体失败。")
            }
            throw Error.apiError(error: response.statusCode.description, errorMessage: string, cause: nil)
        }
        return response
    }
}
