//
//  NetworkCustomizationTests.swift
//  IAPKitTests
//
//  Created by IAPKit
//

import XCTest
@testable import IAPKit

final class NetworkCustomizationTests: XCTestCase {
    
    // MARK: - Mock Components
    
    final class MockNetworkRequestExecutor: NetworkRequestExecutor, @unchecked Sendable {
        private var _mockResponse: (Data, URLResponse)?
        private var _mockError: Error?
        private var _executedRequests: [URLRequest] = []
        
        var mockResponse: (Data, URLResponse)? {
            get { _mockResponse }
            set { _mockResponse = newValue }
        }
        
        var mockError: Error? {
            get { _mockError }
            set { _mockError = newValue }
        }
        
        var executedRequests: [URLRequest] {
            _executedRequests
        }
        
        func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
            _executedRequests.append(request)
            let error = _mockError
            let response = _mockResponse
            
            if let error = error {
                throw error
            }
            
            return response ?? (Data(), HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }
    }
    
    final class MockNetworkResponseParser: NetworkResponseParser, @unchecked Sendable {
        private var _mockResult: Any?
        private var _mockError: Error?
        private var _parsedResponses: [(Data, URLResponse)] = []
        
        var mockResult: Any? {
            get { _mockResult }
            set { _mockResult = newValue }
        }
        
        var mockError: Error? {
            get { _mockError }
            set { _mockError = newValue }
        }
        
        var parsedResponses: [(Data, URLResponse)] {
            _parsedResponses
        }
        
        func parse<T: Codable>(_ data: Data, response: URLResponse, as type: T.Type) async throws -> T {
            _parsedResponses.append((data, response))
            let error = _mockError
            let result = _mockResult
            
            if let error = error {
                throw error
            }
            
            if let result = result as? T {
                return result
            }
            
            // Return default for EmptyResponse
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            
            throw IAPError.networkError
        }
    }
    
    final class MockNetworkRequestBuilder: NetworkRequestBuilder, @unchecked Sendable {
        private var _mockRequest: URLRequest?
        private var _mockError: Error?
        private var _buildRequests: [(URL, String, [String: Any?]?, [String: String]?)] = []
        
        var mockRequest: URLRequest? {
            get { _mockRequest }
            set { _mockRequest = newValue }
        }
        
        var mockError: Error? {
            get { _mockError }
            set { _mockError = newValue }
        }
        
        var buildRequests: [(URL, String, [String: Any?]?, [String: String]?)] {
            _buildRequests
        }
        
        func buildRequest(
            endpoint: URL,
            method: String,
            body: [String: Any?]?,
            headers: [String: String]?
        ) async throws -> URLRequest {
            _buildRequests.append((endpoint, method, body, headers))
            let error = _mockError
            let request = _mockRequest
            
            if let error = error {
                throw error
            }
            
            return request ?? URLRequest(url: endpoint)
        }
    }
    
    // MARK: - Tests
    
    func testDefaultNetworkComponents() async throws {
        // Given
        let configuration = NetworkConfiguration.default(baseURL: URL(string: "https://test.example.com")!)
        let networkClient = NetworkClient(configuration: configuration)
        
        // When/Then - Should not crash and use default components
        XCTAssertNotNil(networkClient)
    }
    
    func testCustomNetworkRequestExecutor() async throws {
        // Given
        let mockExecutor = MockNetworkRequestExecutor()
        let mockResponse = OrderCreationResponse(
            orderID: "test-order",
            serverOrderID: "server-123",
            status: "created"
        )
        
        let responseData = try JSONEncoder().encode(mockResponse)
        mockExecutor.mockResponse = (responseData, HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!)
        
        let customComponents = NetworkCustomComponents(
            requestExecutor: mockExecutor
        )
        
        let configuration = NetworkConfiguration(
            baseURL: URL(string: "https://test.com")!,
            customComponents: customComponents
        )
        
        let networkClient = NetworkClient(configuration: configuration)
        
        let testOrder = IAPOrder(
            id: "test-order",
            productID: "test-product",
            userInfo: nil,
            createdAt: Date(),
            amount: nil,
            currency: nil,
            userID: nil
        )
        
        // When
        let result = try await networkClient.createOrder(testOrder)
        
        // Then
        XCTAssertEqual(result.orderID, "test-order")
        XCTAssertEqual(result.serverOrderID, "server-123")
        let executedRequests = await mockExecutor.executedRequests
        XCTAssertEqual(executedRequests.count, 1)
    }
    
    func testCustomNetworkResponseParser() async throws {
        // Given
        let mockParser = MockNetworkResponseParser()
        let mockResponse = OrderStatusResponse(
            orderID: "test-order",
            status: "completed",
            updatedAt: Date()
        )
        mockParser.mockResult = mockResponse
        
        let customComponents = NetworkCustomComponents(
            responseParser: mockParser
        )
        
        let configuration = NetworkConfiguration(
            baseURL: URL(string: "https://test.com")!,
            customComponents: customComponents
        )
        
        let networkClient = NetworkClient(configuration: configuration)
        
        // When
        let result = try await networkClient.queryOrderStatus("test-order")
        
        // Then
        XCTAssertEqual(result.orderID, "test-order")
        XCTAssertEqual(result.status, "completed")
        let parsedResponses = await mockParser.parsedResponses
        XCTAssertEqual(parsedResponses.count, 1)
    }
    
