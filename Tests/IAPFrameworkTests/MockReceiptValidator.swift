import Foundation

/// Mock 收据验证器状态管理器
@globalActor
public actor MockReceiptValidatorActor {
    public static let shared = MockReceiptValidatorActor()
    
    private var mockValidationResult: IAPReceiptValidationResult?
    private var mockError: IAPError?
    private var mockDelay: TimeInterval = 0
    private var shouldThrowError: Bool = false
    private var callHistory: [String] = []
    private var validateCallCount: Int = 0
    private var lastValidatedReceiptData: Data?
    private var validationCache: [String: IAPReceiptValidationResult] = [:]
    
    public func setMockValidationResult(_ result: IAPReceiptValidationResult?) {
        mockValidationResult = result
    }
    
    public func getMockValidationResult() -> IAPReceiptValidationResult? {
        return mockValidationResult
    }
    
    public func setMockError(_ error: IAPError?) {
        mockError = error
        shouldThrowError = error != nil
    }
    
    public func getMockError() -> IAPError? {
        return mockError
    }
    
    public func getShouldThrowError() -> Bool {
        return shouldThrowError
    }
    
    public func setMockDelay(_ delay: TimeInterval) {
        mockDelay = delay
    }
    
    public func getMockDelay() -> TimeInterval {
        return mockDelay
    }
    
    public func addCallHistory(_ call: String) {
        callHistory.append(call)
    }
    
    public func getCallHistory() -> [String] {
        return callHistory
    }
    
    public func incrementValidateCallCount() {
        validateCallCount += 1
    }
    
    public func getValidateCallCount() -> Int {
        return validateCallCount
    }
    
    public func setLastValidatedReceiptData(_ data: Data?) {
        lastValidatedReceiptData = data
    }
    
    public func getLastValidatedReceiptData() -> Data? {
        return lastValidatedReceiptData
    }
    
    public func getCachedResult(for key: String) -> IAPReceiptValidationResult? {
        return validationCache[key]
    }
    
    public func setCachedResult(_ result: IAPReceiptValidationResult, for key: String) {
        validationCache[key] = result
    }
    
    public func reset() {
        mockValidationResult = nil
        mockError = nil
        mockDelay = 0
        shouldThrowError = false
        callHistory.removeAll()
        validateCallCount = 0
        lastValidatedReceiptData = nil
        validationCache.removeAll()
    }
}

/// Mock 收据验证器，用于测试
public final class MockReceiptValidator: ReceiptValidatorProtocol, Sendable {
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Mock Configuration
    
    /// 设置模拟的验证结果
    /// - Parameter result: 验证结果
    public func setMockValidationResult(_ result: IAPReceiptValidationResult?) async {
        await MockReceiptValidatorActor.shared.setMockValidationResult(result)
    }
    
    /// 设置模拟错误
    /// - Parameter error: 错误
    public func setMockError(_ error: IAPError?) async {
        await MockReceiptValidatorActor.shared.setMockError(error)
    }
    
    /// 设置模拟延迟
    /// - Parameter delay: 延迟时间（秒）
    public func setMockDelay(_ delay: TimeInterval) async {
        await MockReceiptValidatorActor.shared.setMockDelay(delay)
    }
    
    /// 重置所有状态
    public func reset() async {
        await MockReceiptValidatorActor.shared.reset()
    }
    
    // MARK: - Mock Data Access
    
    /// 获取调用历史
    public var callHistory: [String] {
        get async {
            return await MockReceiptValidatorActor.shared.getCallHistory()
        }
    }
    
    /// 获取验证调用次数
    public var validateCallCount: Int {
        get async {
            return await MockReceiptValidatorActor.shared.getValidateCallCount()
        }
    }
    
    /// 获取最后验证的收据数据
    public var lastValidatedReceiptData: Data? {
        get async {
            return await MockReceiptValidatorActor.shared.getLastValidatedReceiptData()
        }
    }
    
    // MARK: - ReceiptValidatorProtocol Implementation
    
