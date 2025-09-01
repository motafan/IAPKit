# Network Endpoint Builder Guide

This guide explains how the NetworkClient has been enhanced to build endpoints based on different OrderServiceProtocol actions, providing flexible and customizable URL construction.

## Overview

The NetworkClient now uses an action-based approach to build endpoints, where each OrderServiceProtocol action maps to specific HTTP methods and URL patterns. This allows for:

- **Consistent endpoint patterns** across different operations
- **Customizable URL structures** through custom endpoint builders
- **Automatic parameter substitution** in URL paths
- **Type-safe action definitions** with associated HTTP methods

## Core Components

### OrderServiceAction Enum

```swift
public enum OrderServiceAction: String, Sendable, CaseIterable {
    case createOrder = "create_order"
    case queryOrderStatus = "query_order_status"
    case updateOrderStatus = "update_order_status"
    case cancelOrder = "cancel_order"
    case cleanupExpiredOrders = "cleanup_expired_orders"
    case recoverPendingOrders = "recover_pending_orders"
}
```

Each action includes:
- **HTTP Method**: Automatically determined based on the action type
- **Default Path**: Standard REST-style path pattern
- **Parameter Support**: URL parameter substitution (e.g., `{orderID}`)

### NetworkEndpointBuilder Protocol

```swift
public protocol NetworkEndpointBuilder: Sendable {
    func buildEndpoint(for action: OrderServiceAction, parameters: [String: String]) async throws -> URL
}
```

This protocol allows custom endpoint building logic while maintaining consistency with the action-based approach.

## Default Endpoint Patterns

| Action | HTTP Method | Default Path | Example URL |
|--------|-------------|--------------|-------------|
| `createOrder` | POST | `orders` | `POST /orders` |
| `queryOrderStatus` | GET | `orders/{orderID}/status` | `GET /orders/12345/status` |
| `updateOrderStatus` | PUT | `orders/{orderID}/status` | `PUT /orders/12345/status` |
| `cancelOrder` | DELETE | `orders/{orderID}` | `DELETE /orders/12345` |
| `cleanupExpiredOrders` | POST | `orders/cleanup` | `POST /orders/cleanup` |
| `recoverPendingOrders` | GET | `orders/recovery` | `GET /orders/recovery` |

## Usage Examples

### Using Default Endpoint Builder

```swift
// Create configuration with default endpoint builder
let config = NetworkConfiguration.default(baseURL: URL(string: "https://api.example.com")!)
let networkClient = NetworkClient(configuration: config)

// The client automatically builds endpoints:
// createOrder -> POST https://api.example.com/orders
// queryOrderStatus -> GET https://api.example.com/orders/{orderID}/status
```

### Using Custom Endpoint Builder

```swift
// Create custom endpoint builder
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
            return baseURL.appendingPathComponent("/api/\(apiVersion)/purchase/orders")
        case .queryOrderStatus:
            guard let orderID = parameters["orderID"] else {
                throw IAPError.configurationError("Missing orderID parameter")
            }
            return baseURL.appendingPathComponent("/api/\(apiVersion)/purchase/orders/\(orderID)")
        // ... other cases
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

### Built-in Custom Endpoint Builders

The framework includes several pre-built custom endpoint builders:

#### VersionedNetworkEndpointBuilder

```swift
let versionedBuilder = VersionedNetworkEndpointBuilder(
    baseURL: URL(string: "https://api.example.com")!,
    apiVersion: "v2",
    pathPrefix: "api"
)

// Generates URLs like: https://api.example.com/api/v2/orders
```

## NetworkClient Integration

The NetworkClient automatically uses the endpoint builder to construct URLs:

```swift
// Internal NetworkClient method
private func performRequest<T: Codable>(
    action: OrderServiceAction,
    endpoint: URL,
    body: [String: Any?]?,
    responseType: T.Type
) async throws -> T {
    // Build request using action's HTTP method
    let request = try await requestBuilder.buildRequest(
        endpoint: endpoint,
        method: action.httpMethod,  // Automatically uses correct HTTP method
        body: body
    )
    // ... rest of implementation
}
```

## Configuration Options

### Default Configuration

```swift
let config = NetworkConfiguration.default(baseURL: URL(string: "https://api.example.com")!)
// Uses DefaultNetworkEndpointBuilder with standard REST patterns
```

### Custom Endpoint Configuration

```swift
let config = NetworkConfiguration.withCustomEndpoints(
    baseURL: baseURL,
    endpointBuilder: customEndpointBuilder
)
```

### Combined Custom Components

```swift
let customComponents = NetworkCustomComponents(
    requestExecutor: customExecutor,
    responseParser: customParser,
    requestBuilder: customBuilder,
    endpointBuilder: customEndpointBuilder
)

let config = NetworkConfiguration(
    baseURL: baseURL,
    customComponents: customComponents
)
```

## Benefits

1. **Consistency**: All network operations follow the same pattern
2. **Flexibility**: Easy to customize URL structures for different APIs
3. **Type Safety**: Actions are strongly typed with associated HTTP methods
4. **Maintainability**: Centralized endpoint logic
5. **Testability**: Easy to mock and test different endpoint patterns

## Migration from Previous Version

If you were previously using hardcoded endpoints, the migration is straightforward:

**Before:**
```swift
let endpoint = baseURL.appendingPathComponent("orders/\(orderID)/status")
```

**After:**
```swift
let endpoint = try await endpointBuilder.buildEndpoint(
    for: .queryOrderStatus,
    parameters: ["orderID": orderID]
)
```

The NetworkClient handles this automatically, so most existing code will continue to work without changes.

## Error Handling

The endpoint builder can throw errors for invalid configurations:

```swift
// Missing required parameter
guard let orderID = parameters["orderID"] else {
    throw IAPError.configurationError("Missing orderID parameter")
}
```

These errors are propagated through the NetworkClient's error handling system.

## Best Practices

1. **Use Default Builder**: Start with the default endpoint builder for standard REST APIs
2. **Custom Builders for Special Cases**: Create custom builders for non-standard API patterns
3. **Parameter Validation**: Always validate required parameters in custom builders
4. **Consistent Patterns**: Maintain consistent URL patterns within your custom builder
5. **Error Handling**: Provide clear error messages for configuration issues

## Testing

The action-based approach makes testing easier:

```swift
func testEndpointBuilding() async throws {
    let builder = DefaultNetworkEndpointBuilder(baseURL: URL(string: "https://test.com")!)
    
    let endpoint = try await builder.buildEndpoint(
        for: .createOrder,
        parameters: [:]
    )
    
    XCTAssertEqual(endpoint.absoluteString, "https://test.com/orders")
}
```

This enhancement provides a robust foundation for network operations while maintaining flexibility for different API requirements.