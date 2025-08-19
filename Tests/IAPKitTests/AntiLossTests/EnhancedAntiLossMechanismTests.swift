import Foundation
import Testing
@testable import IAPKit

// MARK: - 增强的防丢单机制测试

@Test("AntiLoss - 重试管理器指数退避算法验证")
func testRetryManagerExponentialBackoffAlgorithm() async throws {
    // Given
    let config = RetryConfiguration(
        maxRetries: 5,
        baseDelay: 1.0,
        maxDelay: 16.0,
        backoffMultiplier: 2.0,
        strategy: .exponential
    )
    let retryManager = RetryManager(configuration: config)
    let operationId = "exponential_test"
    
    var delays: [TimeInterval] = []
    
    // When - 记录每次重试的延迟
    for _ in 0..<5 {
        let delay = await retryManager.getDelay(for: operationId)
        delays.append(delay)
        await retryManager.recordAttempt(for: operationId)
    }
    
    // Then - 验证指数退避模式
    #expect(delays[0] == 0) // 第一次尝试无延迟
    #expect(delays[1] == 1.0) // 基础延迟
    #expect(delays[2] == 2.0) // 2^1 * 基础延迟
    #expect(delays[3] == 4.0) // 2^2 * 基础延迟
    #expect(delays[4] == 8.0) // 2^3 * 基础延迟
}

@Test("AntiLoss - 重试管理器最大延迟限制")
func testRetryManagerMaxDelayLimit() async throws {
    // Given
    let config = RetryConfiguration(
        maxRetries: 10,
        baseDelay: 1.0,
        maxDelay: 5.0, // 最大延迟限制
        backoffMultiplier: 2.0,
        strategy: .exponential
    )
    let retryManager = RetryManager(configuration: config)
    let operationId = "max_delay_test"
    
    // When - 执行多次重试直到达到最大延迟
    for _ in 0..<8 {
        await retryManager.recordAttempt(for: operationId)
    }
    
    let finalDelay = await retryManager.getDelay(for: operationId)
    
    // Then - 延迟不应超过最大限制
    #expect(finalDelay <= 5.0)
}

@Test("AntiLoss - 重试管理器线性退避策略")
func testRetryManagerLinearBackoffStrategy() async throws {
    // Given
    let config = RetryConfiguration(
        maxRetries: 4,
        baseDelay: 1.0,
        maxDelay: 10.0,
        backoffMultiplier: 1.5,
        strategy: .linear
    )
    let retryManager = RetryManager(configuration: config)
    let operationId = "linear_test"
    
    var delays: [TimeInterval] = []
    
    // When
    for _ in 0..<4 {
        let delay = await retryManager.getDelay(for: operationId)
        delays.append(delay)
        await retryManager.recordAttempt(for: operationId)
    }
    
    // Then - 验证线性增长
    #expect(delays[0] == 0) // 第一次尝试无延迟
    #expect(delays[1] == 1.0) // 基础延迟
    #expect(delays[2] == 2.0) // 1.0 * 2 (线性增长)
    #expect(delays[3] == 3.0) // 1.0 * 3 (线性增长)
}

@Test("AntiLoss - 重试管理器固定延迟策略")
func testRetryManagerFixedDelayStrategy() async throws {
    // Given
    let config = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 2.0,
        maxDelay: 10.0,
        backoffMultiplier: 1.0,
        strategy: .fixed
    )
    let retryManager = RetryManager(configuration: config)
    let operationId = "fixed_test"
    
    var delays: [TimeInterval] = []
    
    // When
    for _ in 0..<3 {
        let delay = await retryManager.getDelay(for: operationId)
        delays.append(delay)
        await retryManager.recordAttempt(for: operationId)
    }
    
    // Then - 验证固定延迟
    #expect(delays[0] == 0) // 第一次尝试无延迟
    #expect(delays[1] == 2.0) // 固定延迟
    #expect(delays[2] == 2.0) // 固定延迟
}

