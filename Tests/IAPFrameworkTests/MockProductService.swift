import Foundation

/// Mock 商品服务，用于测试
@MainActor
public final class MockProductService: Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的商品数据
    public var mockProducts: [IAPProduct] = []
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 调用记录
    public private(set) var callHistory: [String] = []
    
    /// 加载商品的调用次数
    public private(set) var loadProductsCallCount = 0
    
    /// 最后一次加载商品的参数
    public private(set) var lastLoadProductsIDs: Set<String>?
    
    // MARK: - Cache Mock Data
    
    /// 模拟的缓存统计
    public var mockCacheStats = CacheStats(totalItems: 0, validItems: 0, expiredItems: 0)
    
    /// 缓存的商品
    private var cachedProducts: [String: IAPProduct] = [:]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Mock Configuration
    
    /// 设置模拟商品
    /// - Parameter products: 商品数组
    public func setMockProducts(_ products: [IAPProduct]) {
        mockProducts = products
        // 同时更新缓存
        for product in products {
            cachedProducts[product.id] = product
        }
        updateCacheStats()
    }
    
    /// 添加模拟商品
    /// - Parameter product: 商品
    public func addMockProduct(_ product: IAPProduct) {
        mockProducts.append(product)
        cachedProducts[product.id] = product
        updateCacheStats()
    }
    
    /// 设置模拟错误
    /// - Parameter error: 错误
    public func setMockError(_ error: IAPError) {
        mockError = error
        shouldThrowError = true
    }
    
    /// 清除模拟错误
    public func clearMockError() {
        mockError = nil
        shouldThrowError = false
    }
    
    /// 重置所有状态
    public func reset() {
        mockProducts.removeAll()
        cachedProducts.removeAll()
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        callHistory.removeAll()
        loadProductsCallCount = 0
        lastLoadProductsIDs = nil
        updateCacheStats()
    }
    
    // MARK: - ProductService Interface
    
    /// 加载商品信息
    /// - Parameter productIDs: 商品ID集合
    /// - Returns: 商品信息数组
    /// - Throws: IAPError 相关错误
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        callHistory.append("loadProducts(\(productIDs))")
        loadProductsCallCount += 1
        lastLoadProductsIDs = productIDs
        
        // 模拟延迟
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        // 模拟错误
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // 返回匹配的商品
        let matchingProducts = mockProducts.filter { productIDs.contains($0.id) }
        return matchingProducts
    }
    
    /// 获取单个商品信息
    /// - Parameter productID: 商品ID
    /// - Returns: 商品信息，如果不存在则返回 nil
    public func getProduct(by productID: String) async -> IAPProduct? {
        callHistory.append("getProduct(\(productID))")
        
        // 模拟延迟
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        return cachedProducts[productID]
    }
    
    /// 预加载商品信息
    /// - Parameter productIDs: 商品ID集合
    public func preloadProducts(productIDs: Set<String>) async {
        callHistory.append("preloadProducts(\(productIDs))")
        
        // 模拟延迟
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        // 预加载不抛出错误，只是静默失败
    }
    
    /// 刷新商品信息
    /// - Parameter productIDs: 商品ID集合
    /// - Returns: 商品信息数组
    /// - Throws: IAPError 相关错误
    public func refreshProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        callHistory.append("refreshProducts(\(productIDs))")
        
        // 清除指定商品的缓存
        for productID in productIDs {
            cachedProducts.removeValue(forKey: productID)
        }
        updateCacheStats()
        
        // 重新加载
        return try await loadProducts(productIDs: productIDs)
    }
    
    /// 获取所有缓存的商品
    /// - Returns: 缓存的商品数组
    public func getCachedProducts() async -> [IAPProduct] {
        callHistory.append("getCachedProducts()")
        return Array(cachedProducts.values)
    }
    
    /// 清除商品缓存
    public func clearCache() async {
        callHistory.append("clearCache()")
        cachedProducts.removeAll()
        updateCacheStats()
    }
    
    /// 清理过期的缓存项
    public func cleanExpiredCache() async {
        callHistory.append("cleanExpiredCache()")
        // Mock 实现不需要实际清理过期项
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    public func getCacheStats() async -> CacheStats {
        callHistory.append("getCacheStats()")
        return mockCacheStats
    }
    
    // MARK: - Product Validation
    
    /// 验证商品ID格式
    /// - Parameter productIDs: 商品ID集合
    /// - Returns: 验证结果
    public func validateProductIDs(_ productIDs: Set<String>) -> ProductIDValidationResult {
        callHistory.append("validateProductIDs(\(productIDs))")
        
        var validIDs: Set<String> = []
        var invalidIDs: Set<String> = []
        
        for productID in productIDs {
            if isValidProductID(productID) {
                validIDs.insert(productID)
            } else {
                invalidIDs.insert(productID)
            }
        }
        
        return ProductIDValidationResult(
            validIDs: validIDs,
            invalidIDs: invalidIDs,
            isAllValid: invalidIDs.isEmpty
        )
    }
    
    /// 按类型过滤商品
    /// - Parameters:
    ///   - products: 商品数组
    ///   - type: 商品类型
    /// - Returns: 过滤后的商品数组
    public func filterProducts(_ products: [IAPProduct], by type: IAPProductType) -> [IAPProduct] {
        callHistory.append("filterProducts(count: \(products.count), type: \(type))")
        return products.filter { $0.productType == type }
    }
    
    /// 按价格排序商品
    /// - Parameters:
    ///   - products: 商品数组
    ///   - ascending: 是否升序排列
    /// - Returns: 排序后的商品数组
    public func sortProductsByPrice(_ products: [IAPProduct], ascending: Bool = true) -> [IAPProduct] {
        callHistory.append("sortProductsByPrice(count: \(products.count), ascending: \(ascending))")
        return products.sorted { product1, product2 in
            if ascending {
                return product1.price < product2.price
            } else {
                return product1.price > product2.price
            }
        }
    }
    
    /// 搜索商品
    /// - Parameters:
    ///   - products: 商品数组
    ///   - searchText: 搜索文本
    /// - Returns: 匹配的商品数组
    public func searchProducts(_ products: [IAPProduct], searchText: String) -> [IAPProduct] {
        callHistory.append("searchProducts(count: \(products.count), searchText: '\(searchText)')")
        
        guard !searchText.isEmpty else { return products }
        
        let lowercasedSearch = searchText.lowercased()
        
        return products.filter { product in
            product.displayName.lowercased().contains(lowercasedSearch) ||
            product.description.lowercased().contains(lowercasedSearch) ||
            product.id.lowercased().contains(lowercasedSearch)
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidProductID(_ productID: String) -> Bool {
        guard !productID.isEmpty,
              productID.count <= 255,
              !productID.hasPrefix("."),
              !productID.hasSuffix(".") else {
            return false
        }
        
        let invalidCharacters = CharacterSet(charactersIn: " \t\n\r")
        return productID.rangeOfCharacter(from: invalidCharacters) == nil
    }
    
    private func updateCacheStats() {
        mockCacheStats = CacheStats(
            totalItems: cachedProducts.count,
            validItems: cachedProducts.count,
            expiredItems: 0
        )
    }
}

// MARK: - Test Helpers

extension MockProductService {
    
    /// 验证是否调用了指定方法
    /// - Parameter methodName: 方法名
    /// - Returns: 是否调用过
    public func wasMethodCalled(_ methodName: String) -> Bool {
        return callHistory.contains { $0.contains(methodName) }
    }
    
    /// 获取指定方法的调用次数
    /// - Parameter methodName: 方法名
    /// - Returns: 调用次数
    public func getCallCount(for methodName: String) -> Int {
        return callHistory.filter { $0.contains(methodName) }.count
    }
    
    /// 获取最后一次方法调用
    /// - Returns: 最后一次调用的方法名
    public func getLastCall() -> String? {
        return callHistory.last
    }
    
    /// 创建测试商品集合
    /// - Parameter count: 商品数量
    /// - Returns: 测试商品数组
    public static func createTestProducts(count: Int) -> [IAPProduct] {
        return (1...count).map { index in
            IAPProduct.mock(
                id: "test.product.\(index)",
                displayName: "Test Product \(index)",
                price: Decimal(index),
                productType: index % 2 == 0 ? .consumable : .nonConsumable
            )
        }
    }
}