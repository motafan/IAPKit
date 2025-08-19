//
//  NetworkClient.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// Response model for order creation API calls
struct OrderCreationResponse: Sendable, Codable {
    let orderID: String
    let serverOrderID: String
    let status: String
    let expiresAt: Date?
    let metadata: [String: String]?
}

/// Response model for order status queries
struct OrderStatusResponse: Sendable, Codable {
    let orderID: String
    let status: String
    let updatedAt: Date
    let metadata: [String: String]?
}

/// Network client for server API communication
/// Handles all server-side order management operations
@MainActor
final class NetworkClient: Sendable {
    
    // MARK: - Configuration
    
    private let baseURL: URL
    private let session: URLSession
    private let retryManager: RetryManager
    private let timeout: TimeInterval
    
    // MARK: - Initialization
    
    init(configuration: NetworkConfiguration, retryManager: RetryManager = RetryManager()) {
        self.baseURL = configuration.baseURL
        self.timeout = configuration.timeout
        self.retryManager = retryManager
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.timeoutIntervalForResource = configuration.timeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Order Creation API
    
    /// Creates an order on the server
    /// - Parameters:
    ///   - order: The local order to create on server
    /// - Returns: Server response with order details
    /// - Throws: IAPError if creation fails
    func createOrder(_ order: IAPOrder) async throws -> OrderCreationResponse {
        let endpoint = baseURL.appendingPathComponent("orders")
        
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
            endpoint: endpoint,
            method: "POST",
            body: requestBody,
            responseType: OrderCreationResponse.self,
            operationName: "createOrder"
        )
    }
    
    // MARK: - Order Status API
    
    /// Queries order status from server
    /// - Parameter orderID: The order identifier
    /// - Returns: Current order status response
    /// - Throws: IAPError if query fails
    func queryOrderStatus(_ orderID: String) async throws -> OrderStatusResponse {
        let endpoint = baseURL.appendingPathComponent("orders/\(orderID)/status")
        
        return try await performRequest(
            endpoint: endpoint,
            method: "GET",
            body: nil,
            responseType: OrderStatusResponse.self,
            operationName: "queryOrderStatus"
        )
    }
    
    /// Updates order status on server
    /// - Parameters:
    ///   - orderID: The order identifier
    ///   - status: The new status
    /// - Throws: IAPError if update fails
    func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws {
        let endpoint = baseURL.appendingPathComponent("orders/\(orderID)/status")
        
        let requestBody = [
            "status": status.rawValue,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        let _: EmptyResponse = try await performRequest(
            endpoint: endpoint,
            method: "PUT",
            body: requestBody,
            responseType: EmptyResponse.self,
            operationName: "updateOrderStatus"
        )
    }
    
    // MARK: - Private Network Operations
    
    /// Performs HTTP request with retry logic and error handling
    private func performRequest<T: Codable>(
        endpoint: URL,
        method: String,
        body: [String: Any?]?,
        responseType: T.Type,
        operationName: String
    ) async throws -> T {
        
        var lastError: Error?
        
        while await retryManager.shouldRetry(for: operationName) {
            do {
                await retryManager.recordAttempt(for: operationName)
                
                var request = URLRequest(url: endpoint)
                request.httpMethod = method
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                // Add request body if provided
                if let body = body {
                    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
                    request.httpBody = jsonData
                }
                
                let (data, response) = try await session.data(for: request)
                
                // Check HTTP status
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw IAPError.networkError
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw mapHTTPError(statusCode: httpResponse.statusCode, data: data)
                }
                
                // Parse response
                if T.self == EmptyResponse.self {
                    await retryManager.resetAttempts(for: operationName)
                    return EmptyResponse() as! T
                } else {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let result = try decoder.decode(T.self, from: data)
                    await retryManager.resetAttempts(for: operationName)
                    return result
                }
                
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
    
    /// Maps HTTP status codes to appropriate IAP errors
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

// MARK: - Helper Types

/// Empty response for operations that don't return data
private struct EmptyResponse: Codable, Sendable {
    init() {}
}