import Foundation

/// 商品服务，负责商品信息的加载和管理
@MainActor
public final class ProductService: Sendable {
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 商品缓存
    private let cache: IAPProductCache
    
    /// 配置信息
    private let configuration: IAPConfiguration
    
    /// 初始化商品服务
    /// - Parameters:
    ///   - adapter: StoreKit 适配器
    ///   - configuration: 配置信息
    public init(
        adapter: StoreKitAdapterProtocol,
        configuration: IAPConfiguration = .default
    ) {
        self.adapter = adapter
        self.configuration = configuration
        self.cache = IAPProductCache(cacheExpiration: configuration.productCacheExpiration)
    }
    
    // MARK: - Public Methods
    
    /// 加载商品信息
    /// - Parameter productIDs: 商品ID集合
    /// - Returns: 商品信息数组
    /// - Throws: IAPError 相关错误
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        IAPLogger.debug("ProductService: Loading products \(productIDs)")
        
        guard !productIDs.isEmpty else {
            IAPLogger.warning("ProductService: Empty product IDs provided")
            return []
        }
        
        // 检查缓存
        let cachedProducts = await cache.getCachedProducts(for: productIDs)
        let uncachedProductIDs = await cache.getUncachedProductIDs(for: productIDs)
        
        if configuration.enableDebugLogging {
            IAPLogger.debug("ProductService: Found \(cachedProducts.count) cached products")
            IAPLogger.debug("ProductService: Need to load \(uncachedProductIDs.count) products from store")
        }
        
        var allProducts = cachedProducts
        
        // 加载未缓存的商品
        if !uncachedProductIDs.isEmpty {
            do {
                let newProducts = try await adapter.loadProducts(productIDs: uncachedProductIDs)
                
                // 缓存新加载的商品
                await cache.cache(newProducts)
                
                allProducts.append(contentsOf: newProducts)
                
                IAPLogger.info("ProductService: Successfully loaded \(newProducts.count) new products")
                
            } catch {
                let iapError = error as? IAPError ?? IAPError.from(error)
                IAPLogger.logError(
                    iapError,
                    context: [
                        "productIDs": uncachedProductIDs.joined(separator: ","),
                        "cachedCount": String(cachedProducts.count)
                    ]
                )
                
                // 如果有缓存的商品，返回缓存的商品而不是抛出错误
                if !cachedProducts.isEmpty {
                    IAPLogger.warning("ProductService: Returning cached products due to load error")
                    return cachedProducts
                }
                
                throw iapError
            }
        }
        
        // 按原始顺序排序
        let sortedProducts = productIDs.compactMap { productID in
            allProducts.first { $0.id == productID }
        }
        
