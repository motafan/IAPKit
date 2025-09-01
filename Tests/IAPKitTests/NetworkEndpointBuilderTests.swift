//
//  NetworkEndpointBuilderTests.swift
//  IAPKitTests
//
//  Tests for the NetworkEndpointBuilder functionality
//

import XCTest
@testable import IAPKit

final class NetworkEndpointBuilderTests: XCTestCase {
    
    func testDefaultEndpointBuilder() async throws {
        let baseURL = URL(string: "https://api.example.com")!
        let builder = DefaultNetworkEndpointBuilder(baseURL: baseURL)
        
        // Test createOrder endpoint
        let createOrderEndpoint = try await builder.buildEndpoint(for: .createOrder, parameters: [:])
        XCTAssertEqual(createOrderEndpoint.absoluteString, "https://api.example.com/orders")
        
        // Test queryOrderStatus endpoint
        let queryEndpoint = try await builder.buildEndpoint(
            for: .queryOrderStatus,
            parameters: ["orderID": "12345"]
        )
        XCTAssertEqual(queryEndpoint.absoluteString, "https://api.example.com/orders/12345/status")
        
        // Test updateOrderStatus endpoint
        let updateEndpoint = try await builder.buildEndpoint(
            for: .updateOrderStatus,
            parameters: ["orderID": "67890"]
        )
        XCTAssertEqual(updateEndpoint.absoluteString, "https://api.example.com/orders/67890/status")
        
        // Test cancelOrder endpoint
        let cancelEndpoint = try await builder.buildEndpoint(
            for: .cancelOrder,
            parameters: ["orderID": "abc123"]
        )
        XCTAssertEqual(cancelEndpoint.absoluteString, "https://api.example.com/orders/abc123")
        
        // Test cleanupExpiredOrders endpoint
        let cleanupEndpoint = try await builder.buildEndpoint(for: .cleanupExpiredOrders, parameters: [:])
        XCTAssertEqual(cleanupEndpoint.absoluteString, "https://api.example.com/orders/cleanup")
        
        // Test recoverPendingOrders endpoint
        let recoveryEndpoint = try await builder.buildEndpoint(for: .recoverPendingOrders, parameters: [:])
        XCTAssertEqual(recoveryEndpoint.absoluteString, "https://api.example.com/orders/recovery")
    }
    
    func testOrderServiceActionProperties() {
        // Test HTTP methods
        XCTAssertEqual(OrderServiceAction.createOrder.httpMethod, "POST")
        XCTAssertEqual(OrderServiceAction.queryOrderStatus.httpMethod, "GET")
        XCTAssertEqual(OrderServiceAction.updateOrderStatus.httpMethod, "PUT")
        XCTAssertEqual(OrderServiceAction.cancelOrder.httpMethod, "DELETE")
        XCTAssertEqual(OrderServiceAction.cleanupExpiredOrders.httpMethod, "POST")
        XCTAssertEqual(OrderServiceAction.recoverPendingOrders.httpMethod, "GET")
        
        // Test default paths
        XCTAssertEqual(OrderServiceAction.createOrder.defaultPath, "orders")
        XCTAssertEqual(OrderServiceAction.queryOrderStatus.defaultPath, "orders/{orderID}/status")
        XCTAssertEqual(OrderServiceAction.updateOrderStatus.defaultPath, "orders/{orderID}/status")
        XCTAssertEqual(OrderServiceAction.cancelOrder.defaultPath, "orders/{orderID}")
        XCTAssertEqual(OrderServiceAction.cleanupExpiredOrders.defaultPath, "orders/cleanup")
        XCTAssertEqual(OrderServiceAction.recoverPendingOrders.defaultPath, "orders/recovery")
    }
    
    func testVersionedEndpointBuilder() async throws {
        let baseURL = URL(string: "https://api.example.com")!
        let builder = VersionedNetworkEndpointBuilder(
            baseURL: baseURL,
            apiVersion: "v2",
            pathPrefix: "api"
        )
        
        // Test createOrder endpoint with versioning
        let createOrderEndpoint = try await builder.buildEndpoint(for: .createOrder, parameters: [:])
        XCTAssertEqual(createOrderEndpoint.absoluteString, "https://api.example.com/api/v2/orders")
        
        // Test queryOrderStatus endpoint with versioning
        let queryEndpoint = try await builder.buildEndpoint(
            for: .queryOrderStatus,
            parameters: ["orderID": "test-order"]
        )
        XCTAssertEqual(queryEndpoint.absoluteString, "https://api.example.com/api/v2/orders/test-order/status")
    }
    
    func testNetworkConfigurationWithCustomEndpoints() {
        let baseURL = URL(string: "https://api.example.com")!
        let customBuilder = VersionedNetworkEndpointBuilder(baseURL: baseURL, apiVersion: "v3")
        
        let config = NetworkConfiguration.withCustomEndpoints(
            baseURL: baseURL,
            endpointBuilder: customBuilder
        )
        
        XCTAssertEqual(config.baseURL, baseURL)
        XCTAssertNotNil(config.customComponents?.endpointBuilder)
    }
    
    func testNetworkClientWithEndpointBuilder() {
        let baseURL = URL(string: "https://api.example.com")!
        let config = NetworkConfiguration.default(baseURL: baseURL)
        
        // This should not throw and should create a client with default endpoint builder
        let networkClient = NetworkClient(configuration: config)
        XCTAssertNotNil(networkClient)
    }
}