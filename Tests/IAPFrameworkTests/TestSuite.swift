import Foundation

/// 综合测试套件，展示如何使用测试基础设施
public struct TestSuite {
    
    // MARK: - Test Suite Configuration
    
    /// 测试套件配置
    public struct Configuration: Sendable {
        /// 是否启用性能测试
        public let enablePerformanceTests: Bool
        
        /// 是否启用集成测试
        public let enableIntegrationTests: Bool
        
        /// 是否启用错误场景测试
        public let enableErrorScenarioTests: Bool
        
        /// 测试超时时间（秒）
        public let testTimeout: TimeInterval
        
        /// 是否启用详细日志
        public let enableVerboseLogging: Bool
        
        public init(
            enablePerformanceTests: Bool = true,
            enableIntegrationTests: Bool = true,
            enableErrorScenarioTests: Bool = true,
            testTimeout: TimeInterval = 10.0,
            enableVerboseLogging: Bool = false
        ) {
            self.enablePerformanceTests = enablePerformanceTests
            self.enableIntegrationTests = enableIntegrationTests
            self.enableErrorScenarioTests = enableErrorScenarioTests
            self.testTimeout = testTimeout
            self.enableVerboseLogging = enableVerboseLogging
        }
    }
    
    // MARK: - Test Execution
    
