import Foundation
@testable import IAPKit

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
    
    /// 模拟的订单创建结果
    public var mockOrderCreationResult: IAPOrder?
    
    /// 模拟的订单状态查询结果
    public var mockOrderStatusResult: IAPOrderStatus?
    
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
    
    /// 创建的订单记录
    public private(set) var createdOrders: [IAPOrder] = []
    
    /// 查询的订单ID记录
    public private(set) var queriedOrderIDs: [String] = []
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - PurchaseService Mock Methods
    
    public func purchase(_ product: IAPProduct, userInfo: [String: Any]? = nil) async throws -> IAPPurchaseResult {
        incrementCallCount(for: "purchase")
        callParameters["purchase_product"] = product
        callParameters["purchase_userInfo"] = userInfo
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
        
        // 默认返回成功结果，包含订单信息
        let transaction = IAPTransaction.successful(
            id: "mock_tx_\(UUID().uuidString)",
            productID: product.id
        )
        let order = IAPOrder.created(
            id: "mock_order_\(UUID().uuidString)",
            productID: product.id,
            userInfo: userInfo?.compactMapValues { "\($0)" }
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
    
    public func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult {
        incrementCallCount(for: "validateReceiptWithOrder")
        callParameters["validateReceiptWithOrder_receiptData"] = receiptData
        callParameters["validateReceiptWithOrder_order"] = order
        validatedReceipts.append(receiptData)
        
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
        
        if let result = mockReceiptValidationResult {
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
    
    public func createOrder(for product: IAPProduct, userInfo: [String: Any]? = nil) async throws -> IAPOrder {
        incrementCallCount(for: "createOrder")
        callParameters["createOrder_product"] = product
        callParameters["createOrder_userInfo"] = userInfo
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        let order = mockOrderCreationResult ?? IAPOrder.created(
            id: "mock_order_\(UUID().uuidString)",
            productID: product.id,
            userInfo: userInfo?.compactMapValues { "\($0)" }
        )
        
        createdOrders.append(order)
        return order
    }
    
    public func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus {
        incrementCallCount(for: "queryOrderStatus")
        callParameters["queryOrderStatus_orderID"] = orderID
        queriedOrderIDs.append(orderID)
        
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        return mockOrderStatusResult ?? .created
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
    
    /// 设置模拟订单创建结果
    /// - Parameter order: 订单
    public func setMockOrderCreationResult(_ order: IAPOrder) {
        mockOrderCreationResult = order
    }
    
    /// 设置模拟订单状态查询结果
    /// - Parameter status: 订单状态
    public func setMockOrderStatusResult(_ status: IAPOrderStatus) {
        mockOrderStatusResult = status
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
        mockOrderCreationResult = nil
        mockOrderStatusResult = nil
        callCounts.removeAll()
        callParameters.removeAll()
        purchasedProducts.removeAll()
        finishedTransactions.removeAll()
        validatedReceipts.removeAll()
        createdOrders.removeAll()
        queriedOrderIDs.removeAll()
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
    
    /// 获取所有创建的订单
    /// - Returns: 订单列表
    public func getAllCreatedOrders() -> [IAPOrder] {
        return createdOrders
    }
    
    /// 获取最后创建的订单
    /// - Returns: 订单
    public func getLastCreatedOrder() -> IAPOrder? {
        return createdOrders.last
    }
    
    /// 获取所有查询的订单ID
    /// - Returns: 订单ID列表
    public func getAllQueriedOrderIDs() -> [String] {
        return queriedOrderIDs
    }
    
    /// 检查是否创建过特定商品的订单
    /// - Parameter productID: 商品ID
    /// - Returns: 是否创建过
    public func wasOrderCreated(for productID: String) -> Bool {
        return createdOrders.contains { $0.productID == productID }
    }
    
    /// 检查是否查询过特定订单状态
    /// - Parameter orderID: 订单ID
    /// - Returns: 是否查询过
    public func wasOrderStatusQueried(_ orderID: String) -> Bool {
        return queriedOrderIDs.contains(orderID)
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
        let order = IAPOrder.created(
            id: "success_order",
            productID: "test_product"
        )
        service.setMockPurchaseResult(.success(transaction, order))
        return service
    }
    
    /// 创建总是取消购买的 Mock 服务
    /// - Returns: Mock 服务
    public static func alwaysCancelled() -> MockPurchaseService {
        let service = MockPurchaseService()
        let order = IAPOrder.created(
            id: "cancelled_order",
            productID: "test_product"
        )
        service.setMockPurchaseResult(.cancelled(order))
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
        let order = IAPOrder.created(
            id: "success_order_\(product.id)",
            productID: product.id
        )
        setMockPurchaseResult(.success(transaction, order))
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
    
    /// 配置订单创建场景
    /// - Parameters:
    ///   - order: 要创建的订单
    ///   - shouldSucceed: 是否应该成功
    public func configureOrderCreation(order: IAPOrder? = nil, shouldSucceed: Bool = true) {
        if shouldSucceed {
            let defaultOrder = order ?? IAPOrder.created(
                id: "mock_order_\(UUID().uuidString)",
                productID: "test_product"
            )
            setMockOrderCreationResult(defaultOrder)
        } else {
            setMockError(.orderCreationFailed(underlying: "Mock order creation failure"), shouldThrow: true)
        }
    }
    
    /// 配置订单状态查询场景
    /// - Parameter status: 订单状态
    public func configureOrderStatusQuery(status: IAPOrderStatus) {
        setMockOrderStatusResult(status)
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
}