import Foundation
import Testing
@testable import IAPKit

// MARK: - 核心功能单元测试

@Test("商品模型属性验证")
func testProductModelProperties() {
    // 测试基本商品创建
    let product = IAPProduct.mock(
        id: "test.product",
        displayName: "测试商品",
        price: 9.99,
        productType: .consumable
    )
    
    #expect(product.id == "test.product")
    #expect(product.displayName == "测试商品")
    #expect(product.price == 9.99)
    #expect(product.productType == .consumable)
    #expect(product.isConsumable == true)
    #expect(product.isSubscription == false)
    
    // 测试订阅商品
    let subscriptionProduct = IAPProduct.mock(
        id: "subscription.monthly",
        displayName: "月度订阅",
        price: 9.99,
        productType: .autoRenewableSubscription
    )
    
    #expect(subscriptionProduct.isSubscription == true)
    #expect(subscriptionProduct.isConsumable == false)
    
    // 测试商品相等性（基于ID）
    let sameProduct = IAPProduct.mock(id: "test.product", displayName: "不同名称")
    #expect(product == sameProduct)
}

@Test("交易模型状态验证")
func testTransactionModelStates() {
    let productID = "test.product"
    
    // 测试成功交易
    let successfulTransaction = IAPTransaction.successful(
        id: "tx_success",
        productID: productID
    )
    
    #expect(successfulTransaction.id == "tx_success")
    #expect(successfulTransaction.productID == productID)
    #expect(successfulTransaction.isSuccessful == true)
    #expect(successfulTransaction.isFailed == false)
    #expect(successfulTransaction.isPending == false)
    #expect(successfulTransaction.failureError == nil)
    
    // 测试失败交易
    let failedTransaction = IAPTransaction.failed(
        id: "tx_failed",
        productID: productID,
        error: .purchaseFailed(underlying: "网络错误")
    )
    
    #expect(failedTransaction.isSuccessful == false)
    #expect(failedTransaction.isFailed == true)
    #expect(failedTransaction.failureError != nil)
    
    // 测试待处理交易
    let pendingTransaction = IAPTransaction(
        id: "tx_pending",
        productID: productID,
        purchaseDate: Date(),
        transactionState: .purchasing
    )
    
    #expect(pendingTransaction.isPending == true)
    #expect(pendingTransaction.isSuccessful == false)
    #expect(pendingTransaction.isFailed == false)
    
    // 测试恢复交易
    let restoredTransaction = IAPTransaction(
        id: "tx_restored",
        productID: productID,
        purchaseDate: Date(),
        transactionState: .restored
    )
    
    #expect(restoredTransaction.isSuccessful == true)
    #expect(restoredTransaction.isPending == false)
    #expect(restoredTransaction.isFailed == false)
    
    // 测试延期交易
    let deferredTransaction = IAPTransaction(
        id: "tx_deferred",
        productID: productID,
        purchaseDate: Date(),
        transactionState: .deferred
    )
    
    #expect(deferredTransaction.isPending == true)
    #expect(deferredTransaction.isSuccessful == false)
}

@Test("错误处理和分类")
func testErrorHandlingAndClassification() {
    // 测试错误描述
    let productNotFoundError = IAPError.productNotFound
    #expect(productNotFoundError.errorDescription != nil)
    #expect(productNotFoundError.recoverySuggestion != nil)
    
    // 测试错误严重程度
    #expect(IAPError.purchaseCancelled.severity == .info)
    #expect(IAPError.networkError.severity == .warning)
    #expect(IAPError.receiptValidationFailed.severity == .critical)
    
    // 测试错误分类
    #expect(IAPError.purchaseCancelled.isUserCancelled == true)
    #expect(IAPError.networkError.isNetworkError == true)
    #expect(IAPError.timeout.isRetryable == true)
    #expect(IAPError.productNotFound.isRetryable == false)
    
    // 测试系统错误转换
    let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    let iapError = IAPError.from(nsError)
    #expect(iapError == .networkError)
    
    // 测试错误相等性
    let error1 = IAPError.purchaseFailed(underlying: "测试消息")
    let error2 = IAPError.purchaseFailed(underlying: "测试消息")
    let error3 = IAPError.purchaseFailed(underlying: "不同消息")
    
    #expect(error1 == error2)
    #expect(error1 != error3)
}

