# External NetworkClient Usage Guide

The IAPKit framework provides a powerful and flexible NetworkClient that can be used independently outside the framework for general HTTP operations or custom order management systems.

## Overview

The NetworkClient is designed with modularity and extensibility in mind, allowing you to:

- **Use it standalone** for any HTTP-based API communication
- **Customize every aspect** of request/response handling
- **Integrate with existing systems** using familiar patterns
- **Build custom order management** solutions

## Quick Start

### Basic Usage

```swift
import IAPKit

// Create a basic configuration
let config = NetworkConfiguration.default(
    baseURL: URL(string: "https://your-api.example.com")!
)

// Create the network client
let networkClient = NetworkClient.default(configuration: config)

// Use the client for order operations
let order = IAPOrder.created(id: "order-123", productID: "product-456")
let response = try await networkClient.createOrder(order)
```

### Custom Configuration

```swift
import IAPKit

// Create custom configuration with timeout and retry settings
let config = NetworkConfiguration(
    baseURL: URL(string: "https://your-api.example.com")!,
    timeout: 60.0,
    maxRetryAttempts: 5,
    baseRetryDelay: 2.0
)

let networkClient = NetworkClient(configuration: config)
```

## Available Operations

The NetworkClient supports all OrderServiceProtocol operations:

### Order Management

```swift
// Create a new order
let order = IAPOrder.created(id: "order-123", productID: "product-456")
let createResponse = try await networkClient.createOrder(order)

// Query order status
let statusResponse = try await networkClient.queryOrderStatus("order-123")

// Update order status
try await networkClient.updateOrderStatus("order-123", status: .completed)

// Cancel an order
try await networkClient.cancelOrder("order-123")
```

### Maintenance Operations

```swift
// Clean up expired orders
let cleanupResponse = try await networkClient.cleanupExpiredOrders()
print("Cleaned up \(cleanupResponse.cleanedOrdersCount) orders")

// Recover pending orders
let recoveryResponse = try await networkClient.recoverPendingOrders()
print("Recovered \(recoveryResponse.totalRecovered) orders")
```

## Customization Options

### 1. Custom Endpoint Builder

Create custom URL patterns for your API:

```swift
class CustomEndpointBuilder: NetworkEndpointBuilder {
    private let baseURL: URL
    private let apiVersion: String
    
    init(baseURL: URL, apiVersion: String = "v1") {
        self.baseURL = baseURL
        self.apiVersion = apiVersion
    }
    
    func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL {
        switch action {
        case .createOrder:
            return baseURL.appendingPathComponent("/api/\(apiVersion)/orders")
        case .queryOrderStatus:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID")
            }
            return baseURL.appendingPathComponent("/api/\(apiVersion)/orders/\(orderID)")
        // ... handle other cases
        }
    }
}

// Use custom endpoint builder
let customBuilder = CustomEndpointBuilder(baseURL: baseURL, apiVersion: "v2")
let config = NetworkConfiguration.withCustomEndpoints(
    baseURL: baseURL,
    endpointBuilder: customBuilder
)
let networkClient = NetworkClient(configuration: config)
```

### 2. Authentication

Add authentication to all requests:

```swift
let config = NetworkConfiguration.withAuthentication(
    baseURL: URL(string: "https://your-api.example.com")!,
    authTokenProvider: {
        // Your token retrieval logic
        return await getAuthToken()
    }
)
let networkClient = NetworkClient(configuration: config)
```

### 3. Custom Request/Response Handling

```swift
// Custom request executor with logging
class LoggingRequestExecutor: NetworkRequestExecutor {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        print("Executing request: \(request.url?.absoluteString ?? "unknown")")
        let result = try await session.data(for: request)
        print("Request completed with \(result.0.count) bytes")
        return result
    }
}

// Custom response parser with validation
class ValidatingResponseParser: NetworkResponseParser {
    private let decoder = JSONDecoder()
    
    func parse<T: Codable>(_ data: Data, response: URLResponse, as type: T.Type) async throws -> T {
        // Custom validation logic
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IAPError.networkError
        }
        
        // Check custom headers
        if let customHeader = httpResponse.allHeaderFields["X-API-Version"] as? String {
            print("API Version: \(customHeader)")
        }
        
        return try decoder.decode(T.self, from: data)
    }
}

// Create client with custom components
let networkClient = NetworkClient.custom(
    baseURL: URL(string: "https://your-api.example.com")!,
    requestExecutor: LoggingRequestExecutor(),
    responseParser: ValidatingResponseParser(),
    requestBuilder: DefaultNetworkRequestBuilder(),
    endpointBuilder: DefaultNetworkEndpointBuilder(baseURL: baseURL)
)
```

## Integration Patterns

### 1. Dependency Injection

```swift
protocol OrderServiceProtocol {
    func createOrder(for product: IAPProduct, userInfo: [String: any Sendable]?) async throws -> IAPOrder
    // ... other methods
}

class CustomOrderService: OrderServiceProtocol {
    private let networkClient: NetworkClientProtocol
    
    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }
    
    func createOrder(for product: IAPProduct, userInfo: [String: any Sendable]?) async throws -> IAPOrder {
        let order = IAPOrder.created(
            id: UUID().uuidString,
            productID: product.id,
            userInfo: userInfo?.compactMapValues { $0 as? String }
        )
        
        let response = try await networkClient.createOrder(order)
        return order.withServerOrderID(response.serverOrderID)
    }
}

// Usage
let networkClient = NetworkClient.default(configuration: config)
let orderService = CustomOrderService(networkClient: networkClient)
```

