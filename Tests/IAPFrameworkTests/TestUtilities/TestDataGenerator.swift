import Foundation
@testable import IAPFramework

/// 测试数据生成器，用于创建各种测试数据
public struct TestDataGenerator {
    
    // MARK: - Product Generation
    
    /// 生成测试商品
    /// - Parameters:
    ///   - id: 商品ID
    ///   - displayName: 显示名称
    ///   - price: 价格
    ///   - productType: 商品类型
    /// - Returns: 测试商品
    public static func generateProduct(
        id: String = "test.product",
        displayName: String = "Test Product",
        price: Decimal = 0.99,
        productType: IAPProductType = .consumable
    ) -> IAPProduct {
        return IAPProduct.mock(
            id: id,
            displayName: displayName,
            price: price,
            productType: productType
        )
    }
    
    /// 生成多个测试商品
    /// - Parameter count: 商品数量
    /// - Returns: 商品列表
    public static func generateProducts(count: Int) -> [IAPProduct] {
        return (0..<count).map { index in
            generateProduct(
                id: "test.product.\(index)",
                displayName: "Test Product \(index)",
                price: Decimal(index + 1) * 0.99,
                productType: IAPProductType.allCases[index % IAPProductType.allCases.count]
            )
        }
    }
    
    /// 生成不同类型的商品集合
    /// - Returns: 包含各种类型商品的数组
    public static func generateMixedProducts() -> [IAPProduct] {
        return [
            generateProduct(id: "consumable.coins", displayName: "100 Coins", price: 0.99, productType: .consumable),
            generateProduct(id: "nonconsumable.premium", displayName: "Premium Features", price: 4.99, productType: .nonConsumable),
            generateProduct(id: "subscription.monthly", displayName: "Monthly Subscription", price: 9.99, productType: .autoRenewableSubscription),
            generateProduct(id: "subscription.season", displayName: "Season Pass", price: 19.99, productType: .nonRenewingSubscription)
        ]
    }
    
    /// 生成订阅商品
    /// - Parameters:
    ///   - id: 商品ID
    ///   - displayName: 显示名称
    ///   - price: 价格
    ///   - subscriptionPeriod: 订阅周期
    /// - Returns: 订阅商品
    public static func generateSubscriptionProduct(
        id: String = "subscription.monthly",
        displayName: String = "Monthly Subscription",
        price: Decimal = 9.99,
        subscriptionPeriod: IAPSubscriptionPeriod = IAPSubscriptionPeriod(unit: .month, value: 1)
    ) -> IAPProduct {
        let subscriptionInfo = IAPSubscriptionInfo(
            subscriptionGroupID: "group1",
            subscriptionPeriod: subscriptionPeriod
        )
        
        let locale = Locale.current
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        let localizedPrice = formatter.string(from: NSDecimalNumber(decimal: price)) ?? "$9.99"
        
        return IAPProduct(
            id: id,
            displayName: displayName,
            description: "Test subscription product",
            price: price,
            priceLocale: locale,
            localizedPrice: localizedPrice,
            productType: .autoRenewableSubscription,
            subscriptionInfo: subscriptionInfo
        )
    }
    
    // MARK: - Transaction Generation
    
    /// 生成测试交易
    /// - Parameters:
    ///   - id: 交易ID
    ///   - productID: 商品ID
    ///   - state: 交易状态
    ///   - purchaseDate: 购买日期
    /// - Returns: 测试交易
    public static func generateTransaction(
        id: String = "test.transaction",
        productID: String = "test.product",
        state: IAPTransactionState = .purchased,
        purchaseDate: Date = Date()
    ) -> IAPTransaction {
        return IAPTransaction(
            id: id,
            productID: productID,
            purchaseDate: purchaseDate,
            transactionState: state
        )
    }
    
    /// 生成成功交易
    /// - Parameters:
    ///   - id: 交易ID
    ///   - productID: 商品ID
    ///   - receiptData: 收据数据
    /// - Returns: 成功交易
    public static func generateSuccessfulTransaction(
        id: String = "success.transaction",
        productID: String = "test.product",
        receiptData: Data? = nil
    ) -> IAPTransaction {
        return IAPTransaction.successful(
            id: id,
            productID: productID,
            receiptData: receiptData ?? generateReceiptData()
        )
    }
    
    /// 生成失败交易
    /// - Parameters:
    ///   - id: 交易ID
    ///   - productID: 商品ID
    ///   - error: 错误
    /// - Returns: 失败交易
    public static func generateFailedTransaction(
        id: String = "failed.transaction",
        productID: String = "test.product",
        error: IAPError = .purchaseFailed(underlying: "Test error")
    ) -> IAPTransaction {
        return IAPTransaction.failed(
            id: id,
            productID: productID,
            error: error
        )
    }
    
