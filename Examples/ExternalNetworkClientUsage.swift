//
//  ExternalNetworkClientUsage.swift
//  IAPKit Examples
//
//  Demonstrates how to use NetworkClient independently outside the IAPKit framework
//

import Foundation
import IAPKit

/// Example showing external usage of NetworkClient for custom order management
class ExternalNetworkClientExample {
    
    private let networkClient: NetworkClient
    
    init(baseURL: URL) {
        // Create configuration for your API
        let config = NetworkConfiguration.default(baseURL: baseURL)
        
        // Initialize the network client
        self.networkClient = NetworkClient.default(configuration: config)
    }
    
    /// Example: Create a purchase order for an external e-commerce system
    func createPurchaseOrder(productID: String, userID: String, amount: Decimal, currency: String) async throws -> String {
        // Create an order using IAPKit's order model
        let order = IAPOrder(
            id: UUID().uuidString,
            productID: productID,
            userInfo: ["userID": userID],
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600), // 1 hour expiration
            status: .created,
            amount: amount,
            currency: currency,
            userID: userID
        )
        
        // Send to your server
        let response = try await networkClient.createOrder(order)
        
        print("Order created successfully:")
        print("- Local ID: \(response.orderID)")
        print("- Server ID: \(response.serverOrderID)")
        print("- Status: \(response.status)")
        
        return response.serverOrderID
    }
    
    /// Example: Check order status
    func checkOrderStatus(orderID: String) async throws -> (status: String, updatedAt: Date) {
        let response = try await networkClient.queryOrderStatus(orderID)
        
        print("Order status for \(orderID):")
        print("- Status: \(response.status)")
        print("- Updated: \(response.updatedAt)")
        
        return (response.status, response.updatedAt)
    }
    
    /// Example: Complete an order
    func completeOrder(orderID: String) async throws {
        try await networkClient.updateOrderStatus(orderID, status: .completed)
        print("Order \(orderID) marked as completed")
    }
    
    /// Example: Cancel an order
    func cancelOrder(orderID: String) async throws {
        try await networkClient.cancelOrder(orderID)
        print("Order \(orderID) has been cancelled")
    }
    
    /// Example: Bulk operations
    func performMaintenanceOperations() async throws {
        // Clean up expired orders
        let cleanupResponse = try await networkClient.cleanupExpiredOrders()
        print("Maintenance completed:")
        print("- Cleaned up \(cleanupResponse.cleanedOrdersCount) expired orders")
        
        // Recover any pending orders
        let recoveryResponse = try await networkClient.recoverPendingOrders()
        print("- Recovered \(recoveryResponse.totalRecovered) pending orders")
        
        for recoveredOrder in recoveryResponse.recoveredOrders {
            print("  - Recovered order: \(recoveredOrder.serverOrderID)")
        }
    }
}

/// Example with custom authentication
class AuthenticatedNetworkClientExample {
    
    private let networkClient: NetworkClient
    
    init(baseURL: URL, apiKey: String) {
        // Create configuration with authentication
        let config = NetworkConfiguration.withAuthentication(
            baseURL: baseURL,
            authTokenProvider: {
                // In a real app, you might refresh tokens here
                return "Bearer \(apiKey)"
            }
        )
        
        self.networkClient = NetworkClient(configuration: config)
    }
    
    func createSecureOrder(productID: String, userID: String) async throws -> String {
        let order = IAPOrder.created(
            id: UUID().uuidString,
            productID: productID,
            userInfo: ["userID": userID, "source": "mobile_app"]
        )
        
        let response = try await networkClient.createOrder(order)
        return response.serverOrderID
    }
}

/// Example with custom endpoint patterns
class CustomAPINetworkClientExample {
    
    private let networkClient: NetworkClient
    
    init(baseURL: URL) {
        // Create custom endpoint builder for your API structure
        let endpointBuilder = CustomAPIEndpointBuilder(baseURL: baseURL)
        
        let config = NetworkConfiguration.withCustomEndpoints(
            baseURL: baseURL,
            endpointBuilder: endpointBuilder
        )
        
        self.networkClient = NetworkClient(configuration: config)
    }
    
