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

/// 订单缓存项
public struct IAPOrderCacheItem: Sendable {
    /// 订单信息
    public let order: IAPOrder
    
    /// 缓存时间
    public let cachedAt: Date
    
    /// 最后更新时间
    public let lastUpdated: Date
    
    public init(order: IAPOrder) {
        self.order = order
        self.cachedAt = Date()
        self.lastUpdated = Date()
    }
    
    public init(order: IAPOrder, cachedAt: Date, lastUpdated: Date) {
        self.order = order
        self.cachedAt = cachedAt
        self.lastUpdated = lastUpdated
    }
    
    /// 是否已过期（基于订单的过期时间）
    public var isExpired: Bool {
        return order.isExpired
    }
    
    /// 是否为终态订单
    public var isTerminal: Bool {
        return order.isTerminal
    }
    
    /// 更新订单信息
    /// - Parameter newOrder: 新的订单信息
    /// - Returns: 更新后的缓存项
    public func updated(with newOrder: IAPOrder) -> IAPOrderCacheItem {
        return IAPOrderCacheItem(
            order: newOrder,
            cachedAt: cachedAt,
            lastUpdated: Date()
        )
    }
}

/// 统一缓存管理器，支持商品和订单缓存
public actor IAPCache {
    private var productCache: [String: IAPCacheItem] = [:]
    private var orderCache: [String: IAPOrderCacheItem] = [:]
    private let productCacheExpiration: TimeInterval
    
    public init(productCacheExpiration: TimeInterval = 300) { // 默认5分钟
        self.productCacheExpiration = productCacheExpiration
    }
    
    // Backward compatibility initializer
    public init(cacheExpiration: TimeInterval = 300) {
        self.productCacheExpiration = cacheExpiration
    }
    
    // MARK: - Product Cache Methods
    
    /// 缓存商品
    /// - Parameter products: 要缓存的商品列表
    public func cache(_ products: [IAPProduct]) {
        for product in products {
            let item = IAPCacheItem(product: product, cacheExpiration: productCacheExpiration)
            productCache[product.id] = item
        }
    }
    
    /// 获取缓存的商品
    /// - Parameter productIDs: 商品ID列表
    /// - Returns: 缓存中有效的商品列表
    public func getCachedProducts(for productIDs: Set<String>) -> [IAPProduct] {
        var cachedProducts: [IAPProduct] = []
        
        for productID in productIDs {
            if let item = productCache[productID], !item.isExpired {
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
            if let item = productCache[productID] {
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
        guard let item = productCache[productID], !item.isExpired else {
            return nil
        }
        return item.product
    }
    
    /// 移除过期的商品缓存项
    public func cleanExpiredProducts() {
        productCache = productCache.filter { !$0.value.isExpired }
    }
    
    /// 清空所有商品缓存
    public func clearAllProducts() {
        productCache.removeAll()
    }
    
    /// 移除指定商品的缓存
    /// - Parameter productID: 商品ID
    public func removeProduct(_ productID: String) {
        productCache.removeValue(forKey: productID)
    }
    
    /// 获取所有有效的缓存商品
    /// - Returns: 所有未过期的缓存商品
    public func getAllValidProducts() -> [IAPProduct] {
        return productCache.values
            .filter { !$0.isExpired }
            .map { $0.product }
    }
    
    // MARK: - Order Cache Methods
    
    /// 存储订单
    /// - Parameter order: 要缓存的订单
    public func storeOrder(_ order: IAPOrder) {
        let item = IAPOrderCacheItem(order: order)
        orderCache[order.id] = item
    }
    
    /// 获取订单
    /// - Parameter orderID: 订单ID
    /// - Returns: 缓存的订单信息
    public func getOrder(_ orderID: String) -> IAPOrder? {
        return orderCache[orderID]?.order
    }
    
    /// 更新订单状态
    /// - Parameters:
    ///   - orderID: 订单ID
    ///   - status: 新的订单状态
    public func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) {
        guard let existingItem = orderCache[orderID] else { return }
        let updatedOrder = existingItem.order.withStatus(status)
        orderCache[orderID] = existingItem.updated(with: updatedOrder)
    }
    
    /// 移除订单
    /// - Parameter orderID: 订单ID
    public func removeOrder(_ orderID: String) {
        orderCache.removeValue(forKey: orderID)
    }
    
    /// 获取所有订单
    /// - Returns: 所有缓存的订单
    public func getAllOrders() -> [IAPOrder] {
        return orderCache.values.map { $0.order }
    }
    
    /// 获取待处理的订单
    /// - Returns: 状态为created或pending的订单列表
    public func getPendingOrders() -> [IAPOrder] {
        return orderCache.values
            .map { $0.order }
            .filter { $0.status.isInProgress && !$0.isExpired }
    }
    
    /// 获取已过期的订单
    /// - Returns: 已过期的订单列表
    public func getExpiredOrders() -> [IAPOrder] {
        return orderCache.values
            .map { $0.order }
            .filter { $0.isExpired }
    }
    
    /// 获取指定状态的订单
    /// - Parameter status: 订单状态
    /// - Returns: 指定状态的订单列表
    public func getOrders(with status: IAPOrderStatus) -> [IAPOrder] {
        return orderCache.values
            .map { $0.order }
            .filter { $0.status == status }
    }
    
    /// 获取指定商品的订单
    /// - Parameter productID: 商品ID
    /// - Returns: 该商品的所有订单
    public func getOrders(for productID: String) -> [IAPOrder] {
        return orderCache.values
            .map { $0.order }
            .filter { $0.productID == productID }
    }
    
    /// 清理过期的订单
    public func cleanupExpiredOrders() {
        let expiredOrderIDs = orderCache.compactMap { key, value in
            value.order.isExpired ? key : nil
        }
        
        for orderID in expiredOrderIDs {
            orderCache.removeValue(forKey: orderID)
        }
    }
    
    /// 清理终态订单（可选择保留最近的一些记录）
    /// - Parameter keepRecentCount: 保留的最近终态订单数量，默认为10
    public func cleanupTerminalOrders(keepRecentCount: Int = 10) {
        let terminalOrders = orderCache.values
            .filter { $0.order.isTerminal }
            .sorted { $0.lastUpdated > $1.lastUpdated }
        
        // 如果终态订单数量超过保留数量，移除较旧的订单
        if terminalOrders.count > keepRecentCount {
            let ordersToRemove = Array(terminalOrders.dropFirst(keepRecentCount))
            for item in ordersToRemove {
                orderCache.removeValue(forKey: item.order.id)
            }
        }
    }
    
    /// 清空所有订单缓存
    public func clearAllOrders() {
        orderCache.removeAll()
    }
    
    /// 获取订单缓存统计信息
    /// - Returns: 订单缓存统计信息
    public func getOrderCacheStats() -> OrderCacheStats {
        let allOrders = orderCache.values.map { $0.order }
        let pendingCount = allOrders.filter { $0.status.isInProgress }.count
        let completedCount = allOrders.filter { $0.status == .completed }.count
        let failedCount = allOrders.filter { $0.status.isFailed }.count
        let expiredCount = allOrders.filter { $0.isExpired }.count
        
        return OrderCacheStats(
            totalOrders: allOrders.count,
            pendingOrders: pendingCount,
            completedOrders: completedCount,
            failedOrders: failedCount,
            expiredOrders: expiredCount
        )
    }
    
    // MARK: - Combined Cache Methods
    
    /// 清空所有缓存（商品和订单）
    public func clearAll() {
        clearAllProducts()
        clearAllOrders()
    }
    
    /// 清理所有过期项目
    public func cleanExpiredItems() {
        cleanExpiredProducts()
        cleanupExpiredOrders()
    }
    
    /// 获取商品缓存统计信息
    public func getProductCacheStats() -> ProductCacheStats {
        let totalItems = productCache.count
        let expiredItems = productCache.values.filter { $0.isExpired }.count
        let validItems = totalItems - expiredItems
        
        return ProductCacheStats(
            totalItems: totalItems,
            validItems: validItems,
            expiredItems: expiredItems
        )
    }
    
    /// 获取综合缓存统计信息
    public func getCacheStats() -> CacheStats {
        let productStats = getProductCacheStats()
        let orderStats = getOrderCacheStats()
        
        return CacheStats(
            productStats: productStats,
            orderStats: orderStats
        )
    }
    
    // MARK: - Persistence Methods
    
    /// 保存订单缓存到持久化存储
    public func saveOrdersToDisk() async throws {
        let ordersData = try await serializeOrders()
        let url = getOrdersPersistenceURL()
        try ordersData.write(to: url)
    }
    
    /// 从持久化存储加载订单缓存
    public func loadOrdersFromDisk() async throws {
        let url = getOrdersPersistenceURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        let data = try Data(contentsOf: url)
        let orders = try await deserializeOrders(from: data)
        
        // 清空现有订单缓存并加载持久化的订单
        orderCache.removeAll()
        for order in orders {
            storeOrder(order)
        }
    }
    
    /// 删除持久化的订单数据
    public func clearPersistedOrders() throws {
        let url = getOrdersPersistenceURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// 恢复应用启动时的订单状态
    public func recoverOrdersOnAppStart() async throws -> [IAPOrder] {
        // 加载持久化的订单
        try await loadOrdersFromDisk()
        
        // 获取需要恢复的订单（待处理且未过期的订单）
        let ordersToRecover = getPendingOrders()
        
        // 清理过期的订单
        cleanupExpiredOrders()
        
        // 保存清理后的状态
        try await saveOrdersToDisk()
        
        return ordersToRecover
    }
    
    /// 自动保存订单状态变更
    /// - Parameter order: 更新的订单
    public func autoSaveOrder(_ order: IAPOrder) async {
        storeOrder(order)
        
        // 异步保存到磁盘，不阻塞主要操作
        Task {
            do {
                try await saveOrdersToDisk()
            } catch {
                // 记录错误但不抛出，避免影响主要业务流程
                print("Failed to auto-save order \(order.id): \(error)")
            }
        }
    }
    
    /// 批量保存订单状态变更
    /// - Parameter orders: 要保存的订单列表
    public func batchSaveOrders(_ orders: [IAPOrder]) async throws {
        for order in orders {
            storeOrder(order)
        }
        try await saveOrdersToDisk()
    }
    
    /// 检查持久化存储是否存在
    /// - Returns: 如果存在持久化文件返回true
    public func hasPersistentStorage() -> Bool {
        let url = getOrdersPersistenceURL()
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// 获取持久化文件大小
    /// - Returns: 文件大小（字节），如果文件不存在返回0
    public func getPersistentStorageSize() -> Int64 {
        let url = getOrdersPersistenceURL()
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return 0
        }
        return fileSize
    }
    
    // MARK: - Private Persistence Helpers
    
    /// 序列化订单数据
    private func serializeOrders() async throws -> Data {
        let orders = getAllOrders()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(orders)
    }
    
    /// 反序列化订单数据
    private func deserializeOrders(from data: Data) async throws -> [IAPOrder] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([IAPOrder].self, from: data)
    }
    
    /// 获取订单持久化存储URL
    private func getOrdersPersistenceURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("iap_orders_cache.json")
    }
}

/// 商品缓存统计信息
public struct ProductCacheStats: Sendable {
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

/// 订单缓存统计信息
public struct OrderCacheStats: Sendable {
    /// 总订单数
    public let totalOrders: Int
    
    /// 待处理订单数
    public let pendingOrders: Int
    
    /// 已完成订单数
    public let completedOrders: Int
    
    /// 失败订单数
    public let failedOrders: Int
    
    /// 过期订单数
    public let expiredOrders: Int
    
    /// 成功率
    public var successRate: Double {
        let processedOrders = completedOrders + failedOrders
        guard processedOrders > 0 else { return 0.0 }
        return Double(completedOrders) / Double(processedOrders)
    }
    
    /// 活跃订单数（待处理且未过期）
    public var activeOrders: Int {
        return pendingOrders - expiredOrders
    }
}

/// 综合缓存统计信息
public struct CacheStats: Sendable {
    /// 商品缓存统计
    public let productStats: ProductCacheStats
    
    /// 订单缓存统计
    public let orderStats: OrderCacheStats
    
    /// 总缓存项数
    public var totalItems: Int {
        return productStats.totalItems + orderStats.totalOrders
    }
    
    // Backward compatibility properties
    /// 有效商品缓存项数（向后兼容）
    public var validItems: Int {
        return productStats.validItems
    }
    
    /// 过期商品缓存项数（向后兼容）
    public var expiredItems: Int {
        return productStats.expiredItems
    }
    
    /// 商品缓存命中率（向后兼容）
    public var hitRate: Double {
        return productStats.hitRate
    }
}
// MARK: - Backward Compatibility

/// 向后兼容的商品缓存管理器类型别名
public typealias IAPProductCache = IAPCache