import Foundation

/// 交易恢复管理器，负责处理应用启动时的交易恢复和订单恢复
@MainActor
public final class TransactionRecoveryManager {
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 订单服务
    private let orderService: OrderServiceProtocol
    
    /// 缓存管理器
    private let cache: IAPCache
    
    /// 配置信息
    private let configuration: IAPConfiguration
    
    /// 状态管理器
    private weak var stateManager: IAPState?
    
    /// 恢复统计信息
    private var recoveryStats = RecoveryStatistics()
    
    /// 恢复状态
    private var isRecovering = false
    
    /// 当前恢复结果
    private var currentRecoveryResult: RecoveryResult?
    
    /// 初始化交易恢复管理器
    /// - Parameters:
    ///   - adapter: StoreKit 适配器
    ///   - orderService: 订单服务
    ///   - cache: 缓存管理器
    ///   - configuration: 配置信息
    ///   - stateManager: 状态管理器
    public init(
        adapter: StoreKitAdapterProtocol,
        orderService: OrderServiceProtocol,
        cache: IAPCache,
        configuration: IAPConfiguration = .default,
        stateManager: IAPState? = nil
    ) {
        self.adapter = adapter
        self.orderService = orderService
        self.cache = cache
        self.configuration = configuration
        self.stateManager = stateManager
    }
    
    // MARK: - Public Methods
    
    /// 开始交易和订单恢复
    /// - Returns: 恢复结果
    public func startRecovery() async -> RecoveryResult {
        guard !isRecovering else {
            IAPLogger.debug("TransactionRecoveryManager: Recovery already in progress")
            return .alreadyInProgress
        }
        
        IAPLogger.info("TransactionRecoveryManager: Starting transaction and order recovery")
        isRecovering = true
        recoveryStats.reset()
        recoveryStats.startTime = Date()
        currentRecoveryResult = nil
        
        // 更新状态
        stateManager?.setRecoveryInProgress(true)
        
        // 1. 首先进行订单状态同步
        await synchronizeOrderStatus()
        
        // 2. 清理过期和失败的订单
        await cleanupExpiredAndFailedOrders()
        
        // 3. 获取未完成的交易
        let pendingTransactions = await adapter.getPendingTransactions()
        recoveryStats.totalTransactions = pendingTransactions.count
        
        // 4. 获取待处理的订单
        let pendingOrders = await cache.getPendingOrders()
        recoveryStats.totalOrders = pendingOrders.count
        
        if pendingTransactions.isEmpty && pendingOrders.isEmpty {
            IAPLogger.debug("TransactionRecoveryManager: No pending transactions or orders found")
            return await completeRecovery(with: .success(recoveredCount: 0))
        }
        
        IAPLogger.info("TransactionRecoveryManager: Found \(pendingTransactions.count) pending transactions and \(pendingOrders.count) pending orders")
        
        // 5. 按优先级排序交易和订单
        let sortedTransactions = prioritizeTransactions(pendingTransactions)
        let sortedOrders = prioritizeOrders(pendingOrders)
        
        // 6. 处理订单和交易（订单优先）
        await processOrdersAndTransactions(orders: sortedOrders, transactions: sortedTransactions)
        
        // 完成恢复
        let totalRecovered = recoveryStats.recoveredTransactions + recoveryStats.recoveredOrders
        return await completeRecovery(with: .success(recoveredCount: totalRecovered))
    }
    
    /// 获取恢复统计信息
    public func getRecoveryStatistics() -> RecoveryStatistics {
        return recoveryStats
    }
    
    /// 检查是否正在恢复
    public var isRecoveryInProgress: Bool {
        return isRecovering
    }
    
    // MARK: - Private Methods
    
    /// 同步订单状态
    private func synchronizeOrderStatus() async {
        IAPLogger.debug("TransactionRecoveryManager: Synchronizing order status on app startup")
        
        do {
            let recoveredOrders = try await orderService.recoverPendingOrders()
            recoveryStats.synchronizedOrders = recoveredOrders.count
            
            for order in recoveredOrders {
                await cache.storeOrder(order)
            }
            
            IAPLogger.info("TransactionRecoveryManager: Synchronized \(recoveredOrders.count) orders")
        } catch {
            IAPLogger.error("TransactionRecoveryManager: Failed to synchronize order status: \(error)")
        }
    }
    