    /// 运行完整的测试套件
    /// - Parameter configuration: 测试配置
    /// - Returns: 测试结果
    public static func runFullTestSuite(configuration: Configuration = Configuration()) async -> TestSuiteResult {
        let startTime = Date()
        var results: [TestResult] = []
        
        // 设置测试环境
        TestConfiguration.shared.setEnvironment(.unit)
        TestStateManager.shared.startTest("Full Test Suite")
        
        // 1. 基础功能测试
        let basicTests = await runBasicFunctionalityTests()
        results.append(contentsOf: basicTests)
        
        // 2. 错误处理测试
        if configuration.enableErrorScenarioTests {
            let errorTests = await runErrorHandlingTests()
            results.append(contentsOf: errorTests)
        }
        
        // 3. 集成测试
        if configuration.enableIntegrationTests {
            let integrationTests = await runIntegrationTests()
            results.append(contentsOf: integrationTests)
        }
        
        // 4. 性能测试
        if configuration.enablePerformanceTests {
            let performanceTests = await runPerformanceTests()
            results.append(contentsOf: performanceTests)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        TestStateManager.shared.endTest(status: .passed)
        
        return TestSuiteResult(
            totalTests: results.count,
            passedTests: results.filter { $0.status == .passed }.count,
            failedTests: results.filter { $0.status == .failed }.count,
            skippedTests: results.filter { $0.status == .skipped }.count,
            duration: duration,
            results: results
        )
    }
    
    // MARK: - Basic Functionality Tests
    
    /// 运行基础功能测试
    /// - Returns: 测试结果数组
    public static func runBasicFunctionalityTests() async -> [TestResult] {
        var results: [TestResult] = []
        
        // 测试商品服务
        results.append(await testProductService())
        
        // 测试购买服务
        results.append(await testPurchaseService())
        
        // 测试收据验证
        results.append(await testReceiptValidator())
        
        // 测试交易监控
        results.append(await testTransactionMonitor())
        
        // 测试 StoreKit 适配器
        results.append(await testStoreKitAdapter())
        
        return results
    }
    
    /// 测试商品服务
    /// - Returns: 测试结果
    public static func testProductService() async -> TestResult {
        let testName = "ProductService Basic Functionality"
        
        do {
            let mockService = MockProductService()
            let testProducts = TestDataGenerator.createVariousProducts()
            
            // 设置测试数据
            mockService.setMockProducts(testProducts)
            
            // 测试加载商品
            let productIDs = Set(testProducts.map { $0.id })
            let loadedProducts = try await mockService.loadProducts(productIDs: productIDs)
            
            // 验证结果
            guard loadedProducts.count == testProducts.count else {
                return TestResult(name: testName, status: .failed, message: "Product count mismatch")
            }
            
            // 测试单个商品获取
            let firstProduct = testProducts.first!
            let retrievedProduct = await mockService.getProduct(by: firstProduct.id)
            
            guard retrievedProduct?.id == firstProduct.id else {
                return TestResult(name: testName, status: .failed, message: "Single product retrieval failed")
            }
            
            // 验证调用记录
            guard mockService.wasMethodCalled("loadProducts") else {
                return TestResult(name: testName, status: .failed, message: "Method call not recorded")
            }
            
            return TestResult(name: testName, status: .passed, message: "All product service tests passed")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
    
    /// 测试购买服务
    /// - Returns: 测试结果
    public static func testPurchaseService() async -> TestResult {
        let testName = "PurchaseService Basic Functionality"
        
        do {
            let mockService = MockPurchaseService()
            let testProduct = TestDataGenerator.createProduct()
            
            // 设置成功的购买结果
            let successTransaction = TestDataGenerator.createSuccessfulTransaction(productID: testProduct.id)
            mockService.setMockPurchaseResult(.success(successTransaction))
            
            // 测试购买
            let purchaseResult = try await mockService.purchase(testProduct)
            
            // 验证结果
            guard case .success(let transaction) = purchaseResult else {
                return TestResult(name: testName, status: .failed, message: "Purchase result not success")
            }
            
            guard transaction.productID == testProduct.id else {
                return TestResult(name: testName, status: .failed, message: "Transaction product ID mismatch")
            }
            
            // 测试恢复购买
            let restoreTransactions = [TestDataGenerator.createRestoredTransaction()]
            mockService.setMockRestoreResult(restoreTransactions)
            
            let restoredTransactions = try await mockService.restorePurchases()
            
            guard restoredTransactions.count == 1 else {
                return TestResult(name: testName, status: .failed, message: "Restore purchases count mismatch")
            }
            
            return TestResult(name: testName, status: .passed, message: "All purchase service tests passed")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
    
    /// 测试收据验证器
    /// - Returns: 测试结果
    public static func testReceiptValidator() async -> TestResult {
        let testName = "ReceiptValidator Basic Functionality"
        
        do {
            let mockValidator = MockReceiptValidator()
            let receiptData = TestDataGenerator.createMockReceiptData()
            
            // 设置成功的验证结果
            mockValidator.simulateValidationSuccess()
            
            // 测试验证
            let validationResult = try await mockValidator.validateReceipt(receiptData)
            
            // 验证结果
            guard validationResult.isValid else {
                return TestResult(name: testName, status: .failed, message: "Validation result not valid")
            }
            
            // 测试失败场景
            mockValidator.simulateValidationFailure()
            let failedResult = try await mockValidator.validateReceipt(receiptData)
            
            guard !failedResult.isValid else {
                return TestResult(name: testName, status: .failed, message: "Failed validation should be invalid")
            }
            
            return TestResult(name: testName, status: .passed, message: "All receipt validator tests passed")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
    
    /// 测试交易监控器
    /// - Returns: 测试结果
    public static func testTransactionMonitor() async -> TestResult {
        let testName = "TransactionMonitor Basic Functionality"
        
        let mockMonitor = MockTransactionMonitor()
        let pendingTransactions = MockTransactionMonitor.createPendingTransactions(count: 3)
        
        // 设置测试数据
        mockMonitor.setMockPendingTransactions(pendingTransactions)
        
        // 测试开始监控
        await mockMonitor.startMonitoring()
        
        guard mockMonitor.isMonitoring else {
            return TestResult(name: testName, status: .failed, message: "Monitor should be active")
        }
        
        // 测试处理未完成交易
        await mockMonitor.handlePendingTransactions()
        
        // 验证调用记录
        guard mockMonitor.wasMethodCalled("handlePendingTransactions") else {
            return TestResult(name: testName, status: .failed, message: "Handle pending transactions not called")
        }
        
        // 测试停止监控
        mockMonitor.stopMonitoring()
        
        guard !mockMonitor.isMonitoring else {
            return TestResult(name: testName, status: .failed, message: "Monitor should be inactive")
        }
        
        return TestResult(name: testName, status: .passed, message: "All transaction monitor tests passed")
    }
    
    /// 测试 StoreKit 适配器
    /// - Returns: 测试结果
    public static func testStoreKitAdapter() async -> TestResult {
        let testName = "StoreKitAdapter Basic Functionality"
        
        do {
            let mockAdapter = MockStoreKitAdapter()
            let testProducts = MockStoreKitAdapter.createVariousTestProducts()
            
            // 设置测试数据
            mockAdapter.setMockProducts(testProducts)
            
            // 测试加载商品
            let productIDs = Set(testProducts.map { $0.id })
            let loadedProducts = try await mockAdapter.loadProducts(productIDs: productIDs)
            
            guard loadedProducts.count == testProducts.count else {
                return TestResult(name: testName, status: .failed, message: "Product count mismatch")
            }
            
            // 测试购买
            let testProduct = testProducts.first!
            let successTransaction = MockStoreKitAdapter.createTestTransaction(productID: testProduct.id)
            mockAdapter.setMockPurchaseResult(.success(successTransaction))
            
            let purchaseResult = try await mockAdapter.purchase(testProduct)
            
            guard case .success(let transaction) = purchaseResult else {
                return TestResult(name: testName, status: .failed, message: "Purchase result not success")
            }
            
            guard transaction.productID == testProduct.id else {
                return TestResult(name: testName, status: .failed, message: "Transaction product ID mismatch")
            }
            
            return TestResult(name: testName, status: .passed, message: "All StoreKit adapter tests passed")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    /// 运行错误处理测试
    /// - Returns: 测试结果数组
    public static func runErrorHandlingTests() async -> [TestResult] {
        var results: [TestResult] = []
        
        // 测试网络错误处理
        results.append(await testNetworkErrorHandling())
        
        // 测试验证错误处理
        results.append(await testValidationErrorHandling())
        
        // 测试购买取消处理
        results.append(await testPurchaseCancellationHandling())
        
        return results
    }
    
    /// 测试网络错误处理
    /// - Returns: 测试结果
    public static func testNetworkErrorHandling() async -> TestResult {
        let testName = "Network Error Handling"
        
        do {
            let mockService = MockProductService()
            mockService.setMockError(.networkError)
            
            // 尝试加载商品，应该抛出网络错误
            do {
                _ = try await mockService.loadProducts(productIDs: ["test.product"])
                return TestResult(name: testName, status: .failed, message: "Should have thrown network error")
            } catch let error as IAPError {
                guard error == .networkError else {
                    return TestResult(name: testName, status: .failed, message: "Wrong error type")
                }
            }
            
            return TestResult(name: testName, status: .passed, message: "Network error handled correctly")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /// 测试验证错误处理
    /// - Returns: 测试结果
    public static func testValidationErrorHandling() async -> TestResult {
        let testName = "Validation Error Handling"
        
        do {
            let mockValidator = MockReceiptValidator()
            mockValidator.setMockError(.receiptValidationFailed)
            
            let receiptData = TestDataGenerator.createMockReceiptData()
            
            // 尝试验证收据，应该抛出验证错误
            do {
                _ = try await mockValidator.validateReceipt(receiptData)
                return TestResult(name: testName, status: .failed, message: "Should have thrown validation error")
            } catch let error as IAPError {
                guard error == .receiptValidationFailed else {
                    return TestResult(name: testName, status: .failed, message: "Wrong error type")
                }
            }
            
            return TestResult(name: testName, status: .passed, message: "Validation error handled correctly")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /// 测试购买取消处理
    /// - Returns: 测试结果
    public static func testPurchaseCancellationHandling() async -> TestResult {
        let testName = "Purchase Cancellation Handling"
        
        do {
            let mockService = MockPurchaseService()
            let testProduct = TestDataGenerator.createProduct()
            
            // 设置取消的购买结果
            mockService.setMockPurchaseResult(.cancelled)
            
            let purchaseResult = try await mockService.purchase(testProduct)
            
            guard case .cancelled = purchaseResult else {
                return TestResult(name: testName, status: .failed, message: "Purchase result should be cancelled")
            }
            
            return TestResult(name: testName, status: .passed, message: "Purchase cancellation handled correctly")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Integration Tests
    
    /// 运行集成测试
    /// - Returns: 测试结果数组
    public static func runIntegrationTests() async -> [TestResult] {
        var results: [TestResult] = []
        
        // 测试完整的购买流程
        results.append(await testCompletePurchaseFlow())
        
        // 测试恢复购买流程
        results.append(await testRestorePurchaseFlow())
        
        return results
    }
    
    /// 测试完整的购买流程
    /// - Returns: 测试结果
    public static func testCompletePurchaseFlow() async -> TestResult {
        let testName = "Complete Purchase Flow Integration"
        
        do {
            // 创建所有必要的 Mock 对象
            let mockAdapter = MockStoreKitAdapter()
            let mockProductService = MockProductService()
            let mockPurchaseService = MockPurchaseService()
            let mockValidator = MockReceiptValidator()
            
            // 设置测试数据
            let testProducts = TestDataGenerator.createVariousProducts()
            mockAdapter.setMockProducts(testProducts)
            mockProductService.setMockProducts(testProducts)
            
            // 1. 加载商品
            let productIDs = Set(testProducts.prefix(3).map { $0.id })
            let loadedProducts = try await mockProductService.loadProducts(productIDs: productIDs)
            
            guard loadedProducts.count == 3 else {
                return TestResult(name: testName, status: .failed, message: "Failed to load products")
            }
            
            // 2. 购买商品
            let productToPurchase = loadedProducts.first!
            let successTransaction = TestDataGenerator.createSuccessfulTransaction(productID: productToPurchase.id)
            mockPurchaseService.setMockPurchaseResult(.success(successTransaction))
            
            let purchaseResult = try await mockPurchaseService.purchase(productToPurchase)
            
            guard case .success(let transaction) = purchaseResult else {
                return TestResult(name: testName, status: .failed, message: "Purchase failed")
            }
            
            // 3. 验证收据
            if let receiptData = transaction.receiptData {
                mockValidator.simulateValidationSuccess(transactions: [transaction])
                let validationResult = try await mockValidator.validateReceipt(receiptData)
                
                guard validationResult.isValid else {
                    return TestResult(name: testName, status: .failed, message: "Receipt validation failed")
                }
            }
            
            return TestResult(name: testName, status: .passed, message: "Complete purchase flow successful")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
    
    /// 测试恢复购买流程
    /// - Returns: 测试结果
    public static func testRestorePurchaseFlow() async -> TestResult {
        let testName = "Restore Purchase Flow Integration"
        
        do {
            let mockPurchaseService = MockPurchaseService()
            let mockValidator = MockReceiptValidator()
            
            // 设置恢复的交易
            let restoredTransactions = TestDataGenerator.createRestorePurchasesScenario()
            mockPurchaseService.setMockRestoreResult(restoredTransactions)
            
            // 恢复购买
            let transactions = try await mockPurchaseService.restorePurchases()
            
            guard transactions.count == restoredTransactions.count else {
                return TestResult(name: testName, status: .failed, message: "Restored transaction count mismatch")
            }
            
            // 验证每个恢复的交易
            for transaction in transactions {
                if let receiptData = transaction.receiptData {
                    mockValidator.simulateValidationSuccess(transactions: [transaction])
                    let validationResult = try await mockValidator.validateReceipt(receiptData)
                    
                    guard validationResult.isValid else {
                        return TestResult(name: testName, status: .failed, message: "Restored transaction validation failed")
                    }
                }
            }
            
            return TestResult(name: testName, status: .passed, message: "Restore purchase flow successful")
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Tests
    
    /// 运行性能测试
    /// - Returns: 测试结果数组
    public static func runPerformanceTests() async -> [TestResult] {
        var results: [TestResult] = []
        
        // 测试大量商品加载性能
        results.append(await testLargeProductLoadPerformance())
        
        // 测试并发购买性能
        results.append(await testConcurrentPurchasePerformance())
        
        return results
    }
    
    /// 测试大量商品加载性能
    /// - Returns: 测试结果
    public static func testLargeProductLoadPerformance() async -> TestResult {
        let testName = "Large Product Load Performance"
        
        do {
            let mockService = MockProductService()
            let largeProductSet = TestDataGenerator.createPerformanceTestScenario(productCount: 1000)
            mockService.setMockProducts(largeProductSet)
            
            let productIDs = Set(largeProductSet.map { $0.id })
            
            // 测量执行时间
            let (duration, loadedProducts) = try await TestUtilities.measureTime {
                try await mockService.loadProducts(productIDs: productIDs)
            }
            
            guard loadedProducts.count == largeProductSet.count else {
                return TestResult(name: testName, status: .failed, message: "Product count mismatch")
            }
            
            // 检查性能是否在可接受范围内（1秒内）
            guard duration < 1.0 else {
                return TestResult(name: testName, status: .failed, message: "Performance too slow: \(duration)s")
            }
            
            return TestResult(
                name: testName,
                status: .passed,
                message: "Loaded \(loadedProducts.count) products in \(String(format: "%.3f", duration))s"
            )
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
    
    /// 测试并发购买性能
    /// - Returns: 测试结果
    public static func testConcurrentPurchasePerformance() async -> TestResult {
        let testName = "Concurrent Purchase Performance"
        
        do {
            let mockService = MockPurchaseService()
            let testProducts = TestDataGenerator.createProducts(count: 10)
            
            // 设置成功的购买结果
            let successTransaction = TestDataGenerator.createSuccessfulTransaction()
            mockService.setMockPurchaseResult(.success(successTransaction))
            
            // 并发执行多个购买操作
            let (duration, results) = try await TestUtilities.measureTime {
                try await withThrowingTaskGroup(of: IAPPurchaseResult.self) { group in
                    for product in testProducts {
                        group.addTask {
                            try await mockService.purchase(product)
                        }
                    }
                    
                    var purchaseResults: [IAPPurchaseResult] = []
                    for try await result in group {
                        purchaseResults.append(result)
                    }
                    return purchaseResults
                }
            }
            
            guard results.count == testProducts.count else {
                return TestResult(name: testName, status: .failed, message: "Purchase count mismatch")
            }
            
            // 检查所有购买都成功
            let successCount = results.compactMap { result in
                if case .success = result { return result }
                return nil
            }.count
            
            guard successCount == testProducts.count else {
                return TestResult(name: testName, status: .failed, message: "Not all purchases succeeded")
            }
            
            return TestResult(
                name: testName,
                status: .passed,
                message: "Completed \(results.count) concurrent purchases in \(String(format: "%.3f", duration))s"
            )
            
        } catch {
            return TestResult(name: testName, status: .failed, message: "Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

/// 测试结果
public struct TestResult: Sendable {
    /// 测试名称
    public let name: String
    
    /// 测试状态
    public let status: TestStatus
    
    /// 测试消息
    public let message: String
    
    /// 测试持续时间
    public let duration: TimeInterval
    
    public init(name: String, status: TestStatus, message: String, duration: TimeInterval = 0) {
        self.name = name
        self.status = status
        self.message = message
        self.duration = duration
    }
}

/// 测试状态
public enum TestStatus: String, Sendable {
    case passed = "PASSED"
    case failed = "FAILED"
    case skipped = "SKIPPED"
}

/// 测试套件结果
public struct TestSuiteResult: Sendable {
    /// 总测试数
    public let totalTests: Int
    
    /// 通过的测试数
    public let passedTests: Int
    
    /// 失败的测试数
    public let failedTests: Int
    
    /// 跳过的测试数
    public let skippedTests: Int
    
    /// 总持续时间
    public let duration: TimeInterval
    
    /// 详细结果
    public let results: [TestResult]
    
    /// 成功率
    public var successRate: Double {
        return totalTests > 0 ? Double(passedTests) / Double(totalTests) : 0
    }
    
    /// 结果摘要
    public var summary: String {
        return """
        Test Suite Results:
        - Total Tests: \(totalTests)
        - Passed: \(passedTests)
        - Failed: \(failedTests)
        - Skipped: \(skippedTests)
        - Success Rate: \(String(format: "%.1f%%", successRate * 100))
        - Duration: \(String(format: "%.3f", duration))s
        """
    }
}