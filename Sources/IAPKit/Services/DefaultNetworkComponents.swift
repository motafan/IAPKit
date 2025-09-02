//
//  DefaultNetworkComponents.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// 使用 URLSession 的网络请求执行器默认实现
public final class DefaultNetworkRequestExecutor: NetworkRequestExecutor {
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}

/// 使用 JSONDecoder 的网络响应解析器默认实现
public final class DefaultNetworkResponseParser: NetworkResponseParser {
    private let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    public func parse<T: Codable>(_ data: Data, response: URLResponse, as type: T.Type) async throws -> T {
        // 首先检查 HTTP 状态
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                throw mapHTTPError(statusCode: httpResponse.statusCode, data: data)
            }
        }
        
        // 处理空响应类型
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        
        // 解析 JSON 响应
        return try decoder.decode(T.self, from: data)
    }
    
    /// 将 HTTP 状态码映射到相应的 IAP 错误
    private func mapHTTPError(statusCode: Int, data: Data) -> IAPError {
        switch statusCode {
        case 400:
            return .orderCreationFailed(underlying: "Bad request")
        case 404:
            return .orderNotFound
        case 409:
            return .orderAlreadyCompleted
        case 410:
            return .orderExpired
        case 422:
            return .orderValidationFailed
        case 500...599:
            return .networkError
        default:
            return .networkError
        }
    }
}

/// 网络请求构建器的默认实现
public final class DefaultNetworkRequestBuilder: NetworkRequestBuilder {
    private let timeout: TimeInterval
    
    public init(timeout: TimeInterval = 30.0) {
        self.timeout = timeout
    }
    
    public func buildRequest(
        endpoint: URL,
        method: String,
        body: [String: Any?]?,
        headers: [String: String]?
    ) async throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.timeoutInterval = timeout
        
        // 设置默认请求头
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加自定义请求头
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 如果提供了请求体则添加
        if let body = body {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        }
        
        return request
    }
}

/// 网络端点构建器的默认实现
public final class DefaultNetworkEndpointBuilder: NetworkEndpointBuilder {
    private let baseURL: URL
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    public func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL {
        var path = action.defaultPath
        
        // 用实际值替换路径参数
        for (key, value) in parameters {
            path = path.replacingOccurrences(of: "{\(key)}", with: value)
        }
        
        return baseURL.appendingPathComponent(path)
    }
}

/// 不返回数据的操作的空响应
public struct EmptyResponse: Codable, Sendable {
    public init() {}
}