    /// 清理过期和失败的订单
    private func cleanupExpiredAndFailedOrders() async {
        IAPLogger.debug("TransactionRecoveryManager: Cleaning up expired and failed orders")
        
        do {
            // 清理过期订单
            try await orderService.cleanupExpiredOrders()
            
            // 清理本地缓存中的过期订单
            await cache.cleanupExpiredOrders()
            
            IAPLogger.info("TransactionRecoveryManager: Completed order cleanup")
        } catch {
            IAPLogger.error("TransactionRecoveryManager: Failed to cleanup orders: \(error)")
        }
    }
    
    /// 按优先级排序订单
    /// - Parameter orders: 待排序的订单列表
    /// - Returns: 排序后的订单列表
    private func prioritizeOrders(_ orders: [IAPOrder]) -> [IAPOrder] {
        return orders.sorted { order1, order2 in
            // 优先级规则：
            // 1. 创建时间较早的优先
            // 2. pending 状态优先于 created 状态
            // 3. 即将过期的订单优先处理
            
            // 首先按状态优先级排序
            let priority1 = getOrderPriority(order1)
            let priority2 = getOrderPriority(order2)
            
            if priority1 != priority2 {
                return priority1 < priority2
            }
            
            // 然后按创建时间排序
            if order1.createdAt != order2.createdAt {
                return order1.createdAt < order2.createdAt
            }
            
            // 最后按过期时间排序（即将过期的优先）
            if let expires1 = order1.expiresAt, let expires2 = order2.expiresAt {
                return expires1 < expires2
            }
            
            return order1.id < order2.id
        }
    }
    
    /// 获取订单优先级
    /// - Parameter order: 订单
    /// - Returns: 优先级数值（越小优先级越高）
    private func getOrderPriority(_ order: IAPOrder) -> Int {
        switch order.status {
        case .pending:
            return 1 // 最高优先级
        case .created:
            return 2
        case .completed, .cancelled, .failed:
            return 3 // 终态订单优先级最低
        }
    }
    
    /// 处理订单和交易
    /// - Parameters:
    ///   - orders: 排序后的订单列表
    ///   - transactions: 排序后的交易列表
    private func processOrdersAndTransactions(orders: [IAPOrder], transactions: [IAPTransaction]) async {
        // 创建订单-交易关联映射
        let orderTransactionMap = createOrderTransactionMap(orders: orders, transactions: transactions)
        
        // 首先处理有关联交易的订单
        for order in orders {
            if let associatedTransaction = orderTransactionMap[order.id] {
                await processOrderWithTransaction(order: order, transaction: associatedTransaction)
            } else {
                await processStandaloneOrder(order)
            }
        }
        
        // 处理没有关联订单的交易
        let processedTransactionIds = Set(orderTransactionMap.values.map { $0.id })
        let standaloneTransactions = transactions.filter { !processedTransactionIds.contains($0.id) }
        
        for transaction in standaloneTransactions {
            await processTransaction(transaction)
        }
    }
    
    /// 创建订单-交易关联映射
    /// - Parameters:
    ///   - orders: 订单列表
    ///   - transactions: 交易列表
    /// - Returns: 订单ID到交易的映射
    private func createOrderTransactionMap(orders: [IAPOrder], transactions: [IAPTransaction]) -> [String: IAPTransaction] {
        var orderTransactionMap: [String: IAPTransaction] = [:]
        
        // 基于商品ID和时间窗口进行关联
        for order in orders {
            for transaction in transactions {
                if order.productID == transaction.productID {
                    // 检查时间窗口（交易时间应该在订单创建之后）
                    let timeDifference = transaction.purchaseDate.timeIntervalSince(order.createdAt)
                    if timeDifference >= 0 && timeDifference <= 3600 { // 1小时内
                        orderTransactionMap[order.id] = transaction
                        break
                    }
                }
            }
        }
        
        return orderTransactionMap
    }
    