    func testCustomNetworkRequestBuilder() async throws {
        // Given
        let mockBuilder = MockNetworkRequestBuilder()
        var customRequest = URLRequest(url: URL(string: "https://test.com")!)
        customRequest.setValue("custom-value", forHTTPHeaderField: "X-Custom-Header")
        mockBuilder.mockRequest = customRequest
        
        let customComponents = NetworkCustomComponents(
            requestBuilder: mockBuilder
        )
        
        let configuration = NetworkConfiguration(
            baseURL: URL(string: "https://test.com")!,
            customComponents: customComponents
        )
        
        let networkClient = NetworkClient(configuration: configuration)
        
        let testOrder = IAPOrder(
            id: "test-order",
            productID: "test-product",
            userInfo: nil,
            createdAt: Date(),
            amount: nil,
            currency: nil,
            userID: nil
        )
        
        // When
        do {
            _ = try await networkClient.createOrder(testOrder)
        } catch {
            // Expected to fail due to mock setup, but we check if builder was called
        }
        
        // Then
        let buildRequests = await mockBuilder.buildRequests
        XCTAssertEqual(buildRequests.count, 1)
        let (endpoint, method, body, _) = buildRequests[0]
        XCTAssertTrue(endpoint.absoluteString.contains("orders"))
        XCTAssertEqual(method, "POST")
        XCTAssertNotNil(body)
    }
    
    func testAllCustomComponents() async throws {
        // Given
        let mockExecutor = MockNetworkRequestExecutor()
        let mockParser = MockNetworkResponseParser()
        let mockBuilder = MockNetworkRequestBuilder()
        
        let mockResponse = EmptyResponse()
        mockParser.mockResult = mockResponse
        
        let responseData = Data()
        mockExecutor.mockResponse = (responseData, HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!)
        
        mockBuilder.mockRequest = URLRequest(url: URL(string: "https://test.com")!)
        
        let customComponents = NetworkCustomComponents(
            requestExecutor: mockExecutor,
            responseParser: mockParser,
            requestBuilder: mockBuilder
        )
        
        let configuration = NetworkConfiguration(
            baseURL: URL(string: "https://test.com")!,
            customComponents: customComponents
        )
        
        let networkClient = NetworkClient(configuration: configuration)
        
        // When
        try await networkClient.updateOrderStatus("test-order", status: .completed)
        
        // Then
        let buildRequests = await mockBuilder.buildRequests
        let executedRequests = await mockExecutor.executedRequests
        let parsedResponses = await mockParser.parsedResponses
        XCTAssertEqual(buildRequests.count, 1)
        XCTAssertEqual(executedRequests.count, 1)
        XCTAssertEqual(parsedResponses.count, 1)
    }
    
    func testConvenienceConfigurationMethods() {
        // Test authentication configuration
        let authConfig = NetworkConfiguration.withAuthentication(
            baseURL: URL(string: "https://api.example.com")!,
            authTokenProvider: { "test-token" }
        )
        XCTAssertNotNil(authConfig.customComponents?.requestExecutor)
        
        // Test validation configuration
        let validationConfig = NetworkConfiguration.withValidation(
            baseURL: URL(string: "https://api.example.com")!,
            validator: { _, _ in }
        )
        XCTAssertNotNil(validationConfig.customComponents?.responseParser)
        
        // Test security configuration
        let securityConfig = NetworkConfiguration.withSecurity(
            baseURL: URL(string: "https://api.example.com")!,
            additionalHeaders: ["X-API-Key": "test"]
        )
        XCTAssertNotNil(securityConfig.customComponents?.requestBuilder)
    }
    
    func testDefaultNetworkRequestExecutor() async throws {
        // Given
        let executor = DefaultNetworkRequestExecutor()
        let request = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        
        // When/Then - Should not crash (actual network call may fail in test environment)
        do {
            let (data, response) = try await executor.execute(request)
            XCTAssertNotNil(data)
            XCTAssertNotNil(response)
        } catch {
            // Network errors are expected in test environment
            XCTAssertTrue(error is URLError || error is IAPError)
        }
    }
    
    func testDefaultNetworkResponseParser() async throws {
        // Given
        let parser = DefaultNetworkResponseParser()
        let testData = """
        {
            "orderID": "test-123",
            "status": "completed",
            "updatedAt": "2023-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When
        let result = try await parser.parse(testData, response: response, as: OrderStatusResponse.self)
        
        // Then
        XCTAssertEqual(result.orderID, "test-123")
        XCTAssertEqual(result.status, "completed")
    }
    
    func testDefaultNetworkRequestBuilder() async throws {
        // Given
        let builder = DefaultNetworkRequestBuilder(timeout: 60.0)
        let endpoint = URL(string: "https://api.example.com/orders")!
        let body = ["key": "value"]
        let headers = ["X-Custom": "header"]
        
        // When
        let request = try await builder.buildRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            headers: headers
        )
        
        // Then
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.timeoutInterval, 60.0)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "header")
        XCTAssertNotNil(request.httpBody)
    }
}