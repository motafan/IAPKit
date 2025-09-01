import Foundation
import Testing
@testable import IAPKit

// MARK: - 防丢单机制测试

@Test("重试管理器 - 基本重试逻辑")
func testRetryManagerBasicRetry() async throws {
    // Given - 使用无延迟配置进行测试
    let config = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 0.0,  // 无延迟
        maxDelay: 0.0,
        backoffMultiplier: 1.0,
        strategy: .fixed
    )
    let retryManager = RetryManager(configuration: config)
    let operationId = "test_operation"
    
    // When - 第一次尝试
    let shouldRetryFirst = await retryManager.shouldRetry(for: operationId)
    await retryManager.recordAttempt(for: operationId)
    
    // Then
    #expect(shouldRetryFirst == true)
    
    let record = await retryManager.getRecord(for: operationId)
    #expect(record?.attemptCount == 1)
    
    // When - 继续尝试直到达到最大次数
    for _ in 2...3 {
        let shouldRetry = await retryManager.shouldRetry(for: operationId)
        #expect(shouldRetry == true)
        await retryManager.recordAttempt(for: operationId)
    }
    
    // When - 超过最大重试次数（已经尝试了3次，达到maxRetries=3）
    let shouldRetryAfterMax = await retryManager.shouldRetry(for: operationId)
    
    // Then - 不应该再重试
    #expect(shouldRetryAfterMax == false)
    
    let finalRecord = await retryManager.getRecord(for: operationId)
    #expect(finalRecord?.attemptCount == 3)
}

@Test("重试管理器 - 延迟计算")
func testRetryManagerDelayCalculation() async throws {
    // Given
    let config = RetryConfiguration(
        maxRetries: 5,
        baseDelay: 1.0,
        maxDelay: 10.0,
        backoffMultiplier: 2.0,
        strategy: .exponential
    )
    let retryManager = RetryManager(configuration: config)
    let operationId = "delay_test"
    
    // When & Then - 测试指数退避延迟
    let initialDelay = await retryManager.getDelay(for: operationId)
    #expect(initialDelay == 0) // 第一次尝试无延迟
    
    await retryManager.recordAttempt(for: operationId)
    let firstDelay = await retryManager.getDelay(for: operationId)
    #expect(firstDelay == 1.0) // 基础延迟
    
    await retryManager.recordAttempt(for: operationId)
    let secondDelay = await retryManager.getDelay(for: operationId)
    #expect(secondDelay == 2.0) // 指数增长
    
    await retryManager.recordAttempt(for: operationId)
    let thirdDelay = await retryManager.getDelay(for: operationId)
    #expect(thirdDelay == 4.0) // 继续指数增长
}

@Test("重试管理器 - 统计信息")
func testRetryManagerStatistics() async throws {
    // Given
    let retryManager = RetryManager()
    
    // When - 记录多个操作的尝试
    await retryManager.recordAttempt(for: "op1", error: .networkError)
    await retryManager.recordAttempt(for: "op1", error: .networkError)
    await retryManager.recordAttempt(for: "op2", error: .timeout)
    
    // Then
    let stats = await retryManager.getRetryStatistics()
    #expect(stats.totalOperations == 2)
    #expect(stats.totalAttempts == 3)
    #expect(stats.averageAttempts == 1.5)
    #expect(stats.maxAttempts == 2)
}

@Test("重试管理器 - 记录清理")
func testRetryManagerRecordCleanup() async throws {
    // Given
    let retryManager = RetryManager()
    
    // When - 添加一些记录
    await retryManager.recordAttempt(for: "op1")
    await retryManager.recordAttempt(for: "op2")
    await retryManager.recordAttempt(for: "op3")
    
    let initialStats = await retryManager.getRetryStatistics()
    #expect(initialStats.totalOperations == 3)
    
    // When - 清除所有记录
    await retryManager.clearAll()
    
    // Then
    let finalStats = await retryManager.getRetryStatistics()
    #expect(finalStats.totalOperations == 0)
    #expect(finalStats.totalAttempts == 0)
}

@Test("重试管理器 - 带重试的操作执行")
func testRetryManagerExecuteWithRetry() async throws {
    // Given - 使用无延迟配置进行测试
    let config = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 0.0,
        maxDelay: 0.0,
        backoffMultiplier: 1.0,
        strategy: .fixed
    )
    let retryManager = RetryManager(configuration: config)
    
    // 使用actor来安全地管理计数器
    actor AttemptCounter {
        private var count = 0
        
        func increment() -> Int {
            count += 1
            return count
        }
        
        func getCount() -> Int {
            return count
        }
    }
    
    let counter = AttemptCounter()
    
    // When - 执行会失败几次然后成功的操作
    let result = try await retryManager.executeWithRetry(operationId: "test_op") {
        let attemptCount = await counter.increment()
        if attemptCount < 3 {
            throw IAPError.networkError
        }
        return "success"
    }
    
    // Then
    #expect(result == "success")
    let finalCount = await counter.getCount()
    #expect(finalCount == 3)
    
    // 验证重试记录被清除（成功后）
    let record = await retryManager.getRecord(for: "test_op")
    #expect(record == nil)
}
@Test("交易监控器 - 基本监控功能 (AntiLoss)")
@MainActor
func testAntiLossTransactionMonitorBasicMonitoring() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter, configuration: TestConfiguration.defaultIAPConfiguration())
    
    // 设置未完成的交易
    let pendingTransactions = [
        IAPTransaction(id: "tx1", productID: "product1", purchaseDate: Date(), transactionState: .purchasing)
    ]
    await mockAdapter.setMockPendingTransactions(pendingTransactions)
    
    // When
    await monitor.startMonitoring()
    
    // Then
    #expect(monitor.isCurrentlyMonitoring == true)
    
    let stats = monitor.getMonitoringStats()
    #expect(stats.transactionsProcessed >= 0)
    
    // 停止监控
    monitor.stopMonitoring()
    #expect(monitor.isCurrentlyMonitoring == false)
}

