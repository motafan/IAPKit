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
        return CacheStats(
            totalItems: totalItems,
            validItems: validItems,
            expiredItems: expiredItems
        )
    }
    
    // MARK: - Purchase Result Generation
    
    /// 生成购买结果
    /// - Parameter type: 结果类型
    /// - Returns: 购买结果
    public static func generatePurchaseResult(type: PurchaseResultType = .success) -> IAPPurchaseResult {
        switch type {
        case .success:
            let transaction = generateSuccessfulTransaction()
            return .success(transaction)
        case .cancelled:
            return .cancelled
        case .userCancelled:
            return .userCancelled
        case .pending:
            let transaction = generateTransaction(state: .purchasing)
            return .pending(transaction)
        }
    }
    
    /// 购买结果类型枚举
    public enum PurchaseResultType: CaseIterable {
        case success
        case cancelled
        case userCancelled
        case pending
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
            errors: ErrorType.allCases.map { generateError(type: $0) },
            purchaseResults: PurchaseResultType.allCases.map { generatePurchaseResult(type: $0) },
            configurations: [
                generateConfiguration(enableDebugLogging: true),
                generateConfiguration(enableDebugLogging: false),
                generateConfiguration(autoFinishTransactions: false)
            ]
        )
    }
}

/// 测试场景数据集合
public struct TestScenarios {
    public let products: [IAPProduct]
    public let transactions: [IAPTransaction]
    public let errors: [IAPError]
    public let purchaseResults: [IAPPurchaseResult]
    public let configurations: [IAPConfiguration]
    
    public init(
        products: [IAPProduct],
        transactions: [IAPTransaction],
        errors: [IAPError],
        purchaseResults: [IAPPurchaseResult],
        configurations: [IAPConfiguration]
    ) {
        self.products = products
        self.transactions = transactions
        self.errors = errors
        self.purchaseResults = purchaseResults
        self.configurations = configurations
    }
}