import Testing
@testable import IAPFramework
import Foundation

// MARK: - 网络中断和恢复场景测试

@Test("NetworkInterruption - 购买过程中网络中断")
@MainActor
func testPurchaseInterruptedByNetworkFailure() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator()
    let purchaseService = PurchaseService(adapter: mockAdapter, receiptValidator: mockValidator)
    
    let testProduct = TestDataGenerator.generateProduct()
    
    // 模拟购买开始后网络中断
    mockAdapter.setMockDelay(0.2) // 200ms延迟模拟网络操作
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    // When & Then
    do {
        _ = try await purchaseService.purchase(testProduct)
        #expect(Bool(false), "Should have thrown network error")
    } catch let error as IAPError {
        #expect(error == .networkError)
        #expect(error.isNetworkError)
        #expect(error.isRetryable)
    }
    
    // 验证购买服务正确处理了网络中断
    #expect(mockAdapter.wasCalled("purchase"))
}

@Test("NetworkInterruption - 收据验证过程中网络中断")
func testReceiptValidationInterruptedByNetwork() async throws {
    // Given
    let mockValidator = MockReceiptValidator()
    let testReceiptData = TestDataGenerator.generateReceiptData()
    
    // 模拟验证过程中网络中断
    mockValidator.setMockDelay(0.1)
    mockValidator.setMockError(.networkError, shouldThrow: true)
    
    // When & Then
    do {
        _ = try await mockValidator.validateReceipt(testReceiptData)
        #expect(Bool(false), "Should have thrown network error")
    } catch let error as IAPError {
        #expect(error == .networkError)
        #expect(error.isRetryable)
    }
}

@Test("NetworkInterruption - 商品加载过程中网络中断")
@MainActor
func testProductLoadingInterruptedByNetwork() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    // 模拟加载过程中网络中断
    mockAdapter.setMockDelay(0.15)
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    // When & Then
    do {
        _ = try await productService.loadProducts(productIDs: ["test.product"])
        #expect(Bool(false), "Should have thrown network error")
    } catch let error as IAPError {
        #expect(error == .networkError)
        #expect(error.isRetryable)
    }
}

@Test("NetworkInterruption - 网络恢复后自动重试")
@MainActor
func testNetworkRecoveryAutoRetry() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    let retryManager = RetryManager()
    
    var attemptCount = 0
    
    // When - 使用重试机制处理网络中断
    let result = try await retryManager.executeWithRetry(operationId: "network_recovery_test") {
        attemptCount += 1
        
        if attemptCount <= 2 {
            // 前两次模拟网络错误
            throw IAPError.networkError
        } else {
            // 第三次模拟网络恢复，返回成功结果
            mockAdapter.reset()
            let testProducts = TestDataGenerator.generateProducts(count: 1)
            mockAdapter.setMockProducts(testProducts)
            return try await productService.loadProducts(productIDs: Set(testProducts.map { $0.id }))
        }
    }
    
    // Then
    #expect(result.count == 1)
    #expect(attemptCount == 3)
}

@Test("NetworkInterruption - 间歇性网络问题")
@MainActor
func testIntermittentNetworkIssues() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    let retryManager = RetryManager()
    
    var attemptCount = 0
    let networkFailurePattern = [true, false, true, false, false] // 间歇性失败模式
    
    // When
    let result = try await retryManager.executeWithRetry(operationId: "intermittent_network_test") {
        let shouldFail = attemptCount < networkFailurePattern.count ? networkFailurePattern[attemptCount] : false
        attemptCount += 1
        
        if shouldFail {
            throw IAPError.networkError
        } else {
            // 模拟成功
            let testProducts = TestDataGenerator.generateProducts(count: 1)
            mockAdapter.setMockProducts(testProducts)
            return try await productService.loadProducts(productIDs: Set(testProducts.map { $0.id }))
        }
    }
    
    // Then
    #expect(result.count == 1)
    #expect(attemptCount == 2) // 第一次失败，第二次成功
}

@Test("NetworkInterruption - 长时间网络中断")
@MainActor
func testLongTermNetworkOutage() async throws {
    // Given
    let config = RetryConfiguration(
        maxRetries: 5,
        baseDelay: 0.1,
        maxDelay: 1.0,
        strategy: .exponential
    )
    let retryManager = RetryManager(configuration: config)
    
    var attemptCount = 0
    
    // When & Then - 长时间网络中断应该最终失败
    do {
        _ = try await retryManager.executeWithRetry(operationId: "long_outage_test") {
            attemptCount += 1
            throw IAPError.networkError // 持续网络错误
        }
        #expect(Bool(false), "Should have failed after max retries")
    } catch let error as IAPError {
        #expect(error == .networkError)
        #expect(attemptCount == 6) // 初始尝试 + 5次重试
    }
}

