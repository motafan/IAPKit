import Foundation
@testable import IAPFramework

/// 订单测试工具类，提供订单相关的测试辅助功能
public struct OrderTestUtilities {
    
    // MARK: - Order State Verification
    
    /// 验证订单状态
    /// - Parameters:
    ///   - order: 要验证的订单
    ///   - expectedStatus: 期望的状态
    /// - Returns: 验证是否通过
    public static func verifyOrderStatus(_ order: IAPOrder, expectedStatus: IAPOrderStatus) -> Bool {
        return order.status == expectedStatus
    }
    
    /// 验证订单是否过期
    /// - Parameter order: 要验证的订单
    /// - Returns: 验证结果
    public static func verifyOrderExpired(_ order: IAPOrder) -> Bool {
        return order.isExpired
    }
    
    /// 验证订单是否活跃
    /// - Parameter order: 要验证的订单
    /// - Returns: 验证结果
    public static func verifyOrderActive(_ order: IAPOrder) -> Bool {
        return order.isActive
    }
    
    /// 验证订单是否为终态
    /// - Parameter order: 要验证的订单
    /// - Returns: 验证结果
    public static func verifyOrderTerminal(_ order: IAPOrder) -> Bool {
        return order.isTerminal
    }
    
    /// 验证订单是否可取消
    /// - Parameter order: 要验证的订单
    /// - Returns: 验证结果
    public static func verifyOrderCancellable(_ order: IAPOrder) -> Bool {
        return order.isCancellable
    }
    
    /// 验证订单集合的状态分布
    /// - Parameters:
    ///   - orders: 订单集合
    ///   - expectedDistribution: 期望的状态分布
    /// - Returns: 验证是否通过
    public static func verifyOrderStatusDistribution(
        _ orders: [IAPOrder],
        expectedDistribution: [IAPOrderStatus: Int]
    ) -> Bool {
        let actualDistribution = Dictionary(grouping: orders, by: { $0.status })
            .mapValues { $0.count }
        
        return actualDistribution == expectedDistribution
    }
    
    // MARK: - Order Flow Verification
    
