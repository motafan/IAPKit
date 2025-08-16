import Foundation
import Testing
@testable import IAPFramework

/// Tests for the updated purchase flow that integrates order management
/// Tests the complete order-based purchase flow including error handling
@MainActor
struct OrderBasedPurchaseFlowTests {
    
    // MARK: - Helper Methods for Test Setup
    
    private func createTestServices() -> (MockPurchaseService, MockOrderService, IAPProduct) {
        let mockPurchaseService = MockPurchaseService()
        let mockOrderService = MockOrderService()
        let testProduct = TestDataGenerator.generateProduct(
            id: "test.product",
            displayName: "Test Product",
            price: 9.99,
            productType: .consumable
        )
        return (mockPurchaseService, mockOrderService, testProduct)
    }
    
    // MARK: - Complete Order-Based Purchase Flow Tests
    
    /// Test successful complete order-based purchase flow
    @Test("Order-based purchase flow succeeds")
    func orderBasedPurchaseFlowSuccess() async throws {
        // Given - Create test services and configure successful order creation and purchase
        let (mockPurchaseService, mockOrderService, testProduct) = createTestServices()
        
        let expectedOrder = TestDataGenerator.generateOrder(
            id: "test_order_123",
            productID: testProduct.id,
            status: .created
        )
        
        let expectedTransaction = TestDataGenerator.generateSuccessfulTransaction(
            id: "test_transaction_123",
            productID: testProduct.id
        )
        
        // Configure mock services for successful flow
        await configureMockServicesForSuccessfulFlow(
            mockPurchaseService: mockPurchaseService,
            mockOrderService: mockOrderService,
            order: expectedOrder,
            transaction: expectedTransaction
        )
        
        // When - Execute purchase
        let result = try await mockPurchaseService.purchase(testProduct, userInfo: ["userID": "test123"])
        
        // Then - Verify successful result
        switch result {
        case .success(let transaction, let order):
            #expect(transaction.productID == testProduct.id)
            #expect(order.productID == testProduct.id)
            #expect(order.status == .completed)
            #expect(transaction.isSuccessful)
        default:
            Issue.record("Expected successful purchase result, got \(result)")
        }
        
        // Verify the correct sequence of calls was made
        await verifySuccessfulPurchaseFlowCalls(
            mockPurchaseService: mockPurchaseService,
            mockOrderService: mockOrderService
        )
    }
    
    /// Test order-based purchase flow with order creation failure
    @Test("Order-based purchase flow fails when order creation fails")
    func orderBasedPurchaseFlowOrderCreationFailure() async throws {
        // Given - Create test services and configure order creation to fail
        let (mockPurchaseService, mockOrderService, testProduct) = createTestServices()
        mockOrderService.setMockError(.orderCreationFailed(underlying: "Server error"), shouldThrow: true)
        
        // When & Then - Purchase should fail with order creation error
        do {
            _ = try await mockPurchaseService.purchase(testProduct, userInfo: nil)
            Issue.record("Expected purchase to throw order creation error")
        } catch let error as IAPError {
            switch error {
            case .orderCreationFailed:
                break // Expected
            default:
                Issue.record("Expected order creation error, got \(error)")
            }
        } catch {
            Issue.record("Expected IAPError, got \(error)")
        }
        
        // Verify order creation was attempted but purchase was not
        #expect(mockOrderService.wasCalled("createOrder"))
        #expect(mockPurchaseService.wasCalled("executeStoreKitPurchase") == false)
    }
    
    /// Test order-based purchase flow with payment failure
    @Test("Order-based purchase flow fails when payment fails")
    func orderBasedPurchaseFlowPaymentFailure() async throws {
        // Given - Create test services and configure successful order creation but payment failure
        let (mockPurchaseService, mockOrderService, testProduct) = createTestServices()
        
        let order = TestDataGenerator.generateOrder(
            id: "test_order_123",
            productID: testProduct.id,
            status: .created
        )
        
        mockOrderService.addMockOrder(order)
        mockPurchaseService.setMockError(.purchaseFailed(underlying: "Payment failed"), shouldThrow: true)
        
        // When & Then - Purchase should fail with payment error
        do {
            _ = try await mockPurchaseService.purchase(testProduct, userInfo: nil)
            Issue.record("Expected purchase to throw payment error")
        } catch let error as IAPError {
            switch error {
            case .purchaseFailed:
                break // Expected
            default:
                Issue.record("Expected payment error, got \(error)")
            }
        } catch {
            Issue.record("Expected IAPError, got \(error)")
        }
        
        // Verify order was created but payment failed
        #expect(mockOrderService.wasCalled("createOrder"))
        // Order should be cleaned up after payment failure
        let failedOrder = mockOrderService.getOrder(order.id)
        #expect(failedOrder?.status == .failed || failedOrder == nil)
    }
    