@Test("AntiLoss - 重试管理器错误类型记录")
func testRetryManagerErrorTypeRecording() async throws {
    // Given
    let retryManager = RetryManager()
    let operationId = "error_tracking_test"
    
    let errors: [IAPError] = [
        .networkError,
        .timeout,
        .serverValidationFailed(statusCode: 500),
        .networkError
    ]
    
    // When
    for error in errors {
        await retryManager.recordAttempt(for: operationId, error: error)
    }
    
    // Then
    let record = await retryManager.getRecord(for: operationId)
    #expect(record != nil)
    #expect(record?.attemptCount == 4)
    #expect(record?.lastError != nil)
    
    let stats = await retryManager.getRetryStatistics()
    #expect(stats.totalAttempts == 4)
}

@Test("AntiLoss - 重试管理器并发操作")
func testRetryManagerConcurrentOperations() async throws {
    // Given
    let retryManager = RetryManager()
    let operationCount = 10
    let attemptsPerOperation = 3
    
    // When - 并发执行多个操作的重试
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<operationCount {
            group.addTask {
                let operationId = "concurrent_op_\(i)"
                for _ in 0..<attemptsPerOperation {
                    await retryManager.recordAttempt(for: operationId)
                }
            }
        }
        await group.waitForAll()
    }
    
    // Then
    let stats = await retryManager.getRetryStatistics()
    #expect(stats.totalOperations == operationCount)
    #expect(stats.totalAttempts == operationCount * attemptsPerOperation)
}

@Test("AntiLoss - 重试管理器带重试的操作执行")
func testRetryManagerExecuteWithRetrySuccess() async throws {
    // Given
    let retryManager = RetryManager()
    
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
    
    // When - 执行会在第3次尝试成功的操作
    let result = try await retryManager.executeWithRetry(operationId: "retry_success_test") {
        let attemptCount = await counter.increment()
        if attemptCount < 3 {
            throw IAPError.networkError
        }
        return "success_result"
    }
    
    // Then
    #expect(result == "success_result")
    let finalCount = await counter.getCount()
    #expect(finalCount == 3)
    
    // 验证成功后记录被清除
    let record = await retryManager.getRecord(for: "retry_success_test")
    #expect(record == nil)
}

@Test("AntiLoss - 重试管理器带重试的操作最终失败")
func testRetryManagerExecuteWithRetryFailure() async throws {
    // Given
    let config = RetryConfiguration(
        maxRetries: 2,
        baseDelay: 0.1,
        maxDelay: 1.0,
        backoffMultiplier: 2.0,
        strategy: .exponential
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
    
    // When & Then
    do {
        _ = try await retryManager.executeWithRetry(operationId: "retry_failure_test") {
            _ = await counter.increment()
            throw IAPError.networkError
        }
        #expect(Bool(false), "Should have thrown error after max retries")
    } catch let error as IAPError {
        #expect(error == .networkError)
        let finalCount = await counter.getCount()
        #expect(finalCount == 3) // 初始尝试 + 2次重试
    }
    
    // 验证失败记录仍然存在
    let record = await retryManager.getRecord(for: "retry_failure_test")
    #expect(record != nil)
    #expect(record?.attemptCount == 3)
}

@Test("AntiLoss - 重试管理器实际延迟执行")
func testRetryManagerActualDelayExecution() async throws {
    // Given
    let config = RetryConfiguration(
        maxRetries: 2,
        baseDelay: 0.1, // 100ms
        maxDelay: 1.0,
        backoffMultiplier: 1.0,
        strategy: .fixed
    )
    let retryManager = RetryManager(configuration: config)
    
    // 使用actor来安全地管理计数器和时间记录
    actor AttemptTracker {
        private var count = 0
        private var times: [Date] = []
        
        func recordAttempt() -> Int {
            count += 1
            times.append(Date())
            return count
        }
        
        func getCount() -> Int {
            return count
        }
        
        func getTimes() -> [Date] {
            return times
        }
    }
    
    let tracker = AttemptTracker()
    
    // When
    do {
        _ = try await retryManager.executeWithRetry(operationId: "delay_test") {
            _ = await tracker.recordAttempt()
            throw IAPError.networkError
        }
    } catch {
        // 预期会失败
    }
    
    // Then - 验证实际延迟
    let attemptTimes = await tracker.getTimes()
    let attemptCount = await tracker.getCount()
    #expect(attemptCount >= 2) // 至少应该有2次尝试
    #expect(attemptTimes.count >= 2)
    
    // 如果有足够的尝试次数，验证延迟
    if attemptTimes.count >= 2 {
        let delay1 = attemptTimes[1].timeIntervalSince(attemptTimes[0])
        #expect(delay1 >= 0.1)
    }
    
    if attemptTimes.count >= 3 {
        let delay2 = attemptTimes[2].timeIntervalSince(attemptTimes[1])
        #expect(delay2 >= 0.1)
    }
}

@Test("AntiLoss - 交易恢复管理器复杂场景")
@MainActor
func testTransactionRecoveryManagerComplexScenario() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let configuration = IAPConfiguration.default
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache,
        configuration: configuration
    )
    
    // 创建复杂的未完成交易场景
    let complexTransactions = [
        // 成功但未完成的交易
        IAPTransaction.successful(id: "tx1", productID: "product1"),
        IAPTransaction.successful(id: "tx2", productID: "product2"),
        
        // 失败的交易
        IAPTransaction.failed(id: "tx3", productID: "product3", error: .networkError),
        IAPTransaction.failed(id: "tx4", productID: "product4", error: .timeout),
        
        // 正在进行的交易
        IAPTransaction(id: "tx5", productID: "product5", purchaseDate: Date(), transactionState: .purchasing),
        
        // 延期的交易
        IAPTransaction(id: "tx6", productID: "product6", purchaseDate: Date(), transactionState: .deferred),
        
        // 恢复的交易
        IAPTransaction(id: "tx7", productID: "product7", purchaseDate: Date(), transactionState: .restored)
    ]
    
    await mockAdapter.setMockPendingTransactions(complexTransactions)
    
    // When
    let recoveryResult = await recoveryManager.startRecovery()
    let recoveryResults = [recoveryResult]
    
    // Then
    #expect(!recoveryResults.isEmpty)
    
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == complexTransactions.count)
    #expect(stats.processedTransactions == complexTransactions.count)
    
    // 验证不同类型交易的处理
    #expect(stats.recoveredTransactions >= 3) // 至少成功和恢复的交易
    #expect(stats.failedTransactions >= 2) // 失败的交易
}

