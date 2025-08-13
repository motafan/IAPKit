import Foundation

/// 交易监控器，负责实时监听交易状态变化
@MainActor
public final class TransactionMonitor: Sendable {
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 配置信息
    private let configuration: IAPConfiguration
    
    /// 是否正在监控
    private var isMonitoring = false
    
    /// 交易更新回调
    private var transactionUpdateHandlers: [String: (IAPTransaction) -> Void] = [:]
    
    /// 监控统计信息
    private var monitoringStats = MonitoringStats()
    
    /// 初始化交易监控器
    /// - Parameters:
    ///   - adapter: StoreKit 适配器
    ///   - configuration: 配置信息
    public init(
        adapter: StoreKitAdapterProtocol,
        configuration: IAPConfiguration = .default
    ) {
        self.adapter = adapter
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// 开始监控交易
    public func startMonitoring() async {
        guard !isMonitoring else {
            IAPLogger.debug("TransactionMonitor: Already monitoring transactions")
            return
        }
        
        IAPLogger.info("TransactionMonitor: Starting transaction monitoring")
        
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
        
        IAPLogger.info("TransactionMonitor: Transaction monitoring started")
    }
    
    /// 停止监控交易
    public func stopMonitoring() {
        guard isMonitoring else {
            IAPLogger.debug("TransactionMonitor: Not currently monitoring transactions")
            return
        }
        
        IAPLogger.info("TransactionMonitor: Stopping transaction monitoring")
        
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
        
        IAPLogger.info("TransactionMonitor: Transaction monitoring stopped")
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
    
    /// 移除交易更新处理器
    /// - Parameter identifier: 处理器标识符
    public func removeTransactionUpdateHandler(identifier: String) {
        transactionUpdateHandlers.removeValue(forKey: identifier)
        IAPLogger.debug("TransactionMonitor: Removed transaction update handler: \(identifier)")
    }
    
    /// 清除所有交易更新处理器
    public func clearAllTransactionUpdateHandlers() {
        let count = transactionUpdateHandlers.count
        transactionUpdateHandlers.removeAll()
        IAPLogger.debug("TransactionMonitor: Cleared \(count) transaction update handlers")
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
    
    // MARK: - Private Methods
    
    /// 处理交易更新
    /// - Parameter transaction: 交易信息
    private func handleTransactionUpdate(_ transaction: IAPTransaction) async {
        IAPLogger.debug("TransactionMonitor: Handling transaction update: \(transaction.id)")
        
        // 更新统计信息
        monitoringStats.transactionsProcessed += 1
        
        switch transaction.transactionState {
        case .purchased:
            monitoringStats.successfulTransactions += 1
            await handleSuccessfulTransaction(transaction)
            
        case .failed:
            monitoringStats.failedTransactions += 1
            await handleFailedTransaction(transaction)
            
        case .restored:
            monitoringStats.restoredTransactions += 1
            await handleRestoredTransaction(transaction)
            
        case .purchasing:
            await handlePurchasingTransaction(transaction)
            
        case .deferred:
            monitoringStats.deferredTransactions += 1
            await handleDeferredTransaction(transaction)
        }
        
        // 通知所有注册的处理器
        for (identifier, handler) in transactionUpdateHandlers {
            handler(transaction)
            IAPLogger.debug("TransactionMonitor: Notified handler: \(identifier)")
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
    
    /// 总监控时长
    public var totalDuration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }
    
    /// 成功率
    public var successRate: Double {
        guard transactionsProcessed > 0 else { return 0.0 }
        return Double(successfulTransactions) / Double(transactionsProcessed)
    }
    
    /// 统计摘要
    public var summary: String {
        let duration = totalDuration ?? currentDuration ?? 0
        return """
        Monitoring Duration: \(String(format: "%.1f", duration))s
        Transactions Processed: \(transactionsProcessed)
        Success Rate: \(String(format: "%.1f", successRate * 100))%
        Successful: \(successfulTransactions), Failed: \(failedTransactions)
        Restored: \(restoredTransactions), Deferred: \(deferredTransactions)
        Pending Processed: \(pendingTransactionsProcessed)
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
}