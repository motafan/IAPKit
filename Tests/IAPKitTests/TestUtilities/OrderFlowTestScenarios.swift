import Foundation
@testable import IAPKit

/// 订单流程测试场景集合
public struct OrderFlowTestScenarios {
    
    // MARK: - Basic Order Flow Scenarios
    
    /// 成功的订单创建场景
    public static func successfulOrderCreation() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "test.product", displayName: "Test Product")
        let expectedOrder = TestDataGenerator.generateOrder(productID: product.id, status: .created)
        
        return OrderFlowScenario(
            name: "Successful Order Creation",
            description: "Test successful order creation for a product",
            product: product,
            expectedOrder: expectedOrder,
            expectedResult: .success,
            mockConfiguration: { mockService in
                await mockService.configureOrderCreation(order: expectedOrder, shouldSucceed: true)
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                // 验证 Mock 服务调用
                if !(await mockService.wasCalled("createOrder")) {
                    issues.append("createOrder method was not called")
                }
                
                // 验证创建的订单
                let createdOrders = await mockService.getAllCreatedOrders()
                if createdOrders.isEmpty {
                    issues.append("No orders were created")
                } else if createdOrders.first?.productID != product.id {
                    issues.append("Created order has wrong product ID")
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    /// 订单创建失败场景
    public static func failedOrderCreation() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "test.product")
        
        return OrderFlowScenario(
            name: "Failed Order Creation",
            description: "Test order creation failure handling",
            product: product,
            expectedOrder: nil,
            expectedResult: .failure,
            mockConfiguration: { mockService in
                await mockService.configureOrderCreation(shouldSucceed: false)
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                if (await mockService.wasCalled("createOrder")) {
                    let createdOrders = await mockService.getAllCreatedOrders()
                    if !createdOrders.isEmpty {
                        issues.append("Orders were created despite failure configuration")
                    }
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    /// 订单过期场景
    public static func expiredOrderHandling() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "expired.product")
        let expiredOrder = TestDataGenerator.generateExpiredOrder(productID: product.id)
        
        return OrderFlowScenario(
            name: "Expired Order Handling",
            description: "Test handling of expired orders",
            product: product,
            expectedOrder: expiredOrder,
            expectedResult: .failure,
            mockConfiguration: { mockService in
                await mockService.configureOrderExpired()
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                // 验证过期订单被正确处理
                if let error = result?.error, error != .orderExpired {
                    issues.append("Expected orderExpired error, got \(error)")
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    // MARK: - Purchase Flow Scenarios
    
    /// 完整的订单购买流程场景
    public static func completePurchaseFlow() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "purchase.product")
        let order = TestDataGenerator.generateOrder(productID: product.id, status: .pending)
        
        return OrderFlowScenario(
            name: "Complete Purchase Flow",
            description: "Test complete order-based purchase flow",
            product: product,
            expectedOrder: order,
            expectedResult: .success,
            mockConfiguration: { mockService in
                await mockService.configureSuccessfulPurchase(for: product)
                await mockService.configureOrderCreation(order: order)
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                // 验证购买流程调用
                let expectedCalls = ["createOrder", "purchase", "validateReceiptWithOrder"]
                for call in expectedCalls {
                    if !(await mockService.wasCalled(call)) {
                        issues.append("Expected call '\(call)' was not made")
                    }
                }
                
                // 验证购买结果
                if let purchaseResult = result?.purchaseResult {
                    let verificationResult = OrderTestUtilities.verifyPurchaseResultConsistency(purchaseResult)
                    if !verificationResult.isValid {
                        issues.append(contentsOf: verificationResult.issues)
                    }
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    /// 购买取消场景
    public static func purchaseCancellation() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "cancelled.product")
        let order = TestDataGenerator.generateOrder(productID: product.id, status: .cancelled)
        
        return OrderFlowScenario(
            name: "Purchase Cancellation",
            description: "Test purchase cancellation with order cleanup",
            product: product,
            expectedOrder: order,
            expectedResult: .cancelled,
            mockConfiguration: { mockService in
                await mockService.configureCancelledPurchase(order: order)
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                if let purchaseResult = result?.purchaseResult {
                    if case .cancelled(let resultOrder) = purchaseResult {
                        if let resultOrder = resultOrder, resultOrder.status != .cancelled {
                            issues.append("Cancelled purchase should have cancelled order")
                        }
                    } else {
                        issues.append("Expected cancelled purchase result")
                    }
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    // MARK: - Error Handling Scenarios
    
    /// 网络错误处理场景
    public static func networkErrorHandling() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "network.product")
        
        return OrderFlowScenario(
            name: "Network Error Handling",
            description: "Test network error handling during order operations",
            product: product,
            expectedOrder: nil,
            expectedResult: .failure,
            mockConfiguration: { mockService in
                await mockService.configureNetworkError()
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                if let error = result?.error, error != .networkError {
                    issues.append("Expected network error, got \(error)")
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    /// 订单验证失败场景
    public static func orderValidationFailure() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "validation.product")
        let order = TestDataGenerator.generateOrder(productID: product.id)
        
        return OrderFlowScenario(
            name: "Order Validation Failure",
            description: "Test order validation failure handling",
            product: product,
            expectedOrder: order,
            expectedResult: .failure,
            mockConfiguration: { mockService in
                await mockService.configureOrderValidationFailed()
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                if let error = result?.error, error != .orderValidationFailed {
                    issues.append("Expected order validation failed error, got \(error)")
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    /// 服务器订单不匹配场景
    public static func serverOrderMismatch() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "mismatch.product")
        let order = TestDataGenerator.generateOrder(productID: product.id)
        
        return OrderFlowScenario(
            name: "Server Order Mismatch",
            description: "Test server order mismatch error handling",
            product: product,
            expectedOrder: order,
            expectedResult: .failure,
            mockConfiguration: { mockService in
                await mockService.configureServerOrderMismatch()
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                if let error = result?.error, error != .serverOrderMismatch {
                    issues.append("Expected server order mismatch error, got \(error)")
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    // MARK: - Recovery Scenarios
    
    /// 订单恢复场景
    public static func orderRecovery() -> OrderFlowScenario {
        let product = TestDataGenerator.generateProduct(id: "recovery.product")
        let pendingOrder = TestDataGenerator.generatePendingOrder(productID: product.id)
        
        return OrderFlowScenario(
            name: "Order Recovery",
            description: "Test order recovery on app restart",
            product: product,
            expectedOrder: pendingOrder,
            expectedResult: .success,
            mockConfiguration: { mockService in
                await mockService.configureOrderStatusQuery(status: .completed)
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                if !(await mockService.wasCalled("queryOrderStatus")) {
                    issues.append("Order status query was not called during recovery")
                }
                
                let queriedOrderIDs = await mockService.getAllQueriedOrderIDs()
                if !queriedOrderIDs.contains(pendingOrder.id) {
                    issues.append("Expected order ID was not queried during recovery")
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    // MARK: - Complex Scenarios
    
    /// 多订单并发处理场景
    public static func concurrentOrderProcessing() -> OrderFlowScenario {
        let products = TestDataGenerator.generateProducts(count: 3)
        let orders = products.map { TestDataGenerator.generateOrder(productID: $0.id) }
        
        return OrderFlowScenario(
            name: "Concurrent Order Processing",
            description: "Test concurrent processing of multiple orders",
            product: products.first!,
            expectedOrder: orders.first,
            expectedResult: .success,
            mockConfiguration: { mockService in
                for (product, order) in zip(products, orders) {
                    await mockService.configureSuccessfulPurchase(for: product)
                    await mockService.configureOrderCreation(order: order)
                }
            },
            verification: { result, mockService in
                var issues: [String] = []
                
                let createdOrders = await mockService.getAllCreatedOrders()
                if createdOrders.count < products.count {
                    issues.append("Not all orders were created during concurrent processing")
                }
                
                return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
            }
        )
    }
    
    /// 获取所有测试场景
    public static func allScenarios() -> [OrderFlowScenario] {
        return [
            successfulOrderCreation(),
            failedOrderCreation(),
            expiredOrderHandling(),
            completePurchaseFlow(),
            purchaseCancellation(),
            networkErrorHandling(),
            orderValidationFailure(),
            serverOrderMismatch(),
            orderRecovery(),
            concurrentOrderProcessing()
        ]
    }
}

// MARK: - Order Flow Scenario Definition

/// 订单流程测试场景
public struct OrderFlowScenario {
    /// 场景名称
    public let name: String
    /// 场景描述
    public let description: String
    /// 测试商品
    public let product: IAPProduct
    /// 期望的订单
    public let expectedOrder: IAPOrder?
    /// 期望的结果类型
    public let expectedResult: ExpectedResultType
    /// Mock 配置闭包
    public let mockConfiguration: (MockPurchaseService) async -> Void
    /// 验证闭包
    public let verification: (OrderFlowResult?, MockPurchaseService) async -> OrderVerificationResult
    
    public init(
        name: String,
        description: String,
        product: IAPProduct,
        expectedOrder: IAPOrder?,
        expectedResult: ExpectedResultType,
        mockConfiguration: @escaping (MockPurchaseService) async -> Void,
        verification: @escaping (OrderFlowResult?, MockPurchaseService) async -> OrderVerificationResult
    ) {
        self.name = name
        self.description = description
        self.product = product
        self.expectedOrder = expectedOrder
        self.expectedResult = expectedResult
        self.mockConfiguration = mockConfiguration
        self.verification = verification
    }
    
    /// 执行测试场景
    /// - Parameter mockService: Mock 服务
    /// - Returns: 测试结果
    public func execute(with mockService: MockPurchaseService) async -> OrderFlowTestResult {
        // 重置 Mock 服务
        await mockService.reset()
        
        // 配置 Mock 服务
        await mockConfiguration(mockService)
        
        var orderFlowResult: OrderFlowResult?
        var executionError: Error?
        
        do {
            // 执行订单操作
            switch expectedResult {
            case .success, .cancelled, .failure:
                let purchaseResult = try await mockService.purchase(product)
                orderFlowResult = OrderFlowResult(purchaseResult: purchaseResult, error: nil)
            }
        } catch {
            executionError = error
            orderFlowResult = OrderFlowResult(purchaseResult: nil, error: error as? IAPError)
        }
        
        // 执行验证
        let verificationResult = await verification(orderFlowResult, mockService)
        
        // 验证期望结果类型
        var resultTypeIssues: [String] = []
        if let result = orderFlowResult {
            let actualResultType = determineResultType(from: result)
            if actualResultType != expectedResult {
                resultTypeIssues.append("Expected \(expectedResult), got \(actualResultType)")
            }
        } else if expectedResult != .failure {
            resultTypeIssues.append("Expected \(expectedResult), but execution failed")
        }
        
        let combinedVerification = OrderVerificationResult.combine([
            verificationResult,
            OrderVerificationResult(isValid: resultTypeIssues.isEmpty, issues: resultTypeIssues)
        ])
        
        return OrderFlowTestResult(
            scenario: self,
            result: orderFlowResult,
            executionError: executionError,
            verification: combinedVerification
        )
    }
    
    private func determineResultType(from result: OrderFlowResult) -> ExpectedResultType {
        if let purchaseResult = result.purchaseResult {
            switch purchaseResult {
            case .success:
                return .success
            case .cancelled:
                return .cancelled
            case .pending:
                return .success // Pending is considered a form of success
            case .failed:
                return .failure
            }
        } else if result.error != nil {
            return .failure
        } else {
            return .success
        }
    }
}

/// 期望的结果类型
public enum ExpectedResultType {
    case success
    case cancelled
    case failure
}

/// 订单流程结果
public struct OrderFlowResult {
    public let purchaseResult: IAPPurchaseResult?
    public let error: IAPError?
    
    public init(purchaseResult: IAPPurchaseResult?, error: IAPError?) {
        self.purchaseResult = purchaseResult
        self.error = error
    }
}

/// 订单流程测试结果
public struct OrderFlowTestResult {
    /// 测试场景
    public let scenario: OrderFlowScenario
    /// 执行结果
    public let result: OrderFlowResult?
    /// 执行错误
    public let executionError: Error?
    /// 验证结果
    public let verification: OrderVerificationResult
    
    /// 测试是否通过
    public var isPassed: Bool {
        return verification.isValid
    }
    
    /// 测试结果描述
    public var description: String {
        let status = isPassed ? "PASSED" : "FAILED"
        var description = "[\(status)] \(scenario.name): \(scenario.description)"
        
        if !isPassed {
            description += "\nIssues: \(verification.issues.joined(separator: ", "))"
        }
        
        if let executionError = executionError {
            description += "\nExecution Error: \(executionError.localizedDescription)"
        }
        
        return description
    }
    
    public init(
        scenario: OrderFlowScenario,
        result: OrderFlowResult?,
        executionError: Error?,
        verification: OrderVerificationResult
    ) {
        self.scenario = scenario
        self.result = result
        self.executionError = executionError
        self.verification = verification
    }
}

// MARK: - Batch Test Runner

/// 批量订单流程测试运行器
public struct OrderFlowTestRunner {
    
    /// 运行所有测试场景
    /// - Parameter mockService: Mock 服务
    /// - Returns: 所有测试结果
    public static func runAllScenarios(with mockService: MockPurchaseService) async -> [OrderFlowTestResult] {
        let scenarios = OrderFlowTestScenarios.allScenarios()
        var results: [OrderFlowTestResult] = []
        
        for scenario in scenarios {
            let result = await scenario.execute(with: mockService)
            results.append(result)
        }
        
        return results
    }
    
    /// 运行指定的测试场景
    /// - Parameters:
    ///   - scenarios: 要运行的场景
    ///   - mockService: Mock 服务
    /// - Returns: 测试结果
    public static func runScenarios(
        _ scenarios: [OrderFlowScenario],
        with mockService: MockPurchaseService
    ) async -> [OrderFlowTestResult] {
        var results: [OrderFlowTestResult] = []
        
        for scenario in scenarios {
            let result = await scenario.execute(with: mockService)
            results.append(result)
        }
        
        return results
    }
    
    /// 生成测试报告
    /// - Parameter results: 测试结果
    /// - Returns: 测试报告
    public static func generateReport(from results: [OrderFlowTestResult]) -> OrderFlowTestReport {
        let passedCount = results.filter { $0.isPassed }.count
        let failedCount = results.count - passedCount
        
        return OrderFlowTestReport(
            totalTests: results.count,
            passedTests: passedCount,
            failedTests: failedCount,
            results: results
        )
    }
}

/// 订单流程测试报告
public struct OrderFlowTestReport {
    public let totalTests: Int
    public let passedTests: Int
    public let failedTests: Int
    public let results: [OrderFlowTestResult]
    
    /// 测试通过率
    public var passRate: Double {
        guard totalTests > 0 else { return 0.0 }
        return Double(passedTests) / Double(totalTests)
    }
    
    /// 报告描述
    public var description: String {
        let passRatePercentage = Int(passRate * 100)
        var report = """
        Order Flow Test Report
        ======================
        Total Tests: \(totalTests)
        Passed: \(passedTests)
        Failed: \(failedTests)
        Pass Rate: \(passRatePercentage)%
        
        """
        
        if failedTests > 0 {
            report += "Failed Tests:\n"
            for result in results where !result.isPassed {
                report += "- \(result.scenario.name): \(result.verification.issues.joined(separator: ", "))\n"
            }
        }
        
        return report
    }
    
    public init(totalTests: Int, passedTests: Int, failedTests: Int, results: [OrderFlowTestResult]) {
        self.totalTests = totalTests
        self.passedTests = passedTests
        self.failedTests = failedTests
        self.results = results
    }
}