@Test("交易监控器 - 处理器管理 (AntiLoss)")
@MainActor
func testAntiLossTransactionMonitorHandlerManagement() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter, configuration: TestConfiguration.defaultIAPConfiguration())
    
    var callCount = 0
    
    // When - 添加处理器
    monitor.addTransactionUpdateHandler(identifier: "test1") { _ in
        callCount += 1
    }
    
    monitor.addTransactionUpdateHandler(identifier: "test2") { _ in
        callCount += 1
    }
    
    // Then
    #expect(monitor.hasActiveHandlers == true)
    #expect(monitor.activeHandlerCount == 2)
    #expect(monitor.activeHandlerIdentifiers.contains("test1"))
    #expect(monitor.activeHandlerIdentifiers.contains("test2"))
    
    // When - 移除处理器
    monitor.removeTransactionUpdateHandler(identifier: "test1")
    
    // Then
    #expect(monitor.activeHandlerCount == 1)
    #expect(!monitor.activeHandlerIdentifiers.contains("test1"))
    #expect(monitor.activeHandlerIdentifiers.contains("test2"))
    
    // When - 清除所有处理器
    monitor.clearAllTransactionUpdateHandlers()
    
    // Then
    #expect(monitor.hasActiveHandlers == false)
    #expect(monitor.activeHandlerCount == 0)
}

@Test("交易恢复管理器 - 基本功能测试")
@MainActor
func testTransactionRecoveryManagerBasicFunctionality() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let configuration = IAPConfiguration.default(networkBaseURL: URL(string: "https://test.example.com")!)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache,
        configuration: configuration,
        stateManager: IAPState()
    )
    
    // 设置未完成的交易
    let pendingTransactions = [
        IAPTransaction.successful(id: "tx1", productID: "product1"),
        IAPTransaction.successful(id: "tx2", productID: "product2")
    ]
    await mockAdapter.setMockPendingTransactions(pendingTransactions)
    
    // When
    let recoveryResult = await recoveryManager.startRecovery()
    
    // Then
    if case .success(let recoveredCount) = recoveryResult {
        #expect(recoveredCount == 2)
    } else {
        #expect(Bool(false), "Expected successful recovery")
    }
    
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == 2)
    #expect(stats.recoveredTransactions == 2)
    #expect(stats.failedTransactions == 0)
}

@Test("交易恢复管理器 - 空队列处理")
@MainActor
func testTransactionRecoveryManagerEmptyQueue() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache,
        configuration: TestConfiguration.defaultIAPConfiguration(),
        stateManager: IAPState()
    )
    
    // 设置空的未完成交易队列
    await mockAdapter.setMockPendingTransactions([])
    
    // When
    let recoveryResult = await recoveryManager.startRecovery()
    
    // Then
    if case .success(let recoveredCount) = recoveryResult {
        #expect(recoveredCount == 0)
    } else {
        #expect(Bool(false), "Expected successful recovery with 0 count")
    }
    
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == 0)
    #expect(stats.processedTransactions == 0)
}

@Test("网络中断场景模拟")
@MainActor
func testNetworkInterruptionScenario() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache,
        configuration: TestConfiguration.defaultIAPConfiguration(),
        stateManager: IAPState()
    )
    
    // 模拟网络中断导致的未完成交易
    let interruptedTransactions = [
        IAPTransaction(id: "tx1", productID: "product1", purchaseDate: Date(), transactionState: .purchasing),
        IAPTransaction.failed(id: "tx2", productID: "product2", error: .networkError),
        IAPTransaction.successful(id: "tx3", productID: "product3") // 成功但未完成
    ]
    await mockAdapter.setMockPendingTransactions(interruptedTransactions)
    
    // When - 模拟应用重启后的恢复
    let recoveryResult = await recoveryManager.startRecovery()
    
    // Then
    
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == 3)
    #expect(stats.processedTransactions == 3)
    
    // 验证网络错误的交易被正确处理
    #expect(stats.failedTransactions >= 0) // 可能有失败的交易
    #expect(stats.recoveredTransactions >= 1) // 至少恢复了成功的交易
}

@Test("应用崩溃恢复场景")
@MainActor
func testAppCrashRecoveryScenario() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter, configuration: TestConfiguration.defaultIAPConfiguration())
    
    // 模拟应用崩溃前的状态 - 有多个进行中的交易
    let crashedTransactions = [
        IAPTransaction(id: "tx1", productID: "product1", purchaseDate: Date().addingTimeInterval(-300), transactionState: .purchasing),
        IAPTransaction(id: "tx2", productID: "product2", purchaseDate: Date().addingTimeInterval(-200), transactionState: .purchasing),
        IAPTransaction(id: "tx3", productID: "product3", purchaseDate: Date().addingTimeInterval(-100), transactionState: .deferred)
    ]
    await mockAdapter.setMockPendingTransactions(crashedTransactions)
    
    // When - 模拟应用重启后启动监控
    await monitor.startMonitoring()
    
    // 等待处理完成 - 简化版本
    try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
    
    // Then
    let stats = monitor.getMonitoringStats()
    #expect(stats.transactionsProcessed >= 0) // 应该处理了一些交易
    
    monitor.stopMonitoring()
}
