import Foundation

/// Mock 交易监控器，用于测试
@MainActor
public final class MockTransactionMonitor: Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的未完成交易
    public var mockPendingTransactions: [IAPTransaction] = []
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 调用记录
    public private(set) var callHistory: [String] = []
    
    /// 各方法的调用次数
    public private(set) var startMonitoringCallCount = 0
    public private(set) var stopMonitoringCallCount = 0
    public private(set) var handlePendingCallCount = 0
    
    /// 监控状态
    public private(set) var isMonitoring = false
    
    /// 交易状态变化回调
    public var onTransactionUpdate: ((IAPTransaction) -> Void)?
    
    /// 监控统计
    private var monitoringStats = MockMonitoringStats()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Mock Configuration
    
    /// 设置模拟的未完成交易
    /// - Parameter transactions: 交易数组
    public func setMockPendingTransactions(_ transactions: [IAPTransaction]) {
        mockPendingTransactions = transactions
    }
    
    /// 添加模拟的未完成交易
    /// - Parameter transaction: 交易
    public func addMockPendingTransaction(_ transaction: IAPTransaction) {
        mockPendingTransactions.append(transaction)
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
        mockPendingTransactions.removeAll()
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        callHistory.removeAll()
        startMonitoringCallCount = 0
        stopMonitoringCallCount = 0
        handlePendingCallCount = 0
        isMonitoring = false
        onTransactionUpdate = nil
        monitoringStats = MockMonitoringStats()
    }
    
    // MARK: - TransactionMonitor Interface
    
    /// 开始监控交易
    public func startMonitoring() async {
        callHistory.append("startMonitoring()")
        startMonitoringCallCount += 1
        
        // 模拟延迟
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        isMonitoring = true
        monitoringStats.startTime = Date()
        
        // 自动处理未完成的交易
        await handlePendingTransactions()
    }
    
    /// 停止监控交易
    public func stopMonitoring() {
        callHistory.append("stopMonitoring()")
        stopMonitoringCallCount += 1
        
        isMonitoring = false
        if let startTime = monitoringStats.startTime {
            monitoringStats.totalMonitoringTime += Date().timeIntervalSince(startTime)
        }
    }
    
    /// 处理未完成的交易
    public func handlePendingTransactions() async {
        callHistory.append("handlePendingTransactions()")
        handlePendingCallCount += 1
        
        // 模拟延迟
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        // 模拟错误
        if shouldThrowError, let error = mockError {
            monitoringStats.errorCount += 1
            // 在实际实现中，这里会记录错误但不抛出
            return
        }
        
        // 处理所有未完成的交易
        for transaction in mockPendingTransactions {
            await processTransaction(transaction)
        }
        
        // 清空已处理的交易
        mockPendingTransactions.removeAll()
    }
    
    /// 获取监控统计信息
    /// - Returns: 监控统计信息
    public func getMonitoringStats() -> MockMonitoringStats {
        var stats = monitoringStats
        
        // 如果正在监控，计算当前的监控时间
        if isMonitoring, let startTime = stats.startTime {
            stats.currentSessionTime = Date().timeIntervalSince(startTime)
        }
        
        return stats
    }
    
    // MARK: - Test Helpers
    
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
    
    /// 模拟交易状态更新
    /// - Parameter transaction: 更新的交易
    public func simulateTransactionUpdate(_ transaction: IAPTransaction) {
        callHistory.append("simulateTransactionUpdate(\(transaction.id))")
        monitoringStats.transactionsProcessed += 1
        
        // 触发回调
        onTransactionUpdate?(transaction)
    }
    
    /// 模拟多个交易状态更新
    /// - Parameter transactions: 更新的交易数组
    public func simulateMultipleTransactionUpdates(_ transactions: [IAPTransaction]) {
        for transaction in transactions {
            simulateTransactionUpdate(transaction)
        }
    }
    
    /// 模拟监控错误
    /// - Parameter error: 错误
    public func simulateMonitoringError(_ error: IAPError) {
        callHistory.append("simulateMonitoringError(\(error.localizedDescription))")
        monitoringStats.errorCount += 1
    }
    
    /// 创建测试用的未完成交易
    /// - Parameter count: 交易数量
    /// - Returns: 未完成交易数组
    public static func createPendingTransactions(count: Int) -> [IAPTransaction] {
        return (1...count).map { index in
            IAPTransaction(
                id: "pending_tx_\(index)",
                productID: "test.product.\(index)",
                purchaseDate: Date(),
                transactionState: .purchasing
            )
        }
    }
    
    /// 创建测试用的成功交易
    /// - Parameter count: 交易数量
    /// - Returns: 成功交易数组
    public static func createSuccessfulTransactions(count: Int) -> [IAPTransaction] {
        return (1...count).map { index in
            IAPTransaction.successful(
                id: "success_tx_\(index)",
                productID: "test.product.\(index)",
                receiptData: TestDataGenerator.createMockReceiptData()
            )
        }
    }
    
    /// 创建测试用的失败交易
    /// - Parameter count: 交易数量
    /// - Returns: 失败交易数组
    public static func createFailedTransactions(count: Int) -> [IAPTransaction] {
        return (1...count).map { index in
            IAPTransaction.failed(
                id: "failed_tx_\(index)",
                productID: "test.product.\(index)",
                error: .purchaseFailed(underlying: "Test error \(index)")
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func processTransaction(_ transaction: IAPTransaction) async {
        // 模拟交易处理
        monitoringStats.transactionsProcessed += 1
        
        // 根据交易状态进行不同的处理
        switch transaction.transactionState {
        case .purchasing:
            // 模拟处理中的交易
            let updatedTransaction = IAPTransaction(
                id: transaction.id,
                productID: transaction.productID,
                purchaseDate: transaction.purchaseDate,
                transactionState: .purchased,
                receiptData: TestDataGenerator.createMockReceiptData()
            )
            simulateTransactionUpdate(updatedTransaction)
            
        case .purchased, .restored:
            // 已完成的交易
            simulateTransactionUpdate(transaction)
            
        case .failed:
            // 失败的交易
            monitoringStats.errorCount += 1
            simulateTransactionUpdate(transaction)
            
        case .deferred:
            // 延期的交易，暂时不处理
            break
        }
    }
}

// MARK: - Supporting Types

/// Mock 监控统计信息
public struct MockMonitoringStats: Sendable {
    /// 处理的交易数量
    public var transactionsProcessed: Int = 0
    
    /// 错误数量
    public var errorCount: Int = 0
    
    /// 监控开始时间
    public var startTime: Date?
    
    /// 总监控时间
    public var totalMonitoringTime: TimeInterval = 0
    
    /// 当前会话时间
    public var currentSessionTime: TimeInterval = 0
    
    /// 是否正在监控
    public var isMonitoring: Bool {
        return startTime != nil
    }
    
    /// 统计摘要
    public var summary: String {
        return """
        Monitoring Stats:
        - Transactions Processed: \(transactionsProcessed)
        - Errors: \(errorCount)
        - Total Monitoring Time: \(String(format: "%.1f", totalMonitoringTime))s
        - Current Session Time: \(String(format: "%.1f", currentSessionTime))s
        - Is Monitoring: \(isMonitoring)
        """
    }
    
    public init() {}
}

// MARK: - Test Scenarios

extension MockTransactionMonitor {
    
    /// 创建各种监控场景
    /// - Returns: 监控场景数组
    public static func createMonitoringScenarios() -> [(description: String, transactions: [IAPTransaction])] {
        return [
            ("Empty queue", []),
            ("Single pending transaction", createPendingTransactions(count: 1)),
            ("Multiple pending transactions", createPendingTransactions(count: 5)),
            ("Mixed transaction states", [
                createPendingTransactions(count: 2),
                createSuccessfulTransactions(count: 2),
                createFailedTransactions(count: 1)
            ].flatMap { $0 }),
            ("Large queue", createPendingTransactions(count: 50))
        ]
    }
    
    /// 创建错误场景
    /// - Returns: 错误场景数组
    public static func createErrorScenarios() -> [(description: String, error: IAPError)] {
        return [
            ("Network error during monitoring", .networkError),
            ("Transaction processing failed", .transactionProcessingFailed("Processing error")),
            ("Unknown error", .unknownError("Unknown monitoring error"))
        ]
    }
}
