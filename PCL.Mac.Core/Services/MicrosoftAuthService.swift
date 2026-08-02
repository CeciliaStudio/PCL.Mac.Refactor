//
//  MicrosoftAuthService.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/1/14.
//

import Foundation
import SwiftyJSON

public class MicrosoftAuthService {
    public private(set) var pollCount: Int?
    public private(set) var pollInterval: Int?
    private let clientID: String = "dd28b3f2-1db5-49b7-9228-99fdb46dfaca"
    private var deviceCode: String?
    private var oAuthToken: String?
    private var refreshToken: String?
    
    public init() {}
    
    /// 开始登录并获取设备码。
    /// - Returns: 用户授权代码和 `URL`。
    public func start() async throws -> AuthorizationCode {
        let json = try await post(
            "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode",
            [
                "client_id": clientID,
                "scope": "XboxLive.signin offline_access"
            ],
            encodeMethod: .urlEncoded
        )
        self.deviceCode = json["device_code"].stringValue
        let expiresIn: Int = json["expires_in"].intValue
        let interval: Int = json["interval"].intValue
        self.pollCount = expiresIn / interval
        self.pollInterval = interval
        return .init(
            code: json["user_code"].stringValue,
            verificationURL: URL(string: json["verification_uri"].stringValue) ?? URL(string: "https://microsoft.com/link")!
        )
    }
    
    /// 轮询用户验证状态。
    /// - Returns: 用户是否完成了验证。
    public func poll() async throws -> Bool {
        guard let deviceCode else {
            throw Error.internalError
        }
        let json: JSON = try await post(
            "https://login.microsoftonline.com/consumers/oauth2/v2.0/token",
            [
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "client_id": clientID,
                "device_code": deviceCode
            ],
            encodeMethod: .urlEncoded
        )
        if let accessToken = json["access_token"].string, let refreshToken = json["refresh_token"].string {
            self.oAuthToken = accessToken
            self.refreshToken = refreshToken
            return true
        }
        return false
    }
    
    /// 完成后续登录步骤。
    /// - Returns: 包含玩家档案、Minecraft 令牌和 OAuth 刷新令牌的结构体。
    public func authenticate() async throws -> MinecraftAuthResponse {
        guard let oAuthToken, let refreshToken else {
            err("OAuth access token 或 refresh token 未设置")
            throw Error.internalError
        }
        let xboxLiveAuthResponse: XboxLiveAuthResponse = try await authenticateXBL(with: oAuthToken)
        let xstsAuthResponse: XboxLiveAuthResponse = try await authorizeXSTS(with: xboxLiveAuthResponse.token)
        let minecraftToken: String = try await loginMinecraft(with: xstsAuthResponse)
        guard let profile: PlayerProfile = try await getMinecraftProfile(with: minecraftToken) else {
            throw Error.notPurchased
        }
        return .init(profile: profile, accessToken: minecraftToken, refreshToken: refreshToken)
    }
    
    /// 刷新 Minecraft 登录信息和令牌。
    /// - Parameter token: OAuth 刷新令牌。
    /// - Returns: 新的 `MinecraftAuthResponse`。
    public func refresh(token: String) async throws -> MinecraftAuthResponse {
        let json: JSON = try await post(
            "https://login.microsoftonline.com/consumers/oauth2/v2.0/token",
            [
                "client_id": clientID,
                "refresh_token": token,
                "grant_type": "refresh_token",
                "scope": "XboxLive.signin offline_access"
            ],
            encodeMethod: .urlEncoded
        )
        guard let oAuthToken = json["access_token"].string,
              let refreshToken = json["refresh_token"].string else {
            err("响应中不存在 error，但也不包含 access_token 键")
            throw Error.internalError
        }
        let xboxLiveAuthResponse: XboxLiveAuthResponse = try await authenticateXBL(with: oAuthToken)
        let xstsAuthResponse: XboxLiveAuthResponse = try await authorizeXSTS(with: xboxLiveAuthResponse.token)
        let minecraftToken: String = try await loginMinecraft(with: xstsAuthResponse)
        guard let profile: PlayerProfile = try await getMinecraftProfile(with: minecraftToken) else {
            throw Error.notPurchased
        }
        return .init(profile: profile, accessToken: minecraftToken, refreshToken: refreshToken)
    }
    
    public struct AuthorizationCode {
        public let code: String
        public let verificationURL: URL
    }
    