    func processOrder(productID: String) async throws {
        let order = IAPOrder.created(id: UUID().uuidString, productID: productID)
        
        // This will use your custom endpoint patterns
        let response = try await networkClient.createOrder(order)
        print("Order processed with custom endpoints: \(response.serverOrderID)")
    }
}

/// Custom endpoint builder for non-standard API patterns
class CustomAPIEndpointBuilder: NetworkEndpointBuilder {
    private let baseURL: URL
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL {
        switch action {
        case .createOrder:
            // Custom pattern: /v1/commerce/orders/create
            return baseURL.appendingPathComponent("/v1/commerce/orders/create")
            
        case .queryOrderStatus:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            // Custom pattern: /v1/commerce/orders/status?id=orderID
            var components = URLComponents(url: baseURL.appendingPathComponent("/v1/commerce/orders/status"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "id", value: orderID)]
            return components.url!
            
        case .updateOrderStatus:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            // Custom pattern: /v1/commerce/orders/update/orderID
            return baseURL.appendingPathComponent("/v1/commerce/orders/update/\(orderID)")
            
        case .cancelOrder:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            // Custom pattern: /v1/commerce/orders/cancel/orderID
            return baseURL.appendingPathComponent("/v1/commerce/orders/cancel/\(orderID)")
            
        case .cleanupExpiredOrders:
            // Custom pattern: /v1/admin/cleanup-expired
            return baseURL.appendingPathComponent("/v1/admin/cleanup-expired")
            
        case .recoverPendingOrders:
            // Custom pattern: /v1/admin/recover-pending
            return baseURL.appendingPathComponent("/v1/admin/recover-pending")
        }
    }
}

/// Usage examples
func demonstrateExternalUsage() async {
    let baseURL = URL(string: "https://your-api.example.com")!
    
    do {
        // Basic usage
        let basicExample = ExternalNetworkClientExample(baseURL: baseURL)
        let serverOrderID = try await basicExample.createPurchaseOrder(
            productID: "premium_subscription",
            userID: "user123",
            amount: 9.99,
            currency: "USD"
        )
        
        let (status, _) = try await basicExample.checkOrderStatus(orderID: serverOrderID)
        
        if status == "pending" {
            try await basicExample.completeOrder(orderID: serverOrderID)
        }
        
        // Authenticated usage
        let authExample = AuthenticatedNetworkClientExample(
            baseURL: baseURL,
            apiKey: "your-api-key"
        )
        let secureOrderID = try await authExample.createSecureOrder(
            productID: "premium_feature",
            userID: "user456"
        )
        
        print("Secure order created: \(secureOrderID)")
        
        // Custom endpoint usage
        let customExample = CustomAPINetworkClientExample(baseURL: baseURL)
        try await customExample.processOrder(productID: "custom_product")
        
        // Maintenance operations
        try await basicExample.performMaintenanceOperations()
        
    } catch {
        print("Error in external network client usage: \(error)")
    }
}

/// Integration with existing systems
class ExistingSystemIntegration {
    private let networkClient: NetworkClient
    
    init() {
        // Configure for your existing API
        let config = NetworkConfiguration(
            baseURL: URL(string: "https://existing-api.company.com")!,
            timeout: 45.0,
            maxRetryAttempts: 3,
            baseRetryDelay: 2.0
        )
        
        self.networkClient = NetworkClient(configuration: config)
    }
    
    /// Integrate with existing order processing pipeline
    func integrateWithExistingPipeline(orderData: [String: Any]) async throws {
        // Convert existing order data to IAPOrder format
        let order = IAPOrder(
            id: orderData["id"] as? String ?? UUID().uuidString,
            productID: orderData["productId"] as? String ?? "",
            userInfo: orderData["metadata"] as? [String: String],
            createdAt: Date(),
            status: .created,
            amount: orderData["amount"] as? Decimal,
            currency: orderData["currency"] as? String,
            userID: orderData["userId"] as? String
        )
        
        // Process through NetworkClient
        let response = try await networkClient.createOrder(order)
        
        // Update your existing system with the response
        print("Integrated order processed: \(response.serverOrderID)")
    }
}