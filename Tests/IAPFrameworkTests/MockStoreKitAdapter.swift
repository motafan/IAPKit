import Foundation
@testable import IAPFramework

/// Mock StoreKit 适配器状态管理器
@globalActor
public actor MockStoreKitAdapterActor {
    public static let shared = MockStoreKitAdapterActor()
    
    private var mockProducts: [IAPProduct] = []
    private var mockPurchaseResult: IAPPurchaseResult?
    private var mockRestoreResult: [IAPTransaction] = []
    private var mockError: IAPError?
    private var mockDelay: TimeInterval = 0
    private var shouldThrowError: Bool = false
    private var callHistory: [String] = []
    private var loadProductsCallCount: Int = 0
    private var purchaseCallCount: Int = 0
    private var restoreCallCount: Int = 0
    private var finishTransactionCallCount: Int = 0
    private var isObserverActive: Bool = false
    private var mockPendingTransactions: [IAPTransaction] = []
    private var shouldFailFinishTransaction: Bool = false
    
    public func setMockProducts(_ products: [IAPProduct]) {
        mockProducts = products
    }
    
    public func getMockProducts() -> [IAPProduct] {
        return mockProducts
    }
    
    public func setMockPurchaseResult(_ result: IAPPurchaseResult?) {
        mockPurchaseResult = result
    }
    
    public func getMockPurchaseResult() -> IAPPurchaseResult? {
        return mockPurchaseResult
    }
    
    public func setMockRestoreResult(_ transactions: [IAPTransaction]) {
        mockRestoreResult = transactions
    }
    
    public func getMockRestoreResult() -> [IAPTransaction] {
        return mockRestoreResult
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
    
    public func incrementLoadProductsCallCount() {
        loadProductsCallCount += 1
    }
    
    public func getLoadProductsCallCount() -> Int {
        return loadProductsCallCount
    }
    
    public func incrementPurchaseCallCount() {
        purchaseCallCount += 1
    }
    
    public func getPurchaseCallCount() -> Int {
        return purchaseCallCount
    }
    
    public func incrementRestoreCallCount() {
        restoreCallCount += 1
    }
    
    public func getRestoreCallCount() -> Int {
        return restoreCallCount
    }
    
    public func incrementFinishTransactionCallCount() {
        finishTransactionCallCount += 1
    }
    
    public func getFinishTransactionCallCount() -> Int {
        return finishTransactionCallCount
    }
    
    public func setObserverActive(_ active: Bool) {
        isObserverActive = active
    }
    
    public func getObserverActive() -> Bool {
        return isObserverActive
    }
    
    public func setMockPendingTransactions(_ transactions: [IAPTransaction]) {
        mockPendingTransactions = transactions
    }
    
    public func getMockPendingTransactions() -> [IAPTransaction] {
        return mockPendingTransactions
    }
    
    public func setShouldFailFinishTransaction(_ shouldFail: Bool) {
        shouldFailFinishTransaction = shouldFail
    }
    
    public func getShouldFailFinishTransaction() -> Bool {
        return shouldFailFinishTransaction
    }
    
    public func reset() {
        mockProducts.removeAll()
        mockPurchaseResult = nil
        mockRestoreResult.removeAll()
        mockError = nil
        mockDelay = 0
        shouldThrowError = false
        callHistory.removeAll()
        loadProductsCallCount = 0
        purchaseCallCount = 0
        restoreCallCount = 0
        finishTransactionCallCount = 0
        isObserverActive = false
        mockPendingTransactions.removeAll()
        shouldFailFinishTransaction = false
    }
}

/// Mock StoreKit 适配器，用于测试
public final class MockStoreKitAdapter: StoreKitAdapterProtocol, Sendable {
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Mock Configuration
    
    /// 设置模拟商品
    /// - Parameter products: 商品数组
    public func setMockProducts(_ products: [IAPProduct]) async {
        await MockStoreKitAdapterActor.shared.setMockProducts(products)
    }
    
    /// 设置模拟购买结果
    /// - Parameter result: 购买结果
    public func setMockPurchaseResult(_ result: IAPPurchaseResult?) async {
        await MockStoreKitAdapterActor.shared.setMockPurchaseResult(result)
    }
    
    /// 设置模拟恢复购买结果
    /// - Parameter transactions: 交易数组
    public func setMockRestoreResult(_ transactions: [IAPTransaction]) async {
        await MockStoreKitAdapterActor.shared.setMockRestoreResult(transactions)
    }
    
    /// 设置模拟错误
    /// - Parameter error: 错误
    public func setMockError(_ error: IAPError?) async {
        await MockStoreKitAdapterActor.shared.setMockError(error)
    }
    
    /// 设置模拟延迟
    /// - Parameter delay: 延迟时间（秒）
    public func setMockDelay(_ delay: TimeInterval) async {
        await MockStoreKitAdapterActor.shared.setMockDelay(delay)
    }
    
    /// 重置所有状态
    public func reset() async {
        await MockStoreKitAdapterActor.shared.reset()
    }
    
    // MARK: - Mock Data Access
    
    /// 获取调用历史
    public var callHistory: [String] {
        get async {
            return await MockStoreKitAdapterActor.shared.getCallHistory()
        }
    }
    
    /// 获取加载商品调用次数
    public var loadProductsCallCount: Int {
        get async {
            return await MockStoreKitAdapterActor.shared.getLoadProductsCallCount()
        }
    }
    
    /// 获取购买调用次数
    public var purchaseCallCount: Int {
        get async {
            return await MockStoreKitAdapterActor.shared.getPurchaseCallCount()
        }
    }
    
    /// 获取恢复购买调用次数
    public var restoreCallCount: Int {
        get async {
            return await MockStoreKitAdapterActor.shared.getRestoreCallCount()
        }
    }
    
    /// 获取完成交易调用次数
    public var finishTransactionCallCount: Int {
        get async {
            return await MockStoreKitAdapterActor.shared.getFinishTransactionCallCount()
        }
    }
    
    /// 获取观察器是否活跃
    public var isObserverActive: Bool {
        get async {
            return await MockStoreKitAdapterActor.shared.getObserverActive()
        }
    }
    
    // MARK: - StoreKitAdapterProtocol Implementation
    
    /// 加载商品信息
    /// - Parameter productIDs: 商品ID集合
    /// - Returns: 商品信息数组
    /// - Throws: IAPError 相关错误
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        await MockStoreKitAdapterActor.shared.addCallHistory("loadProducts(\(productIDs))")
        await MockStoreKitAdapterActor.shared.incrementLoadProductsCallCount()
        
        // 模拟延迟
        let delay = await MockStoreKitAdapterActor.shared.getMockDelay()
        if delay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(delay))
            } else {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // 检查是否应该抛出错误
        if await MockStoreKitAdapterActor.shared.getShouldThrowError() {
            if let error = await MockStoreKitAdapterActor.shared.getMockError() {
                throw error
            }
        }
        
        // 返回匹配的商品
        let allProducts = await MockStoreKitAdapterActor.shared.getMockProducts()
        return allProducts.filter { productIDs.contains($0.id) }
    }
    
    /// 购买商品
    /// - Parameter product: 要购买的商品
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        await MockStoreKitAdapterActor.shared.addCallHistory("purchase(\(product.id))")
        await MockStoreKitAdapterActor.shared.incrementPurchaseCallCount()
        
        // 模拟延迟
        let delay = await MockStoreKitAdapterActor.shared.getMockDelay()
        if delay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(delay))
            } else {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // 检查是否应该抛出错误
        if await MockStoreKitAdapterActor.shared.getShouldThrowError() {
            if let error = await MockStoreKitAdapterActor.shared.getMockError() {
                throw error
            }
        }
        
        // 返回模拟结果或默认成功结果
        if let result = await MockStoreKitAdapterActor.shared.getMockPurchaseResult() {
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
        await MockStoreKitAdapterActor.shared.addCallHistory("restorePurchases()")
        await MockStoreKitAdapterActor.shared.incrementRestoreCallCount()
        
        // 模拟延迟
        let delay = await MockStoreKitAdapterActor.shared.getMockDelay()
        if delay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(delay))
            } else {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // 检查是否应该抛出错误
        if await MockStoreKitAdapterActor.shared.getShouldThrowError() {
            if let error = await MockStoreKitAdapterActor.shared.getMockError() {
                throw error
            }
        }
        
        return await MockStoreKitAdapterActor.shared.getMockRestoreResult()
    }
    
    /// 完成交易
    /// - Parameter transaction: 要完成的交易
    /// - Throws: IAPError 相关错误
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        await MockStoreKitAdapterActor.shared.addCallHistory("finishTransaction(\(transaction.id))")
        await MockStoreKitAdapterActor.shared.incrementFinishTransactionCallCount()
        
        // 模拟延迟
        let delay = await MockStoreKitAdapterActor.shared.getMockDelay()
        if delay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try await Task.sleep(for: .seconds(delay))
            } else {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // 检查是否应该抛出错误（包括特定的完成交易错误）
        let shouldFailFinish = await MockStoreKitAdapterActor.shared.getShouldFailFinishTransaction()
        let shouldThrowError = await MockStoreKitAdapterActor.shared.getShouldThrowError()
        
        if shouldFailFinish || shouldThrowError {
            if let error = await MockStoreKitAdapterActor.shared.getMockError() {
                throw error
            }
        }
        
        // Mock 实现不需要实际完成交易
    }
    
    /// 开始交易观察器
    public func startTransactionObserver() async {
        await MockStoreKitAdapterActor.shared.addCallHistory("startTransactionObserver()")
        await MockStoreKitAdapterActor.shared.setObserverActive(true)
        
        // 模拟延迟
        let delay = await MockStoreKitAdapterActor.shared.getMockDelay()
        if delay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try? await Task.sleep(for: .seconds(delay))
            } else {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    /// 停止交易观察器
    public func stopTransactionObserver() {
        Task {
            await MockStoreKitAdapterActor.shared.addCallHistory("stopTransactionObserver()")
            await MockStoreKitAdapterActor.shared.setObserverActive(false)
        }
    }
    
    /// 获取未完成的交易
    /// - Returns: 未完成的交易数组
    public func getPendingTransactions() async -> [IAPTransaction] {
        await MockStoreKitAdapterActor.shared.addCallHistory("getPendingTransactions()")
        
        // 模拟延迟
        let delay = await MockStoreKitAdapterActor.shared.getMockDelay()
        if delay > 0 {
            if #available(iOS 16.0, macOS 13.0, *) {
                try? await Task.sleep(for: .seconds(delay))
            } else {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        return await MockStoreKitAdapterActor.shared.getMockPendingTransactions()
    }
    
    // MARK: - Test Utilities
    
    /// 设置未完成的交易
    /// - Parameter transactions: 交易数组
    public func setMockPendingTransactions(_ transactions: [IAPTransaction]) async {
        await MockStoreKitAdapterActor.shared.setMockPendingTransactions(transactions)
    }
    
    /// 设置完成交易是否应该失败
    /// - Parameter shouldFail: 是否应该失败
    public func setShouldFailFinishTransaction(_ shouldFail: Bool) async {
        await MockStoreKitAdapterActor.shared.setShouldFailFinishTransaction(shouldFail)
    }
    
    /// 验证是否调用了指定方法
    /// - Parameter methodName: 方法名
    /// - Returns: 是否调用过
    public func wasMethodCalled(_ methodName: String) async -> Bool {
        let history = await MockStoreKitAdapterActor.shared.getCallHistory()
        return history.contains { $0.contains(methodName) }
    }
    
    /// 获取指定方法的调用次数
    /// - Parameter methodName: 方法名
    /// - Returns: 调用次数
    public func getCallCount(for methodName: String) async -> Int {
        let history = await MockStoreKitAdapterActor.shared.getCallHistory()
        return history.filter { $0.contains(methodName) }.count
    }
    
    /// 获取最后一次方法调用
    /// - Returns: 最后一次调用的方法名
    public func getLastCall() async -> String? {
        let history = await MockStoreKitAdapterActor.shared.getCallHistory()
        return history.last
    }
    
    /// 模拟交易更新（用于测试）
    /// - Parameter transaction: 更新的交易
    public func simulateTransactionUpdate(_ transaction: IAPTransaction) {
        // 这个方法用于测试中模拟交易更新
        // 在实际的适配器中，这会通过系统回调触发
    }
    
    /// 设置未完成交易的便利方法（同步版本，用于测试）
    /// - Parameter transactions: 交易数组
    public func setPendingTransactions(_ transactions: [IAPTransaction]) {
        Task {
            await setMockPendingTransactions(transactions)
        }
    }
}

// MARK: - Convenience Extensions

extension MockStoreKitAdapter {
    
    /// 创建用于测试的 Mock 适配器
    /// - Parameters:
    ///   - products: 模拟商品
    ///   - shouldSucceed: 是否应该成功
    ///   - delay: 模拟延迟
    /// - Returns: 配置好的 Mock 适配器
    public static func createForTesting(
        products: [IAPProduct] = [],
        shouldSucceed: Bool = true,
        delay: TimeInterval = 0
    ) async -> MockStoreKitAdapter {
        let adapter = MockStoreKitAdapter()
        
        await adapter.setMockProducts(products)
        await adapter.setMockDelay(delay)
        
        if !shouldSucceed {
            await adapter.setMockError(.unknownError("Test error"))
        }
        
        return adapter
    }
}