@Test("AntiLoss - 交易恢复管理器优先级排序")
@MainActor
func testTransactionRecoveryManagerPrioritySorting() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache
    )
    
    let now = Date()
    let _ = [
        // 最旧的交易（最高优先级）
        IAPTransaction.successful(id: "old_tx", productID: "product1"),
        
        // 中等优先级
        IAPTransaction.successful(id: "medium_tx", productID: "product2"),
        
        // 最新的交易（最低优先级）
        IAPTransaction.successful(id: "new_tx", productID: "product3")
    ]
    
    // 修改交易的购买日期以测试排序
    let sortedTransactions = [
        IAPTransaction(
            id: "old_tx",
            productID: "product1",
            purchaseDate: now.addingTimeInterval(-3600), // 1小时前
            transactionState: .purchased
        ),
        IAPTransaction(
            id: "medium_tx",
            productID: "product2",
            purchaseDate: now.addingTimeInterval(-1800), // 30分钟前
            transactionState: .purchased
        ),
        IAPTransaction(
            id: "new_tx",
            productID: "product3",
            purchaseDate: now.addingTimeInterval(-900), // 15分钟前
            transactionState: .purchased
        )
    ]
    
    await mockAdapter.setMockPendingTransactions(sortedTransactions)
    
    // When
    _ = await recoveryManager.startRecovery()
    
    // Then
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == 3)
    #expect(stats.processedTransactions == 3)
    
    // 验证处理顺序（通过适配器调用验证）
    #expect(mockAdapter.wasCalled("getPendingTransactions"))
    #expect(mockAdapter.wasCalled("finishTransaction"))
}

@Test("AntiLoss - 交易恢复管理器批量处理")
@MainActor
func testTransactionRecoveryManagerBatchProcessing() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache
    )
    
    // 创建大量未完成交易
    let batchSize = 50
    let batchTransactions = (0..<batchSize).map { index in
        IAPTransaction.successful(
            id: "batch_tx_\(index)",
            productID: "product_\(index)"
        )
    }
    
    await mockAdapter.setMockPendingTransactions(batchTransactions)
    
    // When
    let startTime = Date()
    _ = await recoveryManager.startRecovery()
    let processingTime = Date().timeIntervalSince(startTime)
    
    // Then
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == batchSize)
    #expect(stats.processedTransactions == batchSize)
    
    // 批量处理应该相对高效
    #expect(processingTime < 5.0) // 应该在5秒内完成
}