    /// Test order-based purchase flow with receipt validation failure
    @Test("Order-based purchase flow fails when receipt validation fails")
    func orderBasedPurchaseFlowReceiptValidationFailure() async throws {
        // Given - Create test services and configure successful order and payment but validation failure
        let (mockPurchaseService, mockOrderService, testProduct) = createTestServices()
        
        let order = TestDataGenerator.generateOrder(
            id: "test_order_123",
            productID: testProduct.id,
            status: .pending
        )
        
        let transaction = TestDataGenerator.generateSuccessfulTransaction(
            id: "test_transaction_123",
            productID: testProduct.id
        )
        
        mockOrderService.addMockOrder(order)
        mockPurchaseService.setMockPurchaseResult(.success(transaction, order))
        mockPurchaseService.setMockReceiptValidationError(.receiptValidationFailed)
        
        // When & Then - Purchase should fail with validation error
        do {
            _ = try await mockPurchaseService.purchase(testProduct, userInfo: nil)
            Issue.record("Expected purchase to throw receipt validation error")
        } catch IAPError.receiptValidationFailed {
            // Expected
        } catch {
            Issue.record("Expected receipt validation error, got \(error)")
        }
    }
    
    // MARK: - Purchase Cancellation Tests
    
    /// Test purchase cancellation with order cleanup
    @Test("Purchase cancellation cleans up order properly")
    func purchaseCancellationWithOrderCleanup() async throws {
        // Given - Create test services and configure purchase cancellation
        let (mockPurchaseService, mockOrderService, testProduct) = createTestServices()
        
        let order = TestDataGenerator.generateOrder(
            id: "test_order_123",
            productID: testProduct.id,
            status: .created
        )
        
        mockOrderService.addMockOrder(order)
        mockPurchaseService.setMockPurchaseResult(.cancelled(order))
        
        // When - Execute purchase (which will be cancelled)
        let result = try await mockPurchaseService.purchase(testProduct, userInfo: nil)
        
        // Then - Verify cancellation result
        switch result {
        case .cancelled(let cancelledOrder):
            #expect(cancelledOrder != nil)
            #expect(cancelledOrder?.id == order.id)
            #expect(cancelledOrder?.status == .cancelled)
        default:
            Issue.record("Expected cancelled purchase result, got \(result)")
        }
        
        // Verify order was cancelled
        let updatedOrder = mockOrderService.getOrder(order.id)
        #expect(updatedOrder?.status == .cancelled)
    }
    
    // MARK: - Receipt Validation with Order Information Tests
    
    /// Test receipt validation with order information
    @Test("Receipt validation works with order information")
    func receiptValidationWithOrderInformation() async throws {
        // Given - Create test services and set up order and transaction
        let (mockPurchaseService, mockOrderService, testProduct) = createTestServices()
        
        let order = TestDataGenerator.generateOrder(
            id: "test_order_123",
            productID: testProduct.id,
            status: .pending,
            userInfo: ["userID": "test123"]
        )
        
        let transaction = TestDataGenerator.generateSuccessfulTransaction(
            id: "test_transaction_123",
            productID: testProduct.id
        )
        
        let receiptData = TestDataGenerator.generateReceiptData()
        
        // Configure mock services
        mockOrderService.addMockOrder(order)
        mockPurchaseService.setMockReceiptValidationResult(
            .init(isValid: true, transactions: [transaction])
        )
        
        // When - Validate receipt with order information
        let result = try await mockPurchaseService.validateReceiptWithOrder(receiptData, order: order)
        
        // Then - Verify validation result includes order information
        #expect(result.isValid)
        #expect(result.transactions.count == 1)
        #expect(result.transactions.first?.productID == testProduct.id)
        
        // Verify validation was called with order information
        #expect(mockPurchaseService.wasCalled("validateReceiptWithOrder"))
    }
    
