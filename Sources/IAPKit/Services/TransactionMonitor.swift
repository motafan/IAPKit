import Foundation

/// 交易监控器，负责实时监听交易状态变化和订单跟踪
@MainActor
public final class TransactionMonitor: Sendable {
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 订单服务
    private let orderService: OrderServiceProtocol?
    
    /// 缓存管理器
    private let cache: IAPCache?
    
    /// 配置信息
    private let configuration: IAPConfiguration
    
    /// 是否正在监控
    private var isMonitoring = false
    
    /// 交易更新回调
    private var transactionUpdateHandlers: [String: (IAPTransaction) -> Void] = [:]
    
    /// 订单更新回调
    private var orderUpdateHandlers: [String: (IAPOrder) -> Void] = [:]
    
    /// 订单-交易关联映射
    private var orderTransactionAssociations: [String: String] = [:]
    
    /// 监控统计信息
    private var monitoringStats = MonitoringStats()
    
    /// 订单超时监控任务
    private var orderTimeoutTask: Task<Void, Never>?
    
    /// 初始化交易监控器
    /// - Parameters:
    ///   - adapter: StoreKit 适配器
    ///   - orderService: 订单服务（可选）
    ///   - cache: 缓存管理器（可选）
    ///   - configuration: 配置信息
    public init(
        adapter: StoreKitAdapterProtocol,
        orderService: OrderServiceProtocol? = nil,
        cache: IAPCache? = nil,
        configuration: IAPConfiguration
    ) {
        self.adapter = adapter
        self.orderService = orderService
        self.cache = cache
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// 开始监控交易和订单
    public func startMonitoring() async {
        guard !isMonitoring else {
            IAPLogger.debug("TransactionMonitor: Already monitoring transactions and orders")
            return
        }
        
        IAPLogger.info("TransactionMonitor: Starting transaction and order monitoring")
        
        isMonitoring = true
        monitoringStats.startTime = Date()
        
        // 设置适配器的交易更新处理器
        if #available(iOS 15.0, macOS 12.0, *) {
            if let storeKit2Adapter = adapter as? StoreKit2Adapter {
                storeKit2Adapter.setTransactionUpdateHandler { [weak self] transaction in
                    Task { @MainActor in
                        await self?.handleTransactionUpdate(transaction)
                    }
                }
            }
        }
        
        // 启动适配器的交易观察者
        await adapter.startTransactionObserver()
        
        // 处理启动时的未完成交易
        if configuration.autoRecoverTransactions {
            await handlePendingTransactions()
        }
        
        // 启动订单监控
        if orderService != nil && cache != nil {
            await startOrderMonitoring()
        }
        
        IAPLogger.info("TransactionMonitor: Transaction and order monitoring started")
    }
    
    /// 停止监控交易和订单
    public func stopMonitoring() {
        guard isMonitoring else {
            IAPLogger.debug("TransactionMonitor: Not currently monitoring transactions and orders")
            return
        }
        
        IAPLogger.info("TransactionMonitor: Stopping transaction and order monitoring")
        
        isMonitoring = false
        monitoringStats.endTime = Date()
        
        // 停止适配器的交易观察者
        adapter.stopTransactionObserver()
        
        // 清除交易更新处理器
        if #available(iOS 15.0, macOS 12.0, *) {
            if let storeKit2Adapter = adapter as? StoreKit2Adapter {
                storeKit2Adapter.setTransactionUpdateHandler { _ in }
            }
        }
        
        // 停止订单监控
        stopOrderMonitoring()
        