@Test("购买结果相等性")
func testPurchaseResultEquality() {
    let transaction1 = IAPTransaction.successful(id: "tx1", productID: "test.product")
    let transaction2 = IAPTransaction.successful(id: "tx2", productID: "test.product")
    
    let order1 = TestDataGenerator.generateOrder()
    let order2 = TestDataGenerator.generateOrder()
    
    let result1 = IAPPurchaseResult.success(transaction1, order1)
    let result2 = IAPPurchaseResult.success(transaction1, order1) // 相同交易
    let result3 = IAPPurchaseResult.success(transaction2, order2) // 不同交易
    let result4 = IAPPurchaseResult.cancelled(nil)
    let result5 = IAPPurchaseResult.cancelled(nil)
    
    #expect(result1 == result2)
    #expect(result1 != result3)
    #expect(result4 == result5)
    #expect(result1 != result4)
}

@Test("收据验证结果")
func testReceiptValidationResult() {
    let transaction = IAPTransaction.successful(id: "tx1", productID: "test.product")
    let transactions = [transaction]
    
    // 测试有效结果
    let validResult = IAPReceiptValidationResult(
        isValid: true,
        transactions: transactions,
        receiptCreationDate: Date(),
        appVersion: "1.0.0",
        originalAppVersion: "1.0.0"
    )
    
    #expect(validResult.isValid == true)
    #expect(validResult.transactions.count == 1)
    #expect(validResult.error == nil)
    #expect(validResult.appVersion == "1.0.0")
    
    // 测试无效结果
    let invalidResult = IAPReceiptValidationResult(
        isValid: false,
        error: .receiptValidationFailed
    )
    
    #expect(invalidResult.isValid == false)
    #expect(invalidResult.error == .receiptValidationFailed)
    #expect(invalidResult.transactions.isEmpty)
}

@Test("商品类型分类")
func testProductTypeClassificationCore() {
    // 测试消耗型商品
    let consumableProduct = IAPProduct.mock(
        id: "consumable.coins",
        displayName: "100金币",
        productType: .consumable
    )
    #expect(consumableProduct.isConsumable == true)
    #expect(consumableProduct.isSubscription == false)
    
    // 测试非消耗型商品
    let nonConsumableProduct = IAPProduct.mock(
        id: "nonconsumable.premium",
        displayName: "高级功能",
        productType: .nonConsumable
    )
    #expect(nonConsumableProduct.isConsumable == false)
    #expect(nonConsumableProduct.isSubscription == false)
    
    // 测试自动续费订阅
    let autoRenewableProduct = IAPProduct.mock(
        id: "subscription.monthly",
        displayName: "月度订阅",
        productType: .autoRenewableSubscription
    )
    #expect(autoRenewableProduct.isConsumable == false)
    #expect(autoRenewableProduct.isSubscription == true)
    
    // 测试非续费订阅
    let nonRenewingProduct = IAPProduct.mock(
        id: "subscription.season",
        displayName: "季票",
        productType: .nonRenewingSubscription
    )
    #expect(nonRenewingProduct.isConsumable == false)
    #expect(nonRenewingProduct.isSubscription == true)
}

@Test("配置默认值验证")
func testConfigurationDefaultValues() {
    let defaultConfig = IAPConfiguration.default
    
    #expect(defaultConfig.enableDebugLogging == false)
    #expect(defaultConfig.autoFinishTransactions == true)
    #expect(defaultConfig.autoRecoverTransactions == true)
    #expect(defaultConfig.productCacheExpiration == 300) // 5分钟
    
    // 测试收据验证配置
    let receiptConfig = defaultConfig.receiptValidation
    #expect(receiptConfig.mode == .local)
    #expect(receiptConfig.timeout == 30)
}

