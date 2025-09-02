//
//  NetworkClient.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// 订单创建 API 调用的响应模型
public struct OrderCreationResponse: Sendable, Codable {
    public let orderID: String
    public let serverOrderID: String
    public let status: String
    public let expiresAt: Date?
    public let metadata: [String: String]?
    
    public init(orderID: String, serverOrderID: String, status: String, expiresAt: Date? = nil, metadata: [String: String]? = nil) {
        self.orderID = orderID
        self.serverOrderID = serverOrderID
        self.status = status
        self.expiresAt = expiresAt
        self.metadata = metadata
    }
}

/// 订单状态查询的响应模型
public struct OrderStatusResponse: Sendable, Codable {
    public let orderID: String
    public let status: String
    public let updatedAt: Date
    public let metadata: [String: String]?
    
    public init(orderID: String, status: String, updatedAt: Date, metadata: [String: String]? = nil) {
        self.orderID = orderID
        self.status = status
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

/// 灵活的网络客户端，用于服务器 API 通信
/// 支持可自定义的请求执行、响应解析和请求构建
/// 
/// 此客户端可以独立于 IAPKit 框架用于一般 HTTP 操作
/// 或与自定义订单管理系统集成。
public final class NetworkClient: NetworkClientProtocol, Sendable {
    
    // MARK: - 配置
    
    private let baseURL: URL
    private let retryManager: RetryManager
    private let requestExecutor: NetworkRequestExecutor
    private let responseParser: NetworkResponseParser
    private let requestBuilder: NetworkRequestBuilder
    private let endpointBuilder: NetworkEndpointBuilder
    
    // MARK: - 初始化
    
    /// 使用配置初始化（支持自定义组件）
    public init(configuration: NetworkConfiguration, retryManager: RetryManager = RetryManager()) {
        self.baseURL = configuration.baseURL
        self.retryManager = retryManager
        
        // 如果提供了自定义组件则使用，否则使用默认组件
        if let customComponents = configuration.customComponents {
            self.requestExecutor = customComponents.requestExecutor ?? {
                let sessionConfig = URLSessionConfiguration.default
                sessionConfig.timeoutIntervalForRequest = configuration.timeout
                sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
                let session = URLSession(configuration: sessionConfig)
                return DefaultNetworkRequestExecutor(session: session)
            }()
            
            self.responseParser = customComponents.responseParser ?? DefaultNetworkResponseParser()
            self.requestBuilder = customComponents.requestBuilder ?? DefaultNetworkRequestBuilder(timeout: configuration.timeout)
            self.endpointBuilder = customComponents.endpointBuilder ?? DefaultNetworkEndpointBuilder(baseURL: configuration.baseURL)
        } else {
            // 使用配置创建 URLSession
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = configuration.timeout
            sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
            let session = URLSession(configuration: sessionConfig)
            
            // 使用默认实现
            self.requestExecutor = DefaultNetworkRequestExecutor(session: session)
            self.responseParser = DefaultNetworkResponseParser()
            self.requestBuilder = DefaultNetworkRequestBuilder(timeout: configuration.timeout)
            self.endpointBuilder = DefaultNetworkEndpointBuilder(baseURL: configuration.baseURL)
        }
    }
    
    /// 使用自定义组件初始化以获得完全灵活性
    public init(
        baseURL: URL,
        retryManager: RetryManager = RetryManager(),
        requestExecutor: NetworkRequestExecutor,
        responseParser: NetworkResponseParser,
        requestBuilder: NetworkRequestBuilder,
        endpointBuilder: NetworkEndpointBuilder? = nil
    ) {
        self.baseURL = baseURL
        self.retryManager = retryManager
        self.requestExecutor = requestExecutor
        self.responseParser = responseParser
        self.requestBuilder = requestBuilder
        self.endpointBuilder = endpointBuilder ?? DefaultNetworkEndpointBuilder(baseURL: baseURL)
    }
    
    // MARK: - 订单管理 API
    
    /// 在服务器上创建订单
    /// - Parameters:
    ///   - order: 要在服务器上创建的本地订单
    /// - Returns: 包含订单详情的服务器响应
    /// - Throws: 创建失败时抛出 IAPError
    public func createOrder(_ order: IAPOrder) async throws -> OrderCreationResponse {
        let endpoint = try await endpointBuilder.buildEndpoint(for: .createOrder, parameters: [:])
        
        let requestBody = [
            "localOrderID": order.id,
            "productID": order.productID,
            "userInfo": order.userInfo ?? [:],
            "createdAt": ISO8601DateFormatter().string(from: order.createdAt),
            "amount": order.amount?.description,
            "currency": order.currency,
            "userID": order.userID
        ] as [String: Any?]
        
        return try await performRequest(
            action: .createOrder,
            endpoint: endpoint,
            body: requestBody,
            responseType: OrderCreationResponse.self
        )
    }
    
    /// 从服务器查询订单状态
    /// - Parameter orderID: 订单标识符
    /// - Returns: 当前订单状态响应
    /// - Throws: 查询失败时抛出 IAPError
    public func queryOrderStatus(_ orderID: String) async throws -> OrderStatusResponse {
        let endpoint = try await endpointBuilder.buildEndpoint(
            for: .queryOrderStatus,
            parameters: ["orderID": orderID]
        )
        
        return try await performRequest(
            action: .queryOrderStatus,
            endpoint: endpoint,
            body: nil,
            responseType: OrderStatusResponse.self
        )
    }
    
    /// 在服务器上更新订单状态
    /// - Parameters:
    ///   - orderID: 订单标识符
    ///   - status: 新状态
    /// - Throws: 更新失败时抛出 IAPError
    public func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws {
        let endpoint = try await endpointBuilder.buildEndpoint(
            for: .updateOrderStatus,
            parameters: ["orderID": orderID]
        )
        
        let requestBody = [
            "status": status.rawValue,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        let _: EmptyResponse = try await performRequest(
            action: .updateOrderStatus,
            endpoint: endpoint,
            body: requestBody,
            responseType: EmptyResponse.self
        )
    }
    
    /// 取消现有订单
    /// - Parameter orderID: 要取消的订单的唯一标识符
    /// - Throws: 无法取消订单时抛出 IAPError
    public func cancelOrder(_ orderID: String) async throws {
        let endpoint = try await endpointBuilder.buildEndpoint(
            for: .cancelOrder,
            parameters: ["orderID": orderID]
        )
        
        let _: EmptyResponse = try await performRequest(
            action: .cancelOrder,
            endpoint: endpoint,
            body: nil,
            responseType: EmptyResponse.self
        )
    }
    
    /// 从服务器清理过期订单
    /// - Returns: 包含清理统计信息的响应
    /// - Throws: 清理操作失败时抛出 IAPError
    public func cleanupExpiredOrders() async throws -> CleanupResponse {
        let endpoint = try await endpointBuilder.buildEndpoint(for: .cleanupExpiredOrders, parameters: [:])
        
        return try await performRequest(
            action: .cleanupExpiredOrders,
            endpoint: endpoint,
            body: nil,
            responseType: CleanupResponse.self
        )
    }
    
    /// 从服务器恢复待处理订单
    /// - Returns: 包含恢复订单的响应
    /// - Throws: 恢复操作失败时抛出 IAPError
    public func recoverPendingOrders() async throws -> OrderRecoveryResponse {
        let endpoint = try await endpointBuilder.buildEndpoint(for: .recoverPendingOrders, parameters: [:])
        
        return try await performRequest(
            action: .recoverPendingOrders,
            endpoint: endpoint,
            body: nil,
            responseType: OrderRecoveryResponse.self
        )
    }
    
    // MARK: - 私有网络操作
    
    /// 执行带有重试逻辑和错误处理的 HTTP 请求
    /// 使用注入的组件以获得最大灵活性
    private func performRequest<T: Codable>(
        action: OrderServiceAction,
        endpoint: URL,
        body: [String: Any?]?,
        headers: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        
        let operationName = action.rawValue
        var lastError: Error?
        
        while await retryManager.shouldRetry(for: operationName) {
            do {
                await retryManager.recordAttempt(for: operationName)
                
                // 使用注入的构建器构建请求
                let request = try await requestBuilder.buildRequest(
                    endpoint: endpoint,
                    method: action.httpMethod,
                    body: body,
                    headers: headers
                )
                
                // 使用注入的执行器执行请求
                let (data, response) = try await requestExecutor.execute(request)
                
                // 使用注入的解析器解析响应
                let result = try await responseParser.parse(data, response: response, as: responseType)
                
                await retryManager.resetAttempts(for: operationName)
                return result
                
            } catch {
                lastError = error
                
                // 对于某些错误不进行重试
                if !shouldRetryError(error) {
                    break
                }
                
                // 应用指数退避延迟
                let delay = await retryManager.getDelay(for: operationName)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // 所有重试都已用尽，抛出最后的错误
        throw lastError ?? IAPError.networkError
    }
    

    
    /// 确定错误是否应该触发重试
    private func shouldRetryError(_ error: Error) -> Bool {
        if let iapError = error as? IAPError {
            switch iapError {
            case .networkError:
                return true
            case .orderCreationFailed, .orderValidationFailed:
                return false
            default:
                return false
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

// MARK: - 工厂方法

// MARK: - 公共工厂方法

extension NetworkClient {
    /// 使用默认配置创建 NetworkClient
    /// - Parameter configuration: 包含基础 URL 和设置的网络配置
    /// - Returns: 配置好的 NetworkClient 实例
    public static func `default`(configuration: NetworkConfiguration) -> NetworkClient {
        return NetworkClient(configuration: configuration)
    }
    
    /// 为高级用例创建带有自定义组件的 NetworkClient
    /// - Parameters:
    ///   - baseURL: 所有请求的基础 URL
    ///   - retryManager: 自定义重试管理器（可选）
    ///   - requestExecutor: 自定义请求执行器
    ///   - responseParser: 自定义响应解析器
    ///   - requestBuilder: 自定义请求构建器
    ///   - endpointBuilder: 自定义端点构建器（可选）
    /// - Returns: 带有自定义组件的 NetworkClient
    public static func custom(
        baseURL: URL,
        retryManager: RetryManager = RetryManager(),
        requestExecutor: NetworkRequestExecutor,
        responseParser: NetworkResponseParser,
        requestBuilder: NetworkRequestBuilder,
        endpointBuilder: NetworkEndpointBuilder? = nil
    ) -> NetworkClient {
        return NetworkClient(
            baseURL: baseURL,
            retryManager: retryManager,
            requestExecutor: requestExecutor,
            responseParser: responseParser,
            requestBuilder: requestBuilder,
            endpointBuilder: endpointBuilder
        )
    }
}