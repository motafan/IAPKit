import Testing
@testable import IAPFramework

// MARK: - Basic Data Model Tests

@Test("IAPProduct Model Properties")
func testIAPProductModelProperties() {
    // Test basic product creation
    let product = IAPProduct.mock(
        id: "test.product",
        displayName: "Test Product",
        price: 9.99,
        productType: .consumable
    )
    
    #expect(product.id == "test.product")
    #expect(product.displayName == "Test Product")
    #expect(product.price == 9.99)
    #expect(product.productType == .consumable)
    #expect(product.isConsumable == true)
    #expect(product.isSubscription == false)
    
    // Test subscription product
    let subscriptionProduct = IAPProduct.mock(
        id: "subscription.monthly",
        displayName: "Monthly Subscription",
        price: 9.99,
        productType: .autoRenewableSubscription
    )
    
    #expect(subscriptionProduct.isSubscription == true)
    #expect(subscriptionProduct.isConsumable == false)
    
    // Test product equality
    let sameProduct = IAPProduct.mock(id: "test.product", displayName: "Different Name")
    #expect(product == sameProduct) // Equality based on ID
}

@Test("IAPTransaction Model Properties")
func testIAPTransactionModelProperties() {
    // Test successful transaction
    let successfulTransaction = IAPTransaction.successful(
        id: "tx_123",
        productID: "test.product"
    )
    
    #expect(successfulTransaction.id == "tx_123")
    #expect(successfulTransaction.productID == "test.product")
    #expect(successfulTransaction.isSuccessful == true)
    #expect(successfulTransaction.isFailed == false)
    #expect(successfulTransaction.isPending == false)
    #expect(successfulTransaction.failureError == nil)
    
    // Test failed transaction
    let failedTransaction = IAPTransaction.failed(
        id: "tx_456",
        productID: "test.product",
        error: .purchaseFailed(underlying: "Network error")
    )
    
    #expect(failedTransaction.isSuccessful == false)
    #expect(failedTransaction.isFailed == true)
    #expect(failedTransaction.failureError != nil)
    
    // Test pending transaction
    let pendingTransaction = IAPTransaction(
        id: "tx_789",
        productID: "test.product",
        purchaseDate: Date(),
        transactionState: .purchasing
    )
    
    #expect(pendingTransaction.isPending == true)
    #expect(pendingTransaction.isSuccessful == false)
}

@Test("IAPError Properties and Behavior")
func testIAPErrorPropertiesAndBehavior() {
    // Test error descriptions
    let productNotFoundError = IAPError.productNotFound
    #expect(productNotFoundError.errorDescription != nil)
    #expect(productNotFoundError.recoverySuggestion != nil)
    
    // Test error severity
    #expect(IAPError.purchaseCancelled.severity == .info)
    #expect(IAPError.networkError.severity == .warning)
    #expect(IAPError.receiptValidationFailed.severity == .critical)
    
    // Test error categories
    #expect(IAPError.purchaseCancelled.isUserCancelled == true)
    #expect(IAPError.networkError.isNetworkError == true)
    #expect(IAPError.timeout.isRetryable == true)
    #expect(IAPError.productNotFound.isRetryable == false)
    
    // Test error creation from system errors
    let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    let iapError = IAPError.from(nsError)
    #expect(iapError == .networkError)
    
    // Test error equality
    let error1 = IAPError.purchaseFailed(underlying: "Test message")
    let error2 = IAPError.purchaseFailed(underlying: "Test message")
    let error3 = IAPError.purchaseFailed(underlying: "Different message")
    
    #expect(error1 == error2)
    #expect(error1 != error3)
}

@Test("IAPPurchaseResult Equality")
func testIAPPurchaseResultEquality() {
    let transaction1 = IAPTransaction.successful(id: "tx1", productID: "test.product")
    let transaction2 = IAPTransaction.successful(id: "tx2", productID: "test.product")
    
    let result1 = IAPPurchaseResult.success(transaction1)
    let result2 = IAPPurchaseResult.success(transaction1) // Same transaction
    let result3 = IAPPurchaseResult.success(transaction2) // Different transaction
    let result4 = IAPPurchaseResult.cancelled
    let result5 = IAPPurchaseResult.cancelled
    
    #expect(result1 == result2)
    #expect(result1 != result3)
    #expect(result4 == result5)
    #expect(result1 != result4)
}

