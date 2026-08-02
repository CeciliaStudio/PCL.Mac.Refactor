//
//  HTTPClient.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/12/3.
//

import Foundation
import SwiftyJSON

public protocol URLConvertible {
    var url: URL? { get }
}

extension URL: URLConvertible {
    public var url: URL? { self }
}

extension String: URLConvertible {
    public var url: URL? { URL(string: self) }
}

public class HTTPClient {
    public static let shared: HTTPClient = .init()
    
    public enum EncodeMethod {
        case json
        case urlEncoded
    }
    
    public class Response {
        private let response: HTTPURLResponse
        public let statusCode: Int
        public let headers: [String: String]
        public let data: Data
        
        fileprivate init(data: Data, response: HTTPURLResponse) {
            self.response = response
            self.statusCode = response.statusCode
            self.headers = Self.parseHeaders(response.allHeaderFields)
            self.data = data
        }
        
        public func json() throws -> JSON {
            do {
                return try JSON(data: data)
            } catch {
                throw ResponseError(.decodeError, url: response.url, response: response)
            }
        }
        
        public func decode<T: Decodable>(_ type: T.Type) throws -> T {
            do {
                return try JSONDecoder.shared.decode(type, from: data)
            } catch {
                throw ResponseError(.decodeError, url: response.url, response: response)
            }
        }
        
        private static func parseHeaders(_ headers: [AnyHashable: Any]) -> [String: String] {
            return headers.reduce(into: [:]) { result, entry in
                if let key = entry.key as? String, let value = entry.value as? String {
                    result[key.lowercased()] = value
                }
            }
        }
    }
    
    /// 向目标 URL 发送请求。
    /// - Parameters:
    ///   - url: 目标 URL，可以是 `String` 与 `URL`。
    ///   - method: 请求方法，如 `GET`、`POST`。
    ///   - headers: 请求头。
    ///   - body: 请求体，在请求方法为 `GET` 时被视为 URL params。
    ///   - encodeMethod: 请求体的编码方式。
    ///   - throwOnError: 在最终响应状态码为非 `2XX` 时是否抛出错误。
    ///   - revalidate: 是否使用 `.reloadIgnoringLocalCacheData` 缓存策略（先判断本地缓存是否过期）。
    ///   - timeout: 请求超时时间。
    /// - Returns: 返回的响应。
    public func request(
        url: URLConvertible,
        method: String,
        headers: [String: String?]? = nil,
        body: [String: Any?]? = nil,
        using encodeMethod: EncodeMethod = .json,
        throwOnError: Bool = false,
        revalidate: Bool = false,
        timeout: TimeInterval
    ) async throws -> Response {
        guard let url = url.url else { throw RequestError.invalidURL(url) }
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { throw RequestError.invalidScheme(url: url) }
        
        let headers = headers?.compactMapValues(\.self)
        let body = body?.compactMapValues(\.self)
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.setValue("PCL-Mac/\(Metadata.appVersion)", forHTTPHeaderField: "User-Agent")
        if revalidate {
            request.cachePolicy = .reloadRevalidatingCacheData
        }
        request.timeoutInterval = timeout
        
        if let body {
            if method == "GET" {
                // url params
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = body.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
                request.url = components.url
            } else {
                let bodyData: Data
                let contentType: String
                do {
                    (bodyData, contentType) = try encode(body, using: encodeMethod)
                } catch {
                    throw RequestError.encodeError(underlying: error)
                }
                
                request.httpBody = bodyData
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error where error.isCancellationError {
            throw CancellationError()
        }
        guard let response = response as? HTTPURLResponse else {
            throw ResponseError(.invalidType, url: url, response: response)
        }
        if throwOnError && !(200..<300).contains(response.statusCode) {
            throw ResponseError(.badStatus, url: url, response: response)
        }
        
        return Response(data: data, response: response)
    }
    
    /// 向目标 URL 发送 `GET` 请求。
    /// - Parameters:
    ///   - url: 目标 URL，可以是 `String` 与 `URL`。
    ///   - headers: 请求头。
    ///   - params: 请求的 URL params。
    ///   - throwOnError: 在最终响应状态码为非 `2XX` 时是否抛出错误。
    ///   - revalidate: 是否使用 `.reloadIgnoringLocalCacheData` 缓存策略（先判断本地缓存是否过期）。
    ///   - timeout: 请求超时时间，默认 30s。
    /// - Returns: 返回的响应。
    public func get(
        _ url: URLConvertible,
        headers: [String: String?]? = nil,
        params: [String: String?]? = nil,
        throwOnError: Bool = false,
        revalidate: Bool = false,
        timeout: TimeInterval = 30
    ) async throws -> Response {
        return try await request(url: url, method: "GET", headers: headers, body: params, using: .urlEncoded, throwOnError: throwOnError, revalidate: revalidate, timeout: timeout)
    }
    
    /// 向目标 URL 发送 `POST` 请求。
    /// - Parameters:
    ///   - url: 目标 URL，可以是 `String` 与 `URL`。
    ///   - headers: 请求头。
    ///   - body: 请求体。
    ///   - encodeMethod: 请求体的编码方式。
    ///   - throwOnError: 在最终响应状态码为非 `2XX` 时是否抛出错误。
    ///   - timeout: 请求超时时间，默认 30s。
    /// - Returns: 返回的响应。
    public func post(
        _ url: URLConvertible,
        headers: [String: String?]? = nil,
        body: [String: Any?]?,
        using encodeMethod: EncodeMethod,
        throwOnError: Bool = false,
        timeout: TimeInterval = 30
    ) async throws -> Response {
        return try await request(url: url, method: "POST", headers: headers, body: body, using: encodeMethod, throwOnError: throwOnError, revalidate: false, timeout: timeout)
    }
    
    private func encode(_ body: [String: Any], using method: EncodeMethod) throws -> (Data, String) {
        switch method {
        case .json:
            return (try JSONSerialization.data(withJSONObject: body), "application/json")
        case .urlEncoded:
            return (try body.map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8).unwrap(), "application/x-www-form-urlencoded")
        }
    }
    
    private init() {}
}

public enum RequestError: LocalizedError {
    case invalidURL(_ url: URLConvertible)
    case invalidScheme(url: URL)
    case encodeError(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            "无效的 URL：\(url)。"
        case .invalidScheme(let url):
            "无效的 URL Scheme" + (url.scheme == nil ? "" : "：\(url.scheme!)") + "。"
        case .encodeError(let underlying):
            "编码请求体失败：\(underlying.localizedDescription)。"
        }
    }
}

public struct ResponseError: LocalizedError {
    public let kind: Kind
    public let url: URL?
    public let response: URLResponse?
    public let error: Error?
    
    init(_ kind: Kind, url: URL?, response: URLResponse?, underlying error: Error? = nil) {
        self.kind = kind
        self.url = url
        self.response = response
        self.error = error
    }
    
    public enum Kind {
        case invalidType
        case badStatus
        case decodeError
    }
    
    public var errorDescription: String? {
        switch kind {
        case .invalidType:
            return "无效的响应类型" + (response == nil ? "" : "：\(type(of: response))") + "。"
        case .badStatus:
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                return "错误响应码。"
            }
            return "错误响应码：\(statusCode)。"
        case .decodeError:
            return "解码响应体失败。"
        }
    }
}
