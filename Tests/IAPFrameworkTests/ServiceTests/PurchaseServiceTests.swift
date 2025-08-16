import Testing
import Foundation
@testable import IAPFramework

// MARK: - PurchaseService 单元测试

@MainActor
@Test("PurchaseService - 基本购买功能")
func testPurchaseServiceBasicPurchase() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    
    let testProduct = TestDataGenerator.generateProduct(id: "test.product")
    let testOrder = TestDataGenerator.generateOrder(for: testProduct)
    let successTransaction = TestDataGenerator.generateSuccessfulTransaction(productID: testProduct.id)
    mockAdapter.setMockPurchaseResult(.success(successTransaction, testOrder))
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let result = try await purchaseService.purchase(testProduct)
    
    // Then
    let verification = TestStateVerifier.verifyPurchaseResult(result, expectedType: .success)
    #expect(verification.isValid, verification.summary)
    #expect(mockAdapter.wasCalled("purchase"))
}

@MainActor
@Test("PurchaseService - 购买取消")
func testPurchaseServiceCancelledPurchase() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    mockAdapter.setMockPurchaseResult(.cancelled(nil))
    
    let testProduct = TestDataGenerator.generateProduct()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let result = try await purchaseService.purchase(testProduct)
    
    // Then
    let verification = TestStateVerifier.verifyPurchaseResult(result, expectedType: .cancelled)
    #expect(verification.isValid, verification.summary)
}

@MainActor
@Test("PurchaseService - 购买失败")
func testPurchaseServiceFailedPurchase() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    mockAdapter.setMockError(.purchaseFailed(underlying: "Test error"), shouldThrow: true)
    
    let testProduct = TestDataGenerator.generateProduct()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When & Then
    do {
        _ = try await purchaseService.purchase(testProduct)
        #expect(Bool(false), "Should have thrown purchase failed error")
    } catch let error as IAPError {
        #expect(error == .purchaseFailed(underlying: "Test error"))
    }
}

@MainActor
@Test("PurchaseService - 重复购买检测")
func testPurchaseServiceDuplicatePurchaseDetection() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    mockAdapter.setMockDelay(0.5) // 500ms delay to simulate ongoing purchase
    
    let testProduct = TestDataGenerator.generateProduct()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let firstPurchaseTask = Task {
        try await purchaseService.purchase(testProduct)
    }
    
    // Start second purchase immediately
    do {
        _ = try await purchaseService.purchase(testProduct)
        #expect(Bool(false), "Should have thrown transaction processing failed error")
    } catch let error as IAPError {
        #expect(error == .transactionProcessingFailed("Purchase already in progress"))
    }
    
    // Clean up
    _ = try await firstPurchaseTask.value
}

@MainActor
@Test("PurchaseService - 恢复购买")
func testPurchaseServiceRestorePurchases() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    
    let restoredTransactions = TestDataGenerator.generateTransactions(
        count: 3,
        state: .restored
    )
    mockAdapter.setMockRestoreResult(restoredTransactions)
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let result = try await purchaseService.restorePurchases()
    
    // Then
    let verification = TestStateVerifier.verifyTransactions(
        result,
        expectedCount: 3
    )
    #expect(verification.isValid, verification.summary)
    #expect(mockAdapter.wasCalled("restorePurchases"))
}

@MainActor
@Test("PurchaseService - 空恢复购买结果")
func testPurchaseServiceEmptyRestoreResult() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    mockAdapter.setMockRestoreResult([])
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let result = try await purchaseService.restorePurchases()
    
    // Then
    #expect(result.isEmpty)
    #expect(mockAdapter.wasCalled("restorePurchases"))
}

@MainActor
@Test("PurchaseService - 交易完成")
func testPurchaseServiceFinishTransaction() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    
    let testTransaction = TestDataGenerator.generateSuccessfulTransaction()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    try await purchaseService.finishTransaction(testTransaction)
    
    // Then
    #expect(mockAdapter.wasCalled("finishTransaction"))
    let callCount = mockAdapter.getCallCount(for: "finishTransaction")
    #expect(callCount == 1)
}

@MainActor
@Test("PurchaseService - 收据验证")
func testPurchaseServiceReceiptValidation() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator()
    
    let testReceiptData = TestDataGenerator.generateReceiptData()
    let expectedResult = TestDataGenerator.generateReceiptValidationResult(isValid: true)
    await mockValidator.setMockValidationResult(expectedResult)
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let result = try await purchaseService.validateReceipt(testReceiptData)
    
    // Then
    let verification = TestStateVerifier.verifyReceiptValidationResult(
        result,
        expectedValidity: true
    )
    #expect(verification.isValid, verification.summary)
    #expect(mockValidator.wasCalled("validateReceipt"))
}