@Test("IAPReceiptValidationResult Properties")
func testIAPReceiptValidationResultProperties() {
    let transaction = IAPTransaction.successful(id: "tx1", productID: "test.product")
    let transactions = [transaction]
    
    // Test valid result
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
    
    // Test invalid result
    let invalidResult = IAPReceiptValidationResult(
        isValid: false,
        error: .receiptValidationFailed
    )
    
    #expect(invalidResult.isValid == false)
    #expect(invalidResult.error == .receiptValidationFailed)
    #expect(invalidResult.transactions.isEmpty)
}

// MARK: - Error Handling Tests

@Test("Comprehensive Error Handling")
func testComprehensiveErrorHandling() {
    let errors: [IAPError] = [
        .productNotFound,
        .purchaseCancelled,
        .purchaseFailed(underlying: "Test error"),
        .receiptValidationFailed,
        .networkError,
        .paymentNotAllowed,
        .productNotAvailable,
        .timeout,
        .unknownError("Unknown error")
    ]
    
    for error in errors {
        // Test that all errors have descriptions
        #expect(error.errorDescription != nil, "Error should have description")
        
        // Test that all errors have failure reasons
        #expect(error.failureReason != nil, "Error should have failure reason")
        
        // Test severity is assigned
        let severity = error.severity
        #expect([.info, .warning, .error, .critical].contains(severity), 
               "Error should have valid severity")
    }
}

@Test("Network Error Handling")
func testNetworkErrorHandling() {
    let networkErrors: [IAPError] = [
        .networkError,
        .timeout,
        .purchaseFailed(underlying: "Connection timeout")
    ]
    
    for error in networkErrors {
        if error == .networkError || error == .timeout {
            #expect(error.isNetworkError == true, "Should be identified as network error")
            #expect(error.isRetryable == true, "Network errors should be retryable")
        }
    }
}

// MARK: - Product Type Tests

@Test("Product Type Classification")
func testProductTypeClassification() {
    // Test consumable product
    let consumableProduct = IAPProduct.mock(
        id: "consumable.coins",
        displayName: "100 Coins",
        productType: .consumable
    )
    #expect(consumableProduct.isConsumable == true)
    #expect(consumableProduct.isSubscription == false)
    
    // Test non-consumable product
    let nonConsumableProduct = IAPProduct.mock(
        id: "nonconsumable.premium",
        displayName: "Premium Features",
        productType: .nonConsumable
    )
    #expect(nonConsumableProduct.isConsumable == false)
    #expect(nonConsumableProduct.isSubscription == false)
    
    // Test auto-renewable subscription
    let autoRenewableProduct = IAPProduct.mock(
        id: "subscription.monthly",
        displayName: "Monthly Subscription",
        productType: .autoRenewableSubscription
    )
    #expect(autoRenewableProduct.isConsumable == false)
    #expect(autoRenewableProduct.isSubscription == true)
    
    // Test non-renewing subscription
    let nonRenewingProduct = IAPProduct.mock(
        id: "subscription.season",
        displayName: "Season Pass",
        productType: .nonRenewingSubscription
    )
    #expect(nonRenewingProduct.isConsumable == false)
    #expect(nonRenewingProduct.isSubscription == true)
}

// MARK: - Transaction State Tests

