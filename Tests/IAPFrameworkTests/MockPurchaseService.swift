import Foundation

/// Mock 购买服务，用于测试
@MainActor
public final class MockPurchaseService: Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的购买结果
    public var mockPurchaseResult: IAPPurchaseResult?
    
    /// 模拟的恢复购买结果
    public var mockRestoreResult: [IAPTransaction] = []
    
    /// 模拟的收据验证结果
    public var mockReceiptValidationResult: IAPReceiptValidationResult?
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 调用记录
    public private(set) var callHistory: [String] = []
    
    /// 购买调用次数
    public private(set) var purchaseCallCount = 0
    
    /// 恢复购买调用次数
    public private(set) var restoreCallCount = 0
    
    /// 收据验证调用次数
    public private(set) var validateReceiptCallCount = 0
    
    /// 最后一次购买的商品
    public private(set) var lastPurchasedProduct: IAPProduct?
    
    /// 最后一次验证的收据数据
    public private(set) var lastValidatedReceiptData: Data?
    
    /// 当前活跃的购买操作
    private var activePurchaseProductIDs: Set<String> = []
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Mock Configuration
    
    /// 设置模拟购买结果
    /// - Parameter result: 购买结果
    public func setMockPurchaseResult(_ result: IAPPurchaseResult) {
        mockPurchaseResult = result
    }
    
    /// 设置模拟恢复购买结果
    /// - Parameter transactions: 交易数组
    public func setMockRestoreResult(_ transactions: [IAPTransaction]) {
        mockRestoreResult = transactions
    }
    
    /// 设置模拟收据验证结果
    /// - Parameter result: 验证结果
    public func setMockReceiptValidationResult(_ result: IAPReceiptValidationResult) {
        mockReceiptValidationResult = result
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
        mockPurchaseResult = nil
        mockRestoreResult.removeAll()
        mockReceiptValidationResult = nil
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        callHistory.removeAll()
        purchaseCallCount = 0
        restoreCallCount = 0
        validateReceiptCallCount = 0
        lastPurchasedProduct = nil
        lastValidatedReceiptData = nil
        activePurchaseProductIDs.removeAll()
    }
    
    // MARK: - PurchaseService Interface
    
    /// 购买商品
    /// - Parameter product: 要购买的商品
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        callHistory.append("purchase(\(product.id))")
        purchaseCallCount += 1
        lastPurchasedProduct = product
        
        // 检查是否已有相同商品的购买在进行中
        if activePurchaseProductIDs.contains(product.id) {
            throw IAPError.transactionProcessingFailed("Purchase already in progress")
        }
        
        // 记录活跃购买
        activePurchaseProductIDs.insert(product.id)
        
        defer {
            activePurchaseProductIDs.remove(product.id)
        }
        
        // 模拟延迟
        if mockDelay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(mockDelay))
            } else {
                try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
            }
        }
        
        // 模拟错误
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // 返回模拟结果或默认成功结果
        if let result = mockPurchaseResult {
            return result
        } else {
            let transaction = IAPTransaction.successful(id: "mock_tx_\(product.id)", productID: product.id)
            return .success(transaction)
        }
    }
    
    /// 恢复购买
    /// - Returns: 恢复的交易数组
    /// - Throws: IAPError 相关错误
    public func restorePurchases() async throws -> [IAPTransaction] {
        callHistory.append("restorePurchases()")
        restoreCallCount += 1
        
        // 模拟延迟
        if mockDelay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(mockDelay))
            } else {
                try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
            }
        }
        
        // 模拟错误
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        return mockRestoreResult
    }
    
    /// 完成交易
    /// - Parameter transaction: 要完成的交易
    /// - Throws: IAPError 相关错误
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        callHistory.append("finishTransaction(\(transaction.id))")
        
        // 模拟延迟
        if mockDelay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(mockDelay))
            } else {
                try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
            }
        }
        
        // 模拟错误
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // Mock 实现不需要实际完成交易
    }
    
    /// 验证收据
    /// - Parameter receiptData: 收据数据
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        callHistory.append("validateReceipt(\(receiptData.count) bytes)")
        validateReceiptCallCount += 1
        lastValidatedReceiptData = receiptData
        
        // 模拟延迟
        if mockDelay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(mockDelay))
            } else {
                try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
            }
        }
        
        // 模拟错误
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // 返回模拟结果或默认成功结果
        if let result = mockReceiptValidationResult {
            return result
        } else {
            return IAPReceiptValidationResult(
                isValid: true,
                transactions: [],
                error: nil,
                receiptCreationDate: Date(),
                appVersion: "1.0",
                originalAppVersion: "1.0",
                environment: .sandbox
            )
        }
    }
    
    /// 获取当前活跃的购买操作
    /// - Returns: 活跃购买的商品ID数组
    public func getActivePurchases() -> [String] {
        callHistory.append("getActivePurchases()")
        return Array(activePurchaseProductIDs)
    }
    
    /// 取消指定商品的购买操作
    /// - Parameter productID: 商品ID
    /// - Returns: 是否成功取消
    public func cancelPurchase(for productID: String) -> Bool {
        callHistory.append("cancelPurchase(\(productID))")
        let wasActive = activePurchaseProductIDs.contains(productID)
        activePurchaseProductIDs.remove(productID)
        return wasActive
    }
    
    /// 取消所有活跃的购买操作
    public func cancelAllPurchases() {
        callHistory.append("cancelAllPurchases()")
        activePurchaseProductIDs.removeAll()
    }
    
    // MARK: - Purchase Statistics
    
    /// 购买统计信息
    public struct PurchaseStats: Sendable {
        /// 活跃购买数量
        public let activePurchasesCount: Int
        
        /// 活跃购买的商品ID
        public let activePurchaseProductIDs: [String]
        
        /// 是否有活跃购买
        public var hasActivePurchases: Bool {
            return activePurchasesCount > 0
        }
    }
    
    /// 获取购买统计信息
    /// - Returns: 购买统计信息
    public func getPurchaseStats() -> PurchaseStats {
        callHistory.append("getPurchaseStats()")
        return PurchaseStats(
            activePurchasesCount: activePurchaseProductIDs.count,
            activePurchaseProductIDs: Array(activePurchaseProductIDs)
        )
    }
    
    // MARK: - Purchase Validation
    
    /// 购买验证结果
    public struct PurchaseValidationResult: Sendable {
        /// 是否可以购买
        public let canPurchase: Bool
        
        /// 验证错误（如果有）
        public let error: IAPError?
        
        /// 验证消息
        public let message: String?
        
        public init(canPurchase: Bool, error: IAPError? = nil, message: String? = nil) {
            self.canPurchase = canPurchase
            self.error = error
            self.message = message
        }
    }
    
    /// 验证是否可以购买指定商品
    /// - Parameter product: 商品信息
    /// - Returns: 验证结果
    public func validateCanPurchase(_ product: IAPProduct) -> PurchaseValidationResult {
        callHistory.append("validateCanPurchase(\(product.id))")
        
        // 检查是否已有相同商品的购买在进行中
        let hasActivePurchase = activePurchaseProductIDs.contains(product.id)
        
        if hasActivePurchase {
            return PurchaseValidationResult(
                canPurchase: false,
                error: .transactionProcessingFailed("Purchase already in progress"),
                message: "A purchase for this product is already in progress"
            )
        }
        
        // 基本验证
        if product.id.isEmpty {
            return PurchaseValidationResult(
                canPurchase: false,
                error: .productNotFound,
                message: "Product ID is empty"
            )
        }
        
        if product.price < 0 {
            return PurchaseValidationResult(
                canPurchase: false,
                error: .productNotAvailable,
                message: "Product price is invalid"
            )
        }
        
        return PurchaseValidationResult(canPurchase: true)
    }
}

