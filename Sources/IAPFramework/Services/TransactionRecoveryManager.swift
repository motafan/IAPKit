import Foundation

/// 交易恢复管理器，负责处理应用启动时的交易恢复
@MainActor
public final class TransactionRecoveryManager {
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 配置信息
    private let configuration: IAPConfiguration
    
    /// 状态管理器
    private weak var stateManager: IAPState?
    
    /// 恢复统计信息
    private var recoveryStats = RecoveryStatistics()
    
    /// 恢复状态
    private var isRecovering = false
    
    /// 恢复完成回调
    private var recoveryCompletionHandlers: [(RecoveryResult) -> Void] = []
    
    /// 初始化交易恢复管理器
    /// - Parameters:
    ///   - adapter: StoreKit 适配器
    ///   - configuration: 配置信息
    ///   - stateManager: 状态管理器
    public init(
        adapter: StoreKitAdapterProtocol,
        configuration: IAPConfiguration = .default,
        stateManager: IAPState? = nil
    ) {
        self.adapter = adapter
        self.configuration = configuration
        self.stateManager = stateManager
    }
    
    // MARK: - Public Methods
    
    /// 开始交易恢复
    /// - Parameter completion: 恢复完成回调
    public func startRecovery(completion: @escaping (RecoveryResult) -> Void = { _ in }) async {
        guard !isRecovering else {
            IAPLogger.debug("TransactionRecoveryManager: Recovery already in progress")
            completion(.alreadyInProgress)
            return
        }
        
        IAPLogger.info("TransactionRecoveryManager: Starting transaction recovery")
        isRecovering = true
        recoveryStats.reset()
        recoveryStats.startTime = Date()
        
        // 添加完成回调
        recoveryCompletionHandlers.append(completion)
        
        // 更新状态
        stateManager?.setRecoveryInProgress(true)
        
        // 获取未完成的交易
        let pendingTransactions = await adapter.getPendingTransactions()
        recoveryStats.totalTransactions = pendingTransactions.count
        
        if pendingTransactions.isEmpty {
            IAPLogger.debug("TransactionRecoveryManager: No pending transactions found")
            await completeRecovery(with: .success(recoveredCount: 0))
            return
        }
        
        IAPLogger.info("TransactionRecoveryManager: Found \\(pendingTransactions.count) pending transactions")
        
        // 按优先级排序交易
        let sortedTransactions = prioritizeTransactions(pendingTransactions)
        
        // 处理每个交易
        for transaction in sortedTransactions {
            await processTransaction(transaction)
        }
        
        // 完成恢复
        await completeRecovery(with: .success(recoveredCount: recoveryStats.recoveredTransactions))
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
    private func completeRecovery(with result: RecoveryResult) async {
        recoveryStats.endTime = Date()
        isRecovering = false
        
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
        
        // 调用所有完成回调
        for handler in recoveryCompletionHandlers {
            handler(result)
        }
        recoveryCompletionHandlers.removeAll()
    }
}

// MARK: - Supporting Types

/// 恢复结果
public enum RecoveryResult {
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
    
    /// 恢复持续时间
    public var duration: TimeInterval? {
        guard let startTime = startTime, let endTime = endTime else {
            return nil
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    /// 成功率
    public var successRate: Double {
        guard processedTransactions > 0 else { return 0.0 }
        return Double(recoveredTransactions) / Double(processedTransactions)
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
    }
}

// MARK: - Configuration Extensions

extension IAPConfiguration {
    /// 是否自动重试失败的交易
    public var autoRetryFailedTransactions: Bool {
        return autoRecoverTransactions // 复用现有配置
    }
}