@Test("自定义配置创建")
func testCustomConfigurationCreation() {
    let customReceiptConfig = ReceiptValidationConfiguration(
        mode: .remote,
        timeout: 60
    )
    
    let customConfig = IAPConfiguration(
        enableDebugLogging: true,
        autoFinishTransactions: false,
        productCacheExpiration: 600,
        autoRecoverTransactions: false,
        receiptValidation: customReceiptConfig
    )
    
    #expect(customConfig.enableDebugLogging == true)
    #expect(customConfig.autoFinishTransactions == false)
    #expect(customConfig.autoRecoverTransactions == false)
    #expect(customConfig.productCacheExpiration == 600)
    #expect(customConfig.receiptValidation.mode == .remote)
    #expect(customConfig.receiptValidation.timeout == 60)
}

@Test("价格处理验证")
func testPriceHandling() {
    // 测试各种价格值
    let freeProduct = IAPProduct.mock(id: "free", displayName: "免费商品", price: 0.00)
    #expect(freeProduct.price == 0.00)
    
    let cheapProduct = IAPProduct.mock(id: "cheap", displayName: "便宜商品", price: 0.99)
    #expect(cheapProduct.price == 0.99)
    
    let expensiveProduct = IAPProduct.mock(id: "expensive", displayName: "昂贵商品", price: 99.99)
    #expect(expensiveProduct.price == 99.99)
    
    // 测试本地化价格生成
    #expect(freeProduct.localizedPrice.isEmpty == false)
    #expect(cheapProduct.localizedPrice.isEmpty == false)
    #expect(expensiveProduct.localizedPrice.isEmpty == false)
}

@Test("交易数量处理")
func testTransactionQuantityHandlingCore() {
    // 测试默认数量
    let defaultTransaction = IAPTransaction.successful(id: "tx1", productID: "product1")
    #expect(defaultTransaction.quantity == 1)
    
    // 测试自定义数量
    let multipleTransaction = IAPTransaction(
        id: "tx2",
        productID: "product2",
        purchaseDate: Date(),
        transactionState: .purchased,
        quantity: 5
    )
    #expect(multipleTransaction.quantity == 5)
}

@Test("收据环境处理")
func testReceiptEnvironmentHandlingCore() {
    // 测试沙盒环境
    let sandboxResult = IAPReceiptValidationResult(
        isValid: true,
        environment: .sandbox
    )
    #expect(sandboxResult.environment == .sandbox)
    
    // 测试生产环境
    let productionResult = IAPReceiptValidationResult(
        isValid: true,
        environment: .production
    )
    #expect(productionResult.environment == .production)
    
    // 测试未指定环境
    let noEnvResult = IAPReceiptValidationResult(isValid: true)
    #expect(noEnvResult.environment == nil)
}

@Test("协议一致性验证")
@MainActor
func testProtocolConformance() {
    // 测试IAPManager符合IAPManagerProtocol
    let _: IAPManagerProtocol = IAPManager.shared
    // 如果能到这里，说明协议一致性正常
    #expect(Bool(true))
}

@Test("Sendable协议一致性")
func testSendableConformance() {
    // 测试关键类型符合Sendable
    let _: any Sendable = IAPProduct.mock(id: "test", displayName: "测试")
    let _: any Sendable = IAPTransaction.successful(id: "tx1", productID: "test")
    let _: any Sendable = IAPError.productNotFound
    let _: any Sendable = IAPPurchaseResult.cancelled(nil)
    
    // 如果编译通过，说明Sendable一致性正常
    #expect(Bool(true))
}