    /// 生成多个测试交易
    /// - Parameters:
    ///   - count: 交易数量
    ///   - productID: 商品ID
    ///   - state: 交易状态
    /// - Returns: 交易列表
    public static func generateTransactions(
        count: Int,
        productID: String = "test.product",
        state: IAPTransactionState = .purchased
    ) -> [IAPTransaction] {
        return (0..<count).map { index in
            generateTransaction(
                id: "test.transaction.\(index)",
                productID: "\(productID).\(index)",
                state: state,
                purchaseDate: Date().addingTimeInterval(-TimeInterval(index * 60))
            )
        }
    }
    
    /// 生成混合状态的交易
    /// - Returns: 包含各种状态交易的数组
    public static func generateMixedTransactions() -> [IAPTransaction] {
        return [
            generateSuccessfulTransaction(id: "tx1", productID: "product1"),
            generateFailedTransaction(id: "tx2", productID: "product2", error: .networkError),
            generateTransaction(id: "tx3", productID: "product3", state: .purchasing),
            generateTransaction(id: "tx4", productID: "product4", state: .restored),
            generateTransaction(id: "tx5", productID: "product5", state: .deferred)
        ]
    }   
 
    // MARK: - Order Generation
    
    /// 生成测试订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - status: 订单状态
    ///   - userInfo: 用户信息
    ///   - createdAt: 创建时间
    ///   - expiresAt: 过期时间
    /// - Returns: 测试订单
    public static func generateOrder(
        id: String = "test.order",
        productID: String = "test.product",
        status: IAPOrderStatus = .created,
        userInfo: [String: String]? = nil,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) -> IAPOrder {
        return IAPOrder(
            id: id,
            productID: productID,
            userInfo: userInfo,
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: status
        )
    }
    
    /// 生成成功的订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - serverOrderID: 服务器订单ID
    /// - Returns: 成功订单
    public static func generateSuccessfulOrder(
        id: String = "success.order",
        productID: String = "test.product",
        serverOrderID: String? = nil
    ) -> IAPOrder {
        return IAPOrder.completed(
            id: id,
            productID: productID,
            serverOrderID: serverOrderID ?? "server_\(id)"
        )
    }
    
    /// 生成失败的订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - serverOrderID: 服务器订单ID
    /// - Returns: 失败订单
    public static func generateFailedOrder(
        id: String = "failed.order",
        productID: String = "test.product",
        serverOrderID: String? = nil
    ) -> IAPOrder {
        return IAPOrder.failed(
            id: id,
            productID: productID,
            serverOrderID: serverOrderID
        )
    }
    
    /// 生成过期的订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - minutesAgo: 多少分钟前过期
    /// - Returns: 过期订单
    public static func generateExpiredOrder(
        id: String = "expired.order",
        productID: String = "test.product",
        minutesAgo: Int = 30
    ) -> IAPOrder {
        let expiredTime = Date().addingTimeInterval(-TimeInterval(minutesAgo * 60))
        return IAPOrder(
            id: id,
            productID: productID,
            createdAt: expiredTime.addingTimeInterval(-300), // 创建时间比过期时间早5分钟
            expiresAt: expiredTime,
            status: .created
        )
    }
    
    /// 生成待处理的订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - expiresInMinutes: 多少分钟后过期
    /// - Returns: 待处理订单
    public static func generatePendingOrder(
        id: String = "pending.order",
        productID: String = "test.product",
        expiresInMinutes: Int = 30
    ) -> IAPOrder {
        let expirationTime = Date().addingTimeInterval(TimeInterval(expiresInMinutes * 60))
        return IAPOrder(
            id: id,
            productID: productID,
            expiresAt: expirationTime,
            status: .pending
        )
    }
    
    /// 生成多个测试订单
    /// - Parameters:
    ///   - count: 订单数量
    ///   - productID: 商品ID前缀
    ///   - status: 订单状态
    /// - Returns: 订单列表
    public static func generateOrders(
        count: Int,
        productID: String = "test.product",
        status: IAPOrderStatus = .created
    ) -> [IAPOrder] {
        return (0..<count).map { index in
            generateOrder(
                id: "test.order.\(index)",
                productID: "\(productID).\(index)",
                status: status,
                createdAt: Date().addingTimeInterval(-TimeInterval(index * 60))
            )
        }
    }
    
