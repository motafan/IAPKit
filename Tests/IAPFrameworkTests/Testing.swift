import Foundation

// MARK: - Testing Framework Export

/// IAP Framework 测试基础设施
/// 
/// 这个模块提供了完整的测试基础设施，包括：
/// - Mock 服务类：模拟所有核心服务的行为
/// - 测试数据生成器：创建各种测试场景的数据
/// - 测试工具类：提供测试辅助方法和性能测量
/// - 测试配置管理：管理不同测试环境的配置
/// - 综合测试套件：展示如何使用测试基础设施
///
/// ## 使用示例
///
/// ### 基本 Mock 使用
/// ```swift
/// let mockProductService = MockProductService()
/// let testProducts = TestDataGenerator.createVariousProducts()
/// mockProductService.setMockProducts(testProducts)
/// 
/// let loadedProducts = try await mockProductService.loadProducts(productIDs: Set(testProducts.map { $0.id }))
/// ```
///
/// ### 错误场景测试
/// ```swift
/// let mockPurchaseService = MockPurchaseService()
/// mockPurchaseService.setMockError(.networkError)
/// 
/// do {
///     _ = try await mockPurchaseService.purchase(testProduct)
/// } catch let error as IAPError {
///     // 处理预期的网络错误
/// }
/// ```
///
/// ### 性能测试
/// ```swift
/// let (duration, result) = try await TestUtilities.measureTime {
///     try await someExpensiveOperation()
/// }
/// ```
///
/// ### 完整测试套件
/// ```swift
/// let testResult = await TestSuite.runFullTestSuite()
/// print(testResult.summary)
/// ```

// MARK: - Public Exports

// Mock Services - Remove circular references
// These are already defined in their respective files

// Test Utilities - Import types from their respective files
// These types are defined in their respective files and imported here for convenience

// MARK: - Quick Start Guide

/// 快速开始指南
public struct TestingQuickStart {
    
    /// 创建基本的测试环境
    /// - Returns: 配置好的 Mock 服务集合
    @MainActor
    public static func createBasicTestEnvironment() -> BasicTestEnvironment {
        let mockProductService = MockProductService()
        let mockPurchaseService = MockPurchaseService()
        let mockStoreKitAdapter = MockStoreKitAdapter()
        let mockReceiptValidator = MockReceiptValidator()
        let mockTransactionMonitor = MockTransactionMonitor()
        
        // 设置基本的测试数据
        let testProducts = TestDataGenerator.createVariousProducts()
        mockProductService.setMockProducts(testProducts)
        mockStoreKitAdapter.setMockProducts(testProducts)
        
        // 设置成功的默认行为
        mockReceiptValidator.simulateValidationSuccess()
        
        return BasicTestEnvironment(
            productService: mockProductService,
            purchaseService: mockPurchaseService,
            storeKitAdapter: mockStoreKitAdapter,
            receiptValidator: mockReceiptValidator,
            transactionMonitor: mockTransactionMonitor
        )
    }
    
    /// 创建错误测试环境
    /// - Parameter errorType: 错误类型
    /// - Returns: 配置了错误行为的测试环境
    @MainActor
    public static func createErrorTestEnvironment(errorType: IAPError) -> BasicTestEnvironment {
        let environment = createBasicTestEnvironment()
        
        // 设置所有服务都返回指定错误
        environment.productService.setMockError(errorType)
        environment.purchaseService.setMockError(errorType)
        environment.storeKitAdapter.setMockError(errorType)
        environment.receiptValidator.setMockError(errorType)
        
        return environment
    }
    
    /// 创建性能测试环境
    /// - Parameter productCount: 商品数量
    /// - Returns: 配置了大量数据的测试环境
    @MainActor
    public static func createPerformanceTestEnvironment(productCount: Int = 1000) -> BasicTestEnvironment {
        let environment = createBasicTestEnvironment()
        
        // 设置大量测试数据
        let largeProductSet = TestDataGenerator.createPerformanceTestScenario(productCount: productCount)
        environment.productService.setMockProducts(largeProductSet)
        environment.storeKitAdapter.setMockProducts(largeProductSet)
        
        return environment
    }
}

/// 基本测试环境
public struct BasicTestEnvironment {
    /// Mock 商品服务
    public let productService: MockProductService
    
    /// Mock 购买服务
    public let purchaseService: MockPurchaseService
    
    /// Mock StoreKit 适配器
    public let storeKitAdapter: MockStoreKitAdapter
    
    /// Mock 收据验证器
    public let receiptValidator: MockReceiptValidator
    
    /// Mock 交易监控器
    public let transactionMonitor: MockTransactionMonitor
    
    /// 重置所有 Mock 服务
    @MainActor
    public func resetAll() {
        productService.reset()
        purchaseService.reset()
        storeKitAdapter.reset()
        receiptValidator.reset()
        transactionMonitor.reset()
    }
    
    /// 获取所有服务的调用统计
    /// - Returns: 调用统计摘要
    public func getCallStatistics() -> String {
        return """
        Call Statistics:
        - ProductService: \(productService.callHistory.count) calls
        - PurchaseService: \(purchaseService.callHistory.count) calls
        - StoreKitAdapter: \(storeKitAdapter.callHistory.count) calls
        - ReceiptValidator: \(receiptValidator.callHistory.count) calls
        - TransactionMonitor: \(transactionMonitor.callHistory.count) calls
        """
    }
}