    /// 验证订单创建流程
    /// - Parameters:
    ///   - order: 创建的订单
    ///   - productID: 期望的商品ID
    ///   - userInfo: 期望的用户信息
    /// - Returns: 验证结果
    public static func verifyOrderCreation(
        _ order: IAPOrder,
        productID: String,
        userInfo: [String: String]? = nil
    ) -> OrderVerificationResult {
        var issues: [String] = []
        
        if order.productID != productID {
            issues.append("Product ID mismatch: expected \(productID), got \(order.productID)")
        }
        
        if order.status != .created {
            issues.append("Status should be .created, got \(order.status)")
        }
        
        if let expectedUserInfo = userInfo {
            if order.userInfo != expectedUserInfo {
                issues.append("User info mismatch")
            }
        }
        
        if order.id.isEmpty {
            issues.append("Order ID should not be empty")
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证订单完成流程
    /// - Parameters:
    ///   - order: 完成的订单
    ///   - transaction: 关联的交易
    /// - Returns: 验证结果
    public static func verifyOrderCompletion(
        _ order: IAPOrder,
        transaction: IAPTransaction
    ) -> OrderVerificationResult {
        var issues: [String] = []
        
        if order.status != .completed {
            issues.append("Order status should be .completed, got \(order.status)")
        }
        
        if order.productID != transaction.productID {
            issues.append("Product ID mismatch between order and transaction")
        }
        
        if !transaction.isSuccessful {
            issues.append("Transaction should be successful for completed order")
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证订单取消流程
    /// - Parameter order: 取消的订单
    /// - Returns: 验证结果
    public static func verifyOrderCancellation(_ order: IAPOrder) -> OrderVerificationResult {
        var issues: [String] = []
        
        if order.status != .cancelled {
            issues.append("Order status should be .cancelled, got \(order.status)")
        }
        
        if !order.isTerminal {
            issues.append("Cancelled order should be terminal")
        }
        
        if order.isActive {
            issues.append("Cancelled order should not be active")
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证订单失败流程
    /// - Parameter order: 失败的订单
    /// - Returns: 验证结果
    public static func verifyOrderFailure(_ order: IAPOrder) -> OrderVerificationResult {
        var issues: [String] = []
        
        if order.status != .failed {
            issues.append("Order status should be .failed, got \(order.status)")
        }
        
        if !order.isTerminal {
            issues.append("Failed order should be terminal")
        }
        
        if order.isActive {
            issues.append("Failed order should not be active")
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Order-Transaction Association Verification
    
    /// 验证订单和交易的关联
    /// - Parameters:
    ///   - order: 订单
    ///   - transaction: 交易
    /// - Returns: 验证结果
    public static func verifyOrderTransactionAssociation(
        _ order: IAPOrder,
        _ transaction: IAPTransaction
    ) -> OrderVerificationResult {
        var issues: [String] = []
        
        if order.productID != transaction.productID {
            issues.append("Product ID mismatch: order has \(order.productID), transaction has \(transaction.productID)")
        }
        
        // 验证状态一致性
        switch (order.status, transaction.transactionState) {
        case (.completed, .purchased), (.completed, .restored):
            break // 正确的组合
        case (.pending, .purchasing):
            break // 正确的组合
        case (.failed, .failed):
            break // 正确的组合
        default:
            issues.append("Status inconsistency: order is \(order.status), transaction is \(transaction.transactionState)")
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证购买结果中的订单和交易关联
    /// - Parameter result: 购买结果
    /// - Returns: 验证结果
    public static func verifyPurchaseResultConsistency(_ result: IAPPurchaseResult) -> OrderVerificationResult {
        var issues: [String] = []
        
        switch result {
        case .success(let transaction, let order):
            let associationResult = verifyOrderTransactionAssociation(order, transaction)
            if !associationResult.isValid {
                issues.append(contentsOf: associationResult.issues)
            }
            
            if order.status != .completed {
                issues.append("Order in success result should be completed")
            }
            
            if !transaction.isSuccessful {
                issues.append("Transaction in success result should be successful")
            }
            
        case .pending(let transaction, let order):
            if order.status != .pending {
                issues.append("Order in pending result should be pending")
            }
            
            if !transaction.isPending {
                issues.append("Transaction in pending result should be pending")
            }
            
        case .cancelled(let order):
            if let order = order {
                if order.status != .cancelled {
                    issues.append("Order in cancelled result should be cancelled")
                }
            }
            
        case .failed(_, let order):
            if let order = order {
                if order.status != .failed {
                    issues.append("Order in failed result should be failed")
                }
            }
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Order Collection Verification
    
    /// 验证订单集合的完整性
    /// - Parameters:
    ///   - orders: 订单集合
    ///   - expectedCount: 期望的数量
    ///   - allowDuplicates: 是否允许重复
    /// - Returns: 验证结果
    public static func verifyOrderCollection(
        _ orders: [IAPOrder],
        expectedCount: Int? = nil,
        allowDuplicates: Bool = false
    ) -> OrderVerificationResult {
        var issues: [String] = []
        
        if let expectedCount = expectedCount, orders.count != expectedCount {
            issues.append("Expected \(expectedCount) orders, got \(orders.count)")
        }
        
        if !allowDuplicates {
            let uniqueIDs = Set(orders.map { $0.id })
            if uniqueIDs.count != orders.count {
                issues.append("Duplicate order IDs found")
            }
        }
        
        // 验证每个订单的基本有效性
        for (index, order) in orders.enumerated() {
            if order.id.isEmpty {
                issues.append("Order at index \(index) has empty ID")
            }
            
            if order.productID.isEmpty {
                issues.append("Order at index \(index) has empty product ID")
            }
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证订单恢复结果
    /// - Parameters:
    ///   - recoveredOrders: 恢复的订单
    ///   - originalOrders: 原始订单
    /// - Returns: 验证结果
    public static func verifyOrderRecovery(
        recoveredOrders: [IAPOrder],
        originalOrders: [IAPOrder]
    ) -> OrderVerificationResult {
        var issues: [String] = []
        
        let originalOrderIDs = Set(originalOrders.map { $0.id })
        let recoveredOrderIDs = Set(recoveredOrders.map { $0.id })
        
        // 检查是否有遗漏的订单
        let missingOrders = originalOrderIDs.subtracting(recoveredOrderIDs)
        if !missingOrders.isEmpty {
            issues.append("Missing orders after recovery: \(missingOrders)")
        }
        
        // 检查是否有多余的订单
        let extraOrders = recoveredOrderIDs.subtracting(originalOrderIDs)
        if !extraOrders.isEmpty {
            issues.append("Extra orders after recovery: \(extraOrders)")
        }
        
        // 验证恢复的订单状态
        for recoveredOrder in recoveredOrders {
            if let originalOrder = originalOrders.first(where: { $0.id == recoveredOrder.id }) {
                if originalOrder.status.isInProgress && recoveredOrder.status.isTerminal {
                    // 这是正常的，进行中的订单可能在恢复时已完成
                    continue
                } else if originalOrder.status != recoveredOrder.status {
                    issues.append("Order \(recoveredOrder.id) status changed unexpectedly during recovery")
                }
            }
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Order Timing Verification
    
    /// 验证订单时间相关属性
    /// - Parameter order: 订单
    /// - Returns: 验证结果
    public static func verifyOrderTiming(_ order: IAPOrder) -> OrderVerificationResult {
        var issues: [String] = []
        
        let now = Date()
        
        // 创建时间不应该在未来
        if order.createdAt > now {
            issues.append("Order creation time is in the future")
        }
        
        // 如果有过期时间，应该在创建时间之后
        if let expiresAt = order.expiresAt {
            if expiresAt <= order.createdAt {
                issues.append("Order expiration time should be after creation time")
            }
        }
        
        // 验证过期状态的一致性
        if let expiresAt = order.expiresAt {
            let shouldBeExpired = now > expiresAt
            if order.isExpired != shouldBeExpired {
                issues.append("Order expiration status inconsistency")
            }
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Mock Service Verification
    
    /// 验证 Mock 服务的订单操作记录
    /// - Parameters:
    ///   - mockService: Mock 服务
    ///   - expectedOperations: 期望的操作记录
    /// - Returns: 验证结果
    @MainActor
    public static func verifyMockServiceOrderOperations(
        _ mockService: MockPurchaseService,
        expectedOperations: [String]
    ) -> OrderVerificationResult {
        var issues: [String] = []
        
        for operation in expectedOperations {
            if !mockService.wasCalled(operation) {
                issues.append("Expected operation '\(operation)' was not called")
            }
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证 Mock 服务的订单创建记录
    /// - Parameters:
    ///   - mockService: Mock 服务
    ///   - expectedProductIDs: 期望创建订单的商品ID
    /// - Returns: 验证结果
    @MainActor
    public static func verifyMockServiceOrderCreation(
        _ mockService: MockPurchaseService,
        expectedProductIDs: [String]
    ) -> OrderVerificationResult {
        var issues: [String] = []
        
        let createdOrders = mockService.getAllCreatedOrders()
        let createdProductIDs = createdOrders.map { $0.productID }
        
        for expectedProductID in expectedProductIDs {
            if !createdProductIDs.contains(expectedProductID) {
                issues.append("Expected order for product '\(expectedProductID)' was not created")
            }
        }
        
        return OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
    }
}

// MARK: - Order Verification Result

/// 订单验证结果
public struct OrderVerificationResult {
    /// 验证是否通过
    public let isValid: Bool
    /// 验证问题列表
    public let issues: [String]
    
    public init(isValid: Bool, issues: [String] = []) {
        self.isValid = isValid
        self.issues = issues
    }
    
    /// 合并多个验证结果
    /// - Parameter results: 要合并的结果
    /// - Returns: 合并后的结果
    public static func combine(_ results: [OrderVerificationResult]) -> OrderVerificationResult {
        let allIssues = results.flatMap { $0.issues }
        let isValid = results.allSatisfy { $0.isValid }
        return OrderVerificationResult(isValid: isValid, issues: allIssues)
    }
    
    /// 验证结果的描述
    public var description: String {
        if isValid {
            return "Verification passed"
        } else {
            return "Verification failed with issues: \(issues.joined(separator: ", "))"
        }
    }
}

// MARK: - Order Test Scenarios Builder

/// 订单测试场景构建器
public struct OrderTestScenariosBuilder {
    private var activeOrders: [IAPOrder] = []
    private var expiredOrders: [IAPOrder] = []
    private var completedOrders: [IAPOrder] = []
    private var failedOrders: [IAPOrder] = []
    private var orderTransactionPairs: [(order: IAPOrder, transaction: IAPTransaction)] = []
    
    public init() {}
    
    /// 添加活跃订单
    /// - Parameter order: 订单
    /// - Returns: 构建器实例
    public mutating func addActiveOrder(_ order: IAPOrder) -> OrderTestScenariosBuilder {
        activeOrders.append(order)
        return self
    }
    
    /// 添加过期订单
    /// - Parameter order: 订单
    /// - Returns: 构建器实例
    public mutating func addExpiredOrder(_ order: IAPOrder) -> OrderTestScenariosBuilder {
        expiredOrders.append(order)
        return self
    }
    
    /// 添加完成订单
    /// - Parameter order: 订单
    /// - Returns: 构建器实例
    public mutating func addCompletedOrder(_ order: IAPOrder) -> OrderTestScenariosBuilder {
        completedOrders.append(order)
        return self
    }
    
    /// 添加失败订单
    /// - Parameter order: 订单
    /// - Returns: 构建器实例
    public mutating func addFailedOrder(_ order: IAPOrder) -> OrderTestScenariosBuilder {
        failedOrders.append(order)
        return self
    }
    
    /// 添加订单-交易对
    /// - Parameters:
    ///   - order: 订单
    ///   - transaction: 交易
    /// - Returns: 构建器实例
    public mutating func addOrderTransactionPair(
        order: IAPOrder,
        transaction: IAPTransaction
    ) -> OrderTestScenariosBuilder {
        orderTransactionPairs.append((order: order, transaction: transaction))
        return self
    }
    
    /// 构建测试场景
    /// - Returns: 订单测试场景
    public func build() -> OrderTestScenarios {
        return OrderTestScenarios(
            activeOrders: activeOrders,
            expiredOrders: expiredOrders,
            completedOrders: completedOrders,
            failedOrders: failedOrders,
            orderTransactionPairs: orderTransactionPairs
        )
    }
}

// MARK: - Order Flow Testing Utilities

/// 订单流程测试工具
public struct OrderFlowTestUtilities {
    
    /// 模拟完整的订单购买流程
    /// - Parameters:
    ///   - product: 商品
    ///   - mockService: Mock 服务
    ///   - shouldSucceed: 是否应该成功
    /// - Returns: 购买结果和验证结果
    @MainActor
    public static func simulateOrderPurchaseFlow(
        product: IAPProduct,
        mockService: MockPurchaseService,
        shouldSucceed: Bool = true
    ) async -> (result: IAPPurchaseResult?, verification: OrderVerificationResult) {
        var issues: [String] = []
        
        do {
            // 配置 Mock 服务
            if shouldSucceed {
                mockService.configureSuccessfulPurchase(for: product)
            } else {
                mockService.configureFailedPurchase(error: .purchaseFailed(underlying: "Test failure"))
            }
            
            // 执行购买
            let result = try await mockService.purchase(product)
            
            // 验证结果
            let verificationResult = OrderTestUtilities.verifyPurchaseResultConsistency(result)
            if !verificationResult.isValid {
                issues.append(contentsOf: verificationResult.issues)
            }
            
            // 验证 Mock 服务调用
            if !mockService.wasCalled("purchase") {
                issues.append("Purchase method was not called")
            }
            
            return (result: result, verification: OrderVerificationResult(isValid: issues.isEmpty, issues: issues))
            
        } catch {
            if shouldSucceed {
                issues.append("Purchase should have succeeded but threw error: \(error)")
            }
            return (result: nil, verification: OrderVerificationResult(isValid: !shouldSucceed, issues: issues))
        }
    }
    
    /// 模拟订单恢复流程
    /// - Parameters:
    ///   - orders: 要恢复的订单
    ///   - mockService: Mock 服务
    /// - Returns: 恢复结果和验证结果
    @MainActor
    public static func simulateOrderRecoveryFlow(
        orders: [IAPOrder],
        mockService: MockPurchaseService
    ) async -> (recoveredOrders: [IAPOrder], verification: OrderVerificationResult) {
        var issues: [String] = []
        var recoveredOrders: [IAPOrder] = []
        
        // 模拟恢复每个订单
        for order in orders {
            do {
                // 配置 Mock 服务返回订单状态
                mockService.setMockOrderStatusResult(order.status)
                
                let status = try await mockService.queryOrderStatus(order.id)
                let recoveredOrder = order.withStatus(status)
                recoveredOrders.append(recoveredOrder)
                
            } catch {
                issues.append("Failed to recover order \(order.id): \(error)")
            }
        }
        
        // 验证恢复结果
        let verificationResult = OrderTestUtilities.verifyOrderRecovery(
            recoveredOrders: recoveredOrders,
            originalOrders: orders
        )
        
        if !verificationResult.isValid {
            issues.append(contentsOf: verificationResult.issues)
        }
        
        return (
            recoveredOrders: recoveredOrders,
            verification: OrderVerificationResult(isValid: issues.isEmpty, issues: issues)
        )
    }
}