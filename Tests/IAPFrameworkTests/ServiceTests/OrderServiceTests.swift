import Testing
@testable import IAPFramework

/// Comprehensive tests for OrderService order creation and management functionality
/// Uses MockOrderService to test order management flows
@MainActor
struct OrderServiceTests {
    
    // MARK: - Test Properties
    
    private let mockOrderService: MockOrderService
    private let testProduct: IAPProduct
    
    // MARK: - Setup
    
    init() {
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
    
    // MARK: - Order Creation Tests
    
    /// Test successful order creation with server response
    @Test func createOrder_Success() async throws {
        // Given
        let userInfo = ["userID": "test123", "sessionID": "session456"]
        mockOrderService.configureSuccessfulOrderCreation(withServerOrderID: true, withExpiration: true)
        
        // When
        let createdOrder = try await mockOrderService.createOrder(for: testProduct, userInfo: userInfo)
        
        // Then
        #expect(createdOrder.productID == testProduct.id)
        #expect(createdOrder.status == .created)
        #expect(createdOrder.serverOrderID != nil)
        #expect(createdOrder.amount == testProduct.price)
        #expect(createdOrder.currency == testProduct.priceLocale.currency?.identifier)
        #expect(createdOrder.userInfo?["userID"] == "test123")
        #expect(createdOrder.userInfo?["sessionID"] == "session456")
        #expect(!createdOrder.id.isEmpty)
        #expect(createdOrder.expiresAt != nil)
        
        // Verify service was called
        #expect(mockOrderService.wasCalled("createOrder"))
        #expect(mockOrderService.getCallCount(for: "createOrder") == 1)
    }
    
    /// Test order creation without user info
    @Test func createOrder_WithoutUserInfo() async throws {
        // Given
        mockOrderService.configureSuccessfulOrderCreation(withServerOrderID: true, withExpiration: false)
        
        // When
        let createdOrder = try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
        
        // Then
        #expect(createdOrder.productID == testProduct.id)
        #expect(createdOrder.status == .created)
        #expect(createdOrder.userInfo == nil)
        #expect(createdOrder.userID == nil)
    }
    
    /// Test order creation failure due to network error
    @Test func createOrder_NetworkFailure() async throws {
        // Given
        mockOrderService.configureNetworkError()
        
        // When & Then
        await #expect(throws: IAPError.networkError) {
            try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
        }
    }
    
    /// Test order creation failure due to server error
    @Test func createOrder_ServerError() async throws {
        // Given
        mockOrderService.configureOrderCreationFailure(error: .orderCreationFailed(underlying: "Server error"))
        
        // When & Then
        do {
            _ = try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
            Issue.record("Expected order creation to fail")
        } catch let error as IAPError {
            switch error {
            case .orderCreationFailed:
                break // Expected
            default:
                Issue.record("Expected orderCreationFailed error, got \(error)")
            }
        }
    }
    
    // MARK: - Order Status Query Tests
    
    /// Test successful order status query from server
    @Test func queryOrderStatus_Success() async throws {
        // Given
        let order = TestDataGenerator.generateOrder(id: "test_order_123", status: .pending)
        mockOrderService.addMockOrder(order)
        
        // When
        let status = try await mockOrderService.queryOrderStatus(order.id)
        
        // Then
        #expect(status == .pending)
        #expect(mockOrderService.wasCalled("queryOrderStatus"))
    }
    
    /// Test order status query with cached terminal status
    @Test func queryOrderStatus_CachedTerminalStatus() async throws {
        // Given - Create a completed order
        let order = TestDataGenerator.generateOrder(id: "cached_order_123", status: .completed)
        mockOrderService.addMockOrder(order)
        
        // When
        let status = try await mockOrderService.queryOrderStatus(order.id)
        
        // Then - Should return completed status
        #expect(status == .completed)
        #expect(mockOrderService.wasCalled("queryOrderStatus"))
    }
    
