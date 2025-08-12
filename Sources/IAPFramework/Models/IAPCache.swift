import Foundation

/// 商品缓存项
public struct IAPCacheItem: Sendable {
    /// 商品信息
    public let product: IAPProduct
    
    /// 缓存时间
    public let cachedAt: Date
    
    /// 过期时间
    public let expiresAt: Date
    
    public init(product: IAPProduct, cacheExpiration: TimeInterval) {
        self.product = product
        self.cachedAt = Date()
        self.expiresAt = cachedAt.addingTimeInterval(cacheExpiration)
    }
    
    /// 是否已过期
    public var isExpired: Bool {
        return Date() > expiresAt
    }
    
    /// 剩余有效时间（秒）
    public var remainingTime: TimeInterval {
        return max(0, expiresAt.timeIntervalSinceNow)
    }
}

/// 商品缓存管理器
public actor IAPProductCache {
    private var cache: [String: IAPCacheItem] = [:]
    private let cacheExpiration: TimeInterval
    
    public init(cacheExpiration: TimeInterval = 300) { // 默认5分钟
        self.cacheExpiration = cacheExpiration
    }
    
    /// 缓存商品
    /// - Parameter products: 要缓存的商品列表
    public func cache(_ products: [IAPProduct]) {
        for product in products {
            let item = IAPCacheItem(product: product, cacheExpiration: cacheExpiration)
            cache[product.id] = item
        }
    }
    
    /// 获取缓存的商品
    /// - Parameter productIDs: 商品ID列表
    /// - Returns: 缓存中有效的商品列表
    public func getCachedProducts(for productIDs: Set<String>) -> [IAPProduct] {
        var cachedProducts: [IAPProduct] = []
        
        for productID in productIDs {
            if let item = cache[productID], !item.isExpired {
                cachedProducts.append(item.product)
            }
        }
        
        return cachedProducts
    }
    
    /// 获取未缓存的商品ID
    /// - Parameter productIDs: 商品ID列表
    /// - Returns: 需要从服务器加载的商品ID
    public func getUncachedProductIDs(for productIDs: Set<String>) -> Set<String> {
        var uncachedIDs: Set<String> = []
        
        for productID in productIDs {
            if let item = cache[productID] {
                if item.isExpired {
                    uncachedIDs.insert(productID)
                }
            } else {
                uncachedIDs.insert(productID)
            }
        }
        
        return uncachedIDs
    }
    
    /// 获取单个商品
    /// - Parameter productID: 商品ID
    /// - Returns: 缓存的商品信息
    public func getProduct(for productID: String) -> IAPProduct? {
        guard let item = cache[productID], !item.isExpired else {
            return nil
        }
        return item.product
    }
    
    /// 移除过期的缓存项
    public func cleanExpiredItems() {
        cache = cache.filter { !$0.value.isExpired }
    }
    
    /// 清空所有缓存
    public func clearAll() {
        cache.removeAll()
    }
    
    /// 移除指定商品的缓存
    /// - Parameter productID: 商品ID
    public func removeProduct(_ productID: String) {
        cache.removeValue(forKey: productID)
    }
    
    /// 获取所有有效的缓存商品
    /// - Returns: 所有未过期的缓存商品
    public func getAllValidProducts() -> [IAPProduct] {
        return cache.values
            .filter { !$0.isExpired }
            .map { $0.product }
    }
    
    /// 获取缓存统计信息
    public func getCacheStats() -> CacheStats {
        let totalItems = cache.count
        let expiredItems = cache.values.filter { $0.isExpired }.count
        let validItems = totalItems - expiredItems
        
        return CacheStats(
            totalItems: totalItems,
            validItems: validItems,
            expiredItems: expiredItems
        )
    }
}

/// 缓存统计信息
public struct CacheStats: Sendable {
    /// 总缓存项数
    public let totalItems: Int
    
    /// 有效缓存项数
    public let validItems: Int
    
    /// 过期缓存项数
    public let expiredItems: Int
    
    /// 缓存命中率
    public var hitRate: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(validItems) / Double(totalItems)
    }
}