    /// 生成混合状态的订单
    /// - Returns: 包含各种状态订单的数组
    public static func generateMixedOrders() -> [IAPOrder] {
        return [
            generateOrder(id: "order1", productID: "product1", status: .created),
            generateOrder(id: "order2", productID: "product2", status: .pending),
            generateSuccessfulOrder(id: "order3", productID: "product3"),
            generateFailedOrder(id: "order4", productID: "product4"),
            generateOrder(id: "order5", productID: "product5", status: .cancelled),
            generateExpiredOrder(id: "order6", productID: "product6"),
            generatePendingOrder(id: "order7", productID: "product7")
        ]
    }
    
    /// 生成带有用户信息的订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - userID: 用户ID
    ///   - customData: 自定义数据
    /// - Returns: 带用户信息的订单
    public static func generateOrderWithUserInfo(
        id: String = "user.order",
        productID: String = "test.product",
        userID: String = "test.user",
        customData: [String: String] = [:]
    ) -> IAPOrder {
        var userInfo = customData
        userInfo["userID"] = userID
        userInfo["timestamp"] = "\(Date().timeIntervalSince1970)"
        
        return IAPOrder(
            id: id,
            productID: productID,
            userInfo: userInfo,
            status: .created,
            userID: userID
        )
    }
    
    /// 生成订单和交易的关联对
    /// - Parameters:
    ///   - orderID: 订单ID
    ///   - productID: 商品ID
    ///   - transactionState: 交易状态
    /// - Returns: 订单和交易的元组
    public static func generateOrderTransactionPair(
        orderID: String = "test.order",
        productID: String = "test.product",
        transactionState: IAPTransactionState = .purchased
    ) -> (order: IAPOrder, transaction: IAPTransaction) {
        let order = generateOrder(id: orderID, productID: productID, status: .pending)
        let transaction = generateTransaction(
            id: "tx_\(orderID)",
            productID: productID,
            state: transactionState
        )
        return (order: order, transaction: transaction)
    }
    
    // MARK: - Receipt Generation
    
