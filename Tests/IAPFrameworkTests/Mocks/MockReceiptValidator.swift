import Foundation
@testable import IAPFramework

/// Mock 收据验证器，用于测试
public final class MockReceiptValidator: ReceiptValidatorProtocol, @unchecked Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的验证结果
    public var mockValidationResult: IAPReceiptValidationResult?
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    /// 模拟的收据格式验证结果
    public var mockFormatValidationResult: Bool = true
    
    // MARK: - Call Tracking
    
    /// 调用计数器
    public private(set) var callCounts: [String: Int] = [:]
    
    /// 调用参数记录
    public private(set) var callParameters: [String: Any] = [:]
    
    /// 验证的收据数据记录
    public private(set) var validatedReceiptData: [Data] = []
    
    /// 验证的订单记录
    public private(set) var validatedOrders: [IAPOrder] = []
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - ReceiptValidatorProtocol Implementation
    
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        incrementCallCount(for: "validateReceipt")
        callParameters["validateReceipt_receiptData"] = receiptData
        validatedReceiptData.append(receiptData)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        if let result = mockValidationResult {
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
    
    public func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult {
        incrementCallCount(for: "validateReceiptWithOrder")
        callParameters["validateReceiptWithOrder_receiptData"] = receiptData
        callParameters["validateReceiptWithOrder_order"] = order
        validatedReceiptData.append(receiptData)
        validatedOrders.append(order)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        // 检查订单状态
        if order.isExpired && shouldThrowError {
            throw IAPError.orderExpired
        }
        
        if order.status == .completed && shouldThrowError {
            throw IAPError.orderAlreadyCompleted
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        if let result = mockValidationResult {
            return result
        }
        
        // 默认返回有效结果，包含匹配的交易
        let matchingTransaction = IAPTransaction(
            id: UUID().uuidString,
            productID: order.productID,
            purchaseDate: Date(),
            transactionState: .purchased,
            receiptData: receiptData,
            originalTransactionID: nil,
            quantity: 1
        )
        
        return IAPReceiptValidationResult(
            isValid: true,
            transactions: [matchingTransaction],
            receiptCreationDate: Date(),
            appVersion: "1.0.0",
            originalAppVersion: "1.0.0",
            environment: .sandbox
        )
    }
    
    public func isReceiptFormatValid(_ receiptData: Data) -> Bool {
        incrementCallCount(for: "isReceiptFormatValid")
        callParameters["isReceiptFormatValid_receiptData"] = receiptData
        
        return mockFormatValidationResult
    }
    
    // MARK: - Mock Configuration Methods
    
    /// 设置模拟验证结果
    /// - Parameter result: 验证结果
    public func setMockValidationResult(_ result: IAPReceiptValidationResult) {
        mockValidationResult = result
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
    
    /// 设置模拟格式验证结果
    /// - Parameter isValid: 是否有效
    public func setMockFormatValidationResult(_ isValid: Bool) {
        mockFormatValidationResult = isValid
    }
    
    // MARK: - Test Helper Methods
    
    /// 重置所有模拟数据
    public func reset() {
        mockValidationResult = nil
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        mockFormatValidationResult = true
        callCounts.removeAll()
        callParameters.removeAll()
        validatedReceiptData.removeAll()
        validatedOrders.removeAll()
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
    
    /// 获取所有验证过的收据数据
    /// - Returns: 收据数据列表
    public func getAllValidatedReceiptData() -> [Data] {
        return validatedReceiptData
    }
    
    /// 获取最后验证的收据数据
    /// - Returns: 收据数据
    public func getLastValidatedReceiptData() -> Data? {
        return validatedReceiptData.last
    }
    
    /// 获取调用统计信息
    /// - Returns: 调用统计
    public func getCallStatistics() -> [String: Int] {
        return callCounts
    }
    
    /// 获取所有验证过的订单
    /// - Returns: 订单列表
    public func getAllValidatedOrders() -> [IAPOrder] {
        return validatedOrders
    }
    
    /// 获取最后验证的订单
    /// - Returns: 订单
    public func getLastValidatedOrder() -> IAPOrder? {
        return validatedOrders.last
    }
    
    /// 检查是否验证过特定订单
    /// - Parameter orderID: 订单ID
    /// - Returns: 是否验证过
    public func wasOrderValidated(_ orderID: String) -> Bool {
        return validatedOrders.contains { $0.id == orderID }
    }
    
    /// 检查是否验证过特定商品的订单
    /// - Parameter productID: 商品ID
    /// - Returns: 是否验证过
    public func wasProductOrderValidated(_ productID: String) -> Bool {
        return validatedOrders.contains { $0.productID == productID }
    }
    
    // MARK: - Private Methods
    
    private func incrementCallCount(for method: String) {
        callCounts[method, default: 0] += 1
    }
}

// MARK: - Convenience Factory Methods

extension MockReceiptValidator {
    
    /// 创建总是返回有效结果的 Mock 验证器
    /// - Returns: Mock 验证器
    public static func alwaysValid() -> MockReceiptValidator {
        let validator = MockReceiptValidator()
        validator.setMockValidationResult(
            IAPReceiptValidationResult(
                isValid: true,
                transactions: [],
                receiptCreationDate: Date(),
                appVersion: "1.0.0",
                originalAppVersion: "1.0.0",
                environment: .sandbox
            )
        )
        return validator
    }
    
    /// 创建总是返回无效结果的 Mock 验证器
    /// - Returns: Mock 验证器
    public static func alwaysInvalid() -> MockReceiptValidator {
        let validator = MockReceiptValidator()
        validator.setMockValidationResult(
            IAPReceiptValidationResult(
                isValid: false,
                error: .receiptValidationFailed
            )
        )
        return validator
    }
    
    /// 创建会抛出错误的 Mock 验证器
    /// - Parameter error: 错误
    /// - Returns: Mock 验证器
    public static func withError(_ error: IAPError) -> MockReceiptValidator {
        let validator = MockReceiptValidator()
        validator.setMockError(error, shouldThrow: true)
        return validator
    }
    
    /// 创建带有延迟的 Mock 验证器
    /// - Parameter delay: 延迟时间（秒）
    /// - Returns: Mock 验证器
    public static func withDelay(_ delay: TimeInterval) -> MockReceiptValidator {
        let validator = MockReceiptValidator()
        validator.setMockDelay(delay)
        return validator
    }
    
    /// 创建带有特定交易的 Mock 验证器
    /// - Parameter transactions: 交易列表
    /// - Returns: Mock 验证器
    public static func withTransactions(_ transactions: [IAPTransaction]) -> MockReceiptValidator {
        let validator = MockReceiptValidator()
        validator.setMockValidationResult(
            IAPReceiptValidationResult(
                isValid: true,
                transactions: transactions,
                receiptCreationDate: Date(),
                appVersion: "1.0.0",
                originalAppVersion: "1.0.0",
                environment: .sandbox
            )
        )
        return validator
    }
}

// MARK: - Test Scenario Builders

extension MockReceiptValidator {
    
    /// 配置成功验证场景
    /// - Parameters:
    ///   - transactions: 交易列表
    ///   - environment: 收据环境
    public func configureSuccessfulValidation(
        transactions: [IAPTransaction] = [],
        environment: ReceiptEnvironment = .sandbox
    ) {
        setMockValidationResult(
            IAPReceiptValidationResult(
                isValid: true,
                transactions: transactions,
                receiptCreationDate: Date(),
                appVersion: "1.0.0",
                originalAppVersion: "1.0.0",
                environment: environment
            )
        )
    }
    
    /// 配置失败验证场景
    /// - Parameter error: 错误
    public func configureFailedValidation(error: IAPError = .receiptValidationFailed) {
        setMockValidationResult(
            IAPReceiptValidationResult(
                isValid: false,
                error: error
            )
        )
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
    
    /// 配置无效收据格式场景
    public func configureInvalidFormat() {
        setMockFormatValidationResult(false)
        setMockError(.invalidReceiptData, shouldThrow: true)
    }
    
    /// 配置服务器验证失败场景
    /// - Parameter statusCode: HTTP 状态码
    public func configureServerValidationFailure(statusCode: Int = 500) {
        setMockError(.serverValidationFailed(statusCode: statusCode), shouldThrow: true)
    }
    
    /// 配置订单过期场景
    public func configureOrderExpired() {
        setMockError(.orderExpired, shouldThrow: true)
    }
    
    /// 配置订单已完成场景
    public func configureOrderAlreadyCompleted() {
        setMockError(.orderAlreadyCompleted, shouldThrow: true)
    }
    
    /// 配置订单验证失败场景
    public func configureOrderValidationFailed() {
        setMockError(.orderValidationFailed, shouldThrow: true)
    }
    
    /// 配置服务器订单不匹配场景
    public func configureServerOrderMismatch() {
        setMockError(.serverOrderMismatch, shouldThrow: true)
    }
    
    /// 配置成功的订单验证场景
    /// - Parameters:
    ///   - order: 订单信息
    ///   - environment: 收据环境
    public func configureSuccessfulOrderValidation(
        for order: IAPOrder,
        environment: ReceiptEnvironment = .sandbox
    ) {
        let matchingTransaction = IAPTransaction(
            id: UUID().uuidString,
            productID: order.productID,
            purchaseDate: Date(),
            transactionState: .purchased,
            receiptData: nil,
            originalTransactionID: nil,
            quantity: 1
        )
        
        setMockValidationResult(
            IAPReceiptValidationResult(
                isValid: true,
                transactions: [matchingTransaction],
                receiptCreationDate: Date(),
                appVersion: "1.0.0",
                originalAppVersion: "1.0.0",
                environment: environment
            )
        )
    }
}