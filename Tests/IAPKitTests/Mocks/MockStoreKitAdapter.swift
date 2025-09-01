import Foundation
@testable import IAPKit

/// Mock StoreKit 适配器，用于测试
public final class MockStoreKitAdapter: StoreKitAdapterProtocol, @unchecked Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的商品列表
    public var mockProducts: [IAPProduct] = []
    
    /// 模拟的购买结果
    public var mockPurchaseResult: IAPPurchaseResult?
    
    /// 模拟的恢复购买结果
    public var mockRestoreResult: [IAPTransaction] = []
    
    /// 模拟的未完成交易
    public var mockPendingTransactions: [IAPTransaction] = []
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    // MARK: - Call Tracking
    
    /// 调用计数器
    private let callCountsLock = NSLock()
    private var _callCounts: [String: Int] = [:]
    public var callCounts: [String: Int] {
        callCountsLock.lock()
        defer { callCountsLock.unlock() }
        return _callCounts
    }
    
    /// 调用参数记录
    private let callParametersLock = NSLock()
    private var _callParameters: [String: Any] = [:]
    public var callParameters: [String: Any] {
        callParametersLock.lock()
        defer { callParametersLock.unlock() }
        return _callParameters
    }
    
    /// 交易观察者是否活跃
    public private(set) var isTransactionObserverActive: Bool = false
    
    /// 交易更新处理器
    public var transactionUpdateHandler: ((IAPTransaction) -> Void)?
    
    /// 订单关联的交易映射
    public private(set) var orderTransactionMapping: [String: String] = [:]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - StoreKitAdapterProtocol Implementation
    
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        incrementCallCount(for: "loadProducts")
        setCallParameter("loadProducts_productIDs", value: productIDs)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // 返回匹配的商品
        let matchingProducts = mockProducts.filter { productIDs.contains($0.id) }
        return matchingProducts
    }
    
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        incrementCallCount(for: "purchase")
        setCallParameter("purchase_product", value: product)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        if let result = mockPurchaseResult {
            return result
        }
        
        // 默认返回成功结果，包含订单信息
        let transaction = IAPTransaction.successful(
            id: "mock_tx_\(UUID().uuidString)",
            productID: product.id
        )
        let order = IAPOrder.created(
            id: "mock_order_\(UUID().uuidString)",
            productID: product.id
        )
        return .success(transaction, order)
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
    
    public func startTransactionObserver() async {
        incrementCallCount(for: "startTransactionObserver")
        isTransactionObserverActive = true
    }
    
    public func stopTransactionObserver() {
        incrementCallCount(for: "stopTransactionObserver")
        isTransactionObserverActive = false
    }
    
    public func getPendingTransactions() async -> [IAPTransaction] {
        incrementCallCount(for: "getPendingTransactions")
        return mockPendingTransactions
    }
    
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        incrementCallCount(for: "finishTransaction")
        setCallParameter("finishTransaction_transaction", value: transaction)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // 从未完成交易中移除
        mockPendingTransactions.removeAll { $0.id == transaction.id }
    }
    
    // MARK: - Mock Configuration Methods
    
    /// 设置模拟商品
    /// - Parameter products: 商品列表
    public func setMockProducts(_ products: [IAPProduct]) {
        mockProducts = products
    }
    
    /// 添加模拟商品
    /// - Parameter product: 商品
    public func addMockProduct(_ product: IAPProduct) {
        mockProducts.append(product)
    }
    
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
    
    /// 设置模拟未完成交易
    /// - Parameter transactions: 交易列表
    public func setMockPendingTransactions(_ transactions: [IAPTransaction]) async {
        mockPendingTransactions = transactions
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
    
    /// 模拟交易更新
    /// - Parameter transaction: 交易
    public func simulateTransactionUpdate(_ transaction: IAPTransaction) {
        transactionUpdateHandler?(transaction)
    }
    
    /// 关联订单和交易
    /// - Parameters:
    ///   - orderID: 订单ID
    ///   - transactionID: 交易ID
    public func associateOrderWithTransaction(orderID: String, transactionID: String) {
        orderTransactionMapping[orderID] = transactionID
    }
    
    /// 获取订单关联的交易ID
    /// - Parameter orderID: 订单ID
    /// - Returns: 交易ID（如果存在）
    public func getTransactionID(for orderID: String) -> String? {
        return orderTransactionMapping[orderID]
    }
    
    /// 获取交易关联的订单ID
    /// - Parameter transactionID: 交易ID
    /// - Returns: 订单ID（如果存在）
    public func getOrderID(for transactionID: String) -> String? {
        return orderTransactionMapping.first { $0.value == transactionID }?.key
    }
    
    /// 模拟多个交易更新
    /// - Parameter transactions: 交易列表
    public func simulateTransactionUpdates(_ transactions: [IAPTransaction]) {
        for transaction in transactions {
            simulateTransactionUpdate(transaction)
        }
    }
    
    // MARK: - Test Helper Methods
    
    /// 重置所有模拟数据
    public func reset() {
        mockProducts.removeAll()
        mockPurchaseResult = nil
        mockRestoreResult.removeAll()
        mockPendingTransactions.removeAll()
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        
        callCountsLock.lock()
        _callCounts.removeAll()
        callCountsLock.unlock()
        
        callParametersLock.lock()
        _callParameters.removeAll()
        callParametersLock.unlock()
        
        isTransactionObserverActive = false
        transactionUpdateHandler = nil
        orderTransactionMapping.removeAll()
    }
    
    /// 获取方法调用次数
    /// - Parameter method: 方法名
    /// - Returns: 调用次数
    public func getCallCount(for method: String) -> Int {
        callCountsLock.lock()
        defer { callCountsLock.unlock() }
        return _callCounts[method] ?? 0
    }
    
    /// 获取方法调用参数
    /// - Parameter method: 方法名
    /// - Returns: 调用参数
    public func getCallParameters(for method: String) -> Any? {
        callParametersLock.lock()
        defer { callParametersLock.unlock() }
        return _callParameters[method]
    }
    
    /// 检查方法是否被调用
    /// - Parameter method: 方法名
    /// - Returns: 是否被调用
    public func wasCalled(_ method: String) -> Bool {
        return getCallCount(for: method) > 0
    }
    
    /// 获取所有调用的方法名
    /// - Returns: 方法名列表
    public func getAllCalledMethods() -> [String] {
        callCountsLock.lock()
        defer { callCountsLock.unlock() }
        return Array(_callCounts.keys)
    }
    
    /// 获取调用统计信息
    /// - Returns: 调用统计
    public func getCallStatistics() -> [String: Int] {
        callCountsLock.lock()
        defer { callCountsLock.unlock() }
        return _callCounts
    }
    
    // MARK: - Private Methods
    
    private func incrementCallCount(for method: String) {
        callCountsLock.lock()
        defer { callCountsLock.unlock() }
        _callCounts[method, default: 0] += 1
    }
    
    private func setCallParameter(_ key: String, value: Any) {
        callParametersLock.lock()
        defer { callParametersLock.unlock() }
        _callParameters[key] = value
    }
}