// MARK: - Test Helpers

extension MockPurchaseService {
    
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
    
    /// 模拟活跃购买状态
    /// - Parameter productIDs: 商品ID数组
    public func simulateActivePurchases(_ productIDs: [String]) {
        activePurchaseProductIDs = Set(productIDs)
    }
    
    /// 创建测试交易
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - state: 交易状态
    /// - Returns: 测试交易
    public static func createTestTransaction(
        productID: String,
        state: IAPTransactionState = .purchased
    ) -> IAPTransaction {
        return IAPTransaction(
            id: "mock_tx_\(productID)_\(UUID().uuidString.prefix(8))",
            productID: productID,
            purchaseDate: Date(),
            transactionState: state,
            receiptData: "mock_receipt_data".data(using: .utf8)
        )
    }
    
    /// 创建测试收据验证结果
    /// - Parameters:
    ///   - isValid: 是否有效
    ///   - transactions: 交易数组
    /// - Returns: 测试验证结果
    public static func createTestReceiptValidationResult(
        isValid: Bool = true,
        transactions: [IAPTransaction] = []
    ) -> IAPReceiptValidationResult {
        return IAPReceiptValidationResult(
            isValid: isValid,
            transactions: transactions,
            error: nil,
            receiptCreationDate: Date(),
            appVersion: "1.0.0",
            originalAppVersion: "1.0.0",
            environment: .sandbox
        )
    }
}