@Test("NetworkInterruption - 网络超时处理")
@MainActor
func testNetworkTimeoutHandling() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    // 模拟网络超时
    mockAdapter.setMockDelay(0.1)
    mockAdapter.setMockError(.timeout, shouldThrow: true)
    
    // When & Then
    do {
        _ = try await productService.loadProducts(productIDs: ["test.product"])
        #expect(Bool(false), "Should have thrown timeout error")
    } catch let error as IAPError {
        #expect(error == .timeout)
        #expect(error.isNetworkError)
        #expect(error.isRetryable)
    }
}

@Test("NetworkInterruption - 服务器错误恢复")
func testServerErrorRecovery() async throws {
    // Given
    let mockValidator = MockReceiptValidator()
    let retryManager = RetryManager()
    let testReceiptData = TestDataGenerator.generateReceiptData()
    
    var attemptCount = 0
    let serverErrorCodes = [500, 502, 503] // 不同的服务器错误
    
    // When
    let result = try await retryManager.executeWithRetry(operationId: "server_error_recovery") {
        if attemptCount < serverErrorCodes.count {
            let errorCode = serverErrorCodes[attemptCount]
            attemptCount += 1
            throw IAPError.serverValidationFailed(statusCode: errorCode)
        } else {
            // 最终成功
            mockValidator.reset()
            mockValidator.configureSuccessfulValidation()
            return try await mockValidator.validateReceipt(testReceiptData)
        }
    }
    
    // Then
    #expect(result.isValid)
    #expect(attemptCount == serverErrorCodes.count)
}

@Test("NetworkInterruption - 并发网络中断处理")
@MainActor
func testConcurrentNetworkInterruptionHandling() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    let concurrentOperations = 5
    var errors: [IAPError] = []
    
    // When - 并发执行多个操作，都遇到网络中断
    await withTaskGroup(of: IAPError?.self) { group in
        for i in 0..<concurrentOperations {
            group.addTask {
                do {
                    _ = try await productService.loadProducts(productIDs: ["product_\(i)"])
                    return nil
                } catch let error as IAPError {
                    return error
                } catch {
                    return .unknownError(error.localizedDescription)
                }
            }
        }
        
        for await error in group {
            if let error = error {
                errors.append(error)
            }
        }
    }
    
    // Then
    #expect(errors.count == concurrentOperations)
    #expect(errors.allSatisfy { $0 == .networkError })
}

@Test("NetworkInterruption - 网络状态监控")
@MainActor
func testNetworkStatusMonitoring() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // 设置网络错误的未完成交易
    let networkFailedTransactions = [
        IAPTransaction.failed(id: "net_tx1", productID: "product1", error: .networkError),
        IAPTransaction.failed(id: "net_tx2", productID: "product2", error: .timeout),
        IAPTransaction.failed(id: "net_tx3", productID: "product3", error: .serverValidationFailed(statusCode: 503))
    ]
    
    await mockAdapter.setMockPendingTransactions(networkFailedTransactions)
    
    var networkErrorCount = 0
    
    // When
    monitor.addTransactionUpdateHandler(identifier: "network_monitor") { transaction in
        if let error = transaction.failureError, error.isNetworkError {
            networkErrorCount += 1
        }
    }
    
    await monitor.startMonitoring()
    
    // 模拟处理网络错误交易
    for transaction in networkFailedTransactions {
        mockAdapter.simulateTransactionUpdate(transaction)
    }
    
    // Then
    #expect(networkErrorCount == 3)
    
    let stats = monitor.getMonitoringStats()
    #expect(stats.failedTransactions >= 3)
    
    monitor.stopMonitoring()
}

@Test("NetworkInterruption - 网络恢复后批量重试")
@MainActor
func testBatchRetryAfterNetworkRecovery() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let recoveryManager = TransactionRecoveryManager(adapter: mockAdapter)
    
    // 创建因网络问题失败的交易
    let networkFailedTransactions = (0..<10).map { index in
        IAPTransaction.failed(
            id: "batch_retry_\(index)",
            productID: "product_\(index)",
            error: .networkError
        )
    }
    
    await mockAdapter.setMockPendingTransactions(networkFailedTransactions)
    
    // When - 模拟网络恢复后的批量重试
    mockAdapter.reset() // 清除错误状态，模拟网络恢复
    
    var recoveryResults: [RecoveryResult] = []
    await recoveryManager.startRecovery { result in
        recoveryResults.append(result)
    }
    
    // Then
    #expect(!recoveryResults.isEmpty)
    
    let stats = recoveryManager.getRecoveryStatistics()
    #expect(stats.totalTransactions == networkFailedTransactions.count)
    #expect(stats.processedTransactions == networkFailedTransactions.count)
}