    public struct MinecraftAuthResponse {
        public let profile: PlayerProfile
        public let accessToken: String
        public let refreshToken: String
    }
    
    public enum Error: Swift.Error {
        case xboxAuthenticationFailed(code: UInt32)
        case apiError(description: String)
        case internalError
        case notPurchased
    }
    
    
    private struct XboxLiveAuthResponse {
        public let token: String
        public let uhs: String
    }
    
    private func post(_ url: URLConvertible, _ body: [String: Any], encodeMethod: HTTPClient.EncodeMethod = .json) async throws -> JSON {
        let response = try await HTTPClient.shared.post(url, body: body, using: encodeMethod)
        let json: JSON = try response.json()
        guard let string: String = .init(data: response.data, encoding: .utf8) else { throw Error.internalError }
        
        if let error: String = json["error"].string {
            if error == "authorization_pending" || error == "slow_down" {
                return json
            }
            
            let description: String = json["error_description"].string ?? json["errorMessage"].stringValue
            err("调用 API 失败：\(response.statusCode) \(error)，错误描述：\(description)")
            throw Error.apiError(description: description)
        }
        if let xerr: UInt32 = json["XErr"].uInt32 {
            err("Xbox Live 验证失败，错误代码：\(xerr)，响应体：\(string)")
            throw Error.xboxAuthenticationFailed(code: xerr)
        }
        if !(200..<300).contains(response.statusCode) {
            err("调用 API 失败：发生未知错误：\(string)")
            throw Error.apiError(description: string)
        }
        return json
    }
    
    private func authenticateXBL(with accessToken: String) async throws -> XboxLiveAuthResponse {
        let json: JSON = try await post(
            "https://user.auth.xboxlive.com/user/authenticate",
            [
                "Properties": [
                    "AuthMethod": "RPS",
                    "SiteName": "user.auth.xboxlive.com",
                    "RpsTicket": "d=\(accessToken)"
                ],
                "RelyingParty": "http://auth.xboxlive.com",
                "TokenType": "JWT"
            ]
        )
        guard let uhs: String = json["DisplayClaims"]["xui"].arrayValue.first?["uhs"].string else {
            err("https://user.auth.xboxlive.com/user/authenticate 返回的响应体中没有 uhs")
            throw Error.internalError
        }
        return XboxLiveAuthResponse(token: json["Token"].stringValue, uhs: uhs)
    }
    
    private func authorizeXSTS(with accessToken: String) async throws -> XboxLiveAuthResponse {
        let json: JSON = try await post(
            "https://xsts.auth.xboxlive.com/xsts/authorize",
            [
                "Properties": [
                    "SandboxId": "RETAIL",
                    "UserTokens": [
                        accessToken
                    ]
                ],
                "RelyingParty": "rp://api.minecraftservices.com/",
                "TokenType": "JWT"
            ]
        )
        guard let uhs: String = json["DisplayClaims"]["xui"].arrayValue.first?["uhs"].string else {
            err("https://xsts.auth.xboxlive.com/xsts/authorize 返回的响应体中没有 uhs")
            throw Error.internalError
        }
        return XboxLiveAuthResponse(token: json["Token"].stringValue, uhs: uhs)
    }
    
    private func loginMinecraft(with xstsAuthResponse: XboxLiveAuthResponse) async throws -> String {
        let json: JSON = try await post(
            "https://api.minecraftservices.com/authentication/login_with_xbox",
            [
                "identityToken": "XBL3.0 x=\(xstsAuthResponse.uhs);\(xstsAuthResponse.token)"
            ]
        )
        return json["access_token"].stringValue
    }
    
    private func getMinecraftProfile(with token: String) async throws -> PlayerProfile? {
        let json: JSON = try await HTTPClient.shared.get(
            "https://api.minecraftservices.com/minecraft/profile",
            headers: [
                "Authorization": "Bearer \(token)"
            ]
        ).json()
        if let error = json["error"].string {
            if error == "NOT_FOUND" {
                return nil
            } else {
                err("发生未知错误：\(error) \(json["errorMessage"].stringValue)")
                throw Error.apiError(description: json["errorMessage"].stringValue)
            }
        }
        // 该接口返回的 JSON 不是标准档案格式，需要根据 UUID 再获取一次
        let id: String = json["id"].stringValue
        let data: Data = try await HTTPClient.shared.get("https://sessionserver.mojang.com/session/minecraft/profile/\(id)").data
        return try JSONDecoder.shared.decode(PlayerProfile.self, from: data)
    }
}
