//
//  ExternalUsageTests.swift
//  IAPKitTests
//
//  Tests for external NetworkClient usage
//

import XCTest
@testable import IAPKit

final class ExternalUsageTests: XCTestCase {
    
    func testNetworkClientPublicAPI() {
        let baseURL = URL(string: "https://api.example.com")!
        
        // Test public configuration creation
        let config = NetworkConfiguration.default(baseURL: baseURL)
        XCTAssertEqual(config.baseURL, baseURL)
        
        // Test public NetworkClient creation
        let networkClient = NetworkClient.default(configuration: config)
        XCTAssertNotNil(networkClient)
        
        // Test custom NetworkClient creation
        let customClient = NetworkClient.custom(
            baseURL: baseURL,
            requestExecutor: DefaultNetworkRequestExecutor(),
            responseParser: DefaultNetworkResponseParser(),
            requestBuilder: DefaultNetworkRequestBuilder()
        )
        XCTAssertNotNil(customClient)
    }
    
    func testOrderServiceActionProperties() {
        // Test that OrderServiceAction is publicly accessible
        let actions = OrderServiceAction.allCases
        XCTAssertEqual(actions.count, 6)
        
        // Test HTTP methods are correct
        XCTAssertEqual(OrderServiceAction.createOrder.httpMethod, "POST")
        XCTAssertEqual(OrderServiceAction.queryOrderStatus.httpMethod, "GET")
        XCTAssertEqual(OrderServiceAction.updateOrderStatus.httpMethod, "PUT")
        XCTAssertEqual(OrderServiceAction.cancelOrder.httpMethod, "DELETE")
        XCTAssertEqual(OrderServiceAction.cleanupExpiredOrders.httpMethod, "POST")
        XCTAssertEqual(OrderServiceAction.recoverPendingOrders.httpMethod, "GET")
    }
    
    func testPublicResponseModels() {
        // Test OrderCreationResponse
        let orderResponse = OrderCreationResponse(
            orderID: "local-123",
            serverOrderID: "server-456",
            status: "created"
        )
        XCTAssertEqual(orderResponse.orderID, "local-123")
        XCTAssertEqual(orderResponse.serverOrderID, "server-456")
        XCTAssertEqual(orderResponse.status, "created")
        
        // Test OrderStatusResponse
        let statusResponse = OrderStatusResponse(
            orderID: "order-123",
            status: "completed",
            updatedAt: Date()
        )
        XCTAssertEqual(statusResponse.orderID, "order-123")
        XCTAssertEqual(statusResponse.status, "completed")
        
        // Test CleanupResponse
        let cleanupResponse = CleanupResponse(cleanedOrdersCount: 5)
        XCTAssertEqual(cleanupResponse.cleanedOrdersCount, 5)
        
        // Test OrderRecoveryResponse
        let recoveryResponse = OrderRecoveryResponse(
            recoveredOrders: [orderResponse],
            totalRecovered: 1
        )
        XCTAssertEqual(recoveryResponse.totalRecovered, 1)
        XCTAssertEqual(recoveryResponse.recoveredOrders.count, 1)
    }
    
    func testCustomEndpointBuilder() async throws {
        let baseURL = URL(string: "https://api.example.com")!
        let builder = DefaultNetworkEndpointBuilder(baseURL: baseURL)
        
        // Test createOrder endpoint
        let createEndpoint = try await builder.buildEndpoint(for: .createOrder, parameters: [:])
        XCTAssertEqual(createEndpoint.absoluteString, "https://api.example.com/orders")
        
        // Test queryOrderStatus endpoint
        let queryEndpoint = try await builder.buildEndpoint(
            for: .queryOrderStatus,
            parameters: ["orderID": "test-123"]
        )
        XCTAssertEqual(queryEndpoint.absoluteString, "https://api.example.com/orders/test-123/status")
    }
    