@Test("管理器单例访问")
@MainActor
func testManagerSingletonAccess() {
    let manager1 = IAPManager.shared
    let manager2 = IAPManager.shared
    
    // 测试两个引用指向同一实例
    #expect(manager1 === manager2)
}

@Test("管理器配置访问")
@MainActor
func testManagerConfigurationAccess() {
    let manager = IAPManager.shared
    
    // 测试配置访问
    let config = manager.currentConfiguration
    #expect(config.enableDebugLogging == false) // 默认值
    #expect(config.autoFinishTransactions == true) // 默认值
    
    // 测试状态访问
    let state = manager.currentState
    #expect(state.products.isEmpty == true) // 初始为空
    #expect(state.isBusy == false) // 初始不忙碌
}

@Test("管理器调试信息")
@MainActor
func testManagerDebugInfo() {
    let manager = IAPManager.shared
    
    // 测试调试信息
    let debugInfo = manager.getDebugInfo()
    #expect(debugInfo.keys.contains("isInitialized"))
    #expect(debugInfo.keys.contains("configuration"))
    #expect(debugInfo.keys.contains("state"))
    #expect(debugInfo.keys.contains("systemInfo"))
    
    // 测试调试信息包含预期类型
    if let configInfo = debugInfo["configuration"] as? [String: Any] {
        #expect(configInfo.keys.contains("enableDebugLogging"))
        #expect(configInfo.keys.contains("autoFinishTransactions"))
    }
    
    if let stateInfo = debugInfo["state"] as? [String: Any] {
        #expect(stateInfo.keys.contains("productsCount"))
        #expect(stateInfo.keys.contains("isBusy"))
    }
}

@Test("管理器便利方法")
@MainActor
func testManagerConvenienceMethods() {
    let manager = IAPManager.shared
    
    // 测试便利属性
    let isBusy = manager.isBusy
    #expect(isBusy == false) // 初始不忙碌
    
    let isObserverActive = manager.isTransactionObserverActive
    #expect(isObserverActive == false) // 初始未激活
}

@Test("商品ID验证")
func testProductIDValidationCore() {
    // 测试有效商品ID
    let validIDs = [
        "com.app.product1",
        "com.app.product_2",
        "product.123",
        "a.b.c.d.e"
    ]
    
    for id in validIDs {
        let product = IAPProduct.mock(id: id, displayName: "测试")
        #expect(product.id == id, "有效商品ID应该被保留")
    }
    
    // 测试不同ID的商品不相等
    let product1 = IAPProduct.mock(id: "product1", displayName: "商品1")
    let product2 = IAPProduct.mock(id: "product2", displayName: "商品2")
    #expect(product1 != product2, "不同ID的商品应该不相等")
}

@Test("综合错误处理")
func testComprehensiveErrorHandlingCore() {
    let errors: [IAPError] = [
        .productNotFound,
        .purchaseCancelled,
        .purchaseFailed(underlying: "测试错误"),
        .receiptValidationFailed,
        .networkError,
        .paymentNotAllowed,
        .productNotAvailable,
        .timeout,
        .unknownError("未知错误")
    ]
    
    for error in errors {
        // 测试所有错误都有描述
        #expect(error.errorDescription != nil, "错误应该有描述")
        
        // 测试所有错误都有失败原因
        #expect(error.failureReason != nil, "错误应该有失败原因")
        
        // 测试严重程度已分配
        let severity = error.severity
        #expect([.info, .warning, .error, .critical].contains(severity), 
               "错误应该有有效的严重程度")
    }
}

@Test("网络错误处理")
func testNetworkErrorHandlingCore() {
    let networkErrors: [IAPError] = [
        .networkError,
        .timeout,
        .purchaseFailed(underlying: "连接超时")
    ]
    
    for error in networkErrors {
        if error == .networkError || error == .timeout {
            #expect(error.isNetworkError == true, "应该被识别为网络错误")
            #expect(error.isRetryable == true, "网络错误应该可重试")
        }
    }
}