        IAPLogger.info("TransactionMonitor: Transaction and order monitoring stopped")
    }
    
    /// 添加交易更新处理器
    /// - Parameters:
    ///   - identifier: 处理器标识符
    ///   - handler: 交易更新处理器
    public func addTransactionUpdateHandler(
        identifier: String,
        handler: @escaping (IAPTransaction) -> Void
    ) {
        transactionUpdateHandlers[identifier] = handler
        IAPLogger.debug("TransactionMonitor: Added transaction update handler: \(identifier)")
    }
    
    /// 添加订单更新处理器
    /// - Parameters:
    ///   - identifier: 处理器标识符
    ///   - handler: 订单更新处理器
    public func addOrderUpdateHandler(
        identifier: String,
        handler: @escaping (IAPOrder) -> Void
    ) {
        orderUpdateHandlers[identifier] = handler
        IAPLogger.debug("TransactionMonitor: Added order update handler: \(identifier)")
    }
    
    /// 移除交易更新处理器
    /// - Parameter identifier: 处理器标识符
    public func removeTransactionUpdateHandler(identifier: String) {
        transactionUpdateHandlers.removeValue(forKey: identifier)
        IAPLogger.debug("TransactionMonitor: Removed transaction update handler: \(identifier)")
    }
    
    /// 移除订单更新处理器
    /// - Parameter identifier: 处理器标识符
    public func removeOrderUpdateHandler(identifier: String) {
        orderUpdateHandlers.removeValue(forKey: identifier)
        IAPLogger.debug("TransactionMonitor: Removed order update handler: \(identifier)")
    }
    
    /// 清除所有交易更新处理器
    public func clearAllTransactionUpdateHandlers() {
        let count = transactionUpdateHandlers.count
        transactionUpdateHandlers.removeAll()
        IAPLogger.debug("TransactionMonitor: Cleared \(count) transaction update handlers")
    }
    
    /// 清除所有订单更新处理器
    public func clearAllOrderUpdateHandlers() {
        let count = orderUpdateHandlers.count
        orderUpdateHandlers.removeAll()
        IAPLogger.debug("TransactionMonitor: Cleared \(count) order update handlers")
    }
    
    /// 关联订单和交易
    /// - Parameters:
    ///   - orderID: 订单ID
    ///   - transactionID: 交易ID
    public func associateOrderWithTransaction(orderID: String, transactionID: String) {
        orderTransactionAssociations[orderID] = transactionID
        IAPLogger.debug("TransactionMonitor: Associated order \(orderID) with transaction \(transactionID)")
    }
    
    /// 取消订单和交易的关联
    /// - Parameter orderID: 订单ID
    public func disassociateOrder(_ orderID: String) {
        orderTransactionAssociations.removeValue(forKey: orderID)
        IAPLogger.debug("TransactionMonitor: Disassociated order \(orderID)")
    }
    
    /// 手动处理未完成交易
    public func handlePendingTransactions() async {
        IAPLogger.debug("TransactionMonitor: Handling pending transactions")
        
        let pendingTransactions = await adapter.getPendingTransactions()
        
        if pendingTransactions.isEmpty {
            IAPLogger.debug("TransactionMonitor: No pending transactions found")
            return
        }
        
        IAPLogger.info("TransactionMonitor: Found \(pendingTransactions.count) pending transactions")
        monitoringStats.pendingTransactionsProcessed += pendingTransactions.count
        
        for transaction in pendingTransactions {
            await handleTransactionUpdate(transaction)
        }
    }
    
    /// 获取监控状态
    /// - Returns: 是否正在监控
    public var isCurrentlyMonitoring: Bool {
        return isMonitoring
    }
    
    /// 获取监控统计信息
    /// - Returns: 监控统计信息
    public func getMonitoringStats() -> MonitoringStats {
        var stats = monitoringStats
        if isMonitoring && stats.startTime != nil {
            stats.currentDuration = Date().timeIntervalSince(stats.startTime!)
        }
        return stats
    }
    
    /// 重置监控统计信息
    public func resetMonitoringStats() {
        monitoringStats = MonitoringStats()
        if isMonitoring {
            monitoringStats.startTime = Date()
        }
        IAPLogger.debug("TransactionMonitor: Reset monitoring statistics")
    }
    
    // MARK: - Order Monitoring Methods
    
    /// 启动订单监控
    private func startOrderMonitoring() async {
        guard let cache = cache else { return }
        
        IAPLogger.debug("TransactionMonitor: Starting order monitoring")
        
        // 启动订单超时监控任务
        orderTimeoutTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkOrderTimeouts()
                
                // 每30秒检查一次订单超时
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        
        // 监控现有的待处理订单
        let pendingOrders = await cache.getPendingOrders()
        for order in pendingOrders {
            await monitorOrder(order)
        }
    }
    
    /// 停止订单监控
    private func stopOrderMonitoring() {
        orderTimeoutTask?.cancel()
        orderTimeoutTask = nil
        orderTransactionAssociations.removeAll()
        IAPLogger.debug("TransactionMonitor: Stopped order monitoring")
    }
    
    /// 监控单个订单
    /// - Parameter order: 要监控的订单
    private func monitorOrder(_ order: IAPOrder) async {
        guard order.isActive else { return }
        
        IAPLogger.debug("TransactionMonitor: Monitoring order \(order.id)")
        monitoringStats.ordersMonitored += 1
        
        // 如果订单即将过期，增加检查频率
        if let expiresAt = order.expiresAt {
            let timeUntilExpiration = expiresAt.timeIntervalSinceNow
            if timeUntilExpiration > 0 && timeUntilExpiration < 300 { // 5分钟内过期
                await scheduleOrderExpirationCheck(order)
            }
        }
    }
    
    /// 检查订单超时
    private func checkOrderTimeouts() async {
        guard let cache = cache, let orderService = orderService else { return }
        
        let pendingOrders = await cache.getPendingOrders()
        
        for order in pendingOrders {
            if order.isExpired {
                IAPLogger.info("TransactionMonitor: Order \(order.id) has expired")
                
                do {
                    // 尝试取消过期订单
                    try await orderService.cancelOrder(order.id)
                    
                    // 通知订单更新处理器
                    let cancelledOrder = order.withStatus(.cancelled)
                    await notifyOrderUpdateHandlers(cancelledOrder)
                    
                    monitoringStats.expiredOrders += 1
                    
                } catch {
                    IAPLogger.error("TransactionMonitor: Failed to cancel expired order \(order.id): \(error)")
                }
            }
        }
    }
    
    /// 安排订单过期检查
    /// - Parameter order: 订单
    private func scheduleOrderExpirationCheck(_ order: IAPOrder) async {
        guard let expiresAt = order.expiresAt else { return }
        
        let timeUntilExpiration = expiresAt.timeIntervalSinceNow
        guard timeUntilExpiration > 0 else { return }
        
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeUntilExpiration * 1_000_000_000))
            await self?.handleOrderExpiration(order.id)
        }
    }
    
    /// 处理订单过期
    /// - Parameter orderID: 订单ID
    private func handleOrderExpiration(_ orderID: String) async {
        guard let cache = cache, let orderService = orderService else { return }
        
        // 重新检查订单状态（可能已经完成）
        guard let order = await cache.getOrder(orderID), order.isExpired else { return }
        
        IAPLogger.info("TransactionMonitor: Handling expiration for order \(orderID)")
        
        do {
            try await orderService.cancelOrder(orderID)
            
            let cancelledOrder = order.withStatus(.cancelled)
            await cache.storeOrder(cancelledOrder)
            await notifyOrderUpdateHandlers(cancelledOrder)
            
            // 如果有关联的交易，也需要处理
            if let transactionID = orderTransactionAssociations[orderID] {
                disassociateOrder(orderID)
                IAPLogger.debug("TransactionMonitor: Disassociated expired order \(orderID) from transaction \(transactionID)")
            }
            
            monitoringStats.expiredOrders += 1
            
        } catch {
            IAPLogger.error("TransactionMonitor: Failed to handle order expiration for \(orderID): \(error)")
        }
    }
    
    /// 通知订单更新处理器
    /// - Parameter order: 更新的订单
    private func notifyOrderUpdateHandlers(_ order: IAPOrder) async {
        for (identifier, handler) in orderUpdateHandlers {
            handler(order)
            IAPLogger.debug("TransactionMonitor: Notified order handler: \(identifier)")
        }
    }
    
    // MARK: - Private Methods
    
    /// 处理交易更新
    /// - Parameter transaction: 交易信息
    private func handleTransactionUpdate(_ transaction: IAPTransaction) async {
        IAPLogger.debug("TransactionMonitor: Handling transaction update: \(transaction.id)")
        
        // 更新统计信息
        monitoringStats.transactionsProcessed += 1
        
        // 检查是否有关联的订单
        let associatedOrderID = findAssociatedOrder(for: transaction)
        
        switch transaction.transactionState {
        case .purchased:
            monitoringStats.successfulTransactions += 1
            await handleSuccessfulTransaction(transaction)
            
            // 更新关联订单状态
            if let orderID = associatedOrderID {
                await updateAssociatedOrderStatus(orderID, status: .completed)
            }
            
        case .failed:
            monitoringStats.failedTransactions += 1
            await handleFailedTransaction(transaction)
            
            // 更新关联订单状态
            if let orderID = associatedOrderID {
                await updateAssociatedOrderStatus(orderID, status: .failed)
            }
            
        case .restored:
            monitoringStats.restoredTransactions += 1
            await handleRestoredTransaction(transaction)
            
        case .purchasing:
            await handlePurchasingTransaction(transaction)
            
            // 更新关联订单状态为pending
            if let orderID = associatedOrderID {
                await updateAssociatedOrderStatus(orderID, status: .pending)
            }
            
        case .deferred:
            monitoringStats.deferredTransactions += 1
            await handleDeferredTransaction(transaction)
            
            // 延期交易保持订单为pending状态
            if let orderID = associatedOrderID {
                await updateAssociatedOrderStatus(orderID, status: .pending)
            }
        }
        
        // 通知所有注册的处理器
        for (identifier, handler) in transactionUpdateHandlers {
            handler(transaction)
            IAPLogger.debug("TransactionMonitor: Notified transaction handler: \(identifier)")
        }
    }
    
    /// 查找与交易关联的订单
    /// - Parameter transaction: 交易
    /// - Returns: 关联的订单ID（如果存在）
    private func findAssociatedOrder(for transaction: IAPTransaction) -> String? {
        // 首先检查直接关联
        for (orderID, transactionID) in orderTransactionAssociations {
            if transactionID == transaction.id {
                return orderID
            }
        }
        
        // 如果没有直接关联，尝试基于商品ID和时间窗口查找
        guard let cache = cache else { return nil }
        
        // 异步查找关联订单
        Task { [weak self] in
            let orders = await cache.getOrders(for: transaction.productID)
            for order in orders {
                if order.isActive {
                    let timeDifference = transaction.purchaseDate.timeIntervalSince(order.createdAt)
                    if timeDifference >= 0 && timeDifference <= 3600 { // 1小时内
                        // 建立关联
                        self?.associateOrderWithTransaction(orderID: order.id, transactionID: transaction.id)
                        break
                    }
                }
            }
        }
        
        return nil
    }
    
    /// 更新关联订单状态
    /// - Parameters:
    ///   - orderID: 订单ID
    ///   - status: 新状态
    private func updateAssociatedOrderStatus(_ orderID: String, status: IAPOrderStatus) async {
        guard let cache = cache, let orderService = orderService else { return }
        
        do {
            // 更新服务器订单状态
            try await orderService.updateOrderStatus(orderID, status: status)
            
            // 更新本地缓存
            await cache.updateOrderStatus(orderID, status: status)
            
            // 获取更新后的订单并通知处理器
            if let updatedOrder = await cache.getOrder(orderID) {
                await notifyOrderUpdateHandlers(updatedOrder)
            }
            
            IAPLogger.info("TransactionMonitor: Updated associated order \(orderID) status to \(status)")
            
        } catch {
            IAPLogger.error("TransactionMonitor: Failed to update associated order \(orderID) status: \(error)")
        }
    }
    
    /// 处理成功的交易
    /// - Parameter transaction: 交易信息
    private func handleSuccessfulTransaction(_ transaction: IAPTransaction) async {
        IAPLogger.info("TransactionMonitor: Processing successful transaction: \(transaction.id)")
        
        // 如果配置了自动完成交易，则完成交易
        if configuration.autoFinishTransactions {
            do {
                try await adapter.finishTransaction(transaction)
                IAPLogger.debug("TransactionMonitor: Auto-finished transaction: \(transaction.id)")
            } catch {
                IAPLogger.warning("TransactionMonitor: Failed to auto-finish transaction \(transaction.id): \(error.localizedDescription)")
            }
        }
    }
    
    /// 处理失败的交易
    /// - Parameter transaction: 交易信息
    private func handleFailedTransaction(_ transaction: IAPTransaction) async {
        IAPLogger.warning("TransactionMonitor: Processing failed transaction: \(transaction.id)")
        
        if let error = transaction.failureError {
            IAPLogger.logError(
                error,
                context: [
                    "transactionID": transaction.id,
                    "productID": transaction.productID
                ]
            )
        }
        
        // 失败的交易通常会自动从队列中移除，但我们可以确保完成
        do {
            try await adapter.finishTransaction(transaction)
        } catch {
            IAPLogger.debug("TransactionMonitor: Failed transaction already removed from queue")
        }
    }
    
    /// 处理恢复的交易
    /// - Parameter transaction: 交易信息
    private func handleRestoredTransaction(_ transaction: IAPTransaction) async {
        IAPLogger.info("TransactionMonitor: Processing restored transaction: \(transaction.id)")
        
        // 恢复的交易需要完成
        if configuration.autoFinishTransactions {
            do {
                try await adapter.finishTransaction(transaction)
                IAPLogger.debug("TransactionMonitor: Auto-finished restored transaction: \(transaction.id)")
            } catch {
                IAPLogger.warning("TransactionMonitor: Failed to auto-finish restored transaction \(transaction.id): \(error.localizedDescription)")
            }
        }
    }
    
    /// 处理正在购买的交易
    /// - Parameter transaction: 交易信息
    private func handlePurchasingTransaction(_ transaction: IAPTransaction) async {
        IAPLogger.debug("TransactionMonitor: Processing purchasing transaction: \(transaction.id)")
        // 正在购买的交易不需要特殊处理，只是记录状态
    }
    
    /// 处理延期的交易
    /// - Parameter transaction: 交易信息
    private func handleDeferredTransaction(_ transaction: IAPTransaction) async {
        IAPLogger.info("TransactionMonitor: Processing deferred transaction: \(transaction.id)")
        // 延期的交易（如等待家长批准）不需要立即处理
    }
    
    // MARK: - Supporting Types
    
    /// 监控统计信息
    public struct MonitoringStats: Sendable {
    /// 监控开始时间
    public var startTime: Date?
    
    /// 监控结束时间
    public var endTime: Date?
    
    /// 当前监控持续时间
    public var currentDuration: TimeInterval?
    
    /// 处理的交易总数
    public var transactionsProcessed: Int = 0
    
    /// 成功的交易数
    public var successfulTransactions: Int = 0
    
    /// 失败的交易数
    public var failedTransactions: Int = 0
    
    /// 恢复的交易数
    public var restoredTransactions: Int = 0
    
    /// 延期的交易数
    public var deferredTransactions: Int = 0
    
    /// 处理的未完成交易数
    public var pendingTransactionsProcessed: Int = 0
    
    /// 监控的订单数
    public var ordersMonitored: Int = 0
    
    /// 过期的订单数
    public var expiredOrders: Int = 0
    
    /// 订单-交易关联数
    public var orderTransactionAssociations: Int = 0
    
    /// 总监控时长
    public var totalDuration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }
    
    /// 交易成功率
    public var transactionSuccessRate: Double {
        guard transactionsProcessed > 0 else { return 0.0 }
        return Double(successfulTransactions) / Double(transactionsProcessed)
    }
    
    /// 向后兼容的成功率属性
    public var successRate: Double {
        return transactionSuccessRate
    }
    
    /// 统计摘要
    public var summary: String {
        let duration = totalDuration ?? currentDuration ?? 0
        return """
        Monitoring Duration: \(String(format: "%.1f", duration))s
        Transactions Processed: \(transactionsProcessed)
        Transaction Success Rate: \(String(format: "%.1f", transactionSuccessRate * 100))%
        Successful: \(successfulTransactions), Failed: \(failedTransactions)
        Restored: \(restoredTransactions), Deferred: \(deferredTransactions)
        Pending Processed: \(pendingTransactionsProcessed)
        Orders Monitored: \(ordersMonitored)
        Expired Orders: \(expiredOrders)
        Order-Transaction Associations: \(orderTransactionAssociations)
        """
    }
    
        public init() {}
    }
}