        IAPLogger.info("ProductService: Returning \(sortedProducts.count) products")
        return sortedProducts
    }
    
    /// 获取单个商品信息
    /// - Parameter productID: 商品ID
    /// - Returns: 商品信息，如果不存在则返回 nil
    public func getProduct(by productID: String) async -> IAPProduct? {
        IAPLogger.debug("ProductService: Getting product \(productID)")
        
        // 先检查缓存
        if let cachedProduct = await cache.getProduct(for: productID) {
            IAPLogger.debug("ProductService: Found product in cache")
            return cachedProduct
        }
        
        // 如果缓存中没有，尝试加载
        do {
            let products = try await loadProducts(productIDs: [productID])
            let product = products.first
            
            if product != nil {
                IAPLogger.debug("ProductService: Product loaded successfully")
            } else {
                IAPLogger.warning("ProductService: Product not found")
            }
            
            return product
        } catch {
            IAPLogger.logError(
                IAPError.from(error),
                context: ["productID": productID]
            )
            return nil
        }
    }
    
    /// 预加载商品信息
    /// - Parameter productIDs: 商品ID集合
    /// - Note: 此方法不会抛出错误，失败时会记录日志
    public func preloadProducts(productIDs: Set<String>) async {
        IAPLogger.debug("ProductService: Preloading products \(productIDs)")
        
        do {
            _ = try await loadProducts(productIDs: productIDs)
            IAPLogger.info("ProductService: Successfully preloaded \(productIDs.count) products")
        } catch {
            IAPLogger.logError(
                IAPError.from(error),
                context: [
                    "operation": "preload",
                    "productIDs": productIDs.joined(separator: ",")
                ]
            )
        }
    }
    
    /// 刷新商品信息（强制从服务器重新加载）
    /// - Parameter productIDs: 商品ID集合
    /// - Returns: 商品信息数组
    /// - Throws: IAPError 相关错误
    public func refreshProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        IAPLogger.debug("ProductService: Refreshing products \(productIDs)")
        
        // 清除指定商品的缓存
        for productID in productIDs {
            await cache.removeProduct(productID)
        }
        
        // 重新加载
        return try await loadProducts(productIDs: productIDs)
    }
    
    /// 获取所有缓存的商品
    /// - Returns: 缓存的商品数组
    public func getCachedProducts() async -> [IAPProduct] {
        let stats = await cache.getCacheStats()
        IAPLogger.debug("ProductService: Getting cached products (total: \(stats.totalItems), valid: \(stats.validItems))")
        
        let cachedProducts = await cache.getAllValidProducts()
        IAPLogger.debug("ProductService: Returning \(cachedProducts.count) cached products")
        
        return cachedProducts
    }
    
    /// 清除商品缓存
    public func clearCache() async {
        IAPLogger.debug("ProductService: Clearing product cache")
        await cache.clearAll()
        IAPLogger.info("ProductService: Product cache cleared")
    }
    
    /// 清理过期的缓存项
    public func cleanExpiredCache() async {
        IAPLogger.debug("ProductService: Cleaning expired cache items")
        await cache.cleanExpiredItems()
        
        let stats = await cache.getCacheStats()
        IAPLogger.info("ProductService: Cache cleaned, remaining items: \(stats.validItems)")
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    public func getCacheStats() async -> CacheStats {
        return await cache.getCacheStats()
    }
    
    // MARK: - Product Validation
    
    /// 验证商品ID格式
    /// - Parameter productIDs: 商品ID集合
    /// - Returns: 验证结果
    public func validateProductIDs(_ productIDs: Set<String>) -> ProductIDValidationResult {
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
    
    /// 检查商品ID是否有效
    /// - Parameter productID: 商品ID
    /// - Returns: 是否有效
    private func isValidProductID(_ productID: String) -> Bool {
        // 基本验证规则
        guard !productID.isEmpty,
              productID.count <= 255,
              !productID.hasPrefix("."),
              !productID.hasSuffix(".") else {
            return false
        }
        
        // 检查是否包含无效字符
        let invalidCharacters = CharacterSet(charactersIn: " \t\n\r")
        return productID.rangeOfCharacter(from: invalidCharacters) == nil
    }
    
    // MARK: - Product Filtering and Sorting
    
    /// 按类型过滤商品
    /// - Parameters:
    ///   - products: 商品数组
    ///   - type: 商品类型
    /// - Returns: 过滤后的商品数组
    public func filterProducts(_ products: [IAPProduct], by type: IAPProductType) -> [IAPProduct] {
        return products.filter { $0.productType == type }
    }
    
    /// 按价格排序商品
    /// - Parameters:
    ///   - products: 商品数组
    ///   - ascending: 是否升序排列
    /// - Returns: 排序后的商品数组
    public func sortProductsByPrice(_ products: [IAPProduct], ascending: Bool = true) -> [IAPProduct] {
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
        guard !searchText.isEmpty else { return products }
        
        let lowercasedSearch = searchText.lowercased()
        
        return products.filter { product in
            product.displayName.lowercased().contains(lowercasedSearch) ||
            product.description.lowercased().contains(lowercasedSearch) ||
            product.id.lowercased().contains(lowercasedSearch)
        }
    }
}

// MARK: - Supporting Types

/// 商品ID验证结果
public struct ProductIDValidationResult: Sendable {
    /// 有效的商品ID
    public let validIDs: Set<String>
    
    /// 无效的商品ID
    public let invalidIDs: Set<String>
    
    /// 是否全部有效
    public let isAllValid: Bool
    
    /// 验证摘要
    public var summary: String {
        return "Valid: \(validIDs.count), Invalid: \(invalidIDs.count)"
    }
}