// MARK: - Test Scenarios

/// 预定义的测试场景
public struct TestScenarios {
    
    /// 成功购买场景
    public static func successfulPurchaseScenario() -> (product: IAPProduct, expectedResult: IAPPurchaseResult) {
        let product = TestDataGenerator.createProduct(id: "success.product", displayName: "Success Product")
        let transaction = TestDataGenerator.createSuccessfulTransaction(productID: product.id)
        let result = IAPPurchaseResult.success(transaction)
        
        return (product, result)
    }
    
    /// 购买取消场景
    public static func cancelledPurchaseScenario() -> (product: IAPProduct, expectedResult: IAPPurchaseResult) {
        let product = TestDataGenerator.createProduct(id: "cancel.product", displayName: "Cancel Product")
        let result = IAPPurchaseResult.cancelled
        
        return (product, result)
    }
    
    /// 网络错误场景
    public static func networkErrorScenario() -> (product: IAPProduct, expectedError: IAPError) {
        let product = TestDataGenerator.createProduct(id: "network.error.product", displayName: "Network Error Product")
        let error = IAPError.networkError
        
        return (product, error)
    }
    
    /// 收据验证失败场景
    public static func receiptValidationFailureScenario() -> (receiptData: Data, expectedError: IAPError) {
        let receiptData = TestDataGenerator.createMockReceiptData()
        let error = IAPError.receiptValidationFailed
        
        return (receiptData, error)
    }
    
    /// 大量商品加载场景
    public static func largeProductLoadScenario(count: Int = 100) -> [IAPProduct] {
        return TestDataGenerator.createProducts(count: count, prefix: "large.load")
    }
    
    /// 混合交易状态场景
    public static func mixedTransactionStatesScenario() -> [IAPTransaction] {
        return [
            TestDataGenerator.createSuccessfulTransaction(productID: "success.product"),
            TestDataGenerator.createFailedTransaction(productID: "failed.product"),
            TestDataGenerator.createPendingTransaction(productID: "pending.product"),
            TestDataGenerator.createRestoredTransaction(productID: "restored.product")
        ]
    }
}

// MARK: - Testing Best Practices

/// 测试最佳实践指南
public struct TestingBestPractices {
    
    /// 测试最佳实践建议
    public static let recommendations = """
    IAP Framework 测试最佳实践:
    
    1. 使用 Mock 对象进行单元测试
       - 使用 MockProductService、MockPurchaseService 等模拟依赖
       - 设置明确的测试数据和预期行为
       - 验证方法调用和参数
    
    2. 测试错误场景
       - 测试网络错误、验证失败等异常情况
       - 使用 setMockError() 方法模拟错误
       - 验证错误处理逻辑的正确性
    
    3. 性能测试
       - 使用 TestUtilities.measureTime() 测量执行时间
       - 测试大量数据的处理性能
       - 设置合理的性能基准
    
    4. 集成测试
       - 测试多个组件之间的协作
       - 模拟完整的用户操作流程
       - 验证端到端的功能
    
    5. 测试数据管理
       - 使用 TestDataGenerator 创建一致的测试数据
       - 为不同场景创建专门的测试数据
       - 保持测试数据的可维护性
    
    6. 测试环境配置
       - 使用 TestConfiguration 管理测试环境
       - 为不同类型的测试设置不同的配置
       - 确保测试的可重复性
    
    7. 异步测试
       - 正确处理 async/await 测试
       - 使用适当的超时设置
       - 测试并发场景
    
    8. 测试清理
       - 在测试后重置 Mock 对象状态
       - 清理测试数据和配置
       - 确保测试之间的独立性
    """
    
    /// 常见测试模式示例
    public static let commonPatterns = """
    常见测试模式:
    
    // 1. 基本功能测试
    func testBasicFunctionality() async throws {
        let mockService = MockProductService()
        let testProducts = TestDataGenerator.createVariousProducts()
        mockService.setMockProducts(testProducts)
        
        let result = try await mockService.loadProducts(productIDs: Set(testProducts.map { $0.id }))
        XCTAssertEqual(result.count, testProducts.count)
    }
    
    // 2. 错误处理测试
    func testErrorHandling() async throws {
        let mockService = MockPurchaseService()
        mockService.setMockError(.networkError)
        
        do {
            _ = try await mockService.purchase(testProduct)
            XCTFail("Should have thrown error")
        } catch let error as IAPError {
            XCTAssertEqual(error, .networkError)
        }
    }
    
    // 3. 性能测试
    func testPerformance() async throws {
        let (duration, result) = try await TestUtilities.measureTime {
            try await expensiveOperation()
        }
        XCTAssertLessThan(duration, 1.0)
    }
    
    // 4. 集成测试
    func testIntegration() async throws {
        let environment = TestingQuickStart.createBasicTestEnvironment()
        // 执行完整的操作流程
        // 验证各组件协作
    }
    """
}