    /// 生成测试收据数据
    /// - Parameter size: 数据大小（字节）
    /// - Returns: 收据数据
    public static func generateReceiptData(size: Int = 1024) -> Data {
        let bytes = (0..<size).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes)
    }
    
    /// 生成收据验证结果
    /// - Parameters:
    ///   - isValid: 是否有效
    ///   - transactions: 交易列表
    ///   - environment: 收据环境
    /// - Returns: 收据验证结果
    public static func generateReceiptValidationResult(
        isValid: Bool = true,
        transactions: [IAPTransaction] = [],
        environment: ReceiptEnvironment = .sandbox
    ) -> IAPReceiptValidationResult {
        return IAPReceiptValidationResult(
            isValid: isValid,
            transactions: transactions,
            receiptCreationDate: Date(),
            appVersion: "1.0.0",
            originalAppVersion: "1.0.0",
            environment: environment
        )
    }
    
    // MARK: - Error Generation
    
    /// 生成测试错误
    /// - Parameter type: 错误类型
    /// - Returns: 测试错误
    public static func generateError(type: ErrorType = .network) -> IAPError {
        switch type {
        case .network:
            return .networkError
        case .timeout:
            return .timeout
        case .productNotFound:
            return .productNotFound
        case .purchaseCancelled:
            return .purchaseCancelled
        case .receiptValidation:
            return .receiptValidationFailed
        case .paymentNotAllowed:
            return .paymentNotAllowed
        case .unknown:
            return .unknownError("Test unknown error")
        }
    }
    
    /// 错误类型枚举
    public enum ErrorType: CaseIterable {
        case network
        case timeout
        case productNotFound
        case purchaseCancelled
        case receiptValidation
        case paymentNotAllowed
        case unknown
    }
    
    /// 生成随机错误
    /// - Returns: 随机错误
    public static func generateRandomError() -> IAPError {
        let errorType = ErrorType.allCases.randomElement() ?? .unknown
        return generateError(type: errorType)
    }
    
    // MARK: - Configuration Generation
    
    /// 生成测试配置
    /// - Parameters:
    ///   - enableDebugLogging: 是否启用调试日志
    ///   - autoFinishTransactions: 是否自动完成交易
    ///   - autoRecoverTransactions: 是否自动恢复交易
    /// - Returns: 测试配置
    public static func generateConfiguration(
        enableDebugLogging: Bool = true,
        autoFinishTransactions: Bool = true,
        autoRecoverTransactions: Bool = true
    ) -> IAPConfiguration {
        return IAPConfiguration(
            enableDebugLogging: enableDebugLogging,
            autoFinishTransactions: autoFinishTransactions,
            autoRecoverTransactions: autoRecoverTransactions
        )
    }
    
    /// 生成收据验证配置
    /// - Parameters:
    ///   - mode: 验证模式
    ///   - timeout: 超时时间
    /// - Returns: 收据验证配置
    public static func generateReceiptValidationConfiguration(
        mode: ReceiptValidationConfiguration.ValidationMode = .local,
        timeout: TimeInterval = 30.0
    ) -> ReceiptValidationConfiguration {
        return ReceiptValidationConfiguration(
            mode: mode,
            timeout: timeout
        )
    }
    
    // MARK: - Cache Generation
    
    /// 生成缓存统计信息
    /// - Parameters:
    ///   - totalItems: 总项目数
    ///   - validItems: 有效项目数
    ///   - expiredItems: 过期项目数
    /// - Returns: 缓存统计信息
    public static func generateCacheStats(
        totalItems: Int = 10,
        validItems: Int = 8,
        expiredItems: Int = 2
    ) -> CacheStats {
        let productStats = ProductCacheStats(
            totalItems: totalItems,
            validItems: validItems,
            expiredItems: expiredItems
        )
        
        let orderStats = OrderCacheStats(
            totalOrders: totalItems / 2,
            pendingOrders: 2,
            completedOrders: validItems / 2,
            failedOrders: 1,
            expiredOrders: expiredItems
        )
        
        return CacheStats(
            productStats: productStats,
            orderStats: orderStats
        )
    }
    
    // MARK: - Purchase Result Generation
    
    /// 生成购买结果（支持订单）
    /// - Parameter type: 结果类型
    /// - Returns: 购买结果
    public static func generatePurchaseResult(type: PurchaseResultType = .success) -> IAPPurchaseResult {
        switch type {
        case .success:
            let transaction = generateSuccessfulTransaction()
            let order = generateSuccessfulOrder(productID: transaction.productID)
            return .success(transaction, order)
        case .cancelled:
            let order = generateOrder(status: .cancelled)
            return .cancelled(order)
        case .userCancelled:
            let order = generateOrder(status: .cancelled)
            return .cancelled(order)
        case .pending:
            let transaction = generateTransaction(state: .purchasing)
            let order = generatePendingOrder(productID: transaction.productID)
            return .pending(transaction, order)
        case .failed:
            let order = generateFailedOrder()
            return .failed(.purchaseFailed(underlying: "Test failure"), order)
        }
    }
    
    /// 购买结果类型枚举
    public enum PurchaseResultType: CaseIterable {
        case success
        case cancelled
        case userCancelled
        case pending
        case failed
    }
    
    // MARK: - Monitoring Stats Generation
    
    /// 生成监控统计信息
    /// - Parameters:
    ///   - transactionsProcessed: 处理的交易数
    ///   - successfulTransactions: 成功交易数
    ///   - failedTransactions: 失败交易数
    /// - Returns: 监控统计信息
    public static func generateMonitoringStats(
        transactionsProcessed: Int = 10,
        successfulTransactions: Int = 8,
        failedTransactions: Int = 2
    ) -> TransactionMonitor.MonitoringStats {
        var stats = TransactionMonitor.MonitoringStats()
        stats.transactionsProcessed = transactionsProcessed
        stats.successfulTransactions = successfulTransactions
        stats.failedTransactions = failedTransactions
        stats.startTime = Date().addingTimeInterval(-300) // 5分钟前开始
        return stats
    }
    
    // MARK: - Validation Result Generation
    
    /// 生成商品ID验证结果
    /// - Parameters:
    ///   - validIDs: 有效ID
    ///   - invalidIDs: 无效ID
    /// - Returns: 验证结果
    public static func generateProductIDValidationResult(
        validIDs: Set<String> = ["valid.product1", "valid.product2"],
        invalidIDs: Set<String> = ["invalid.product"]
    ) -> ProductIDValidationResult {
        return ProductIDValidationResult(
            validIDs: validIDs,
            invalidIDs: invalidIDs,
            isAllValid: invalidIDs.isEmpty
        )
    }
    
    /// 生成购买验证结果
    /// - Parameters:
    ///   - canPurchase: 是否可以购买
    ///   - error: 错误
    ///   - message: 消息
    /// - Returns: 购买验证结果
    public static func generatePurchaseValidationResult(
        canPurchase: Bool = true,
        error: IAPError? = nil,
        message: String? = nil
    ) -> PurchaseService.PurchaseValidationResult {
        return PurchaseService.PurchaseValidationResult(
            canPurchase: canPurchase,
            error: error,
            message: message
        )
    }
    
    // MARK: - Utility Methods
    
    /// 生成随机字符串
    /// - Parameter length: 字符串长度
    /// - Returns: 随机字符串
    public static func generateRandomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// 生成随机商品ID
    /// - Returns: 随机商品ID
    public static func generateRandomProductID() -> String {
        return "com.test.\(generateRandomString(length: 8))"
    }
    
    /// 生成随机交易ID
    /// - Returns: 随机交易ID
    public static func generateRandomTransactionID() -> String {
        return "tx_\(generateRandomString(length: 12))"
    }
    
    /// 生成随机订单ID
    /// - Returns: 随机订单ID
    public static func generateRandomOrderID() -> String {
        return "order_\(generateRandomString(length: 12))"
    }
    
    /// 生成测试日期
    /// - Parameter daysAgo: 几天前
    /// - Returns: 测试日期
    public static func generateTestDate(daysAgo: Int = 0) -> Date {
        return Date().addingTimeInterval(-TimeInterval(daysAgo * 24 * 60 * 60))
    }
    
    /// 生成测试价格
    /// - Parameter range: 价格范围
    /// - Returns: 测试价格
    public static func generateTestPrice(range: ClosedRange<Double> = 0.99...99.99) -> Decimal {
        let randomPrice = Double.random(in: range)
        return Decimal(randomPrice)
    }
}

