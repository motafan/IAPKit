//
//  NetworkEndpointExample.swift
//  IAPKit Examples
//
//  Demonstrates how NetworkClient builds endpoints based on OrderServiceProtocol actions
//

import Foundation
import IAPKit

/// Example showing how to use the NetworkClient with action-based endpoint building
class NetworkEndpointExample {
    
    /// Example of using default endpoint builder
    func demonstrateDefaultEndpointBuilder() async throws {
        // Create a network configuration with default endpoint builder
        let config = NetworkConfiguration.default(baseURL: URL(string: "https://api.example.com")!)
        
        // Create network client
        let networkClient = NetworkClient(configuration: config)
        
        // The client will automatically build endpoints based on actions:
        // - createOrder -> POST https://api.example.com/orders
        // - queryOrderStatus -> GET https://api.example.com/orders/{orderID}/status
        // - updateOrderStatus -> PUT https://api.example.com/orders/{orderID}/status
        // - cancelOrder -> DELETE https://api.example.com/orders/{orderID}
        // - cleanupExpiredOrders -> POST https://api.example.com/orders/cleanup
        // - recoverPendingOrders -> GET https://api.example.com/orders/recovery
        
        print("NetworkClient configured with default endpoint builder")
        print("Base URL: \(config.baseURL)")
        
        // Example actions and their generated endpoints:
        let actions: [OrderServiceAction] = [
            .createOrder,
            .queryOrderStatus,
            .updateOrderStatus,
            .cancelOrder,
            .cleanupExpiredOrders,
            .recoverPendingOrders
        ]
        
        let endpointBuilder = DefaultNetworkEndpointBuilder(baseURL: config.baseURL)
        
        for action in actions {
            let parameters = action == .queryOrderStatus || action == .updateOrderStatus || action == .cancelOrder
                ? ["orderID": "12345"]
                : [:]
            
            let endpoint = try await endpointBuilder.buildEndpoint(for: action, parameters: parameters)
            print("\(action.rawValue): \(action.httpMethod) \(endpoint)")
        }
    }
    
    /// Example of using custom endpoint builder
    func demonstrateCustomEndpointBuilder() async throws {
        // Create a custom endpoint builder
        let customEndpointBuilder = CustomAPIEndpointBuilder(
            baseURL: URL(string: "https://custom-api.example.com")!,
            apiVersion: "v2"
        )
        
        // Create configuration with custom endpoint builder
        let config = NetworkConfiguration.withCustomEndpoints(
            baseURL: URL(string: "https://custom-api.example.com")!,
            endpointBuilder: customEndpointBuilder
        )
        
        // Create network client
        let networkClient = NetworkClient(configuration: config)
        
        print("\nNetworkClient configured with custom endpoint builder")
        print("Base URL: \(config.baseURL)")
        
        // Example actions with custom endpoints:
        let actions: [OrderServiceAction] = [
            .createOrder,
            .queryOrderStatus,
            .cancelOrder
        ]
        
        for action in actions {
            let parameters = action == .queryOrderStatus || action == .cancelOrder
                ? ["orderID": "order-67890"]
                : [:]
            
            let endpoint = try await customEndpointBuilder.buildEndpoint(for: action, parameters: parameters)
            print("\(action.rawValue): \(action.httpMethod) \(endpoint)")
        }
    }
}

/// Custom endpoint builder that demonstrates different URL patterns
class CustomAPIEndpointBuilder: NetworkEndpointBuilder {
    private let baseURL: URL
    private let apiVersion: String
    
    init(baseURL: URL, apiVersion: String = "v1") {
        self.baseURL = baseURL
        self.apiVersion = apiVersion
    }
    
    func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL {
        var path: String
        
        switch action {
        case .createOrder:
            path = "/api/\(apiVersion)/purchase/orders"
        case .queryOrderStatus:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            path = "/api/\(apiVersion)/purchase/orders/\(orderID)"
        case .updateOrderStatus:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            path = "/api/\(apiVersion)/purchase/orders/\(orderID)/status"
        case .cancelOrder:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            path = "/api/\(apiVersion)/purchase/orders/\(orderID)/cancel"
        case .cleanupExpiredOrders:
            path = "/api/\(apiVersion)/maintenance/cleanup-orders"
        case .recoverPendingOrders:
            path = "/api/\(apiVersion)/recovery/pending-orders"
        }
        
        return baseURL.appendingPathComponent(path)
    }
}

/// Example usage
func runNetworkEndpointExamples() async {
    let example = NetworkEndpointExample()
    
    do {
        await example.demonstrateDefaultEndpointBuilder()
        try await example.demonstrateCustomEndpointBuilder()
    } catch {
        print("Error: \(error)")
    }
}