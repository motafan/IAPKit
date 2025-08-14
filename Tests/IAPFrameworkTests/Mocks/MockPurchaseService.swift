import Foundation
@testable import IAPFramework

/// Mock 购买服务，用于测试
@MainActor
public final class MockPurchaseService: @unchecked Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的购买结果
    public var mockPurchaseResult: IAPPurchaseResult?
    
    /// 模拟的恢复购买结果
    public var mockRestoreResult: [IAPTransaction] = []
    
    /// 模拟的收据验证结果
    public var mockReceiptValidationResult: IAPReceiptValidationResult?
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    /// 模拟的活跃购买
    public var mockActivePurchases: [String] = []
    
    /// 模拟的购买验证结果
    public var mockPurchaseValidationResult: PurchaseService.PurchaseValidationResult?
    
    // MARK: - Call Tracking
    
    /// 调用计数器
    public private(set) var callCounts: [String: Int] = [:]
    
    /// 调用参数记录
    public private(set) var callParameters: [String: Any] = [:]
    
    /// 购买的商品记录
    public private(set) var purchasedProducts: [IAPProduct] = []
    
    /// 完成的交易记录
    public private(set) var finishedTransactions: [IAPTransaction] = []
    
    /// 验证的收据记录
    public private(set) var validatedReceipts: [Data] = []
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - PurchaseService Mock Methods
    
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        incrementCallCount(for: "purchase")
        callParameters["purchase_product"] = product
        purchasedProducts.append(product)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        if let result = mockPurchaseResult {
            return result
        }
        
        // 默认返回成功结果
        let transaction = IAPTransaction.successful(
            id: "mock_tx_\(UUID().uuidString)",
            productID: product.id
        )
        return .success(transaction)
    }
    
    public func restorePurchases() async throws -> [IAPTransaction] {
        incrementCallCount(for: "restorePurchases")
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        return mockRestoreResult
    } 
   
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        incrementCallCount(for: "finishTransaction")
        callParameters["finishTransaction_transaction"] = transaction
        finishedTransactions.append(transaction)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
    }
    
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        incrementCallCount(for: "validateReceipt")
        callParameters["validateReceipt_receiptData"] = receiptData
        validatedReceipts.append(receiptData)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        if let result = mockReceiptValidationResult {
            return result
        }
        
        // 默认返回有效结果
        return IAPReceiptValidationResult(
            isValid: true,
            transactions: [],
            receiptCreationDate: Date(),
            appVersion: "1.0.0",
            originalAppVersion: "1.0.0",
            environment: .sandbox
        )
    }
    
    public func getActivePurchases() -> [String] {
        incrementCallCount(for: "getActivePurchases")
        return mockActivePurchases
    }
    
    public func cancelPurchase(for productID: String) -> Bool {
        incrementCallCount(for: "cancelPurchase")
        callParameters["cancelPurchase_productID"] = productID
        
        if let index = mockActivePurchases.firstIndex(of: productID) {
            mockActivePurchases.remove(at: index)
            return true
        }
        return false
    }
    
    public func cancelAllPurchases() {
        incrementCallCount(for: "cancelAllPurchases")
        let cancelledCount = mockActivePurchases.count
        mockActivePurchases.removeAll()
        callParameters["cancelAllPurchases_cancelledCount"] = cancelledCount
    }
    
    public func getPurchaseStats() -> PurchaseService.PurchaseStats {
        incrementCallCount(for: "getPurchaseStats")
        
        return PurchaseService.PurchaseStats(
            activePurchasesCount: mockActivePurchases.count,
            activePurchaseProductIDs: mockActivePurchases
        )
    }
    
    public func validateCanPurchase(_ product: IAPProduct) -> PurchaseService.PurchaseValidationResult {
        incrementCallCount(for: "validateCanPurchase")
        callParameters["validateCanPurchase_product"] = product
        
        if let result = mockPurchaseValidationResult {
            return result
        }
        
        // 默认可以购买
        return PurchaseService.PurchaseValidationResult(canPurchase: true)
    }
    
    // MARK: - Mock Configuration Methods
    
    /// 设置模拟购买结果
    /// - Parameter result: 购买结果
    public func setMockPurchaseResult(_ result: IAPPurchaseResult) {
        mockPurchaseResult = result
    }
    
    /// 设置模拟恢复购买结果
    /// - Parameter transactions: 交易列表
    public func setMockRestoreResult(_ transactions: [IAPTransaction]) {
        mockRestoreResult = transactions
    }
    
    /// 设置模拟收据验证结果
    /// - Parameter result: 验证结果
    public func setMockReceiptValidationResult(_ result: IAPReceiptValidationResult) {
        mockReceiptValidationResult = result
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
    
    /// 设置模拟活跃购买
    /// - Parameter productIDs: 商品ID列表
    public func setMockActivePurchases(_ productIDs: [String]) {
        mockActivePurchases = productIDs
    }
    
    /// 添加模拟活跃购买
    /// - Parameter productID: 商品ID
    public func addMockActivePurchase(_ productID: String) {
        if !mockActivePurchases.contains(productID) {
            mockActivePurchases.append(productID)
        }
    }
    
    /// 设置模拟购买验证结果
    /// - Parameter result: 验证结果
    public func setMockPurchaseValidationResult(_ result: PurchaseService.PurchaseValidationResult) {
        mockPurchaseValidationResult = result
    }
    
    // MARK: - Test Helper Methods
    
    /// 重置所有模拟数据
    public func reset() {
        mockPurchaseResult = nil
        mockRestoreResult.removeAll()
        mockReceiptValidationResult = nil
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        mockActivePurchases.removeAll()
        mockPurchaseValidationResult = nil
        callCounts.removeAll()
        callParameters.removeAll()
        purchasedProducts.removeAll()
        finishedTransactions.removeAll()
        validatedReceipts.removeAll()
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
    
    /// 获取所有购买的商品
    /// - Returns: 商品列表
    public func getAllPurchasedProducts() -> [IAPProduct] {
        return purchasedProducts
    }
    
    /// 获取所有完成的交易
    /// - Returns: 交易列表
    public func getAllFinishedTransactions() -> [IAPTransaction] {
        return finishedTransactions
    }
    
    /// 获取所有验证的收据
    /// - Returns: 收据数据列表
    public func getAllValidatedReceipts() -> [Data] {
        return validatedReceipts
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

// MARK: - Convenience Factory Methods

extension MockPurchaseService {
    
    /// 创建总是成功购买的 Mock 服务
    /// - Returns: Mock 服务
    public static func alwaysSuccessful() -> MockPurchaseService {
        let service = MockPurchaseService()
        let transaction = IAPTransaction.successful(
            id: "success_tx",
            productID: "test_product"
        )
        service.setMockPurchaseResult(.success(transaction))
        return service
    }
    
    /// 创建总是取消购买的 Mock 服务
    /// - Returns: Mock 服务
    public static func alwaysCancelled() -> MockPurchaseService {
        let service = MockPurchaseService()
        service.setMockPurchaseResult(.cancelled)
        return service
    }
    
    /// 创建会抛出错误的 Mock 服务
    /// - Parameter error: 错误
    /// - Returns: Mock 服务
    public static func withError(_ error: IAPError) -> MockPurchaseService {
        let service = MockPurchaseService()
        service.setMockError(error, shouldThrow: true)
        return service
    }
    
    /// 创建带有延迟的 Mock 服务
    /// - Parameter delay: 延迟时间（秒）
    /// - Returns: Mock 服务
    public static func withDelay(_ delay: TimeInterval) -> MockPurchaseService {
        let service = MockPurchaseService()
        service.setMockDelay(delay)
        return service
    }
    
    /// 创建带有恢复交易的 Mock 服务
    /// - Parameter transactions: 交易列表
    /// - Returns: Mock 服务
    public static func withRestoreTransactions(_ transactions: [IAPTransaction]) -> MockPurchaseService {
        let service = MockPurchaseService()
        service.setMockRestoreResult(transactions)
        return service
    }
}

// MARK: - Test Scenario Builders

extension MockPurchaseService {
    
    /// 配置成功购买场景
    /// - Parameter product: 商品
    public func configureSuccessfulPurchase(for product: IAPProduct) {
        let transaction = IAPTransaction.successful(
            id: "success_tx_\(product.id)",
            productID: product.id
        )
        setMockPurchaseResult(.success(transaction))
    }
    
    /// 配置取消购买场景
    public func configureCancelledPurchase() {
        setMockPurchaseResult(.cancelled)
    }
    
    /// 配置失败购买场景
    /// - Parameter error: 错误
    public func configureFailedPurchase(error: IAPError) {
        setMockError(error, shouldThrow: true)
    }
    
    /// 配置网络错误场景
    public func configureNetworkError() {
        setMockError(.networkError, shouldThrow: true)
    }
    
    /// 配置超时场景
    /// - Parameter delay: 延迟时间
    public func configureTimeout(delay: TimeInterval = 5.0) {
        setMockDelay(delay)
        setMockError(.timeout, shouldThrow: true)
    }
    
    /// 配置恢复购买场景
    /// - Parameter transactions: 要恢复的交易
    public func configureRestorePurchases(_ transactions: [IAPTransaction]) {
        setMockRestoreResult(transactions)
    }
    
    /// 配置收据验证场景
    /// - Parameters:
    ///   - isValid: 是否有效
    ///   - transactions: 交易列表
    public func configureReceiptValidation(isValid: Bool, transactions: [IAPTransaction] = []) {
        let result = IAPReceiptValidationResult(
            isValid: isValid,
            transactions: transactions,
            receiptCreationDate: Date(),
            appVersion: "1.0.0",
            originalAppVersion: "1.0.0",
            environment: .sandbox
        )
        setMockReceiptValidationResult(result)
    }
    
    /// 配置活跃购买场景
    /// - Parameter productIDs: 活跃购买的商品ID
    public func configureActivePurchases(_ productIDs: [String]) {
        setMockActivePurchases(productIDs)
    }
    
    /// 配置购买验证场景
    /// - Parameters:
    ///   - canPurchase: 是否可以购买
    ///   - error: 错误（如果有）
    ///   - message: 消息（如果有）
    public func configurePurchaseValidation(
        canPurchase: Bool,
        error: IAPError? = nil,
        message: String? = nil
    ) {
        let result = PurchaseService.PurchaseValidationResult(
            canPurchase: canPurchase,
            error: error,
            message: message
        )
        setMockPurchaseValidationResult(result)
    }
}