// MARK: - Batch Generation Methods

extension TestDataGenerator {
    
    /// 批量生成测试场景数据
    /// - Returns: 测试场景数据集合
    public static func generateTestScenarios() -> TestScenarios {
        return TestScenarios(
            products: generateMixedProducts(),
            transactions: generateMixedTransactions(),
            orders: generateMixedOrders(),
            errors: ErrorType.allCases.map { generateError(type: $0) },
            purchaseResults: PurchaseResultType.allCases.map { generatePurchaseResult(type: $0) },
            configurations: [
                generateConfiguration(enableDebugLogging: true),
                generateConfiguration(enableDebugLogging: false),
                generateConfiguration(autoFinishTransactions: false)
            ]
        )
    }
    
    /// 生成订单测试场景
    /// - Returns: 订单测试场景数据
    public static func generateOrderTestScenarios() -> OrderTestScenarios {
        return OrderTestScenarios(
            activeOrders: generateOrders(count: 3, status: .pending),
            expiredOrders: [generateExpiredOrder()],
            completedOrders: [generateSuccessfulOrder()],
            failedOrders: [generateFailedOrder()],
            orderTransactionPairs: [
                generateOrderTransactionPair(orderID: "order1", productID: "product1"),
                generateOrderTransactionPair(orderID: "order2", productID: "product2", transactionState: .failed(.networkError))
            ]
        )
    }
}

/// 测试场景数据集合
public struct TestScenarios {
    public let products: [IAPProduct]
    public let transactions: [IAPTransaction]
    public let orders: [IAPOrder]
    public let errors: [IAPError]
    public let purchaseResults: [IAPPurchaseResult]
    public let configurations: [IAPConfiguration]
    
    public init(
        products: [IAPProduct],
        transactions: [IAPTransaction],
        orders: [IAPOrder],
        errors: [IAPError],
        purchaseResults: [IAPPurchaseResult],
        configurations: [IAPConfiguration]
    ) {
        self.products = products
        self.transactions = transactions
        self.orders = orders
        self.errors = errors
        self.purchaseResults = purchaseResults
        self.configurations = configurations
    }
}

/// 订单测试场景数据集合
public struct OrderTestScenarios {
    public let activeOrders: [IAPOrder]
    public let expiredOrders: [IAPOrder]
    public let completedOrders: [IAPOrder]
    public let failedOrders: [IAPOrder]
    public let orderTransactionPairs: [(order: IAPOrder, transaction: IAPTransaction)]
    
    public init(
        activeOrders: [IAPOrder],
        expiredOrders: [IAPOrder],
        completedOrders: [IAPOrder],
        failedOrders: [IAPOrder],
        orderTransactionPairs: [(order: IAPOrder, transaction: IAPTransaction)]
    ) {
        self.activeOrders = activeOrders
        self.expiredOrders = expiredOrders
        self.completedOrders = completedOrders
        self.failedOrders = failedOrders
        self.orderTransactionPairs = orderTransactionPairs
    }
    
    /// 获取所有订单
    public var allOrders: [IAPOrder] {
        return activeOrders + expiredOrders + completedOrders + failedOrders
    }
    
    /// 获取所有交易
    public var allTransactions: [IAPTransaction] {
        return orderTransactionPairs.map { $0.transaction }
    }
}