// MARK: - Transaction Monitor Extensions

extension TransactionMonitor {
    
    /// 交易监控器状态
    public enum MonitoringState: Sendable {
        case stopped
        case starting
        case monitoring
        case stopping
    }
    
    /// 获取当前监控状态
    public var monitoringState: MonitoringState {
        return isMonitoring ? .monitoring : .stopped
    }
    
    /// 检查是否有活跃的处理器
    public var hasActiveHandlers: Bool {
        return !transactionUpdateHandlers.isEmpty
    }
    
    /// 获取活跃处理器数量
    public var activeHandlerCount: Int {
        return transactionUpdateHandlers.count
    }
    
    /// 获取活跃处理器标识符列表
    public var activeHandlerIdentifiers: [String] {
        return Array(transactionUpdateHandlers.keys)
    }
    
    /// 检查是否有活跃的订单处理器
    public var hasActiveOrderHandlers: Bool {
        return !orderUpdateHandlers.isEmpty
    }
    
    /// 获取活跃订单处理器数量
    public var activeOrderHandlerCount: Int {
        return orderUpdateHandlers.count
    }
    
    /// 获取活跃订单处理器标识符列表
    public var activeOrderHandlerIdentifiers: [String] {
        return Array(orderUpdateHandlers.keys)
    }
    
