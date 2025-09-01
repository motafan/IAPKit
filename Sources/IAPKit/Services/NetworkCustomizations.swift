//
//  NetworkCustomizations.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

// MARK: - Example Custom Implementations

/// Example: Custom request executor with authentication
public final class AuthenticatedNetworkRequestExecutor: NetworkRequestExecutor {
    private let session: URLSession
    private let authTokenProvider: @Sendable () async throws -> String
    
    public init(session: URLSession = .shared, authTokenProvider: @escaping @Sendable () async throws -> String) {
        self.session = session
        self.authTokenProvider = authTokenProvider
    }
    
    public func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var authenticatedRequest = request
        
        // Add authentication token
        let token = try await authTokenProvider()
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return try await session.data(for: authenticatedRequest)
    }
}

/// Example: Custom response parser with additional validation
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
        // Custom validation
        try await validator(data, response)
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                throw mapHTTPError(statusCode: httpResponse.statusCode, data: data)
            }
        }
        
        // Handle empty response types
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        
        // Parse JSON response
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

/// Example: Custom endpoint builder with versioned API paths
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

/// Example: Custom request builder with additional headers and encryption
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
        
        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add additional headers
        additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add and encrypt request body if provided
        if let body = body {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            let encryptedData = try await encryptBody(jsonData)
            request.httpBody = encryptedData
            
            // Update content type if encryption changes format
            if encryptedData != jsonData {
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            }
        }
        
        return request
    }
}

// MARK: - Convenience Extensions

extension NetworkConfiguration {
    /// Creates a default network configuration with the specified base URL
    /// - Parameter baseURL: The base URL for network requests
    /// - Returns: A NetworkConfiguration with default settings
    public static func `default`(baseURL: URL) -> NetworkConfiguration {
        return NetworkConfiguration(
            baseURL: baseURL,
            timeout: 30.0,
            maxRetryAttempts: 3,
            baseRetryDelay: 1.0,
            customComponents: nil
        )
    }
    
    /// Creates configuration with authentication support
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
    
    /// Creates configuration with response validation
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
    
    /// Creates configuration with secure request building
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
    
    /// Creates configuration with custom endpoint building
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