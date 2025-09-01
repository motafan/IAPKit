//
//  NetworkClient.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// Response model for order creation API calls
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

/// Response model for order status queries
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

/// Flexible network client for server API communication
/// Supports customizable request execution, response parsing, and request building
/// 
/// This client can be used independently outside the IAPKit framework for general HTTP operations
/// or integrated with custom order management systems.
public final class NetworkClient: NetworkClientProtocol, Sendable {
    
    // MARK: - Configuration
    
    private let baseURL: URL
    private let retryManager: RetryManager
    private let requestExecutor: NetworkRequestExecutor
    private let responseParser: NetworkResponseParser
    private let requestBuilder: NetworkRequestBuilder
    private let endpointBuilder: NetworkEndpointBuilder
    
    // MARK: - Initialization
    
    /// Initialize with configuration (supports custom components)
    public init(configuration: NetworkConfiguration, retryManager: RetryManager = RetryManager()) {
        self.baseURL = configuration.baseURL
        self.retryManager = retryManager
        
        // Use custom components if provided, otherwise use defaults
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
            // Create URLSession with configuration
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = configuration.timeout
            sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
            let session = URLSession(configuration: sessionConfig)
            
            // Use default implementations
            self.requestExecutor = DefaultNetworkRequestExecutor(session: session)
            self.responseParser = DefaultNetworkResponseParser()
            self.requestBuilder = DefaultNetworkRequestBuilder(timeout: configuration.timeout)
            self.endpointBuilder = DefaultNetworkEndpointBuilder(baseURL: configuration.baseURL)
        }
    }
    
    /// Initialize with custom components for full flexibility
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
    
    // MARK: - Order Management API
    
    /// Creates an order on the server
    /// - Parameters:
    ///   - order: The local order to create on server
    /// - Returns: Server response with order details
    /// - Throws: IAPError if creation fails
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
    
    /// Queries order status from server
    /// - Parameter orderID: The order identifier
    /// - Returns: Current order status response
    /// - Throws: IAPError if query fails
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
    
    /// Updates order status on server
    /// - Parameters:
    ///   - orderID: The order identifier
    ///   - status: The new status
    /// - Throws: IAPError if update fails
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
    
    /// Cancels an existing order
    /// - Parameter orderID: The unique identifier of the order to cancel
    /// - Throws: IAPError if the order cannot be cancelled
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
    
    /// Cleans up expired orders from server
    /// - Returns: Response containing cleanup statistics
    /// - Throws: IAPError if cleanup operations fail
    public func cleanupExpiredOrders() async throws -> CleanupResponse {
        let endpoint = try await endpointBuilder.buildEndpoint(for: .cleanupExpiredOrders, parameters: [:])
        
        return try await performRequest(
            action: .cleanupExpiredOrders,
            endpoint: endpoint,
            body: nil,
            responseType: CleanupResponse.self
        )
    }
    
    /// Recovers pending orders from server
    /// - Returns: Response containing recovered orders
    /// - Throws: IAPError if recovery operations fail
    public func recoverPendingOrders() async throws -> OrderRecoveryResponse {
        let endpoint = try await endpointBuilder.buildEndpoint(for: .recoverPendingOrders, parameters: [:])
        
        return try await performRequest(
            action: .recoverPendingOrders,
            endpoint: endpoint,
            body: nil,
            responseType: OrderRecoveryResponse.self
        )
    }
    
    // MARK: - Private Network Operations
    
    /// Performs HTTP request with retry logic and error handling
    /// Uses injected components for maximum flexibility
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
                
                // Build request using injected builder
                let request = try await requestBuilder.buildRequest(
                    endpoint: endpoint,
                    method: action.httpMethod,
                    body: body,
                    headers: headers
                )
                
                // Execute request using injected executor
                let (data, response) = try await requestExecutor.execute(request)
                
                // Parse response using injected parser
                let result = try await responseParser.parse(data, response: response, as: responseType)
                
                await retryManager.resetAttempts(for: operationName)
                return result
                
            } catch {
                lastError = error
                
                // Don't retry for certain errors
                if !shouldRetryError(error) {
                    break
                }
                
                // Apply exponential backoff delay
                let delay = await retryManager.getDelay(for: operationName)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries exhausted, throw the last error
        throw lastError ?? IAPError.networkError
    }
    

    
    /// Determines if an error should trigger a retry
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

// MARK: - Factory Methods

// MARK: - Public Factory Methods

extension NetworkClient {
    /// Creates a NetworkClient with default configuration
    /// - Parameter configuration: Network configuration with base URL and settings
    /// - Returns: Configured NetworkClient instance
    public static func `default`(configuration: NetworkConfiguration) -> NetworkClient {
        return NetworkClient(configuration: configuration)
    }
    
    /// Creates a NetworkClient with custom components for advanced use cases
    /// - Parameters:
    ///   - baseURL: Base URL for all requests
    ///   - retryManager: Custom retry manager (optional)
    ///   - requestExecutor: Custom request executor
    ///   - responseParser: Custom response parser
    ///   - requestBuilder: Custom request builder
    ///   - endpointBuilder: Custom endpoint builder (optional)
    /// - Returns: NetworkClient with custom components
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