    /// 处理有关联交易的订单
    /// - Parameters:
    ///   - order: 订单
    ///   - transaction: 关联的交易
    private func processOrderWithTransaction(order: IAPOrder, transaction: IAPTransaction) async {
        IAPLogger.debug("TransactionRecoveryManager: Processing order \(order.id) with transaction \(transaction.id)")
        
        do {
            switch transaction.transactionState {
            case .purchased, .restored:
                // 交易成功，更新订单状态为完成
                try await orderService.updateOrderStatus(order.id, status: .completed)
                try await adapter.finishTransaction(transaction)
                
                recoveryStats.recoveredOrders += 1
                recoveryStats.recoveredTransactions += 1
                
                IAPLogger.info("TransactionRecoveryManager: Successfully recovered order \(order.id) with transaction \(transaction.id)")
                
            case .failed(let error):
                // 交易失败，更新订单状态
                if error.isRetryable && configuration.autoRetryFailedTransactions {
                    await retryOrderWithTransaction(order: order, transaction: transaction)
                } else {
                    try await orderService.updateOrderStatus(order.id, status: .failed)
                    try await adapter.finishTransaction(transaction)
                    recoveryStats.failedOrders += 1
                    recoveryStats.failedTransactions += 1
                }
                
            case .purchasing, .deferred:
                // 交易进行中，保持订单为pending状态
                if order.status != .pending {
                    try await orderService.updateOrderStatus(order.id, status: .pending)
                }
                recoveryStats.skippedOrders += 1
                recoveryStats.skippedTransactions += 1
            }
            
        } catch {
            let iapError = IAPError.from(error)
            recoveryStats.failedOrders += 1
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "processOrderWithTransaction",
                    "orderId": order.id,
                    "transactionId": transaction.id,
                    "orderStatus": "\(order.status)",
                    "transactionState": "\(transaction.transactionState)"
                ]
            )
        }
    }
    
    /// 处理独立订单（没有关联交易）
    /// - Parameter order: 订单
    private func processStandaloneOrder(_ order: IAPOrder) async {
        IAPLogger.debug("TransactionRecoveryManager: Processing standalone order \(order.id)")
        recoveryStats.processedOrders += 1
        
        do {
            // 查询订单状态
            let currentStatus = try await orderService.queryOrderStatus(order.id)
            
            if currentStatus != order.status {
                // 状态已变化，更新本地缓存
                await cache.updateOrderStatus(order.id, status: currentStatus)
                
                if currentStatus.isTerminal {
                    recoveryStats.recoveredOrders += 1
                } else {
                    recoveryStats.skippedOrders += 1
                }
                
                IAPLogger.info("TransactionRecoveryManager: Updated order \(order.id) status: \(order.status) -> \(currentStatus)")
            } else {
                recoveryStats.skippedOrders += 1
            }
            
        } catch {
            let iapError = IAPError.from(error)
            recoveryStats.failedOrders += 1
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "processStandaloneOrder",
                    "orderId": order.id,
                    "orderStatus": "\(order.status)"
                ]
            )
        }
    }
    
    /// 重试订单和交易
    /// - Parameters:
    ///   - order: 订单
    ///   - transaction: 交易
    private func retryOrderWithTransaction(order: IAPOrder, transaction: IAPTransaction) async {
        IAPLogger.info("TransactionRecoveryManager: Retrying order \(order.id) with transaction \(transaction.id)")
        
        do {
            // 尝试重新完成交易
            try await adapter.finishTransaction(transaction)
            
            // 更新订单状态为完成
            try await orderService.updateOrderStatus(order.id, status: .completed)
            
            recoveryStats.recoveredOrders += 1
            recoveryStats.recoveredTransactions += 1
            
            IAPLogger.info("TransactionRecoveryManager: Successfully retried order \(order.id) with transaction \(transaction.id)")
            
        } catch {
            let iapError = IAPError.from(error)
            
            // 重试失败，标记订单为失败
            do {
                try await orderService.updateOrderStatus(order.id, status: .failed)
            } catch {
                IAPLogger.error("TransactionRecoveryManager: Failed to update order status after retry failure")
            }
            
            recoveryStats.failedOrders += 1
            recoveryStats.failedTransactions += 1
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "retryOrderWithTransaction",
                    "orderId": order.id,
                    "transactionId": transaction.id
                ]
            )
        }
    }
    
    /// 按优先级排序交易
    /// - Parameter transactions: 待排序的交易列表
    /// - Returns: 排序后的交易列表
    private func prioritizeTransactions(_ transactions: [IAPTransaction]) -> [IAPTransaction] {
        return transactions.sorted { transaction1, transaction2 in
            // 优先级规则：
            // 1. 购买时间较早的优先
            // 2. 相同时间的话，成功状态优先于失败状态
            // 3. 失败状态中，可重试的优先于不可重试的
            
            if transaction1.purchaseDate != transaction2.purchaseDate {
                return transaction1.purchaseDate < transaction2.purchaseDate
            }
            
            // 状态优先级比较
            let priority1 = getTransactionPriority(transaction1)
            let priority2 = getTransactionPriority(transaction2)
            
            return priority1 < priority2
        }
    }
    
    /// 获取交易优先级
    /// - Parameter transaction: 交易
    /// - Returns: 优先级数值（越小优先级越高）
    private func getTransactionPriority(_ transaction: IAPTransaction) -> Int {
        switch transaction.transactionState {
        case .purchased, .restored:
            return 1 // 最高优先级
        case .purchasing:
            return 2
        case .deferred:
            return 3
        case .failed(let error):
            return error.isRetryable ? 4 : 5 // 可重试的失败交易优先级高于不可重试的
        }
    }
    
    /// 处理单个交易
    /// - Parameter transaction: 交易信息
    private func processTransaction(_ transaction: IAPTransaction) async {
        IAPLogger.debug("TransactionRecoveryManager: Processing transaction: \\(transaction.id)")
        recoveryStats.processedTransactions += 1
        
        do {
            switch transaction.transactionState {
            case .purchased, .restored:
                // 完成成功的交易
                try await adapter.finishTransaction(transaction)
                recoveryStats.recoveredTransactions += 1
                IAPLogger.info("TransactionRecoveryManager: Successfully recovered transaction: \\(transaction.id)")
                
            case .failed(let error):
                if error.isRetryable && configuration.autoRetryFailedTransactions {
                    // 尝试重新处理可重试的失败交易
                    await retryFailedTransaction(transaction)
                } else {
                    // 完成不可重试的失败交易
                    try await adapter.finishTransaction(transaction)
                    recoveryStats.failedTransactions += 1
                    IAPLogger.info("TransactionRecoveryManager: Finished failed transaction: \\(transaction.id)")
                }
                
            case .purchasing, .deferred:
                // 对于进行中或延期的交易，记录但不处理
                recoveryStats.skippedTransactions += 1
                IAPLogger.debug("TransactionRecoveryManager: Skipped transaction in progress: \\(transaction.id)")
            }
            
        } catch {
            let iapError = IAPError.from(error)
            recoveryStats.failedTransactions += 1
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "processTransaction",
                    "transactionId": transaction.id,
                    "transactionState": "\\(transaction.transactionState)"
                ]
            )
        }
    }
    
    /// 重试失败的交易
    /// - Parameter transaction: 失败的交易
    private func retryFailedTransaction(_ transaction: IAPTransaction) async {
        IAPLogger.info("TransactionRecoveryManager: Retrying failed transaction: \\(transaction.id)")
        
        do {
            // 尝试重新完成交易
            try await adapter.finishTransaction(transaction)
            recoveryStats.recoveredTransactions += 1
            IAPLogger.info("TransactionRecoveryManager: Successfully retried transaction: \\(transaction.id)")
            
        } catch {
            let iapError = IAPError.from(error)
            recoveryStats.failedTransactions += 1
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "retryFailedTransaction",
                    "transactionId": transaction.id
                ]
            )
        }
    }
    
    /// 完成恢复过程
    /// - Parameter result: 恢复结果
    /// - Returns: 恢复结果
    private func completeRecovery(with result: RecoveryResult) async -> RecoveryResult {
        recoveryStats.endTime = Date()
        isRecovering = false
        currentRecoveryResult = result
        
        // 更新状态
        stateManager?.setRecoveryInProgress(false)
        
        // 记录恢复结果
        let duration = recoveryStats.endTime?.timeIntervalSince(recoveryStats.startTime ?? Date()) ?? 0
        
        switch result {
        case .success(let recoveredCount):
            IAPLogger.info("TransactionRecoveryManager: Recovery completed successfully. Recovered \(recoveredCount) transactions in \(String(format: "%.2f", duration))s")
            
        case .failure(let error):
            IAPLogger.logError(
                error,
                context: [
                    "operation": "completeRecovery",
                    "duration": String(format: "%.2f", duration),
                    "processedTransactions": String(recoveryStats.processedTransactions)
                ]
            )
            
        case .alreadyInProgress:
            break
        }
        
        return result
    }
}

