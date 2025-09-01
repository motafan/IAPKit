//
//  NetworkClientProtocol.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// Protocol for network request execution
/// Allows customization of how HTTP requests are sent
public protocol NetworkRequestExecutor: Sendable {
    /// Executes an HTTP request
    /// - Parameter request: The URLRequest to execute
    /// - Returns: Response data and URLResponse
    /// - Throws: Error if request fails
    func execute(_ request: URLRequest) async throws -> (Data, URLResponse)
}

/// Protocol for response parsing
/// Allows customization of how responses are parsed
public protocol NetworkResponseParser: Sendable {
    /// Parses response data into a specific type
    /// - Parameters:
    ///   - data: Raw response data
    ///   - response: URLResponse containing metadata
    ///   - type: Target type to parse into
    /// - Returns: Parsed object of specified type
    /// - Throws: Error if parsing fails
    func parse<T: Codable>(_ data: Data, response: URLResponse, as type: T.Type) async throws -> T
}

/// Protocol for request building
/// Allows customization of how requests are constructed
public protocol NetworkRequestBuilder: Sendable {
    /// Builds a URLRequest for the given parameters
    /// - Parameters:
    ///   - endpoint: Target URL
    ///   - method: HTTP method
    ///   - body: Request body data (optional)
    ///   - headers: Additional headers (optional)
    /// - Returns: Configured URLRequest
    /// - Throws: Error if request building fails
    func buildRequest(
        endpoint: URL,
        method: String,
        body: [String: Any?]?,
        headers: [String: String]?
    ) async throws -> URLRequest
}

/// Protocol for building endpoints based on order service actions
public protocol NetworkEndpointBuilder: Sendable {
    /// Builds endpoint URL for a specific order service action
    /// - Parameters:
    ///   - action: The order service action
    ///   - parameters: Action-specific parameters
    /// - Returns: Complete endpoint URL
    /// - Throws: Error if endpoint building fails
    func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL
}

/// Enum representing different order service actions
public enum OrderServiceAction: String, Sendable, CaseIterable {
    case createOrder = "create_order"
    case queryOrderStatus = "query_order_status"
    case updateOrderStatus = "update_order_status"
    case cancelOrder = "cancel_order"
    case cleanupExpiredOrders = "cleanup_expired_orders"
    case recoverPendingOrders = "recover_pending_orders"
    
    /// HTTP method for the action
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
    
    /// Default endpoint path for the action
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

/// Response model for order recovery operations
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

/// Response model for cleanup operations
public struct CleanupResponse: Sendable, Codable {
    public let cleanedOrdersCount: Int
    public let timestamp: Date
    
    public init(cleanedOrdersCount: Int, timestamp: Date = Date()) {
        self.cleanedOrdersCount = cleanedOrdersCount
        self.timestamp = timestamp
    }
}

/// Main protocol for network client functionality
public protocol NetworkClientProtocol: Sendable {
    /// Creates an order on the server
    /// - Parameter order: The local order to create on server
    /// - Returns: Server response with order details
    /// - Throws: IAPError if creation fails
    func createOrder(_ order: IAPOrder) async throws -> OrderCreationResponse
    
    /// Queries order status from server
    /// - Parameter orderID: The order identifier
    /// - Returns: Current order status response
    /// - Throws: IAPError if query fails
    func queryOrderStatus(_ orderID: String) async throws -> OrderStatusResponse
    
    /// Updates order status on server
    /// - Parameters:
    ///   - orderID: The order identifier
    ///   - status: The new status
    /// - Throws: IAPError if update fails
    func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws
    
    /// Cancels an existing order
    /// - Parameter orderID: The unique identifier of the order to cancel
    /// - Throws: IAPError if the order cannot be cancelled
    func cancelOrder(_ orderID: String) async throws
    
    /// Cleans up expired orders from server
    /// - Returns: Response containing cleanup statistics
    /// - Throws: IAPError if cleanup operations fail
    func cleanupExpiredOrders() async throws -> CleanupResponse
    
    /// Recovers pending orders from server
    /// - Returns: Response containing recovered orders
    /// - Throws: IAPError if recovery operations fail
    func recoverPendingOrders() async throws -> OrderRecoveryResponse
}