    func testVersionedEndpointBuilder() async throws {
        let baseURL = URL(string: "https://api.example.com")!
        let builder = VersionedNetworkEndpointBuilder(
            baseURL: baseURL,
            apiVersion: "v2",
            pathPrefix: "api"
        )
        
        // Test versioned endpoint
        let endpoint = try await builder.buildEndpoint(for: .createOrder, parameters: [:])
        XCTAssertEqual(endpoint.absoluteString, "https://api.example.com/api/v2/orders")
    }
    
    func testNetworkConfigurationFactoryMethods() {
        let baseURL = URL(string: "https://api.example.com")!
        
        // Test default configuration
        let defaultConfig = NetworkConfiguration.default(baseURL: baseURL)
        XCTAssertEqual(defaultConfig.baseURL, baseURL)
        XCTAssertEqual(defaultConfig.timeout, 30.0)
        XCTAssertEqual(defaultConfig.maxRetryAttempts, 3)
        
        // Test custom endpoint configuration
        let endpointBuilder = DefaultNetworkEndpointBuilder(baseURL: baseURL)
        let customConfig = NetworkConfiguration.withCustomEndpoints(
            baseURL: baseURL,
            endpointBuilder: endpointBuilder
        )
        XCTAssertEqual(customConfig.baseURL, baseURL)
        XCTAssertNotNil(customConfig.customComponents?.endpointBuilder)
    }
    
    func testPublicIAPOrderCreation() {
        // Test that IAPOrder can be created publicly
        let order = IAPOrder.created(
            id: "test-order",
            productID: "test-product",
            userInfo: ["key": "value"]
        )
        
        XCTAssertEqual(order.id, "test-order")
        XCTAssertEqual(order.productID, "test-product")
        XCTAssertEqual(order.status, .created)
        XCTAssertEqual(order.userInfo?["key"], "value")
        
        // Test order with amount
        let paidOrder = order.withAmount(9.99, currency: "USD")
        XCTAssertEqual(paidOrder.amount, 9.99)
        XCTAssertEqual(paidOrder.currency, "USD")
    }
    
    func testRetryManagerPublicAPI() {
        // Test that RetryManager is publicly accessible
        let retryConfig = RetryConfiguration.default
        let retryManager = RetryManager(configuration: retryConfig)
        
        XCTAssertNotNil(retryManager)
        
        // Test custom retry configuration
        let customConfig = RetryConfiguration(
            maxRetries: 5,
            baseDelay: 2.0,
            maxDelay: 60.0,
            backoffMultiplier: 2.0,
            strategy: .exponential
        )
        
        XCTAssertEqual(customConfig.maxRetries, 5)
        XCTAssertEqual(customConfig.baseDelay, 2.0)
        XCTAssertEqual(customConfig.maxDelay, 60.0)
        XCTAssertEqual(customConfig.backoffMultiplier, 2.0)
    }
    
    func testExternalUsageScenario() {
        // Simulate external usage scenario
        let baseURL = URL(string: "https://my-ecommerce-api.com")!
        
        // 1. Create configuration
        let config = NetworkConfiguration(
            baseURL: baseURL,
            timeout: 45.0,
            maxRetryAttempts: 5,
            baseRetryDelay: 1.5
        )
        
        // 2. Create network client
        let networkClient = NetworkClient.default(configuration: config)
        
        // 3. Create order for external system
        let order = IAPOrder(
            id: UUID().uuidString,
            productID: "premium_subscription",
            userInfo: ["userID": "user123", "source": "mobile_app"],
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            status: .created,
            amount: 9.99,
            currency: "USD",
            userID: "user123"
        )
        
        // Verify order is properly configured
        XCTAssertEqual(order.productID, "premium_subscription")
        XCTAssertEqual(order.amount, 9.99)
        XCTAssertEqual(order.currency, "USD")
        XCTAssertEqual(order.userID, "user123")
        XCTAssertEqual(order.status, .created)
        
        // Verify network client is ready
        XCTAssertNotNil(networkClient)
    }
}