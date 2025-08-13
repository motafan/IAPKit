import Foundation

/// 测试数据生成器，用于创建各种测试场景的数据
public struct TestDataGenerator {
    
    // MARK: - Product Generation
    
    /// 创建基本测试商品
    /// - Parameters:
    ///   - id: 商品ID
    ///   - displayName: 显示名称
    ///   - price: 价格
    ///   - productType: 商品类型
    /// - Returns: 测试商品
    public static func createProduct(
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
    
    /// 创建多个测试商品
    /// - Parameters:
    ///   - count: 商品数量
    ///   - prefix: ID前缀
    /// - Returns: 测试商品数组
    public static func createProducts(count: Int, prefix: String = "test.product") -> [IAPProduct] {
        return (1...count).map { index in
            IAPProduct.mock(
                id: "\(prefix).\(index)",
                displayName: "Test Product \(index)",
                price: Decimal(index),
                productType: index % 2 == 0 ? .consumable : .nonConsumable
            )
        }
    }
    
    /// 创建不同类型的商品集合
    /// - Returns: 包含各种类型的商品数组
    public static func createVariousProducts() -> [IAPProduct] {
        return [
            // 消耗型商品
            IAPProduct.mock(
                id: "consumable.coins.small",
                displayName: "100 Coins",
                price: 0.99,
                productType: .consumable
            ),
            IAPProduct.mock(
                id: "consumable.coins.large",
                displayName: "1000 Coins",
                price: 4.99,
                productType: .consumable
            ),
            
            // 非消耗型商品
            IAPProduct.mock(
                id: "nonconsumable.premium",
                displayName: "Premium Features",
                price: 9.99,
                productType: .nonConsumable
            ),
            IAPProduct.mock(
                id: "nonconsumable.noads",
                displayName: "Remove Ads",
                price: 2.99,
                productType: .nonConsumable
            ),
            
            // 自动续费订阅
            IAPProduct.mock(
                id: "subscription.monthly",
                displayName: "Monthly Subscription",
                price: 9.99,
                productType: .autoRenewableSubscription
            ),
            IAPProduct.mock(
                id: "subscription.yearly",
                displayName: "Yearly Subscription",
                price: 99.99,
                productType: .autoRenewableSubscription
            ),
            
            // 非续费订阅
            IAPProduct.mock(
                id: "subscription.season",
                displayName: "Season Pass",
                price: 19.99,
                productType: .nonRenewingSubscription
            )
        ]
    }
    
    /// 创建价格范围内的商品
    /// - Parameters:
    ///   - minPrice: 最低价格
    ///   - maxPrice: 最高价格
    ///   - count: 商品数量
    /// - Returns: 测试商品数组
    public static func createProductsInPriceRange(
        minPrice: Decimal,
        maxPrice: Decimal,
        count: Int
    ) -> [IAPProduct] {
        let priceStep = (maxPrice - minPrice) / Decimal(count - 1)
        
        return (0..<count).map { index in
            let price = minPrice + (priceStep * Decimal(index))
            return IAPProduct.mock(
                id: "test.product.\(index)",
                displayName: "Test Product \(index)",
                price: price,
                productType: .consumable
            )
        }
    }
    
    // MARK: - Transaction Generation
    
    /// 创建成功的交易
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - transactionID: 交易ID
    ///   - purchaseDate: 购买日期
    /// - Returns: 成功的交易
    public static func createSuccessfulTransaction(
        productID: String = "test.product",
        transactionID: String? = nil,
        purchaseDate: Date = Date()
    ) -> IAPTransaction {
        let id = transactionID ?? "tx_\(productID)_\(UUID().uuidString.prefix(8))"
        return IAPTransaction(
            id: id,
            productID: productID,
            purchaseDate: purchaseDate,
            transactionState: .purchased,
            receiptData: createMockReceiptData()
        )
    }
    
    /// 创建失败的交易
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - error: 失败错误
    ///   - transactionID: 交易ID
    /// - Returns: 失败的交易
    public static func createFailedTransaction(
        productID: String = "test.product",
        error: IAPError = .purchaseFailed(underlying: "Test error"),
        transactionID: String? = nil
    ) -> IAPTransaction {
        let id = transactionID ?? "tx_\(productID)_\(UUID().uuidString.prefix(8))"
        return IAPTransaction(
            id: id,
            productID: productID,
            purchaseDate: Date(),
            transactionState: .failed(error)
        )
    }
    
    /// 创建待处理的交易
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - transactionID: 交易ID
    /// - Returns: 待处理的交易
    public static func createPendingTransaction(
        productID: String = "test.product",
        transactionID: String? = nil
    ) -> IAPTransaction {
        let id = transactionID ?? "tx_\(productID)_\(UUID().uuidString.prefix(8))"
        return IAPTransaction(
            id: id,
            productID: productID,
            purchaseDate: Date(),
            transactionState: .purchasing
        )
    }
    
    /// 创建恢复的交易
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - originalTransactionID: 原始交易ID
    ///   - transactionID: 交易ID
    /// - Returns: 恢复的交易
    public static func createRestoredTransaction(
        productID: String = "test.product",
        originalTransactionID: String? = nil,
        transactionID: String? = nil
    ) -> IAPTransaction {
        let id = transactionID ?? "tx_\(productID)_\(UUID().uuidString.prefix(8))"
        let originalID = originalTransactionID ?? "original_tx_\(productID)"
        
        return IAPTransaction(
            id: id,
            productID: productID,
            purchaseDate: Date().addingTimeInterval(-86400), // 1 day ago
            transactionState: .restored,
            receiptData: createMockReceiptData(),
            originalTransactionID: originalID
        )
    }
    
    /// 创建多个交易
    /// - Parameters:
    ///   - productIDs: 商品ID数组
    ///   - state: 交易状态
    /// - Returns: 交易数组
    public static func createTransactions(
        for productIDs: [String],
        state: IAPTransactionState = .purchased
    ) -> [IAPTransaction] {
        return productIDs.map { productID in
            IAPTransaction(
                id: "tx_\(productID)_\(UUID().uuidString.prefix(8))",
                productID: productID,
                purchaseDate: Date(),
                transactionState: state,
                receiptData: createMockReceiptData()
            )
        }
    }
    
    // MARK: - Purchase Result Generation
    
    /// 创建成功的购买结果
    /// - Parameter transaction: 交易
    /// - Returns: 成功的购买结果
    public static func createSuccessfulPurchaseResult(
        transaction: IAPTransaction? = nil
    ) -> IAPPurchaseResult {
        let tx = transaction ?? createSuccessfulTransaction()
        return .success(tx)
    }
    
    /// 创建取消的购买结果
    /// - Returns: 取消的购买结果
    public static func createCancelledPurchaseResult() -> IAPPurchaseResult {
        return .cancelled
    }
    
    /// 创建待处理的购买结果
    /// - Parameter transaction: 交易
    /// - Returns: 待处理的购买结果
    public static func createPendingPurchaseResult(
        transaction: IAPTransaction? = nil
    ) -> IAPPurchaseResult {
        let tx = transaction ?? createPendingTransaction()
        return .pending(tx)
    }
    
    // MARK: - Receipt Validation Result Generation
    
    /// 创建有效的收据验证结果
    /// - Parameters:
    ///   - transactions: 交易数组
    ///   - appVersion: 应用版本
    /// - Returns: 有效的验证结果
    public static func createValidReceiptValidationResult(
        transactions: [IAPTransaction] = [],
        appVersion: String = "1.0.0"
    ) -> IAPReceiptValidationResult {
        return IAPReceiptValidationResult(
            isValid: true,
            transactions: transactions,
            receiptCreationDate: Date(),
            appVersion: appVersion,
            originalAppVersion: "1.0.0"
        )
    }
    
    /// 创建无效的收据验证结果
    /// - Parameter error: 验证错误
    /// - Returns: 无效的验证结果
    public static func createInvalidReceiptValidationResult(
        error: IAPError = .receiptValidationFailed
    ) -> IAPReceiptValidationResult {
        return IAPReceiptValidationResult(
            isValid: false,
            error: error
        )
    }
    
    // MARK: - Error Generation
    
    /// 创建各种类型的错误
    /// - Returns: 错误数组
    public static func createVariousErrors() -> [IAPError] {
        return [
            .productNotFound,
            .productNotAvailable,
            .purchaseCancelled,
            .purchaseFailed("Network error"),
            .receiptValidationFailed,
            .transactionProcessingFailed("Processing error"),
            .networkError,
            .unknownError("Unknown error")
        ]
    }
    
    /// 创建网络相关错误
    /// - Returns: 网络错误数组
    public static func createNetworkErrors() -> [IAPError] {
        return [
            .networkError,
            .purchaseFailed("Connection timeout"),
            .receiptValidationFailed
        ]
    }
    
    // MARK: - Configuration Generation
    
    /// 创建测试配置
    /// - Parameters:
    ///   - enableDebugLogging: 是否启用调试日志
    ///   - autoFinishTransactions: 是否自动完成交易
    /// - Returns: 测试配置
    public static func createTestConfiguration(
        enableDebugLogging: Bool = true,
        autoFinishTransactions: Bool = true
    ) -> IAPConfiguration {
        return IAPConfiguration(
            enableDebugLogging: enableDebugLogging,
            autoFinishTransactions: autoFinishTransactions,
            productCacheExpiration: 300, // 5 minutes
            receiptValidation: IAPConfiguration.ReceiptValidationConfig(
                mode: .local,
                timeout: 30
            )
        )
    }
    
    // MARK: - Mock Data Helpers
    
    /// 创建模拟收据数据
    /// - Returns: 模拟收据数据
    public static func createMockReceiptData() -> Data {
        let receiptContent = [
            "receipt_type": "ProductionSandbox",
            "adam_id": 123456789,
            "app_item_id": 123456789,
            "bundle_id": "com.test.app",
            "application_version": "1.0.0",
            "download_id": 123456789,
            "version_external_identifier": 123456789,
            "receipt_creation_date": Date().timeIntervalSince1970,
            "receipt_creation_date_ms": Int64(Date().timeIntervalSince1970 * 1000),
            "receipt_creation_date_pst": "2024-01-01 12:00:00 America/Los_Angeles",
            "request_date": Date().timeIntervalSince1970,
            "request_date_ms": Int64(Date().timeIntervalSince1970 * 1000),
            "request_date_pst": "2024-01-01 12:00:00 America/Los_Angeles",
            "original_purchase_date": Date().addingTimeInterval(-86400).timeIntervalSince1970,
            "original_purchase_date_ms": Int64(Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000),
            "original_purchase_date_pst": "2024-01-01 12:00:00 America/Los_Angeles",
            "original_application_version": "1.0.0"
        ] as [String: Any]
        
        return try! JSONSerialization.data(withJSONObject: receiptContent)
    }
    
    /// 创建模拟收据数据（字符串格式）
    /// - Returns: 模拟收据字符串
    public static func createMockReceiptString() -> String {
        return "mock_receipt_data_\(UUID().uuidString)"
    }
    
    /// 创建随机商品ID
    /// - Parameter prefix: ID前缀
    /// - Returns: 随机商品ID
    public static func createRandomProductID(prefix: String = "test") -> String {
        return "\(prefix).product.\(UUID().uuidString.prefix(8))"
    }
    
    /// 创建随机交易ID
    /// - Returns: 随机交易ID
    public static func createRandomTransactionID() -> String {
        return "tx_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }
}

// MARK: - Test Scenario Generators

extension TestDataGenerator {
    
    /// 创建购买流程测试场景
    /// - Returns: 包含商品和预期结果的测试场景
    public static func createPurchaseFlowScenario() -> (products: [IAPProduct], expectedResults: [IAPPurchaseResult]) {
        let products = [
            createProduct(id: "success.product", displayName: "Success Product"),
            createProduct(id: "cancel.product", displayName: "Cancel Product"),
            createProduct(id: "pending.product", displayName: "Pending Product")
        ]
        
        let results = [
            createSuccessfulPurchaseResult(),
            createCancelledPurchaseResult(),
            createPendingPurchaseResult()
        ]
        
        return (products, results)
    }
    
    /// 创建恢复购买测试场景
    /// - Returns: 恢复的交易数组
    public static func createRestorePurchasesScenario() -> [IAPTransaction] {
        return [
            createRestoredTransaction(productID: "nonconsumable.premium"),
            createRestoredTransaction(productID: "subscription.monthly"),
            createRestoredTransaction(productID: "subscription.yearly")
        ]
    }
    
    /// 创建错误处理测试场景
    /// - Returns: 包含各种错误的场景数组
    public static func createErrorHandlingScenarios() -> [(description: String, error: IAPError)] {
        return [
            ("Product not found", .productNotFound),
            ("Product not available", .productNotAvailable),
            ("Purchase cancelled", .purchaseCancelled),
            ("Network error", .networkError),
            ("Receipt validation failed", .receiptValidationFailed),
            ("Transaction processing failed", .transactionProcessingFailed("Test error")),
            ("Unknown error", .unknownError("Test unknown error"))
        ]
    }
    
    /// 创建性能测试场景
    /// - Parameter productCount: 商品数量
    /// - Returns: 大量商品的测试场景
    public static func createPerformanceTestScenario(productCount: Int = 100) -> [IAPProduct] {
        return createProducts(count: productCount, prefix: "perf.test")
    }
}