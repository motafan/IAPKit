//
//  NetworkCustomizations.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

// MARK: - 示例自定义实现

/// 示例：带身份验证的自定义请求执行器
public final class AuthenticatedNetworkRequestExecutor: NetworkRequestExecutor {
    private let session: URLSession
    private let authTokenProvider: @Sendable () async throws -> String
    
    public init(session: URLSession = .shared, authTokenProvider: @escaping @Sendable () async throws -> String) {
        self.session = session
        self.authTokenProvider = authTokenProvider
    }
    
    public func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var authenticatedRequest = request
        
        // 添加身份验证令牌
        let token = try await authTokenProvider()
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return try await session.data(for: authenticatedRequest)
    }
}

/// 示例：带附加验证的自定义响应解析器
public final class ValidatingNetworkResponseParser: NetworkResponseParser {
    private let decoder: JSONDecoder
    private let validator: @Sendable (Data, URLResponse) async throws -> Void
    
    public init(
        decoder: JSONDecoder = JSONDecoder(),
        validator: @escaping @Sendable (Data, URLResponse) async throws -> Void = { _, _ in }
    ) {
        self.decoder = decoder
        self.decoder.dateDecodingStrategy = .iso8601
        self.validator = validator
    }
    
    public func parse<T: Codable>(_ data: Data, response: URLResponse, as type: T.Type) async throws -> T {
        // 自定义验证
        try await validator(data, response)
        
        // 检查 HTTP 状态
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

/// 示例：带版本化 API 路径的自定义端点构建器
public final class VersionedNetworkEndpointBuilder: NetworkEndpointBuilder {
    private let baseURL: URL
    private let apiVersion: String
    private let pathPrefix: String
    
    public init(baseURL: URL, apiVersion: String = "v1", pathPrefix: String = "api") {
        self.baseURL = baseURL
        self.apiVersion = apiVersion
        self.pathPrefix = pathPrefix
    }
    
    public func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL {
        var path: String
        
        switch action {
        case .createOrder:
            path = "/\(pathPrefix)/\(apiVersion)/orders"
        case .queryOrderStatus:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            path = "/\(pathPrefix)/\(apiVersion)/orders/\(orderID)/status"
        case .updateOrderStatus:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            path = "/\(pathPrefix)/\(apiVersion)/orders/\(orderID)/status"
        case .cancelOrder:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            path = "/\(pathPrefix)/\(apiVersion)/orders/\(orderID)"
        case .cleanupExpiredOrders:
            path = "/\(pathPrefix)/\(apiVersion)/orders/cleanup"
        case .recoverPendingOrders:
            path = "/\(pathPrefix)/\(apiVersion)/orders/recovery"
        }
        
        return baseURL.appendingPathComponent(path)
    }
}

/// 示例：带附加请求头和加密的自定义请求构建器
public final class SecureNetworkRequestBuilder: NetworkRequestBuilder {
    private let timeout: TimeInterval
    private let additionalHeaders: [String: String]
    private let encryptBody: @Sendable (Data) async throws -> Data
    
    public init(
        timeout: TimeInterval = 30.0,
        additionalHeaders: [String: String] = [:],
        encryptBody: @escaping @Sendable (Data) async throws -> Data = { $0 }
    ) {
        self.timeout = timeout
        self.additionalHeaders = additionalHeaders
        self.encryptBody = encryptBody
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
        
        // 添加附加请求头
        additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 添加自定义请求头
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 如果提供了请求体，则添加并加密
        if let body = body {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            let encryptedData = try await encryptBody(jsonData)
            request.httpBody = encryptedData
            
            // 如果加密改变了格式，则更新内容类型
            if encryptedData != jsonData {
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            }
        }
        
        return request
    }
}

// MARK: - 便利扩展

extension NetworkConfiguration {
    /// 使用指定的基础 URL 创建默认网络配置
    /// - Parameter baseURL: 网络请求的基础 URL
    /// - Returns: 具有默认设置的 NetworkConfiguration
    public static func `default`(baseURL: URL) -> NetworkConfiguration {
        return NetworkConfiguration(
            baseURL: baseURL,
            timeout: 30.0,
            maxRetryAttempts: 3,
            baseRetryDelay: 1.0,
            customComponents: nil
        )
    }
    
    /// 创建支持身份验证的配置
    public static func withAuthentication(
        baseURL: URL,
        authTokenProvider: @escaping @Sendable () async throws -> String,
        timeout: TimeInterval = 30.0
    ) -> NetworkConfiguration {
        let customComponents = NetworkCustomComponents(
            requestExecutor: AuthenticatedNetworkRequestExecutor(authTokenProvider: authTokenProvider)
        )
        
        return NetworkConfiguration(
            baseURL: baseURL,
            timeout: timeout,
            customComponents: customComponents
        )
    }
    
    /// 创建支持响应验证的配置
    public static func withValidation(
        baseURL: URL,
        validator: @escaping @Sendable (Data, URLResponse) async throws -> Void,
        timeout: TimeInterval = 30.0
    ) -> NetworkConfiguration {
        let customComponents = NetworkCustomComponents(
            responseParser: ValidatingNetworkResponseParser(validator: validator)
        )
        
        return NetworkConfiguration(
            baseURL: baseURL,
            timeout: timeout,
            customComponents: customComponents
        )
    }
    
    /// 创建支持安全请求构建的配置
    public static func withSecurity(
        baseURL: URL,
        additionalHeaders: [String: String] = [:],
        encryptBody: @escaping @Sendable (Data) async throws -> Data = { $0 },
        timeout: TimeInterval = 30.0
    ) -> NetworkConfiguration {
        let customComponents = NetworkCustomComponents(
            requestBuilder: SecureNetworkRequestBuilder(
                timeout: timeout,
                additionalHeaders: additionalHeaders,
                encryptBody: encryptBody
            )
        )
        
        return NetworkConfiguration(
            baseURL: baseURL,
            timeout: timeout,
            customComponents: customComponents
        )
    }
    
    /// 创建支持自定义端点构建的配置
    public static func withCustomEndpoints(
        baseURL: URL,
        endpointBuilder: NetworkEndpointBuilder,
        timeout: TimeInterval = 30.0
    ) -> NetworkConfiguration {
        let customComponents = NetworkCustomComponents(
            endpointBuilder: endpointBuilder
        )
        
        return NetworkConfiguration(
            baseURL: baseURL,
            timeout: timeout,
            customComponents: customComponents
        )
    }
}