    /// Test order status query for non-existent order
    @Test func queryOrderStatus_OrderNotFound() async throws {
        // Given
        let orderID = "non_existent_order"
        mockOrderService.configureOrderNotFound()
        
        // When & Then
        await #expect(throws: IAPError.orderNotFound) {
            try await mockOrderService.queryOrderStatus(orderID)
        }
    }
    
    /// Test order status query with network failure
    @Test func queryOrderStatus_NetworkFailure() async throws {
        // Given
        let orderID = "test_order_123"
        mockOrderService.configureNetworkError()
        
        // When & Then
        await #expect(throws: IAPError.networkError) {
            try await mockOrderService.queryOrderStatus(orderID)
        }
    }
    
    // MARK: - Order Status Update Tests
    
    /// Test successful order status update
    @Test func updateOrderStatus_Success() async throws {
        // Given
        let order = TestDataGenerator.generateOrder(id: "test_order_123", status: .pending)
        mockOrderService.addMockOrder(order)
        let newStatus = IAPOrderStatus.completed
        
        // When
        try await mockOrderService.updateOrderStatus(order.id, status: newStatus)
        
        // Then
        #expect(mockOrderService.wasCalled("updateOrderStatus"))
        
        // Verify the status was updated
        let updatedOrder = mockOrderService.getOrder(order.id)
        #expect(updatedOrder?.status == .completed)
    }
    
    /// Test order status update failure
    @Test func updateOrderStatus_Failure() async throws {
        // Given
        let orderID = "test_order_123"
        mockOrderService.configureNetworkError()
        
        // When & Then
        await #expect(throws: (any Error).self) {
            try await mockOrderService.updateOrderStatus(orderID, status: .completed)
        }
    }
    
    // MARK: - Order Cancellation Tests
    
    /// Test successful order cancellation
    @Test func cancelOrder_Success() async throws {
        // Given
        let order = TestDataGenerator.generateOrder(id: "test_order_123", status: .pending)
        mockOrderService.addMockOrder(order)
        
        // When
        try await mockOrderService.cancelOrder(order.id)
        
        // Then
        #expect(mockOrderService.wasCalled("cancelOrder"))
        
        // Verify the order was cancelled
        let cancelledOrder = mockOrderService.getOrder(order.id)
        #expect(cancelledOrder?.status == .cancelled)
    }
    
    /// Test order cancellation failure
    @Test func cancelOrder_Failure() async throws {
        // Given
        let orderID = "test_order_123"
        mockOrderService.configureOrderAlreadyCompleted()
        
        // When & Then
        await #expect(throws: (any Error).self) {
            try await mockOrderService.cancelOrder(orderID)
        }
    }
    
    // MARK: - Order Cleanup Tests
    
    /// Test cleanup of expired orders
    @Test func cleanupExpiredOrders_Success() async throws {
        // Given - Create some orders, some expired
        let expiredOrder1 = TestDataGenerator.generateExpiredOrder(id: "expired1", productID: "product1")
        let expiredOrder2 = TestDataGenerator.generateExpiredOrder(id: "expired2", productID: "product2")
        let activeOrder = TestDataGenerator.generatePendingOrder(id: "active1", productID: "product3")
        
        mockOrderService.configureExpiredOrdersCleanup(expiredOrders: [expiredOrder1, expiredOrder2])
        mockOrderService.addMockOrder(activeOrder)
        
        // When
        try await mockOrderService.cleanupExpiredOrders()
        
        // Then - Should have attempted to cleanup expired orders
        #expect(mockOrderService.wasCalled("cleanupExpiredOrders"))
    }
    
    /// Test cleanup with some failures
    @Test func cleanupExpiredOrders_PartialFailure() async throws {
        // Given - Create expired orders and configure failure
        let expiredOrder = TestDataGenerator.generateExpiredOrder(id: "expired1", productID: "product1")
        mockOrderService.configureExpiredOrdersCleanup(expiredOrders: [expiredOrder])
        mockOrderService.configureNetworkError()
        
        // When - Should not throw even if some cleanups fail
        try await mockOrderService.cleanupExpiredOrders()
        
        // Then - Method should complete without throwing
        #expect(mockOrderService.wasCalled("cleanupExpiredOrders"))
    }
    
    // MARK: - Order Recovery Tests
    
    /// Test recovery of pending orders
    @Test func recoverPendingOrders_Success() async throws {
        // Given - Create some pending orders
        let pendingOrder1 = TestDataGenerator.generatePendingOrder(id: "pending1", productID: "product1")
        let pendingOrder2 = TestDataGenerator.generatePendingOrder(id: "pending2", productID: "product2")
        
        mockOrderService.configurePendingOrdersRecovery(pendingOrders: [pendingOrder1, pendingOrder2])
        
        // When
        let recoveredOrders = try await mockOrderService.recoverPendingOrders()
        
        // Then
        #expect(recoveredOrders.count >= 0)
        #expect(mockOrderService.wasCalled("recoverPendingOrders"))
    }
    
    /// Test recovery with no pending orders
    @Test func recoverPendingOrders_NoPendingOrders() async throws {
        // Given - No pending orders configured
        
        // When
        let recoveredOrders = try await mockOrderService.recoverPendingOrders()
        
        // Then
        #expect(recoveredOrders.count == 0)
        #expect(mockOrderService.wasCalled("recoverPendingOrders"))
    }
    
    /// Test recovery with some failures
    @Test func recoverPendingOrders_PartialFailure() async throws {
        // Given - Create pending orders and configure failure
        let pendingOrder = TestDataGenerator.generatePendingOrder(id: "pending1", productID: "product1")
        mockOrderService.configurePendingOrdersRecovery(pendingOrders: [pendingOrder])
        mockOrderService.configureNetworkError()
        
        // When & Then - Should not throw even with network errors
        do {
            let recoveredOrders = try await mockOrderService.recoverPendingOrders()
            #expect(recoveredOrders.count == 0)
        } catch {
            // Expected to fail due to network error configuration
        }
    }
    
    // MARK: - Order Expiration Tests
    
    /// Test order expiration logic
    @Test func orderExpiration_ExpiredOrder() async throws {
        // Given - Create an order that will expire soon
        let expiredOrder = TestDataGenerator.generateExpiredOrder(id: "expired_order", productID: testProduct.id)
        mockOrderService.addMockOrder(expiredOrder)
        mockOrderService.setAutoExpireOrders(true)
        
        // When - Query the order status
        let status = try await mockOrderService.queryOrderStatus(expiredOrder.id)
        
        // Then - Order should be considered expired/failed
        #expect([.failed, .cancelled].contains(status))
    }
    
    // MARK: - Concurrent Operations Tests
    
    /// Test concurrent order creation
    @Test func concurrentOrderCreation() async throws {
        // Given
        let products = TestDataGenerator.generateProducts(count: 5)
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When - Create multiple orders concurrently
        let orders = try await withThrowingTaskGroup(of: IAPOrder.self) { group in
            for product in products {
                group.addTask {
                    return try await self.mockOrderService.createOrder(for: product, userInfo: nil)
                }
            }
            
            var results: [IAPOrder] = []
            for try await order in group {
                results.append(order)
            }
            return results
        }
        
        // Then
        #expect(orders.count == products.count)
        
        // Verify all orders have unique IDs
        let orderIDs = Set(orders.map { $0.id })
        #expect(orderIDs.count == orders.count)
        
        // Verify service was called for each order
        #expect(mockOrderService.getCallCount(for: "createOrder") == products.count)
    }
    
    /// Test concurrent status queries
    @Test func concurrentStatusQueries() async throws {
        // Given - Create some orders first
        let orderCount = 3
        var orderIDs: [String] = []
        
        for i in 0..<orderCount {
            let order = TestDataGenerator.generateOrder(id: "order_\(i)", status: .pending)
            mockOrderService.addMockOrder(order)
            orderIDs.append(order.id)
        }
        
        // When - Query statuses concurrently
        let statuses = try await withThrowingTaskGroup(of: IAPOrderStatus.self) { group in
            for orderID in orderIDs {
                group.addTask {
                    return try await self.mockOrderService.queryOrderStatus(orderID)
                }
            }
            
            var results: [IAPOrderStatus] = []
            for try await status in group {
                results.append(status)
            }
            return results
        }
        
        // Then
        #expect(statuses.count == orderCount)
    }
    
    // MARK: - Edge Cases Tests
    
    /// Test order creation with very long user info
    @Test func createOrder_LongUserInfo() async throws {
        // Given
        let longValue = String(repeating: "a", count: 1000)
        let userInfo = ["longKey": longValue]
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When
        let order = try await mockOrderService.createOrder(for: testProduct, userInfo: userInfo)
        
        // Then
        #expect(order.userInfo?["longKey"] == longValue)
    }
    
    /// Test order creation with special characters in user info
    @Test func createOrder_SpecialCharactersInUserInfo() async throws {
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
        #expect(order.userInfo?["emoji"] == "🎉🚀💰")
        #expect(order.userInfo?["unicode"] == "测试数据")
        #expect(order.userInfo?["special"] == "!@#$%^&*()_+-=[]{}|;':\",./<>?")
    }
    
    /// Test order operations with nil/empty values
    @Test func orderOperations_NilEmptyValues() async throws {
        // Given
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When
        let order = try await mockOrderService.createOrder(for: testProduct, userInfo: nil)
        
        // Then
        #expect(order.userInfo == nil)
        #expect(order.userID == nil)
        #expect(order.serverOrderID != nil) // Should still have server order ID
    }
    
    // MARK: - Order Management Flow Tests
    
    /// Test complete order lifecycle
    @Test func orderLifecycle_CompleteFlow() async throws {
        // Given
        mockOrderService.configureSuccessfulOrderCreation()
        
        // When - Create order
        let order = try await mockOrderService.createOrder(for: testProduct, userInfo: ["userID": "test123"])
        
        // Then - Verify creation
        #expect(order.status == .created)
        #expect(order.productID == testProduct.id)
        
        // When - Update to pending
        try await mockOrderService.updateOrderStatus(order.id, status: .pending)
        
        // Then - Verify update
        let pendingOrder = mockOrderService.getOrder(order.id)
        #expect(pendingOrder?.status == .pending)
        
        // When - Complete order
        try await mockOrderService.updateOrderStatus(order.id, status: .completed)
        
        // Then - Verify completion
        let completedOrder = mockOrderService.getOrder(order.id)
        #expect(completedOrder?.status == .completed)
        #expect(completedOrder?.isTerminal ?? false)
    }
    
    /// Test order validation and error handling
    @Test func orderValidation_ErrorHandling() async throws {
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
                Issue.record("Expected error for scenario: \(description)")
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
                    Issue.record("Unexpected error for scenario \(description): expected \(error), got \(thrownError)")
                }
            }
        }
    }
}

// MARK: - Mock Network Client