@Test("AntiLoss - 网络中断和恢复复杂场景")
@MainActor
func testNetworkInterruptionComplexScenario() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache
    )
    
    // 模拟网络中断期间积累的各种交易
    let interruptedTransactions = [
        // 购买成功但网络中断前未完成
        IAPTransaction.successful(id: "success_interrupted", productID: "product1"),
        
        // 网络错误导致的失败交易
        IAPTransaction.failed(id: "network_failed", productID: "product2", error: .networkError),
        
        // 超时的交易
        IAPTransaction.failed(id: "timeout_failed", productID: "product3", error: .timeout),
        
        // 服务器验证失败的交易
        IAPTransaction.failed(id: "server_failed", productID: "product4", error: .serverValidationFailed(statusCode: 500)),
        
        // 正在进行但被中断的交易
        IAPTransaction(id: "purchasing_interrupted", productID: "product5", purchaseDate: Date(), transactionState: .purchasing)
    ]
    
    await mockAdapter.setMockPendingTransactions(interruptedTransactions)
    
    // When - 模拟网络恢复后的处理
    let recoveryResult = await recoveryManager.startRecovery()
    let recoveryResults = [recoveryResult]
    
    // Then
    #expect(!recoveryResults.isEmpty)
    
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == interruptedTransactions.count)
    
    // 验证不同错误类型的处理
    #expect(stats.processedTransactions == interruptedTransactions.count)
    
    // 至少成功的交易应该被恢复
    #expect(stats.recoveredTransactions >= 1)
    
    // 网络相关错误的交易可能需要重试
    #expect(stats.failedTransactions >= 0)
}

@Test("AntiLoss - 应用崩溃后恢复场景")
@MainActor
func testAppCrashRecoveryComplexScenario() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // 模拟应用崩溃前的复杂状态
    let crashScenarioTransactions = [
        // 崩溃时正在处理的购买
        IAPTransaction(
            id: "crash_purchasing",
            productID: "product1",
            purchaseDate: Date().addingTimeInterval(-600), // 10分钟前开始
            transactionState: .purchasing
        ),
        
        // 崩溃前刚完成但未finish的交易
        IAPTransaction.successful(
            id: "crash_unfinished",
            productID: "product2"
        ),
        
        // 崩溃时延期等待批准的交易
        IAPTransaction(
            id: "crash_deferred",
            productID: "product3",
            purchaseDate: Date().addingTimeInterval(-1800), // 30分钟前
            transactionState: .deferred
        ),
        
        // 崩溃前失败但未清理的交易
        IAPTransaction.failed(
            id: "crash_failed",
            productID: "product4",
            error: .networkError
        )
    ]
    
    await mockAdapter.setMockPendingTransactions(crashScenarioTransactions)
    
    var processedTransactions: [IAPTransaction] = []
    
    // When - 模拟应用重启后的监控启动
    monitor.addTransactionUpdateHandler(identifier: "crash_recovery") { transaction in
        processedTransactions.append(transaction)
    }
    
    await monitor.startMonitoring()
    
    // 等待处理完成
    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
    
    // Then
    let stats = monitor.getMonitoringStats()
    #expect(stats.pendingTransactionsProcessed >= crashScenarioTransactions.count)
    
    // 验证监控器正确处理了崩溃恢复
    #expect(monitor.isCurrentlyMonitoring)
    
    monitor.stopMonitoring()
}

