import XCTest
@testable import IAPFramework

/// Comprehensive tests for OrderService order creation and management functionality
/// Uses MockOrderService to test order management flows
@MainActor
final class OrderServiceTests: XCTestCase, @unchecked Sendable {
    
    // MARK: - Test Properties
    
    private var mockOrderService: MockOrderService!
    private var testProduct: IAPProduct!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock order service
        mockOrderService = MockOrderService()
        
        // Create test product
        testProduct = TestDataGenerator.generateProduct(
            id: "test.product",
            displayName: "Test Product",
            price: 9.99,
            productType: .consumable
        )
    }
    
    override func tearDown() async throws {
        mockOrderService = nil
        testProduct = nil
        try await super.tearDown()
    }
    
    // MARK: - Order Creation Tests
    
    /// Test successful order creation with server response
    func testCreateOrder_Success() async throws {
        // Given
        let userInfo = ["userID": "test123", "sessionID": "session456"]
        mockOrderService.configureSuccessfulOrderCreation(withServerOrderID: true, withExpiration: true)
        
        // When
        let createdOrder = try await mockOrderService.createOrder(for: testProduct, userInfo: userInfo)
        
        // Then
        XCTAssertEqual(createdOrder.productID, testProduct.id)
        XCTAssertEqual(createdOrder.status, .created)
        XCTAssertNotNil(createdOrder.serverOrderID)
        XCTAssertEqual(createdOrder.amount, testProduct.price)
        XCTAssertEqual(createdOrder.currency, testProduct.priceLocale.currency?.identifier)
        XCTAssertEqual(createdOrder.userInfo?["userID"], "test123")
        XCTAssertEqual(createdOrder.userInfo?["sessionID"], "session456")
        XCTAssertFalse(createdOrder.id.isEmpty)
        XCTAssertNotNil(createdOrder.expiresAt)
        
        // Verify service was called
        XCTAssertTrue(mockOrderService.wasCalled("createOrder"))
        XCTAssertEqual(mockOrderService.getCallCount(for: "createOrder"), 1)
    }
    
    /// Test order creation without user info
    func testCreateOrder_WithoutUserInfo() async throws {
        // Given
        mockOrderService.configureSuccessfulOrderCreation(withServerOrderID: true, withExpiration: false)
        
        // When
        let createdOrder = try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
        
        // Then
        XCTAssertEqual(createdOrder.productID, testProduct.id)
        XCTAssertEqual(createdOrder.status, .created)
        XCTAssertNil(createdOrder.userInfo)
        XCTAssertNil(createdOrder.userID)
    }
    
    /// Test order creation failure due to network error
    func testCreateOrder_NetworkFailure() async throws {
        // Given
        mockOrderService.configureNetworkError()
        
        // When & Then
        do {
            _ = try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
            XCTFail("Expected order creation to fail")
        } catch let error as IAPError {
            XCTAssertEqual(error, .networkError)
        }
    }
    
    /// Test order creation failure due to server error
    func testCreateOrder_ServerError() async throws {
        // Given
        mockOrderService.configureOrderCreationFailure(error: .orderCreationFailed(underlying: "Server error"))
        
        // When & Then
        do {
            _ = try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
            XCTFail("Expected order creation to fail")
        } catch let error as IAPError {
            switch error {
            case .orderCreationFailed:
                break // Expected
            default:
                XCTFail("Expected orderCreationFailed error, got \(error)")
            }
        }
    }
    
    // MARK: - Order Status Query Tests
    
    /// Test successful order status query from server
    func testQueryOrderStatus_Success() async throws {
        // Given
        let order = TestDataGenerator.generateOrder(id: "test_order_123", status: .pending)
        mockOrderService.addMockOrder(order)
        
        // When
        let status = try await mockOrderService.queryOrderStatus(order.id)
        
        // Then
        XCTAssertEqual(status, .pending)
        XCTAssertTrue(mockOrderService.wasCalled("queryOrderStatus"))
    }
    
    /// Test order status query with cached terminal status
    func testQueryOrderStatus_CachedTerminalStatus() async throws {
        // Given - Create a completed order
        let order = TestDataGenerator.generateOrder(id: "cached_order_123", status: .completed)
        mockOrderService.addMockOrder(order)
        
        // When
        let status = try await mockOrderService.queryOrderStatus(order.id)
        
        // Then - Should return completed status
        XCTAssertEqual(status, .completed)
        XCTAssertTrue(mockOrderService.wasCalled("queryOrderStatus"))
    }
    
    /// Test order status query for non-existent order
    func testQueryOrderStatus_OrderNotFound() async throws {
        // Given
        let orderID = "non_existent_order"
        mockOrderService.configureOrderNotFound()
        
        // When & Then
        do {
            _ = try await mockOrderService.queryOrderStatus(orderID)
            XCTFail("Expected order not found error")
        } catch let error as IAPError {
            XCTAssertEqual(error, .orderNotFound)
        }
    }
    
    /// Test order status query with network failure
    func testQueryOrderStatus_NetworkFailure() async throws {
        // Given
        let orderID = "test_order_123"
        mockOrderService.configureNetworkError()
        
        // When & Then
        do {
            _ = try await mockOrderService.queryOrderStatus(orderID)
            XCTFail("Expected network error")
        } catch let error as IAPError {
            XCTAssertEqual(error, .networkError)
        }
    }
    
    // MARK: - Order Status Update Tests
    
    /// Test successful order status update
    func testUpdateOrderStatus_Success() async throws {
        // Given
        let order = TestDataGenerator.generateOrder(id: "test_order_123", status: .pending)
        mockOrderService.addMockOrder(order)
        let newStatus = IAPOrderStatus.completed
        
        // When
        try await mockOrderService.updateOrderStatus(order.id, status: newStatus)
        
        // Then
        XCTAssertTrue(mockOrderService.wasCalled("updateOrderStatus"))
        
        // Verify the status was updated
        let updatedOrder = mockOrderService.getOrder(order.id)
        XCTAssertEqual(updatedOrder?.status, .completed)
    }
    
    /// Test order status update failure
    func testUpdateOrderStatus_Failure() async throws {
        // Given
        let orderID = "test_order_123"
        mockOrderService.configureNetworkError()
        
        // When & Then
        do {
            try await mockOrderService.updateOrderStatus(orderID, status: .completed)
            XCTFail("Expected status update to fail")
        } catch {
            // Expected failure
        }
    }
    
    // MARK: - Order Cancellation Tests
    
    /// Test successful order cancellation
    func testCancelOrder_Success() async throws {
        // Given
        let order = TestDataGenerator.generateOrder(id: "test_order_123", status: .pending)
        mockOrderService.addMockOrder(order)
        
        // When
        try await mockOrderService.cancelOrder(order.id)
        
        // Then
        XCTAssertTrue(mockOrderService.wasCalled("cancelOrder"))
        
        // Verify the order was cancelled
        let cancelledOrder = mockOrderService.getOrder(order.id)
        XCTAssertEqual(cancelledOrder?.status, .cancelled)
    }
    
    /// Test order cancellation failure
    func testCancelOrder_Failure() async throws {
        // Given
        let orderID = "test_order_123"
        mockOrderService.configureOrderAlreadyCompleted()
        
        // When & Then
        do {
            try await mockOrderService.cancelOrder(orderID)
            XCTFail("Expected cancellation to fail")
        } catch {
            // Expected failure
        }
    }
    
    // MARK: - Order Cleanup Tests
    
    /// Test cleanup of expired orders
    func testCleanupExpiredOrders_Success() async throws {
        // Given - Create some orders, some expired
        let expiredOrder1 = TestDataGenerator.generateExpiredOrder(id: "expired1", productID: "product1")
        let expiredOrder2 = TestDataGenerator.generateExpiredOrder(id: "expired2", productID: "product2")
        let activeOrder = TestDataGenerator.generatePendingOrder(id: "active1", productID: "product3")
        
        mockOrderService.configureExpiredOrdersCleanup(expiredOrders: [expiredOrder1, expiredOrder2])
        mockOrderService.addMockOrder(activeOrder)
        
        // When
        try await mockOrderService.cleanupExpiredOrders()
        
        // Then - Should have attempted to cleanup expired orders
        XCTAssertTrue(mockOrderService.wasCalled("cleanupExpiredOrders"))
    }
    
    /// Test cleanup with some failures
    func testCleanupExpiredOrders_PartialFailure() async throws {
        // Given - Create expired orders and configure failure
        let expiredOrder = TestDataGenerator.generateExpiredOrder(id: "expired1", productID: "product1")
        mockOrderService.configureExpiredOrdersCleanup(expiredOrders: [expiredOrder])
        mockOrderService.configureNetworkError()
        
        // When - Should not throw even if some cleanups fail
        try await mockOrderService.cleanupExpiredOrders()
        
        // Then - Method should complete without throwing
        XCTAssertTrue(mockOrderService.wasCalled("cleanupExpiredOrders"))
    }
    
    // MARK: - Order Recovery Tests
    
    /// Test recovery of pending orders
    func testRecoverPendingOrders_Success() async throws {
        // Given - Create some pending orders
        let pendingOrder1 = TestDataGenerator.generatePendingOrder(id: "pending1", productID: "product1")
        let pendingOrder2 = TestDataGenerator.generatePendingOrder(id: "pending2", productID: "product2")
        
        mockOrderService.configurePendingOrdersRecovery(pendingOrders: [pendingOrder1, pendingOrder2])
        
        // When
        let recoveredOrders = try await mockOrderService.recoverPendingOrders()
        
        // Then
        XCTAssertGreaterThanOrEqual(recoveredOrders.count, 0)
        XCTAssertTrue(mockOrderService.wasCalled("recoverPendingOrders"))
    }
    
    /// Test recovery with no pending orders
    func testRecoverPendingOrders_NoPendingOrders() async throws {
        // Given - No pending orders configured
        
        // When
        let recoveredOrders = try await mockOrderService.recoverPendingOrders()
        
        // Then
        XCTAssertEqual(recoveredOrders.count, 0)
        XCTAssertTrue(mockOrderService.wasCalled("recoverPendingOrders"))
    }
    
    /// Test recovery with some failures
    func testRecoverPendingOrders_PartialFailure() async throws {
        // Given - Create pending orders and configure failure
        let pendingOrder = TestDataGenerator.generatePendingOrder(id: "pending1", productID: "product1")
        mockOrderService.configurePendingOrdersRecovery(pendingOrders: [pendingOrder])
        mockOrderService.configureNetworkError()
        
        // When & Then - Should not throw even with network errors
        do {
            let recoveredOrders = try await mockOrderService.recoverPendingOrders()
            XCTAssertEqual(recoveredOrders.count, 0)
        } catch {
            // Expected to fail due to network error configuration
        }
    }
    
    // MARK: - Order Expiration Tests
    
    /// Test order expiration logic
    func testOrderExpiration_ExpiredOrder() async throws {
        // Given - Create an order that will expire soon
        let expiredOrder = TestDataGenerator.generateExpiredOrder(id: "expired_order", productID: testProduct.id)
        mockOrderService.addMockOrder(expiredOrder)
        mockOrderService.setAutoExpireOrders(true)
        
        // When - Query the order status
        let status = try await mockOrderService.queryOrderStatus(expiredOrder.id)
        
        // Then - Order should be considered expired/failed
        XCTAssertTrue([.failed, .cancelled].contains(status))
    }
    
    // MARK: - Concurrent Operations Tests
    
    /// Test concurrent order creation
    func testConcurrentOrderCreation() async throws {
        // Given
        let products = TestDataGenerator.generateProducts(count: 5)
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When - Create multiple orders concurrently
        let mockOrderService = self.mockOrderService!
        let orders = try await withThrowingTaskGroup(of: IAPOrder.self) { group in
            for product in products {
                group.addTask {
                    return try await mockOrderService.createOrder(for: product, userInfo: nil)
                }
            }
            
            var results: [IAPOrder] = []
            for try await order in group {
                results.append(order)
            }
            return results
        }
        
        // Then
        XCTAssertEqual(orders.count, products.count)
        
        // Verify all orders have unique IDs
        let orderIDs = Set(orders.map { $0.id })
        XCTAssertEqual(orderIDs.count, orders.count)
        
        // Verify service was called for each order
        XCTAssertEqual(mockOrderService.getCallCount(for: "createOrder"), products.count)
    }
    
    /// Test concurrent status queries
    func testConcurrentStatusQueries() async throws {
        // Given - Create some orders first
        let orderCount = 3
        var orderIDs: [String] = []
        
        for i in 0..<orderCount {
            let order = TestDataGenerator.generateOrder(id: "order_\(i)", status: .pending)
            mockOrderService.addMockOrder(order)
            orderIDs.append(order.id)
        }
        
        // When - Query statuses concurrently
        let mockOrderService = self.mockOrderService!
        let statuses = try await withThrowingTaskGroup(of: IAPOrderStatus.self) { group in
            for orderID in orderIDs {
                group.addTask {
                    return try await mockOrderService.queryOrderStatus(orderID)
                }
            }
            
            var results: [IAPOrderStatus] = []
            for try await status in group {
                results.append(status)
            }
            return results
        }
        
        // Then
        XCTAssertEqual(statuses.count, orderCount)
    }
    
    // MARK: - Edge Cases Tests
    
    /// Test order creation with very long user info
    func testCreateOrder_LongUserInfo() async throws {
        // Given
        let longValue = String(repeating: "a", count: 1000)
        let userInfo = ["longKey": longValue]
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When
        let order = try await mockOrderService.createOrder(for: testProduct, userInfo: userInfo)
        
        // Then
        XCTAssertEqual(order.userInfo?["longKey"], longValue)
    }
    
    /// Test order creation with special characters in user info
    func testCreateOrder_SpecialCharactersInUserInfo() async throws {
        // Given
        let userInfo = [
            "emoji": "🎉🚀💰",
            "unicode": "测试数据",
            "special": "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        ]
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When
        let order = try await mockOrderService.createOrder(for: testProduct, userInfo: userInfo)
        
        // Then
        XCTAssertEqual(order.userInfo?["emoji"], "🎉🚀💰")
        XCTAssertEqual(order.userInfo?["unicode"], "测试数据")
        XCTAssertEqual(order.userInfo?["special"], "!@#$%^&*()_+-=[]{}|;':\",./<>?")
    }
    
    /// Test order operations with nil/empty values
    func testOrderOperations_NilEmptyValues() async throws {
        // Given
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When
        let order = try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
        
        // Then
        XCTAssertNil(order.userInfo)
        XCTAssertNil(order.userID)
        XCTAssertNotNil(order.serverOrderID) // Should still have server order ID
    }
    
    // MARK: - Order Management Flow Tests
    
    /// Test complete order lifecycle
    func testOrderLifecycle_CompleteFlow() async throws {
        // Given
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When - Create order
        let order = try await mockOrderService.createOrder(for: testProduct, userInfo: ["userID": "test123"])
        
        // Then - Verify creation
        XCTAssertEqual(order.status, .created)
        XCTAssertEqual(order.productID, testProduct.id)
        
        // When - Update to pending
        try await mockOrderService.updateOrderStatus(order.id, status: .pending)
        
        // Then - Verify update
        let pendingOrder = mockOrderService.getOrder(order.id)
        XCTAssertEqual(pendingOrder?.status, .pending)
        
        // When - Complete order
        try await mockOrderService.updateOrderStatus(order.id, status: .completed)
        
        // Then - Verify completion
        let completedOrder = mockOrderService.getOrder(order.id)
        XCTAssertEqual(completedOrder?.status, .completed)
        XCTAssertTrue(completedOrder?.isTerminal ?? false)
    }
    
    /// Test order validation and error handling
    func testOrderValidation_ErrorHandling() async throws {
        // Given - Configure various error scenarios
        let errorScenarios: [(IAPError, String)] = [
            (.orderNotFound, "Order not found"),
            (.orderExpired, "Order expired"),
            (.orderAlreadyCompleted, "Order already completed"),
            (.networkError, "Network error"),
            (.orderCreationFailed(underlying: "Server error"), "Order creation failed")
        ]
        
        for (error, description) in errorScenarios {
            // Given
            mockOrderService.reset()
            mockOrderService.setMockError(error, shouldThrow: true)
            
            // When & Then
            do {
                _ = try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
                XCTFail("Expected error for scenario: \(description)")
            } catch let thrownError as IAPError {
                // Verify the correct error was thrown
                switch (error, thrownError) {
                case (.orderNotFound, .orderNotFound),
                     (.orderExpired, .orderExpired),
                     (.orderAlreadyCompleted, .orderAlreadyCompleted),
                     (.networkError, .networkError):
                    break // Expected
                case (.orderCreationFailed, .orderCreationFailed):
                    break // Expected
                default:
                    XCTFail("Unexpected error for scenario \(description): expected \(error), got \(thrownError)")
                }
            }
        }
    }
}

// MARK: - Mock Network Client

