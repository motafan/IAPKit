# NetworkClient - Standalone HTTP Client

The IAPKit framework includes a powerful, standalone NetworkClient that can be used independently for any HTTP-based API communication, not just in-app purchases.

## Why Use IAPKit's NetworkClient?

- **🔧 Highly Customizable**: Every component can be customized or replaced
- **🔄 Built-in Retry Logic**: Intelligent exponential backoff with configurable strategies
- **🛡️ Type-Safe**: Full Swift type safety with Codable support
- **⚡ Modern Swift**: Built with async/await and Swift Concurrency
- **🧪 Testable**: Easy to mock and test with dependency injection
- **📱 Production Ready**: Used in production iOS apps for in-app purchase management

## Quick Start

### Installation

Add IAPKit to your project and import it:

```swift
import IAPKit
```

### Basic Usage

```swift
// 1. Create configuration
let config = NetworkConfiguration.default(
    baseURL: URL(string: "https://your-api.example.com")!
)

// 2. Create client
let networkClient = NetworkClient.default(configuration: config)

// 3. Use for HTTP operations
let order = IAPOrder.created(id: "order-123", productID: "product-456")
let response = try await networkClient.createOrder(order)
```

## Supported Operations

The NetworkClient provides these HTTP operations out of the box:

| Operation | HTTP Method | Default Endpoint | Description |
|-----------|-------------|------------------|-------------|
| `createOrder` | POST | `/orders` | Create a new order |
| `queryOrderStatus` | GET | `/orders/{id}/status` | Get order status |
| `updateOrderStatus` | PUT | `/orders/{id}/status` | Update order status |
| `cancelOrder` | DELETE | `/orders/{id}` | Cancel an order |
| `cleanupExpiredOrders` | POST | `/orders/cleanup` | Clean expired orders |
| `recoverPendingOrders` | GET | `/orders/recovery` | Recover pending orders |

## Customization Examples

### Custom Endpoints

```swift
class MyAPIEndpointBuilder: NetworkEndpointBuilder {
    func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL {
        switch action {
        case .createOrder:
            return baseURL.appendingPathComponent("/v2/purchases")
        case .queryOrderStatus:
            return baseURL.appendingPathComponent("/v2/purchases/\(parameters["orderID"]!)")
        // ... other cases
        }
    }
}

let config = NetworkConfiguration.withCustomEndpoints(
    baseURL: baseURL,
    endpointBuilder: MyAPIEndpointBuilder(baseURL: baseURL)
)
```

### Authentication

```swift
let config = NetworkConfiguration.withAuthentication(
    baseURL: baseURL,
    authTokenProvider: {
        return await getAuthToken() // Your token logic
    }
)
```

### Custom Request/Response Handling

```swift
let networkClient = NetworkClient.custom(
    baseURL: baseURL,
    requestExecutor: MyCustomRequestExecutor(),
    responseParser: MyCustomResponseParser(),
    requestBuilder: MyCustomRequestBuilder()
)
```

## Use Cases

### E-commerce Integration

```swift
class ECommerceAPI {
    private let networkClient: NetworkClient
    
    init(baseURL: URL) {
        let config = NetworkConfiguration.default(baseURL: baseURL)
        self.networkClient = NetworkClient(configuration: config)
    }
    
    func createPurchaseOrder(productID: String, userID: String) async throws -> String {
        let order = IAPOrder.created(id: UUID().uuidString, productID: productID)
        let response = try await networkClient.createOrder(order)
        return response.serverOrderID
    }
}
```

### Microservices Communication

```swift
class OrderMicroservice {
    private let networkClient: NetworkClient
    
    init(serviceURL: URL) {
        let config = NetworkConfiguration(
            baseURL: serviceURL,
            timeout: 30.0,
            maxRetryAttempts: 5
        )
        self.networkClient = NetworkClient(configuration: config)
    }
    
    func processOrder(_ order: IAPOrder) async throws {
        let response = try await networkClient.createOrder(order)
        // Handle response...
    }
}
```

### Legacy System Integration

```swift
class LegacySystemAdapter {
    private let networkClient: NetworkClient
    
    func migrateOrder(legacyOrderData: [String: Any]) async throws {
        // Convert legacy data to IAPOrder
        let order = convertLegacyOrder(legacyOrderData)
        
        // Process with modern NetworkClient
        let response = try await networkClient.createOrder(order)
        
        // Update legacy system with new ID
        updateLegacySystem(with: response.serverOrderID)
    }
}
```

## Advanced Features

### Retry Configuration

```swift
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

### Response Models

The NetworkClient returns structured response models:

```swift
struct OrderCreationResponse {
    let orderID: String           // Your local order ID
    let serverOrderID: String     // Server-assigned ID
    let status: String           // Current status
    let expiresAt: Date?         // Optional expiration
    let metadata: [String: String]? // Additional data
}
```

### Error Handling

```swift
do {
    let response = try await networkClient.createOrder(order)
} catch let error as IAPError {
    switch error {
    case .networkError:
        // Handle network issues
    case .orderCreationFailed(let reason):
        // Handle creation failure
    default:
        // Handle other errors
    }
}
```

## Testing

Easy to mock for testing:

```swift
class MockNetworkClient: NetworkClientProtocol {
    func createOrder(_ order: IAPOrder) async throws -> OrderCreationResponse {
        return OrderCreationResponse(
            orderID: order.id,
            serverOrderID: "mock-server-id",
            status: "created"
        )
    }
}
```

## Documentation

- **[Complete External Usage Guide](EXTERNAL_NETWORK_CLIENT_USAGE.md)** - Comprehensive guide with examples
- **[Endpoint Builder Guide](NETWORK_ENDPOINT_BUILDER_GUIDE.md)** - Custom endpoint patterns
- **[Customization Guide](NETWORK_CUSTOMIZATION_GUIDE.md)** - Advanced customization options

## Why Not Just Use URLSession?

While you could use URLSession directly, IAPKit's NetworkClient provides:

- **Built-in retry logic** with exponential backoff
- **Type-safe request/response handling** with Codable
- **Consistent error handling** across all operations
- **Easy customization** without boilerplate code
- **Production-tested reliability** from real-world usage
- **Structured response models** for common operations

## Performance

- Reuses URLSession connections for efficiency
- Memory-efficient design with proper cleanup
- Async/await throughout for optimal concurrency
- Built-in request/response caching where appropriate

## License

Same as IAPKit framework - see LICENSE file for details.

---

**Ready to get started?** Check out the [complete examples](../Examples/ExternalNetworkClientUsage.swift) or read the [detailed usage guide](EXTERNAL_NETWORK_CLIENT_USAGE.md).