### 2. Wrapper for Existing APIs

```swift
class APIWrapper {
    private let networkClient: NetworkClient
    
    init(baseURL: URL) {
        let config = NetworkConfiguration.default(baseURL: baseURL)
        self.networkClient = NetworkClient(configuration: config)
    }
    
    // Wrap your existing API calls
    func createPurchaseOrder(productID: String, userID: String) async throws -> String {
        let order = IAPOrder.created(
            id: UUID().uuidString,
            productID: productID,
            userInfo: ["userID": userID]
        )
        
        let response = try await networkClient.createOrder(order)
        return response.serverOrderID
    }
    
    func checkOrderStatus(orderID: String) async throws -> String {
        let response = try await networkClient.queryOrderStatus(orderID)
        return response.status
    }
}
```

## Error Handling

The NetworkClient provides comprehensive error handling:

```swift
do {
    let response = try await networkClient.createOrder(order)
    // Handle success
} catch let error as IAPError {
    switch error {
    case .networkError:
        // Handle network issues
        print("Network error occurred")
    case .orderCreationFailed(let reason):
        // Handle order creation failure
        print("Order creation failed: \(reason)")
    case .configurationError(let message):
        // Handle configuration issues
        print("Configuration error: \(message)")
    default:
        // Handle other errors
        print("Unexpected error: \(error)")
    }
} catch {
    // Handle other types of errors
    print("Unknown error: \(error)")
}
```

## Response Models

The NetworkClient returns structured response models:

```swift
// Order creation response
struct OrderCreationResponse {
    let orderID: String           // Your local order ID
    let serverOrderID: String     // Server-assigned ID
    let status: String           // Current status
    let expiresAt: Date?         // Optional expiration
    let metadata: [String: String]? // Additional data
}

// Order status response
struct OrderStatusResponse {
    let orderID: String
    let status: String
    let updatedAt: Date
    let metadata: [String: String]?
}

// Recovery response
struct OrderRecoveryResponse {
    let recoveredOrders: [OrderCreationResponse]
    let totalRecovered: Int
    let timestamp: Date
}

// Cleanup response
struct CleanupResponse {
    let cleanedOrdersCount: Int
    let timestamp: Date
}
```

## Best Practices

### 1. Configuration Management

```swift
// Create a configuration factory
struct NetworkConfigurationFactory {
    static func production() -> NetworkConfiguration {
        return NetworkConfiguration(
            baseURL: URL(string: "https://api.production.com")!,
            timeout: 30.0,
            maxRetryAttempts: 3
        )
    }
    
    static func development() -> NetworkConfiguration {
        return NetworkConfiguration(
            baseURL: URL(string: "https://api.dev.com")!,
            timeout: 60.0,
            maxRetryAttempts: 5
        )
    }
}
```

### 2. Retry Strategy

```swift
// Custom retry configuration
let retryConfig = RetryConfiguration(
    maxRetries: 5,
    baseDelay: 1.0,
    maxDelay: 30.0,
    backoffMultiplier: 2.0,
    strategy: .exponential
)

let retryManager = RetryManager(configuration: retryConfig)
let networkClient = NetworkClient(configuration: config, retryManager: retryManager)
```

### 3. Testing

```swift
// Create mock implementations for testing
class MockNetworkClient: NetworkClientProtocol {
    var mockResponses: [String: Any] = [:]
    
    func createOrder(_ order: IAPOrder) async throws -> OrderCreationResponse {
        return OrderCreationResponse(
            orderID: order.id,
            serverOrderID: "mock-server-id",
            status: "created"
        )
    }
    
    // ... implement other methods
}

// Use in tests
let mockClient = MockNetworkClient()
let orderService = CustomOrderService(networkClient: mockClient)
```

## Migration from Internal Usage

If you're migrating from internal IAPKit usage to external NetworkClient usage:

```swift
// Before (internal usage)
let iapManager = IAPManager.shared
let order = try await iapManager.createOrder(for: product)

// After (external usage)
let networkClient = NetworkClient.default(configuration: config)
let order = IAPOrder.created(id: UUID().uuidString, productID: product.id)
let response = try await networkClient.createOrder(order)
```

## Performance Considerations

- **Connection Pooling**: The NetworkClient reuses URLSession connections
- **Retry Logic**: Built-in exponential backoff prevents overwhelming servers
- **Memory Management**: All components are designed to be memory-efficient
- **Concurrency**: Full async/await support with proper actor isolation

## Support and Documentation

- See `NETWORK_ENDPOINT_BUILDER_GUIDE.md` for detailed endpoint customization
- See `NETWORK_CUSTOMIZATION_GUIDE.md` for advanced customization options
- Check the Examples folder for complete implementation examples

The NetworkClient provides a robust foundation for any HTTP-based API communication while maintaining the flexibility to adapt to your specific requirements.