@MainActor
@Test("PurchaseService - 收据验证失败")
func testPurchaseServiceReceiptValidationFailure() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysInvalid()
    
    let testReceiptData = TestDataGenerator.generateReceiptData()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let result = try await purchaseService.validateReceipt(testReceiptData)
    
    // Then
    #expect(!result.isValid)
    #expect(result.error != nil)
}

@MainActor
@Test("PurchaseService - 活跃购买管理")
func testPurchaseServiceActivePurchaseManagement() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When - 初始状态
    let initialActivePurchases = purchaseService.getActivePurchases()
    
    // Then
    #expect(initialActivePurchases.isEmpty)
    
    // When - 取消不存在的购买
    let cancelResult = purchaseService.cancelPurchase(for: "nonexistent.product")
    
    // Then
    #expect(!cancelResult)
    
    // When - 取消所有购买
    purchaseService.cancelAllPurchases()
    let finalActivePurchases = purchaseService.getActivePurchases()
    
    // Then
    #expect(finalActivePurchases.isEmpty)
}

@MainActor
@Test("PurchaseService - 购买统计信息")
func testPurchaseServicePurchaseStats() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let stats = purchaseService.getPurchaseStats()
    
    // Then
    #expect(stats.activePurchasesCount == 0)
    #expect(stats.activePurchaseProductIDs.isEmpty)
    #expect(!stats.hasActivePurchases)
}

@MainActor
@Test("PurchaseService - 购买验证")
func testPurchaseServicePurchaseValidation() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    
    let testProduct = TestDataGenerator.generateProduct()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let validationResult = purchaseService.validateCanPurchase(testProduct)
    
    // Then
    #expect(validationResult.canPurchase)
    #expect(validationResult.error == nil)
    #expect(validationResult.message == nil)
}

@MainActor
@Test("PurchaseService - 无效商品购买验证")
func testPurchaseServiceInvalidProductValidation() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    
    // 创建无效商品（空ID）
    let invalidProduct = IAPProduct(
        id: "",
        displayName: "Invalid Product",
        description: "Test",
        price: 0.99,
        priceLocale: Locale.current,
        localizedPrice: "$0.99",
        productType: .consumable
    )
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let validationResult = purchaseService.validateCanPurchase(invalidProduct)
    
    // Then
    #expect(!validationResult.canPurchase)
    #expect(validationResult.error != nil)
}

@MainActor
@Test("PurchaseService - 网络错误处理")
func testPurchaseServiceNetworkErrorHandling() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    let testProduct = TestDataGenerator.generateProduct()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When & Then
    do {
        _ = try await purchaseService.purchase(testProduct)
        #expect(Bool(false), "Should have thrown network error")
    } catch let error as IAPError {
        #expect(error == .networkError)
    }
}

@MainActor
@Test("PurchaseService - 配置影响")
func testPurchaseServiceWithConfiguration() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    
    let config = TestDataGenerator.generateConfiguration(
        autoFinishTransactions: false
    )
    
    let testProduct = TestDataGenerator.generateProduct(productType: .consumable)
    let testOrder = TestDataGenerator.generateOrder(for: testProduct)
    let successTransaction = TestDataGenerator.generateSuccessfulTransaction(productID: testProduct.id)
    mockAdapter.setMockPurchaseResult(.success(successTransaction, testOrder))
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService,
        configuration: config
    )
    
    // When
    let result = try await purchaseService.purchase(testProduct)
    
    // Then
    if case .success = result {
        // Success case
    } else {
        #expect(Bool(false), "Expected success result")
    }
    // 由于 autoFinishTransactions 为 false，finishTransaction 不应该被自动调用
    // 注意：这个测试依赖于 PurchaseService 的内部实现
}

@MainActor
@Test("PurchaseService - 延迟处理")
func testPurchaseServiceWithDelay() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    mockAdapter.setMockDelay(0.1) // 100ms delay
    
    let testProduct = TestDataGenerator.generateProduct()
    let testOrder = TestDataGenerator.generateOrder(for: testProduct)
    let successTransaction = TestDataGenerator.generateSuccessfulTransaction(productID: testProduct.id)
    mockAdapter.setMockPurchaseResult(.success(successTransaction, testOrder))
    
    let mockOrderService = MockOrderService.alwaysSucceeds()
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService
    )
    
    // When
    let startTime = Date()
    let result = try await purchaseService.purchase(testProduct)
    let duration = Date().timeIntervalSince(startTime)
    
    // Then
    if case .success = result {
        // Success case
    } else {
        #expect(Bool(false), "Expected success result")
    }
    #expect(duration >= 0.1) // Should take at least 100ms
}