@Test("Transaction State Validation")
func testTransactionStateValidation() {
    let productID = "test.product"
    
    // Test purchasing state
    let purchasingTransaction = IAPTransaction(
        id: "tx_purchasing",
        productID: productID,
        purchaseDate: Date(),
        transactionState: .purchasing
    )
    #expect(purchasingTransaction.isPending == true)
    #expect(purchasingTransaction.isSuccessful == false)
    #expect(purchasingTransaction.isFailed == false)
    
    // Test purchased state
    let purchasedTransaction = IAPTransaction(
        id: "tx_purchased",
        productID: productID,
        purchaseDate: Date(),
        transactionState: .purchased
    )
    #expect(purchasedTransaction.isPending == false)
    #expect(purchasedTransaction.isSuccessful == true)
    #expect(purchasedTransaction.isFailed == false)
    
    // Test failed state
    let failedTransaction = IAPTransaction(
        id: "tx_failed",
        productID: productID,
        purchaseDate: Date(),
        transactionState: .failed(.networkError)
    )
    #expect(failedTransaction.isPending == false)
    #expect(failedTransaction.isSuccessful == false)
    #expect(failedTransaction.isFailed == true)
    #expect(failedTransaction.failureError == .networkError)
    
    // Test restored state
    let restoredTransaction = IAPTransaction(
        id: "tx_restored",
        productID: productID,
        purchaseDate: Date(),
        transactionState: .restored
    )
    #expect(restoredTransaction.isPending == false)
    #expect(restoredTransaction.isSuccessful == true)
    #expect(restoredTransaction.isFailed == false)
    
    // Test deferred state
    let deferredTransaction = IAPTransaction(
        id: "tx_deferred",
        productID: productID,
        purchaseDate: Date(),
        transactionState: .deferred
    )
    #expect(deferredTransaction.isPending == true)
    #expect(deferredTransaction.isSuccessful == false)
    #expect(deferredTransaction.isFailed == false)
}

// MARK: - Configuration Tests

@Test("IAPConfiguration Default Values")
func testIAPConfigurationDefaultValues() {
    let defaultConfig = IAPConfiguration.default
    
    #expect(defaultConfig.enableDebugLogging == false)
    #expect(defaultConfig.autoFinishTransactions == true)
    #expect(defaultConfig.autoRecoverTransactions == true)
    #expect(defaultConfig.productCacheExpiration == 300) // 5 minutes
    
    // Test receipt validation config
    let receiptConfig = defaultConfig.receiptValidation
    #expect(receiptConfig.mode == .local)
    #expect(receiptConfig.timeout == 30)
}

@Test("IAPConfiguration Custom Values")
func testIAPConfigurationCustomValues() {
    let customReceiptConfig = IAPConfiguration.ReceiptValidationConfig(
        mode: .remote,
        timeout: 60
    )
    
    let customConfig = IAPConfiguration(
        enableDebugLogging: true,
        autoFinishTransactions: false,
        autoRecoverTransactions: false,
        productCacheExpiration: 600,
        receiptValidation: customReceiptConfig
    )
    
    #expect(customConfig.enableDebugLogging == true)
    #expect(customConfig.autoFinishTransactions == false)
    #expect(customConfig.autoRecoverTransactions == false)
    #expect(customConfig.productCacheExpiration == 600)
    #expect(customConfig.receiptValidation.mode == .remote)
    #expect(customConfig.receiptValidation.timeout == 60)
}

// MARK: - Protocol Conformance Tests

@Test("IAPManager Protocol Conformance")
@MainActor
func testIAPManagerProtocolConformance() {
    // Test that IAPManager conforms to IAPManagerProtocol
    let manager: IAPManagerProtocol = IAPManager.shared
    // Just test that the assignment works - this proves conformance
    #expect(true) // If we get here, conformance works
}

@Test("Sendable Protocol Conformance")
func testSendableProtocolConformance() {
    // Test that key types conform to Sendable
    let product: any Sendable = IAPProduct.mock(id: "test", displayName: "Test")
    let transaction: any Sendable = IAPTransaction.successful(id: "tx1", productID: "test")
    let error: any Sendable = IAPError.productNotFound
    let result: any Sendable = IAPPurchaseResult.cancelled
    
    // If we get here without compiler errors, Sendable conformance works
    #expect(true)
}

// MARK: - Basic Manager Tests

@Test("IAPManager Singleton Access")
@MainActor
func testIAPManagerSingletonAccess() {
    let manager1 = IAPManager.shared
    let manager2 = IAPManager.shared
    
    // Test that both references point to the same instance
    #expect(manager1 === manager2)
}

@Test("IAPManager Configuration Access")
@MainActor
func testIAPManagerConfigurationAccess() {
    let manager = IAPManager.shared
    
    // Test configuration access
    let config = manager.currentConfiguration
    #expect(config.enableDebugLogging == false) // Default value
    #expect(config.autoFinishTransactions == true) // Default value
    
    // Test state access
    let state = manager.currentState
    #expect(state.products.isEmpty == true) // Initially empty
    #expect(state.isBusy == false) // Initially not busy
}