// MARK: - Convenience Factory Methods

extension MockStoreKitAdapter {
    
    /// 创建带有预设商品的 Mock 适配器
    /// - Parameter products: 商品列表
    /// - Returns: Mock 适配器
    public static func withProducts(_ products: [IAPProduct]) -> MockStoreKitAdapter {
        let adapter = MockStoreKitAdapter()
        adapter.setMockProducts(products)
        return adapter
    }
    
    /// 创建会抛出错误的 Mock 适配器
    /// - Parameter error: 错误
    /// - Returns: Mock 适配器
    public static func withError(_ error: IAPError) -> MockStoreKitAdapter {
        let adapter = MockStoreKitAdapter()
        adapter.setMockError(error, shouldThrow: true)
        return adapter
    }
    
    /// 创建带有延迟的 Mock 适配器
    /// - Parameter delay: 延迟时间（秒）
    /// - Returns: Mock 适配器
    public static func withDelay(_ delay: TimeInterval) -> MockStoreKitAdapter {
        let adapter = MockStoreKitAdapter()
        adapter.setMockDelay(delay)
        return adapter
    }
    
    /// 创建带有未完成交易的 Mock 适配器
    /// - Parameter transactions: 未完成交易列表
    /// - Returns: Mock 适配器
    public static func withPendingTransactions(_ transactions: [IAPTransaction]) -> MockStoreKitAdapter {
        let adapter = MockStoreKitAdapter()
        Task {
            await adapter.setMockPendingTransactions(transactions)
        }
        return adapter
    }
}

// MARK: - Test Scenario Builders

extension MockStoreKitAdapter {
    
    /// 配置成功购买场景
    /// - Parameter product: 商品
    public func configureSuccessfulPurchase(for product: IAPProduct) {
        let transaction = IAPTransaction.successful(
            id: "success_tx_\(product.id)",
            productID: product.id
        )
        let order = IAPOrder.created(
            id: "success_order_\(product.id)",
            productID: product.id
        )
        setMockPurchaseResult(.success(transaction, order))
        associateOrderWithTransaction(orderID: order.id, transactionID: transaction.id)
    }
    
    /// 配置取消购买场景
    /// - Parameter order: 关联的订单（可选）
    public func configureCancelledPurchase(order: IAPOrder? = nil) {
        let defaultOrder = order ?? IAPOrder.created(
            id: "cancelled_order_\(UUID().uuidString)",
            productID: "test_product"
        )
        setMockPurchaseResult(.cancelled(defaultOrder))
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
}