    /// 获取当前订单-交易关联数量
    public var orderTransactionAssociationCount: Int {
        return orderTransactionAssociations.count
    }
    
    /// 检查是否启用了订单监控
    public var isOrderMonitoringEnabled: Bool {
        return orderService != nil && cache != nil
    }
}

// MARK: - Convenience Methods

extension TransactionMonitor {
    
    /// 添加简单的交易更新处理器
    /// - Parameter handler: 交易更新处理器
    /// - Returns: 处理器标识符，用于后续移除
    @discardableResult
    public func addTransactionUpdateHandler(
        handler: @escaping (IAPTransaction) -> Void
    ) -> String {
        let identifier = UUID().uuidString
        addTransactionUpdateHandler(identifier: identifier, handler: handler)
        return identifier
    }
    
    /// 添加特定状态的交易处理器
    /// - Parameters:
    ///   - state: 要监听的交易状态
    ///   - handler: 交易处理器
    /// - Returns: 处理器标识符
    @discardableResult
    public func addTransactionHandler(
        for state: IAPTransactionState,
        handler: @escaping (IAPTransaction) -> Void
    ) -> String {
        let identifier = "state_\(state)_\(UUID().uuidString)"
        
        addTransactionUpdateHandler(identifier: identifier) { transaction in
            if transaction.transactionState == state {
                handler(transaction)
            }
        }
        
        return identifier
    }
    