@Test("IAPManager Debug Info")
@MainActor
func testIAPManagerDebugInfo() {
    let manager = IAPManager.shared
    
    // Test debug info
    let debugInfo = manager.getDebugInfo()
    #expect(debugInfo.keys.contains("isInitialized"))
    #expect(debugInfo.keys.contains("configuration"))
    #expect(debugInfo.keys.contains("state"))
    #expect(debugInfo.keys.contains("systemInfo"))
    
    // Test that debug info contains expected types
    if let configInfo = debugInfo["configuration"] as? [String: Any] {
        #expect(configInfo.keys.contains("enableDebugLogging"))
        #expect(configInfo.keys.contains("autoFinishTransactions"))
    }
    
    if let stateInfo = debugInfo["state"] as? [String: Any] {
        #expect(stateInfo.keys.contains("productsCount"))
        #expect(stateInfo.keys.contains("isBusy"))
    }
}

// MARK: - Convenience Method Tests

@Test("IAPManager Convenience Methods")
@MainActor
func testIAPManagerConvenienceMethods() {
    let manager = IAPManager.shared
    
    // Test convenience properties
    let isBusy = manager.isBusy
    #expect(isBusy == false) // Initially not busy
    
    let isObserverActive = manager.isTransactionObserverActive
    #expect(isObserverActive == false) // Initially not active
}

// MARK: - Product Validation Tests

@Test("Product ID Validation")
func testProductIDValidation() {
    // Test valid product IDs
    let validIDs = [
        "com.app.product1",
        "com.app.product_2",
        "product.123",
        "a.b.c.d.e"
    ]
    
    for id in validIDs {
        let product = IAPProduct.mock(id: id, displayName: "Test")
        #expect(product.id == id, "Valid product ID should be preserved")
    }
    
    // Test that products with different IDs are not equal
    let product1 = IAPProduct.mock(id: "product1", displayName: "Product 1")
    let product2 = IAPProduct.mock(id: "product2", displayName: "Product 2")
    #expect(product1 != product2, "Products with different IDs should not be equal")
}

// MARK: - Price and Localization Tests

@Test("Product Price Handling")
func testProductPriceHandling() {
    // Test various price values
    let freeProduct = IAPProduct.mock(id: "free", displayName: "Free Product", price: 0.00)
    #expect(freeProduct.price == 0.00)
    
    let cheapProduct = IAPProduct.mock(id: "cheap", displayName: "Cheap Product", price: 0.99)
    #expect(cheapProduct.price == 0.99)
    
    let expensiveProduct = IAPProduct.mock(id: "expensive", displayName: "Expensive Product", price: 99.99)
    #expect(expensiveProduct.price == 99.99)
    
    // Test that localized price is generated
    #expect(freeProduct.localizedPrice.isEmpty == false)
    #expect(cheapProduct.localizedPrice.isEmpty == false)
    #expect(expensiveProduct.localizedPrice.isEmpty == false)
}

// MARK: - Transaction Quantity Tests

@Test("Transaction Quantity Handling")
func testTransactionQuantityHandling() {
    // Test default quantity
    let defaultTransaction = IAPTransaction.successful(id: "tx1", productID: "product1")
    #expect(defaultTransaction.quantity == 1)
    
    // Test custom quantity
    let multipleTransaction = IAPTransaction(
        id: "tx2",
        productID: "product2",
        purchaseDate: Date(),
        transactionState: .purchased,
        quantity: 5
    )
    #expect(multipleTransaction.quantity == 5)
}

// MARK: - Receipt Environment Tests

@Test("Receipt Environment Handling")
func testReceiptEnvironmentHandling() {
    // Test sandbox environment
    let sandboxResult = IAPReceiptValidationResult(
        isValid: true,
        environment: .sandbox
    )
    #expect(sandboxResult.environment == .sandbox)
    
    // Test production environment
    let productionResult = IAPReceiptValidationResult(
        isValid: true,
        environment: .production
    )
    #expect(productionResult.environment == .production)
    
    // Test no environment specified
    let noEnvResult = IAPReceiptValidationResult(isValid: true)
    #expect(noEnvResult.environment == nil)
}