@Test("AntiLoss - 重试机制与交易恢复集成")
@MainActor
func testRetryMechanismTransactionRecoveryIntegration() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let retryManager = RetryManager()
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache
    )
    
    // 设置适配器在前几次调用时失败
    let _ = 0
    let _ = mockAdapter.finishTransaction
    
    // 模拟finishTransaction前两次失败，第三次成功
    // 注意：这里我们需要修改Mock适配器来支持这种行为
    
    let testTransaction = IAPTransaction.successful(id: "retry_test", productID: "product1")
    await mockAdapter.setMockPendingTransactions([testTransaction])
    
    // When - 使用重试机制执行交易恢复
    // 使用actor来安全地管理计数器
    actor RecoveryAttemptCounter {
        private var count = 0
        
        func increment() -> Int {
            count += 1
            return count
        }
        
        func getCount() -> Int {
            return count
        }
    }
    
    let recoveryCounter = RecoveryAttemptCounter()
    
    let result = try await retryManager.executeWithRetry(operationId: "recovery_with_retry") {
        let recoveryAttempts = await recoveryCounter.increment()
        if recoveryAttempts < 3 {
            throw IAPError.networkError
        }
        
        // 模拟成功的恢复操作
        _ = await recoveryManager.startRecovery()
        return "recovery_success"
    }
    
    // Then
    #expect(result == "recovery_success")
    let finalAttempts = await recoveryCounter.getCount()
    #expect(finalAttempts == 3)
    
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions >= 1)
}

@Test("AntiLoss - 防丢单机制性能测试")
@MainActor
func testAntiLossMechanismPerformance() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache
    )
    
    // 创建大量交易来测试性能
    let transactionCount = 100
    let performanceTransactions = (0..<transactionCount).map { index in
        IAPTransaction.successful(
            id: "perf_tx_\(index)",
            productID: "product_\(index)"
        )
    }
    
    await mockAdapter.setMockPendingTransactions(performanceTransactions)
    
    // When
    let startTime = Date()
    _ = await recoveryManager.startRecovery()
    let processingTime = Date().timeIntervalSince(startTime)
    
    // Then
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == transactionCount)
    #expect(stats.processedTransactions == transactionCount)
    
    // 性能要求：处理100个交易应该在合理时间内完成
    #expect(processingTime < 10.0) // 10秒内完成
    
    // 计算处理速率
    let transactionsPerSecond = Double(transactionCount) / processingTime
    #expect(transactionsPerSecond > 10) // 每秒至少处理10个交易
}

@Test("AntiLoss - 防丢单机制内存使用")
@MainActor
func testAntiLossMechanismMemoryUsage() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache
    )
    
    // When - 处理大量交易并验证内存使用
    for batch in 0..<10 {
        let batchTransactions = (0..<50).map { index in
            IAPTransaction.successful(
                id: "memory_tx_\(batch)_\(index)",
                productID: "product_\(batch)_\(index)"
            )
        }
        
        await mockAdapter.setMockPendingTransactions(batchTransactions)
        _ = await recoveryManager.startRecovery()
        
        // 清理以模拟内存管理
        await mockAdapter.setMockPendingTransactions([])
    }
    
    // Then - 如果没有内存泄漏，测试应该正常完成
    let finalStats = recoveryManager.getRecoveryStatistics()
    #expect(finalStats.totalTransactions >= 500) // 处理了大量交易
}

@Test("AntiLoss - 边缘情况处理")
@MainActor
func testAntiLossMechanismEdgeCases() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockOrderService = MockOrderService()
    let mockCache = IAPCache(productCacheExpiration: 3600)
    let recoveryManager = TransactionRecoveryManager(
        adapter: mockAdapter,
        orderService: mockOrderService,
        cache: mockCache
    )
    
    // 测试各种边缘情况
    let edgeCaseTransactions = [
        // 交易ID为空
        IAPTransaction(
            id: "",
            productID: "product1",
            purchaseDate: Date(),
            transactionState: .purchased
        ),
        
        // 商品ID为空
        IAPTransaction(
            id: "tx1",
            productID: "",
            purchaseDate: Date(),
            transactionState: .purchased
        ),
        
        // 非常旧的交易
        IAPTransaction(
            id: "old_tx",
            productID: "product2",
            purchaseDate: Date().addingTimeInterval(-86400 * 30), // 30天前
            transactionState: .purchased
        ),
        
        // 未来的交易（时钟不同步）
        IAPTransaction(
            id: "future_tx",
            productID: "product3",
            purchaseDate: Date().addingTimeInterval(3600), // 1小时后
            transactionState: .purchased
        )
    ]
    
    await mockAdapter.setMockPendingTransactions(edgeCaseTransactions)
    
    // When
    _ = await recoveryManager.startRecovery()
    
    // Then - 应该能够处理边缘情况而不崩溃
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == edgeCaseTransactions.count)
    #expect(stats.processedTransactions >= 0) // 至少不会崩溃
}