// MARK: - Supporting Types

/// 恢复结果
public enum RecoveryResult: Sendable {
    case success(recoveredCount: Int)
    case failure(IAPError)
    case alreadyInProgress
}

/// 恢复统计信息
public struct RecoveryStatistics {
    /// 开始时间
    public var startTime: Date?
    
    /// 结束时间
    public var endTime: Date?
    
    /// 总交易数
    public var totalTransactions: Int = 0
    
    /// 已处理交易数
    public var processedTransactions: Int = 0
    
    /// 成功恢复的交易数
    public var recoveredTransactions: Int = 0
    
    /// 失败的交易数
    public var failedTransactions: Int = 0
    
    /// 跳过的交易数
    public var skippedTransactions: Int = 0
    
    /// 总订单数
    public var totalOrders: Int = 0
    
    /// 已处理订单数
    public var processedOrders: Int = 0
    
    /// 成功恢复的订单数
    public var recoveredOrders: Int = 0
    
    /// 失败的订单数
    public var failedOrders: Int = 0
    
    /// 跳过的订单数
    public var skippedOrders: Int = 0
    
    /// 同步的订单数
    public var synchronizedOrders: Int = 0
    
    /// 恢复持续时间
    public var duration: TimeInterval? {
        guard let startTime = startTime, let endTime = endTime else {
            return nil
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    /// 交易成功率
    public var transactionSuccessRate: Double {
        guard processedTransactions > 0 else { return 0.0 }
        return Double(recoveredTransactions) / Double(processedTransactions)
    }
    
    /// 订单成功率
    public var orderSuccessRate: Double {
        guard processedOrders > 0 else { return 0.0 }
        return Double(recoveredOrders) / Double(processedOrders)
    }
    
    /// 总体成功率
    public var overallSuccessRate: Double {
        let totalProcessed = processedTransactions + processedOrders
        guard totalProcessed > 0 else { return 0.0 }
        let totalRecovered = recoveredTransactions + recoveredOrders
        return Double(totalRecovered) / Double(totalProcessed)
    }
    
    /// 向后兼容的成功率属性
    public var successRate: Double {
        return transactionSuccessRate
    }
    
    /// 统计摘要
    public var summary: String {
        let duration = self.duration ?? 0
        return """
        Recovery Duration: \(String(format: "%.1f", duration))s
        Transactions: \(recoveredTransactions)/\(totalTransactions) recovered (\(String(format: "%.1f", transactionSuccessRate * 100))%)
        Orders: \(recoveredOrders)/\(totalOrders) recovered (\(String(format: "%.1f", orderSuccessRate * 100))%)
        Overall Success Rate: \(String(format: "%.1f", overallSuccessRate * 100))%
        Synchronized Orders: \(synchronizedOrders)
        """
    }
    
    /// 重置统计信息
    mutating func reset() {
        startTime = nil
        endTime = nil
        totalTransactions = 0
        processedTransactions = 0
        recoveredTransactions = 0
        failedTransactions = 0
        skippedTransactions = 0
        totalOrders = 0
        processedOrders = 0
        recoveredOrders = 0
        failedOrders = 0
        skippedOrders = 0
        synchronizedOrders = 0
    }
}

// MARK: - Configuration Extensions

extension IAPConfiguration {
    /// 是否自动重试失败的交易
    public var autoRetryFailedTransactions: Bool {
        return autoRecoverTransactions // 复用现有配置
    }
}