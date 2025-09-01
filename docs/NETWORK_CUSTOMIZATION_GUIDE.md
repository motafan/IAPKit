# Network Customization Guide

IAPKit 提供了灵活的网络层设计，允许你自定义请求发送、响应解析和请求构建的各个环节。

## 概述

网络层由三个核心组件组成：

1. **NetworkRequestExecutor** - 负责执行 HTTP 请求
2. **NetworkResponseParser** - 负责解析响应数据
3. **NetworkRequestBuilder** - 负责构建请求对象

## 默认实现

框架提供了开箱即用的默认实现：

```swift
// 使用默认网络配置初始化
await IAPManager.shared.initialize(networkBaseURL: URL(string: "https://your-api.com")!)

// 或者自定义网络配置
let customConfig = NetworkConfiguration(
    baseURL: URL(string: "https://your-api.com")!,
    timeout: 30.0,
    maxRetryAttempts: 3
)

let iapConfig = IAPConfiguration(
    networkConfiguration: customConfig
)

let manager = IAPManager(configuration: iapConfig)
```

## 自定义组件

### 1. 自定义请求执行器

添加认证支持：

```swift
// 创建带认证的请求执行器
let authExecutor = AuthenticatedNetworkRequestExecutor { 
    // 返回认证 token
    return await getAuthToken()
}

let customComponents = NetworkCustomComponents(
    requestExecutor: authExecutor
)

let configuration = NetworkConfiguration(
    baseURL: URL(string: "https://your-api.com")!,
    customComponents: customComponents
)
```

### 2. 自定义响应解析器

添加响应验证：

```swift
let validatingParser = ValidatingNetworkResponseParser { data, response in
    // 自定义验证逻辑
    guard let httpResponse = response as? HTTPURLResponse else {
        throw IAPError.networkError
    }
    
    // 检查自定义头部
    if httpResponse.allHeaderFields["X-API-Version"] as? String != "2.0" {
        throw IAPError.networkError
    }
}

let customComponents = NetworkCustomComponents(
    responseParser: validatingParser
)
```

### 3. 自定义请求构建器

添加加密和额外头部：

```swift
let secureBuilder = SecureNetworkRequestBuilder(
    additionalHeaders: [
        "X-API-Key": "your-api-key",
        "X-Client-Version": "1.0.0"
    ],
    encryptBody: { data in
        // 加密请求体
        return try await encryptData(data)
    }
)

let customComponents = NetworkCustomComponents(
    requestBuilder: secureBuilder
)
```

## 完整自定义示例

```swift
// 创建完全自定义的网络配置
let customExecutor = AuthenticatedNetworkRequestExecutor { 
    return await AuthService.shared.getToken()
}

let customParser = ValidatingNetworkResponseParser { data, response in
    // 验证响应签名
    try await validateResponseSignature(data, response)
}

let customBuilder = SecureNetworkRequestBuilder(
    additionalHeaders: [
        "X-API-Key": "your-api-key",
        "X-Client-ID": "your-client-id"
    ],
    encryptBody: { data in
        return try await CryptoService.encrypt(data)
    }
)

let customComponents = NetworkCustomComponents(
    requestExecutor: customExecutor,
    responseParser: customParser,
    requestBuilder: customBuilder
)

let networkConfig = NetworkConfiguration(
    baseURL: URL(string: "https://secure-api.com")!,
    timeout: 45.0,
    customComponents: customComponents
)

let iapConfig = IAPConfiguration(
    networkConfiguration: networkConfig
)

let manager = IAPManager(configuration: iapConfig)
```

## 便捷方法

框架提供了一些便捷的配置方法：

### 带认证的配置

```swift
let config = NetworkConfiguration.withAuthentication(
    baseURL: URL(string: "https://api.example.com")!,
    authTokenProvider: {
        return await AuthService.shared.getToken()
    }
)
```

### 带验证的配置

```swift
let config = NetworkConfiguration.withValidation(
    baseURL: URL(string: "https://api.example.com")!,
    validator: { data, response in
        // 自定义验证逻辑
        try await validateResponse(data, response)
    }
)
```

### 带安全性的配置

```swift
let config = NetworkConfiguration.withSecurity(
    baseURL: URL(string: "https://api.example.com")!,
    additionalHeaders: ["X-API-Key": "key"],
    encryptBody: { data in
        return try await encrypt(data)
    }
)
```

## 实现自定义组件

### 自定义请求执行器

```swift
public final class MyCustomRequestExecutor: NetworkRequestExecutor {
    public func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // 自定义请求执行逻辑
        // 例如：添加重试、缓存、日志等
        
        let session = URLSession.shared
        return try await session.data(for: request)
    }
}
```

### 自定义响应解析器

```swift
public final class MyCustomResponseParser: NetworkResponseParser {
    public func parse<T: Codable>(_ data: Data, response: URLResponse, as type: T.Type) async throws -> T {
        // 自定义解析逻辑
        // 例如：解密、验证、转换等
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
```

### 自定义请求构建器

```swift
public final class MyCustomRequestBuilder: NetworkRequestBuilder {
    public func buildRequest(
        endpoint: URL,
        method: String,
        body: [String: Any?]?,
        headers: [String: String]?
    ) async throws -> URLRequest {
        // 自定义请求构建逻辑
        // 例如：签名、压缩、格式转换等
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        
        // 添加自定义逻辑...
        
        return request
    }
}
```

## 最佳实践

1. **保持组件职责单一** - 每个组件只负责一个特定功能
2. **错误处理** - 确保自定义组件正确处理和传播错误
3. **性能考虑** - 避免在网络组件中执行耗时操作
4. **测试** - 为自定义组件编写单元测试
5. **文档** - 为自定义实现提供清晰的文档

## 测试自定义组件

```swift
// 创建 mock 组件用于测试
final class MockNetworkRequestExecutor: NetworkRequestExecutor {
    var mockResponse: (Data, URLResponse)?
    var mockError: Error?
    
    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return mockResponse ?? (Data(), URLResponse())
    }
}

// 在测试中使用
let mockExecutor = MockNetworkRequestExecutor()
mockExecutor.mockResponse = (testData, testResponse)

let customComponents = NetworkCustomComponents(
    requestExecutor: mockExecutor
)

let testConfig = NetworkConfiguration(
    baseURL: URL(string: "https://test.com")!,
    customComponents: customComponents
)
```

这种设计让你可以根据具体需求灵活定制网络层的各个方面，同时保持代码的清晰和可测试性。