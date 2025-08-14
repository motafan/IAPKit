import Foundation
@testable import IAPFramework

/// Mock 商品服务，用于测试
@MainActor
public final class MockProductService: @unchecked Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的商品列表
    public var mockProducts: [IAPProduct] = []
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    /// 模拟的缓存统计信息
    public var mockCacheStats: CacheStats = CacheStats(totalItems: 0, validItems: 0, expiredItems: 0)
    
    /// 模拟的商品ID验证结果
    public var mockValidationResult: ProductIDValidationResult?
    
    // MARK: - Call Tracking
    
    /// 调用计数器
    public private(set) var callCounts: [String: Int] = [:]
    
    /// 调用参数记录
    public private(set) var callParameters: [String: Any] = [:]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - ProductService Mock Methods
    
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        incrementCallCount(for: "loadProducts")
        callParameters["loadProducts_productIDs"] = productIDs
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // 返回匹配的商品
        let matchingProducts = mockProducts.filter { productIDs.contains($0.id) }
        return matchingProducts
    }
    
    public func getProduct(by productID: String) async -> IAPProduct? {
        incrementCallCount(for: "getProduct")
        callParameters["getProduct_productID"] = productID
        
        return mockProducts.first { $0.id == productID }
    }
    
    public func preloadProducts(productIDs: Set<String>) async {
        incrementCallCount(for: "preloadProducts")
        callParameters["preloadProducts_productIDs"] = productIDs
    }
    
    public func refreshProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        incrementCallCount(for: "refreshProducts")
        callParameters["refreshProducts_productIDs"] = productIDs
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        return mockProducts.filter { productIDs.contains($0.id) }
    }    

    public func getCachedProducts() async -> [IAPProduct] {
        incrementCallCount(for: "getCachedProducts")
        return mockProducts
    }
    
    public func clearCache() async {
        incrementCallCount(for: "clearCache")
    }
    
    public func cleanExpiredCache() async {
        incrementCallCount(for: "cleanExpiredCache")
    }
    
    public func getCacheStats() async -> CacheStats {
        incrementCallCount(for: "getCacheStats")
        return mockCacheStats
    }
    
    public func validateProductIDs(_ productIDs: Set<String>) -> ProductIDValidationResult {
        incrementCallCount(for: "validateProductIDs")
        callParameters["validateProductIDs_productIDs"] = productIDs
        
        if let result = mockValidationResult {
            return result
        }
        
        // 默认所有ID都有效
        return ProductIDValidationResult(
            validIDs: productIDs,
            invalidIDs: [],
            isAllValid: true
        )
    }
    
    public func filterProducts(_ products: [IAPProduct], by type: IAPProductType) -> [IAPProduct] {
        incrementCallCount(for: "filterProducts")
        callParameters["filterProducts_type"] = type
        
        return products.filter { $0.productType == type }
    }
    
    public func sortProductsByPrice(_ products: [IAPProduct], ascending: Bool = true) -> [IAPProduct] {
        incrementCallCount(for: "sortProductsByPrice")
        callParameters["sortProductsByPrice_ascending"] = ascending
        
        return products.sorted { product1, product2 in
            if ascending {
                return product1.price < product2.price
            } else {
                return product1.price > product2.price
            }
        }
    }
    
    public func searchProducts(_ products: [IAPProduct], searchText: String) -> [IAPProduct] {
        incrementCallCount(for: "searchProducts")
        callParameters["searchProducts_searchText"] = searchText
        
        guard !searchText.isEmpty else { return products }
        
        let lowercasedSearch = searchText.lowercased()
        
        return products.filter { product in
            product.displayName.lowercased().contains(lowercasedSearch) ||
            product.description.lowercased().contains(lowercasedSearch) ||
            product.id.lowercased().contains(lowercasedSearch)
        }
    }
    
    // MARK: - Mock Configuration Methods
    
    /// 设置模拟商品
    /// - Parameter products: 商品列表
    public func setMockProducts(_ products: [IAPProduct]) {
        mockProducts = products
    }
    
    /// 添加模拟商品
    /// - Parameter product: 商品
    public func addMockProduct(_ product: IAPProduct) {
        mockProducts.append(product)
    }
    
    /// 设置模拟错误
    /// - Parameters:
    ///   - error: 错误
    ///   - shouldThrow: 是否应该抛出错误
    public func setMockError(_ error: IAPError?, shouldThrow: Bool = true) {
        mockError = error
        shouldThrowError = shouldThrow
    }
    
    /// 设置模拟延迟
    /// - Parameter delay: 延迟时间（秒）
    public func setMockDelay(_ delay: TimeInterval) {
        mockDelay = delay
    }
    
    /// 设置模拟缓存统计信息
    /// - Parameter stats: 缓存统计信息
    public func setMockCacheStats(_ stats: CacheStats) {
        mockCacheStats = stats
    }
    
    /// 设置模拟商品ID验证结果
    /// - Parameter result: 验证结果
    public func setMockValidationResult(_ result: ProductIDValidationResult) {
        mockValidationResult = result
    }
    
    // MARK: - Test Helper Methods
    
    /// 重置所有模拟数据
    public func reset() {
        mockProducts.removeAll()
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        mockCacheStats = CacheStats(totalItems: 0, validItems: 0, expiredItems: 0)
        mockValidationResult = nil
        callCounts.removeAll()
        callParameters.removeAll()
    }
    
    /// 获取方法调用次数
    /// - Parameter method: 方法名
    /// - Returns: 调用次数
    public func getCallCount(for method: String) -> Int {
        return callCounts[method] ?? 0
    }
    
    /// 获取方法调用参数
    /// - Parameter method: 方法名
    /// - Returns: 调用参数
    public func getCallParameters(for method: String) -> Any? {
        return callParameters[method]
    }
    
    /// 检查方法是否被调用
    /// - Parameter method: 方法名
    /// - Returns: 是否被调用
    public func wasCalled(_ method: String) -> Bool {
        return getCallCount(for: method) > 0
    }
    
    /// 获取调用统计信息
    /// - Returns: 调用统计
    public func getCallStatistics() -> [String: Int] {
        return callCounts
    }
    
    // MARK: - Private Methods
    
    private func incrementCallCount(for method: String) {
        callCounts[method, default: 0] += 1
    }
}