    /// 添加特定商品的交易处理器
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - handler: 交易处理器
    /// - Returns: 处理器标识符
    @discardableResult
    public func addProductTransactionHandler(
        for productID: String,
        handler: @escaping (IAPTransaction) -> Void
    ) -> String {
        let identifier = "product_\(productID)_\(UUID().uuidString)"
        
        addTransactionUpdateHandler(identifier: identifier) { transaction in
            if transaction.productID == productID {
                handler(transaction)
            }
        }
        
        return identifier
    }
    
    /// 添加简单的订单更新处理器
    /// - Parameter handler: 订单更新处理器
    /// - Returns: 处理器标识符，用于后续移除
    @discardableResult
    public func addOrderUpdateHandler(
        handler: @escaping (IAPOrder) -> Void
    ) -> String {
        let identifier = UUID().uuidString
        addOrderUpdateHandler(identifier: identifier, handler: handler)
        return identifier
    }
    
    /// 添加特定状态的订单处理器
    /// - Parameters:
    ///   - status: 要监听的订单状态
    ///   - handler: 订单处理器
    /// - Returns: 处理器标识符
    @discardableResult
    public func addOrderHandler(
        for status: IAPOrderStatus,
        handler: @escaping (IAPOrder) -> Void
    ) -> String {
        let identifier = "order_status_\(status.rawValue)_\(UUID().uuidString)"
        
        addOrderUpdateHandler(identifier: identifier) { order in
            if order.status == status {
                handler(order)
            }
        }
        
        return identifier
    }
    
    /// 添加特定商品的订单处理器
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - handler: 订单处理器
    /// - Returns: 处理器标识符
    @discardableResult
    public func addProductOrderHandler(
        for productID: String,
        handler: @escaping (IAPOrder) -> Void
    ) -> String {
        let identifier = "order_product_\(productID)_\(UUID().uuidString)"
        
        addOrderUpdateHandler(identifier: identifier) { order in
            if order.productID == productID {
                handler(order)
            }
        }
        
        return identifier
    }
}