    /// 检查收据格式是否有效
    /// - Parameter receiptData: 收据数据
    /// - Returns: 是否有效
    public func isReceiptFormatValid(_ receiptData: Data) -> Bool {
        // Mock 实现总是返回 true
        return !receiptData.isEmpty
    }
    
    /// 验证收据
    /// - Parameter receiptData: 收据数据
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        // 记录调用
        await MockReceiptValidatorActor.shared.addCallHistory("validateReceipt(\(receiptData.count) bytes)")
        await MockReceiptValidatorActor.shared.incrementValidateCallCount()
        await MockReceiptValidatorActor.shared.setLastValidatedReceiptData(receiptData)
        
        // 模拟延迟
        let delay = await MockReceiptValidatorActor.shared.getMockDelay()
        if delay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(delay))
            } else {
                // 对于更早的版本，使用 nanoseconds
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // 检查是否应该抛出错误
        if await MockReceiptValidatorActor.shared.getShouldThrowError() {
            if let error = await MockReceiptValidatorActor.shared.getMockError() {
                throw error
            }
        }
        
        // 检查是否有特定收据的缓存结果
        let key = receiptData.base64EncodedString()
        if let cachedResult = await MockReceiptValidatorActor.shared.getCachedResult(for: key) {
            return cachedResult
        }
        
        // 返回模拟结果或默认成功结果
        if let mockResult = await MockReceiptValidatorActor.shared.getMockValidationResult() {
            // 缓存结果
            await MockReceiptValidatorActor.shared.setCachedResult(mockResult, for: key)
            return mockResult
        } else {
            // 创建默认的成功验证结果
            let defaultResult = IAPReceiptValidationResult(
                isValid: true,
                transactions: [
                    IAPTransaction.successful(
                        id: UUID().uuidString,
                        productID: "mock.product"
                    )
                ],
                error: nil,
                receiptCreationDate: Date(),
                appVersion: "1.0",
                originalAppVersion: "1.0",
                environment: .sandbox
            )
            
            // 缓存默认结果
            await MockReceiptValidatorActor.shared.setCachedResult(defaultResult, for: key)
            return defaultResult
        }
    }
    
    // MARK: - Test Utilities
    
    /// 设置特定收据的验证结果
    /// - Parameters:
    ///   - result: 验证结果
    ///   - receiptData: 收据数据
    public func setCachedResult(_ result: IAPReceiptValidationResult, for receiptData: Data) async {
        let key = receiptData.base64EncodedString()
        await MockReceiptValidatorActor.shared.setCachedResult(result, for: key)
    }
    
    /// 模拟验证失败
    /// - Parameter error: 失败错误
    public func simulateValidationFailure(_ error: IAPError) async {
        await setMockError(error)
    }
    
    /// 模拟验证成功
    /// - Parameter transactions: 交易列表
    public func simulateValidationSuccess(transactions: [IAPTransaction] = []) async {
        let result = IAPReceiptValidationResult(
            isValid: true,
            transactions: transactions.isEmpty ? [
                IAPTransaction.successful(
                    id: UUID().uuidString,
                    productID: "mock.product"
                )
            ] : transactions,
            error: nil,
            receiptCreationDate: Date(),
            appVersion: "1.0",
            originalAppVersion: "1.0",
            environment: .sandbox
        )
        
        await setMockValidationResult(result)
        await setMockError(nil)
    }
}

// MARK: - Convenience Extensions

extension MockReceiptValidator {
    
    /// 创建用于测试的 Mock 验证器
    /// - Parameters:
    ///   - shouldSucceed: 是否应该成功
    ///   - delay: 模拟延迟
    /// - Returns: 配置好的 Mock 验证器
    public static func createForTesting(
        shouldSucceed: Bool = true,
        delay: TimeInterval = 0
    ) async -> MockReceiptValidator {
        let validator = MockReceiptValidator()
        
        await validator.setMockDelay(delay)
        
        if shouldSucceed {
            await validator.simulateValidationSuccess()
        } else {
            await validator.simulateValidationFailure(.receiptValidationFailed)
        }
        
        return validator
    }
}