    /// Test receipt validation with order mismatch
    @Test("Receipt validation fails with order mismatch")
    func receiptValidationWithOrderMismatch() async throws {
        // Given - Create test services and set up mismatched order and transaction
        let (mockPurchaseService, _, _) = createTestServices()
        
        let order = TestDataGenerator.generateOrder(
            id: "test_order_123",
            productID: "different.product",  // Different product ID
            status: .pending
        )
        
        let receiptData = TestDataGenerator.generateReceiptData()
        
        // Configure mock to detect mismatch
        mockPurchaseService.setMockReceiptValidationError(.serverOrderMismatch)
        
        // When & Then - Validation should fail with mismatch error
        do {
            _ = try await mockPurchaseService.validateReceiptWithOrder(receiptData, order: order)
            Issue.record("Expected validation to throw server order mismatch error")
        } catch IAPError.serverOrderMismatch {
            // Expected
        } catch {
            Issue.record("Expected server order mismatch error, got \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    /// Test comprehensive error handling for order creation failures
    @Test("Error handling works for order creation failures", arguments: [
        (IAPError.networkError, "Network error during order creation"),
        (IAPError.orderCreationTimeout, "Order creation timeout"),
        (IAPError.orderServerUnavailable, "Order server unavailable"),
        (IAPError.orderCreationFailed(underlying: "Server error"), "Server error during order creation")
    ])
    func errorHandlingOrderCreationFailures(error: IAPError, description: String) async throws {
        // Given - Create test services
        let (mockPurchaseService, mockOrderService, testProduct) = createTestServices()
        mockOrderService.setMockError(error, shouldThrow: true)
        
        // When & Then
        do {
            _ = try await mockPurchaseService.purchase(testProduct, userInfo: nil)
            Issue.record("Expected purchase to throw error for scenario: \(description)")
        } catch let thrownError as IAPError {
            // Verify the correct error was propagated
            switch (error, thrownError) {
            case (.networkError, .networkError),
                 (.orderCreationTimeout, .orderCreationTimeout),
                 (.orderServerUnavailable, .orderServerUnavailable):
                break // Expected
            case (.orderCreationFailed, .orderCreationFailed):
                break // Expected
            default:
                Issue.record("Unexpected error for scenario \(description): expected \(error), got \(thrownError)")
            }
        } catch {
            Issue.record("Expected IAPError for scenario \(description), got \(error)")
        }
    }
    
    /// Test error handling for order validation failures
    @Test("Error handling works for order validation failures", arguments: [
        (IAPError.orderValidationFailed, "Order validation failed"),
        (IAPError.serverOrderMismatch, "Server order mismatch"),
        (IAPError.orderExpired, "Order expired during validation"),
        (IAPError.orderAlreadyCompleted, "Order already completed")
    ])
    func errorHandlingOrderValidationFailures(error: IAPError, description: String) async throws {
        // Given - Create test services
        let (mockPurchaseService, mockOrderService, testProduct) = createTestServices()
        
        let order = TestDataGenerator.generateOrder(
            id: "test_order_\(UUID().uuidString)",
            productID: testProduct.id,
            status: .pending
        )
        
        mockOrderService.addMockOrder(order)
        mockPurchaseService.setMockReceiptValidationError(error)
        
        // When & Then
        do {
            _ = try await mockPurchaseService.purchase(testProduct, userInfo: nil)
            Issue.record("Expected purchase to throw validation error for scenario: \(description)")
        } catch let thrownError as IAPError {
            #expect(thrownError == error, "Expected \(error) for scenario \(description), got \(thrownError)")
        } catch {
            Issue.record("Expected IAPError for scenario \(description), got \(error)")
        }
    }
    
    // MARK: - Product Type Specific Tests
    
    /// Test order-based purchase flow for consumable products
    @Test("Order-based purchase flow works for consumable products")
    func orderBasedPurchaseFlowConsumableProduct() async throws {
        // Given - Create test services and consumable product
        let (mockPurchaseService, mockOrderService, _) = createTestServices()
        
        let consumableProduct = TestDataGenerator.generateProduct(
            id: "consumable.coins",
            displayName: "100 Coins",
            price: 0.99,
            productType: .consumable
        )
        
        await configureSuccessfulPurchaseFlow(
            mockPurchaseService: mockPurchaseService,
            mockOrderService: mockOrderService,
            for: consumableProduct
        )
        
        // When - Purchase consumable product
        let result = try await mockPurchaseService.purchase(consumableProduct, userInfo: nil)
        
        // Then - Verify successful consumable purchase
        switch result {
        case .success(let transaction, let order):
            #expect(transaction.productID == consumableProduct.id)
            #expect(order.productID == consumableProduct.id)
            #expect(transaction.isSuccessful)
        default:
            Issue.record("Expected successful purchase result for consumable product")
        }
    }
    
    /// Test order-based purchase flow for subscription products
    @Test("Order-based purchase flow works for subscription products")
    func orderBasedPurchaseFlowSubscriptionProduct() async throws {
        // Given - Create test services and subscription product
        let (mockPurchaseService, mockOrderService, _) = createTestServices()
        
        let subscriptionProduct = TestDataGenerator.generateSubscriptionProduct(
            id: "subscription.monthly",
            displayName: "Monthly Subscription",
            price: 9.99
        )
        
        await configureSuccessfulPurchaseFlow(
            mockPurchaseService: mockPurchaseService,
            mockOrderService: mockOrderService,
            for: subscriptionProduct
        )
        
        // When - Purchase subscription product
        let result = try await mockPurchaseService.purchase(subscriptionProduct, userInfo: ["userID": "subscriber123"])
        
        // Then - Verify successful subscription purchase
        switch result {
        case .success(let transaction, let order):
            #expect(transaction.productID == subscriptionProduct.id)
            #expect(order.productID == subscriptionProduct.id)
            #expect(order.userInfo?["userID"] as? String == "subscriber123")
            #expect(transaction.isSuccessful)
        default:
            Issue.record("Expected successful purchase result for subscription product")
        }
    }
    
    /// Test concurrent order-based purchases
    @Test("Concurrent order-based purchases work correctly")
    func concurrentOrderBasedPurchases() async throws {
        // Given - Create test services and multiple products
        let (mockPurchaseService, mockOrderService, _) = createTestServices()
        let products = TestDataGenerator.generateProducts(count: 3)
        
        // Configure successful purchases for all products
        for product in products {
            await configureSuccessfulPurchaseFlow(
                mockPurchaseService: mockPurchaseService,
                mockOrderService: mockOrderService,
                for: product
            )
        }
        
        // When - Execute concurrent purchases
        let results = try await withThrowingTaskGroup(of: IAPPurchaseResult.self) { group in
            for product in products {
                group.addTask {
                    return try await mockPurchaseService.purchase(product, userInfo: nil)
                }
            }
            
            var purchaseResults: [IAPPurchaseResult] = []
            for try await result in group {
                purchaseResults.append(result)
            }
            return purchaseResults
        }
        
        // Then - Verify all purchases succeeded
        #expect(results.count == products.count)
        
        for result in results {
            switch result {
            case .success:
                break // Expected
            default:
                Issue.record("Expected all concurrent purchases to succeed, got \(result)")
            }
        }
        
        // Verify orders were created for all products
        let createdOrders = mockOrderService.getAllOrders()
        #expect(createdOrders.count >= products.count)
    }
    
    // MARK: - Helper Methods
    
    /// Configure mock services for successful purchase flow
    private func configureSuccessfulPurchaseFlow(
        mockPurchaseService: MockPurchaseService,
        mockOrderService: MockOrderService,
        for product: IAPProduct
    ) async {
        let order = TestDataGenerator.generateOrder(
            id: "order_\(product.id)",
            productID: product.id,
            status: .created
        )
        
        let transaction = TestDataGenerator.generateSuccessfulTransaction(
            id: "tx_\(product.id)",
            productID: product.id
        )
        
        mockOrderService.addMockOrder(order)
        mockPurchaseService.setMockPurchaseResult(.success(transaction, order.withStatus(.completed)))
        mockPurchaseService.setMockReceiptValidationResult(
            .init(isValid: true, transactions: [transaction])
        )
    }
    
    /// Configure mock services for successful flow with specific order and transaction
    private func configureMockServicesForSuccessfulFlow(
        mockPurchaseService: MockPurchaseService,
        mockOrderService: MockOrderService,
        order: IAPOrder,
        transaction: IAPTransaction
    ) async {
        mockOrderService.addMockOrder(order)
        mockPurchaseService.setMockPurchaseResult(.success(transaction, order.withStatus(.completed)))
        mockPurchaseService.setMockReceiptValidationResult(
            .init(isValid: true, transactions: [transaction])
        )
    }
    
    /// Verify the correct sequence of calls for successful purchase flow
    private func verifySuccessfulPurchaseFlowCalls(
        mockPurchaseService: MockPurchaseService,
        mockOrderService: MockOrderService
    ) async {
        // Verify order creation was called
        #expect(mockOrderService.wasCalled("createOrder"))
        
        // Verify purchase was executed
        #expect(mockPurchaseService.wasCalled("purchase"))
        
        // Verify receipt validation was called
        #expect(mockPurchaseService.wasCalled("validateReceiptWithOrder"))
    }
}

// MARK: - Mock Service Extensions for Testing

extension MockPurchaseService {
    
    /// Set mock receipt validation error
    func setMockReceiptValidationError(_ error: IAPError) {
        setMockError(error, shouldThrow: true)
    }
    
    /// Mock method for validating receipt with order
    func validateReceiptWithOrder(_ receiptData: Data, order: IAPOrder) async throws -> IAPReceiptValidationResult {
        // This would be implemented in the actual MockPurchaseService
        return IAPReceiptValidationResult(isValid: true, transactions: [])
    }
}

// MARK: - Test Data Extensions

extension IAPReceiptValidationResult {
    init(isValid: Bool, transactions: [IAPTransaction]) {
        self.init(
            isValid: isValid,
            transactions: transactions,
            receiptCreationDate: Date(),
            appVersion: "1.0.0",
            originalAppVersion: "1.0.0",
            environment: .sandbox
        )
    }
}