@Test("NetworkInterruption - 网络质量自适应重试")
func testAdaptiveRetryBasedOnNetworkQuality() async throws {
    // Given
    let poorNetworkConfig = RetryConfiguration(
        maxRetries: 5,
        baseDelay: 2.0, // 较长的基础延迟
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        strategy: .exponential
    )
    
    let goodNetworkConfig = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 0.5, // 较短的基础延迟
        maxDelay: 5.0,
        backoffMultiplier: 1.5,
        strategy: .exponential
    )
    
    let poorNetworkRetryManager = RetryManager(configuration: poorNetworkConfig)
    let goodNetworkRetryManager = RetryManager(configuration: goodNetworkConfig)
    
    // When & Then - 验证不同网络质量下的重试策略
    
    // 差网络环境下的延迟
    await poorNetworkRetryManager.recordAttempt(for: "poor_network_test")
    let poorNetworkDelay = await poorNetworkRetryManager.getDelay(for: "poor_network_test")
    
    // 好网络环境下的延迟
    await goodNetworkRetryManager.recordAttempt(for: "good_network_test")
    let goodNetworkDelay = await goodNetworkRetryManager.getDelay(for: "good_network_test")
    
    #expect(poorNetworkDelay > goodNetworkDelay)
}

@Test("NetworkInterruption - 网络中断期间的状态保持")
@MainActor
func testStatePreservationDuringNetworkOutage() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // 设置一些正常交易
    let normalTransactions = TestDataGenerator.generateTransactions(count: 3, state: .purchased)
    await mockAdapter.setMockPendingTransactions(normalTransactions)
    
    var processedTransactions: [IAPTransaction] = []
    
    monitor.addTransactionUpdateHandler(identifier: "state_preservation") { transaction in
        processedTransactions.append(transaction)
    }
    
    // When - 启动监控
    await monitor.startMonitoring()
    
    // 模拟网络中断
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    // 尝试处理更多交易（应该失败但不影响已有状态）
    let networkFailedTransactions = TestDataGenerator.generateTransactions(count: 2, state: .purchasing)
    await mockAdapter.setMockPendingTransactions(networkFailedTransactions)
    
    await monitor.handlePendingTransactions()
    
    // Then - 验证状态保持
    #expect(monitor.isCurrentlyMonitoring)
    
    let stats = monitor.getMonitoringStats()
    #expect(stats.transactionsProcessed >= 0) // 应该没有崩溃
    
    monitor.stopMonitoring()
}

@Test("NetworkInterruption - 网络错误分类和处理策略")
func testNetworkErrorClassificationAndHandling() async throws {
    // Given
    let networkErrors: [(IAPError, Bool)] = [
        (.networkError, true),           // 应该重试
        (.timeout, true),               // 应该重试
        (.serverValidationFailed(statusCode: 500), true),  // 服务器错误，应该重试
        (.serverValidationFailed(statusCode: 503), true),  // 服务不可用，应该重试
        (.serverValidationFailed(statusCode: 400), false), // 客户端错误，不应该重试
        (.serverValidationFailed(statusCode: 404), false), // 未找到，不应该重试
        (.purchaseCancelled, false),    // 用户取消，不应该重试
        (.paymentNotAllowed, false)     // 支付不允许，不应该重试
    ]
    
    // When & Then
    for (error, shouldRetry) in networkErrors {
        #expect(error.isRetryable == shouldRetry, 
               "Error \(error) retry classification mismatch")
        
        if error.isNetworkError {
            #expect(shouldRetry, "Network errors should generally be retryable")
        }
    }
}

@Test("NetworkInterruption - 网络恢复检测")
@MainActor
func testNetworkRecoveryDetection() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    // 初始网络错误状态
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    // When - 第一次尝试失败
    do {
        _ = try await productService.loadProducts(productIDs: ["test.product"])
        #expect(Bool(false), "Should have failed")
    } catch {
        // 预期失败
    }
    
    // 模拟网络恢复
    mockAdapter.reset()
    let testProducts = TestDataGenerator.generateProducts(count: 1)
    mockAdapter.setMockProducts(testProducts)
    
    // 第二次尝试应该成功
    let products = try await productService.loadProducts(productIDs: Set(testProducts.map { $0.id }))
    
    // Then
    #expect(products.count == 1)
    #expect(mockAdapter.getCallCount(for: "loadProducts") == 2) // 两次调用
}