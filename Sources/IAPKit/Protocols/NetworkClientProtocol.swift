//
//  NetworkClientProtocol.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// 网络请求执行协议
/// 允许自定义 HTTP 请求的发送方式
public protocol NetworkRequestExecutor: Sendable {
    /// 执行 HTTP 请求
    /// - Parameter request: 要执行的 URLRequest
    /// - Returns: 响应数据和 URLResponse
    /// - Throws: 请求失败时抛出错误
    func execute(_ request: URLRequest) async throws -> (Data, URLResponse)
}

/// 响应解析协议
/// 允许自定义响应的解析方式
public protocol NetworkResponseParser: Sendable {
    /// 将响应数据解析为指定类型
    /// - Parameters:
    ///   - data: 原始响应数据
    ///   - response: 包含元数据的 URLResponse
    ///   - type: 要解析成的目标类型
    /// - Returns: 指定类型的解析对象
    /// - Throws: 解析失败时抛出错误
    func parse<T: Codable>(_ data: Data, response: URLResponse, as type: T.Type) async throws -> T
}

/// 请求构建协议
/// 允许自定义请求的构建方式
public protocol NetworkRequestBuilder: Sendable {
    /// 为给定参数构建 URLRequest
    /// - Parameters:
    ///   - endpoint: 目标 URL
    ///   - method: HTTP 方法
    ///   - body: 请求体数据（可选）
    ///   - headers: 附加请求头（可选）
    /// - Returns: 配置好的 URLRequest
    /// - Throws: 请求构建失败时抛出错误
    func buildRequest(
        endpoint: URL,
        method: String,
        body: [String: Any?]?,
        headers: [String: String]?
    ) async throws -> URLRequest
}

/// 基于订单服务操作构建端点的协议
public protocol NetworkEndpointBuilder: Sendable {
    /// 为特定订单服务操作构建端点 URL
    /// - Parameters:
    ///   - action: 订单服务操作
    ///   - parameters: 操作特定的参数
    /// - Returns: 完整的端点 URL
    /// - Throws: 端点构建失败时抛出错误
    func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL
}

/// 表示不同订单服务操作的枚举
public enum OrderServiceAction: String, Sendable, CaseIterable {
    case createOrder = "create_order"
    case queryOrderStatus = "query_order_status"
    case updateOrderStatus = "update_order_status"
    case cancelOrder = "cancel_order"
    case cleanupExpiredOrders = "cleanup_expired_orders"
    case recoverPendingOrders = "recover_pending_orders"
    
    /// 操作对应的 HTTP 方法
    public var httpMethod: String {
        switch self {
        case .createOrder:
            return "POST"
        case .queryOrderStatus, .recoverPendingOrders:
            return "GET"
        case .updateOrderStatus:
            return "PUT"
        case .cancelOrder:
            return "DELETE"
        case .cleanupExpiredOrders:
            return "POST"
        }
    }
    
    /// 操作的默认端点路径
    public var defaultPath: String {
        switch self {
        case .createOrder:
            return "orders"
        case .queryOrderStatus:
            return "orders/{orderID}/status"
        case .updateOrderStatus:
            return "orders/{orderID}/status"
        case .cancelOrder:
            return "orders/{orderID}"
        case .cleanupExpiredOrders:
            return "orders/cleanup"
        case .recoverPendingOrders:
            return "orders/recovery"
        }
    }
}

/// 订单恢复操作的响应模型
public struct OrderRecoveryResponse: Sendable, Codable {
    public let recoveredOrders: [OrderCreationResponse]
    public let totalRecovered: Int
    public let timestamp: Date
    
    public init(recoveredOrders: [OrderCreationResponse], totalRecovered: Int, timestamp: Date = Date()) {
        self.recoveredOrders = recoveredOrders
        self.totalRecovered = totalRecovered
        self.timestamp = timestamp
    }
}

/// 清理操作的响应模型
public struct CleanupResponse: Sendable, Codable {
    public let cleanedOrdersCount: Int
    public let timestamp: Date
    
    public init(cleanedOrdersCount: Int, timestamp: Date = Date()) {
        self.cleanedOrdersCount = cleanedOrdersCount
        self.timestamp = timestamp
    }
}

/// 网络客户端功能的主要协议
public protocol NetworkClientProtocol: Sendable {
    /// 在服务器上创建订单
    /// - Parameter order: 要在服务器上创建的本地订单
    /// - Returns: 包含订单详情的服务器响应
    /// - Throws: 创建失败时抛出 IAPError
    func createOrder(_ order: IAPOrder) async throws -> OrderCreationResponse
    
    /// 从服务器查询订单状态
    /// - Parameter orderID: 订单标识符
    /// - Returns: 当前订单状态响应
    /// - Throws: 查询失败时抛出 IAPError
    func queryOrderStatus(_ orderID: String) async throws -> OrderStatusResponse
    
    /// 在服务器上更新订单状态
    /// - Parameters:
    ///   - orderID: 订单标识符
    ///   - status: 新状态
    /// - Throws: 更新失败时抛出 IAPError
    func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws
    
    /// 取消现有订单
    /// - Parameter orderID: 要取消的订单的唯一标识符
    /// - Throws: 无法取消订单时抛出 IAPError
    func cancelOrder(_ orderID: String) async throws
    
    /// 从服务器清理过期订单
    /// - Returns: 包含清理统计信息的响应
    /// - Throws: 清理操作失败时抛出 IAPError
    func cleanupExpiredOrders() async throws -> CleanupResponse
    
    /// 从服务器恢复待处理订单
    /// - Returns: 包含恢复订单的响应
    /// - Throws: 恢复操作失败时抛出 IAPError
    func recoverPendingOrders() async throws -> OrderRecoveryResponse
}