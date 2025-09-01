//
//  DefaultNetworkComponents.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// Default implementation of NetworkRequestExecutor using URLSession
public final class DefaultNetworkRequestExecutor: NetworkRequestExecutor {
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}

/// Default implementation of NetworkResponseParser using JSONDecoder
public final class DefaultNetworkResponseParser: NetworkResponseParser {
    private let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    public func parse<T: Codable>(_ data: Data, response: URLResponse, as type: T.Type) async throws -> T {
        // Check HTTP status first
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
}

/// Default implementation of NetworkRequestBuilder
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
        
        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add request body if provided
        if let body = body {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        }
        
        return request
    }
}

/// Default implementation of NetworkEndpointBuilder
public final class DefaultNetworkEndpointBuilder: NetworkEndpointBuilder {
    private let baseURL: URL
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    public func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL {
        var path = action.defaultPath
        
        // Replace path parameters with actual values
        for (key, value) in parameters {
            path = path.replacingOccurrences(of: "{\(key)}", with: value)
        }
        
        return baseURL.appendingPathComponent(path)
    }
}

/// Empty response for operations that don't return data
public struct EmptyResponse: Codable, Sendable {
    public init() {}
}