import Foundation
@testable import IAPFramework

/// Mock 交易恢复管理器，用于测试
@MainActor
public final class MockTransactionRecoveryManager: @unchecked Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的恢复状态
    public var mockIsRecovering: Bool = false
    
    /// 模拟的恢复统计信息
    public var mockRecoveryStats: RecoveryStats = RecoveryStats()
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    /// 模拟的恢复订单
    public var mockRecoveredOrders: [IAPOrder] = []
    
    // MARK: - Call Tracking
    
    /// 调用计数器
    public private(set) var callCounts: [String: Int] = [:]
    
    /// 调用参数记录
    public private(set) var callParameters: [String: Any] = [:]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - TransactionRecoveryManager Mock Methods
    
    public func recoverPendingTransactions() async throws {
        incrementCallCount(for: "recoverPendingTransactions")
        
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        mockIsRecovering = true
        mockRecoveryStats.recoveryAttempts += 1
    }
    
    public func recoverPendingOrders() async throws -> [IAPOrder] {
        incrementCallCount(for: "recoverPendingOrders")
        
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        mockRecoveryStats.ordersRecovered += 1
        
        // 返回模拟的恢复订单
        return mockRecoveredOrders
    }
    
    public func cleanupFailedPurchases() async throws {
        incrementCallCount(for: "cleanupFailedPurchases")
        
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        mockRecoveryStats.failedPurchasesCleanedUp += 1
    }
    
    public func recoverOrderTransactionAssociations() async throws -> [(order: IAPOrder, transaction: IAPTransaction)] {
        incrementCallCount(for: "recoverOrderTransactionAssociations")
        
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // Return empty array for now - can be configured in tests
        return []
    }
    
    public func recoverOrphanedTransactions() async throws -> [IAPTransaction] {
        incrementCallCount(for: "recoverOrphanedTransactions")
        
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // Return empty array for now - can be configured in tests
        return []
    }
    
    public func getRecoveryStats() -> RecoveryStats {
        incrementCallCount(for: "getRecoveryStats")
        return mockRecoveryStats
    }
    
    public func resetRecoveryStats() {
        incrementCallCount(for: "resetRecoveryStats")
        mockRecoveryStats = RecoveryStats()
    }
    
    public var isCurrentlyRecovering: Bool {
        incrementCallCount(for: "isCurrentlyRecovering")
        return mockIsRecovering
    }
    
    // MARK: - Mock Configuration Methods
    
    /// 设置模拟恢复状态
    /// - Parameter isRecovering: 是否正在恢复
    public func setMockIsRecovering(_ isRecovering: Bool) {
        mockIsRecovering = isRecovering
    }
    
    /// 设置模拟恢复统计信息
    /// - Parameter stats: 统计信息
    public func setMockRecoveryStats(_ stats: RecoveryStats) {
        mockRecoveryStats = stats
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
    
    // MARK: - Test Helper Methods
    
    /// 重置所有模拟数据
    public func reset() {
        mockIsRecovering = false
        mockRecoveryStats = RecoveryStats()
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        mockRecoveredOrders = []
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

// MARK: - Supporting Types

/// 恢复统计信息
public struct RecoveryStats: Sendable {
    public var recoveryAttempts: Int = 0
    public var ordersRecovered: Int = 0
    public var transactionsRecovered: Int = 0
    public var failedPurchasesCleanedUp: Int = 0
    public var lastRecoveryTime: Date?
    
    public init() {}
}

// MARK: - Convenience Factory Methods

extension MockTransactionRecoveryManager {
    
    /// 创建正在恢复的 Mock 恢复管理器
    /// - Returns: Mock 恢复管理器
    public static func recovering() -> MockTransactionRecoveryManager {
        let manager = MockTransactionRecoveryManager()
        manager.setMockIsRecovering(true)
        return manager
    }
    
    /// 创建已停止的 Mock 恢复管理器
    /// - Returns: Mock 恢复管理器
    public static func stopped() -> MockTransactionRecoveryManager {
        let manager = MockTransactionRecoveryManager()
        manager.setMockIsRecovering(false)
        return manager
    }
    
    /// 创建会抛出错误的 Mock 恢复管理器
    /// - Parameter error: 错误
    /// - Returns: Mock 恢复管理器
    public static func withError(_ error: IAPError) -> MockTransactionRecoveryManager {
        let manager = MockTransactionRecoveryManager()
        manager.setMockError(error, shouldThrow: true)
        return manager
    }
    
    /// 创建带有延迟的 Mock 恢复管理器
    /// - Parameter delay: 延迟时间（秒）
    /// - Returns: Mock 恢复管理器
    public static func withDelay(_ delay: TimeInterval) -> MockTransactionRecoveryManager {
        let manager = MockTransactionRecoveryManager()
        manager.setMockDelay(delay)
        return manager
    }
}

// MARK: - Test Scenario Builders

extension MockTransactionRecoveryManager {
    
    /// 配置成功恢复场景
    /// - Parameter stats: 统计信息
    public func configureSuccessfulRecovery(stats: RecoveryStats? = nil) {
        setMockIsRecovering(false)
        if let stats = stats {
            setMockRecoveryStats(stats)
        }
    }
    
    /// 配置失败恢复场景
    /// - Parameter error: 错误
    public func configureFailedRecovery(error: IAPError) {
        setMockError(error, shouldThrow: true)
    }
    
    /// 配置待处理订单恢复场景
    /// - Parameter orders: 要恢复的订单
    public func configurePendingOrderRecovery(orders: [IAPOrder]) {
        var stats = mockRecoveryStats
        stats.ordersRecovered = orders.count
        setMockRecoveryStats(stats)
    }
    
    /// 配置混合恢复场景
    /// - Parameters:
    ///   - pending: 待处理订单
    ///   - expired: 过期订单
    public func configureMixedRecovery(pending: [IAPOrder], expired: [IAPOrder]) {
        var stats = mockRecoveryStats
        stats.ordersRecovered = pending.count
        stats.failedPurchasesCleanedUp = expired.count
        setMockRecoveryStats(stats)
    }
    
    /// 配置部分清理场景
    /// - Parameters:
    ///   - cleanupable: 可清理的订单
    ///   - problematic: 有问题的订单
    public func configurePartialCleanup(cleanupable: [IAPOrder], problematic: [IAPOrder]) {
        var stats = mockRecoveryStats
        stats.failedPurchasesCleanedUp = cleanupable.count
        setMockRecoveryStats(stats)
    }
    
    /// 配置过期处理场景
    /// - Parameters:
    ///   - active: 活跃订单
    ///   - nearExpiry: 即将过期订单
    ///   - expired: 已过期订单
    public func configureExpirationHandling(
        active: [IAPOrder],
        nearExpiry: [IAPOrder],
        expired: [IAPOrder]
    ) {
        var stats = mockRecoveryStats
        stats.failedPurchasesCleanedUp = expired.count
        setMockRecoveryStats(stats)
    }
    
    /// 配置关联恢复场景
    /// - Parameter pairs: 订单-交易对
    public func configureAssociationRecovery(pairs: [(order: IAPOrder, transaction: IAPTransaction)]) {
        // Store pairs for later retrieval if needed
        callParameters["associationPairs"] = pairs
    }
    
    /// 配置孤立交易恢复场景
    /// - Parameter transactions: 孤立交易
    public func configureOrphanedTransactionRecovery(transactions: [IAPTransaction]) {
        // Store transactions for later retrieval if needed
        callParameters["orphanedTransactions"] = transactions
    }
    
    /// 配置失败购买清理场景
    /// - Parameters:
    ///   - orders: 失败的订单
    ///   - transactions: 失败的交易
    public func configureFailedPurchaseCleanup(orders: [IAPOrder], transactions: [IAPTransaction]) {
        var stats = mockRecoveryStats
        stats.failedPurchasesCleanedUp = orders.count
        setMockRecoveryStats(stats)
        callParameters["failedOrders"] = orders
        callParameters["failedTransactions"] = transactions
    }
}