// MARK: - Convenience Factory Methods

extension MockProductService {
    
    /// 创建带有预设商品的 Mock 服务
    /// - Parameter products: 商品列表
    /// - Returns: Mock 服务
    public static func withProducts(_ products: [IAPProduct]) -> MockProductService {
        let service = MockProductService()
        service.setMockProducts(products)
        return service
    }
    
    /// 创建会抛出错误的 Mock 服务
    /// - Parameter error: 错误
    /// - Returns: Mock 服务
    public static func withError(_ error: IAPError) -> MockProductService {
        let service = MockProductService()
        service.setMockError(error, shouldThrow: true)
        return service
    }
    
    /// 创建带有延迟的 Mock 服务
    /// - Parameter delay: 延迟时间（秒）
    /// - Returns: Mock 服务
    public static func withDelay(_ delay: TimeInterval) -> MockProductService {
        let service = MockProductService()
        service.setMockDelay(delay)
        return service
    }
}

// MARK: - Test Scenario Builders

extension MockProductService {
    
    /// 配置成功加载场景
    /// - Parameter products: 商品列表
    public func configureSuccessfulLoad(_ products: [IAPProduct]) {
        setMockProducts(products)
        shouldThrowError = false
    }
    
    /// 配置失败加载场景
    /// - Parameter error: 错误
    public func configureFailedLoad(error: IAPError) {
        setMockError(error, shouldThrow: true)
    }
    
    /// 配置网络错误场景
    public func configureNetworkError() {
        setMockError(.networkError, shouldThrow: true)
    }
    
    /// 配置商品未找到场景
    public func configureProductNotFound() {
        setMockProducts([])
        setMockError(.productNotFound, shouldThrow: true)
    }
    
    /// 配置缓存场景
    /// - Parameters:
    ///   - products: 缓存的商品
    ///   - stats: 缓存统计信息
    public func configureCacheScenario(products: [IAPProduct], stats: CacheStats) {
        setMockProducts(products)
        setMockCacheStats(stats)
    }
}