import Foundation
@testable import IAPFramework

/// Mock order service for testing order management flows
@MainActor
public final class MockOrderService: OrderServiceProtocol, @unchecked Sendable {
    
    // MARK: - Mock Data
    
    /// Mock orders storage
    public private(set) var mockOrders: [String: IAPOrder] = [:]
    
    /// Mock error to throw
    public var mockError: IAPError?
    
    /// Whether to throw error
    public var shouldThrowError: Bool = false
    
    /// Mock delay in seconds
    public var mockDelay: TimeInterval = 0
    
    /// Mock server order ID counter
    private var serverOrderIDCounter: Int = 1000
    
    /// Mock order expiration time (default 30 minutes)
    public var mockOrderExpirationTime: TimeInterval = 30 * 60
    
    // MARK: - Call Tracking
    
    /// Call counters
    public private(set) var callCounts: [String: Int] = [:]
    
    /// Call parameters
    public private(set) var callParameters: [String: Any] = [:]
    
    /// Created orders tracking
    public private(set) var createdOrders: [IAPOrder] = []
    
    /// Status queries tracking
    public private(set) var statusQueries: [String] = []
    
    /// Status updates tracking
    public private(set) var statusUpdates: [(orderID: String, status: IAPOrderStatus)] = []
    
    /// Cancelled orders tracking
    public private(set) var cancelledOrders: [String] = []
    
    // MARK: - Configuration
    
    /// Whether to auto-generate server order IDs
    public var autoGenerateServerOrderID: Bool = true
    
    /// Whether to simulate network delays
    public var simulateNetworkDelay: Bool = false
    
    /// Whether to auto-expire orders
    public var autoExpireOrders: Bool = false
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - OrderServiceProtocol Implementation
    
    public func createOrder(for product: IAPProduct, userInfo: [String: Any]?) async throws -> IAPOrder {
        incrementCallCount(for: "createOrder")
        callParameters["createOrder_product"] = product
        callParameters["createOrder_userInfo"] = userInfo
        
        if simulateNetworkDelay && mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // Create order
        let orderID = UUID().uuidString
        let serverOrderID = autoGenerateServerOrderID ? "server_\(serverOrderIDCounter)" : nil
        if autoGenerateServerOrderID {
            serverOrderIDCounter += 1
        }
        
        let expiresAt = autoExpireOrders ? Date().addingTimeInterval(mockOrderExpirationTime) : nil
        
        // Convert [String: Any] to [String: String] for userInfo
        let stringUserInfo: [String: String]?
        if let userInfo = userInfo {
            stringUserInfo = userInfo.compactMapValues { value in
                if let stringValue = value as? String {
                    return stringValue
                } else {
                    return String(describing: value)
                }
            }
        } else {
            stringUserInfo = nil
        }
        
        let order = IAPOrder(
            id: orderID,
            productID: product.id,
            userInfo: stringUserInfo,
            createdAt: Date(),
            expiresAt: expiresAt,
            status: .created,
            serverOrderID: serverOrderID,
            amount: product.price,
            currency: product.priceLocale.currencyCode
        )
        
        // Store order
        mockOrders[orderID] = order
        createdOrders.append(order)
        
        return order
    }
    
    public func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus {
        incrementCallCount(for: "queryOrderStatus")
        callParameters["queryOrderStatus_orderID"] = orderID
        statusQueries.append(orderID)
        
        if simulateNetworkDelay && mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        guard let order = mockOrders[orderID] else {
            throw IAPError.orderNotFound
        }
        
        // Check if order is expired and update status
        if autoExpireOrders && order.isExpired && !order.isTerminal {
            let expiredOrder = order.withStatus(.failed)
            mockOrders[orderID] = expiredOrder
            return .failed
        }
        
        return order.status
    }
    
    public func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws {
        incrementCallCount(for: "updateOrderStatus")
        callParameters["updateOrderStatus_orderID"] = orderID
        callParameters["updateOrderStatus_status"] = status
        statusUpdates.append((orderID: orderID, status: status))
        
        if simulateNetworkDelay && mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        guard let order = mockOrders[orderID] else {
            throw IAPError.orderNotFound
        }
        
        // Update order status
        let updatedOrder = order.withStatus(status)
        mockOrders[orderID] = updatedOrder
    }
    
    public func cancelOrder(_ orderID: String) async throws {
        incrementCallCount(for: "cancelOrder")
        callParameters["cancelOrder_orderID"] = orderID
        cancelledOrders.append(orderID)
        
        if simulateNetworkDelay && mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        guard let order = mockOrders[orderID] else {
            throw IAPError.orderNotFound
        }
        
        // Only allow cancellation of non-terminal orders
        if order.isTerminal {
            throw IAPError.orderAlreadyCompleted
        }
        
        // Update order status to cancelled
        let cancelledOrder = order.withStatus(.cancelled)
        mockOrders[orderID] = cancelledOrder
    }
    
    public func cleanupExpiredOrders() async throws {
        incrementCallCount(for: "cleanupExpiredOrders")
        
        if simulateNetworkDelay && mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // Find and remove expired orders
        let expiredOrderIDs = mockOrders.values
            .filter { $0.isExpired && !$0.isTerminal }
            .map { $0.id }
        
        for orderID in expiredOrderIDs {
            if let order = mockOrders[orderID] {
                let expiredOrder = order.withStatus(.failed)
                mockOrders[orderID] = expiredOrder
            }
        }
    }
    
    public func recoverPendingOrders() async throws -> [IAPOrder] {
        incrementCallCount(for: "recoverPendingOrders")
        
        if simulateNetworkDelay && mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        if shouldThrowError, let error = mockError {
            throw error
        }
        
        // Find pending orders
        let pendingOrders = mockOrders.values.filter { order in
            order.status.isInProgress && !order.isExpired
        }
        
        return Array(pendingOrders)
    }
    
    // MARK: - Mock Configuration Methods
    
    /// Set mock error
    /// - Parameters:
    ///   - error: Error to throw
    ///   - shouldThrow: Whether to throw the error
    public func setMockError(_ error: IAPError?, shouldThrow: Bool = true) {
        mockError = error
        shouldThrowError = shouldThrow
    }
    
    /// Set mock delay
    /// - Parameter delay: Delay in seconds
    public func setMockDelay(_ delay: TimeInterval) {
        mockDelay = delay
    }
    
    /// Set order expiration time
    /// - Parameter time: Expiration time in seconds
    public func setOrderExpirationTime(_ time: TimeInterval) {
        mockOrderExpirationTime = time
    }
    
    /// Enable/disable auto server order ID generation
    /// - Parameter enabled: Whether to auto-generate server order IDs
    public func setAutoGenerateServerOrderID(_ enabled: Bool) {
        autoGenerateServerOrderID = enabled
    }
    
    /// Enable/disable network delay simulation
    /// - Parameter enabled: Whether to simulate network delays
    public func setSimulateNetworkDelay(_ enabled: Bool) {
        simulateNetworkDelay = enabled
    }
    
    /// Enable/disable auto order expiration
    /// - Parameter enabled: Whether to auto-expire orders
    public func setAutoExpireOrders(_ enabled: Bool) {
        autoExpireOrders = enabled
    }
    
    /// Add a pre-configured order
    /// - Parameter order: Order to add
    public func addMockOrder(_ order: IAPOrder) {
        mockOrders[order.id] = order
    }
    
    /// Remove an order
    /// - Parameter orderID: Order ID to remove
    public func removeMockOrder(_ orderID: String) {
        mockOrders.removeValue(forKey: orderID)
    }
    
    /// Get all orders
    /// - Returns: All mock orders
    public func getAllOrders() -> [IAPOrder] {
        return Array(mockOrders.values)
    }
    
    /// Get order by ID
    /// - Parameter orderID: Order ID
    /// - Returns: Order if found
    public func getOrder(_ orderID: String) -> IAPOrder? {
        return mockOrders[orderID]
    }
    
    // MARK: - Test Helper Methods
    
    /// Reset all mock data
    public func reset() {
        mockOrders.removeAll()
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        serverOrderIDCounter = 1000
        mockOrderExpirationTime = 30 * 60
        autoGenerateServerOrderID = true
        simulateNetworkDelay = false
        autoExpireOrders = false
        
        callCounts.removeAll()
        callParameters.removeAll()
        createdOrders.removeAll()
        statusQueries.removeAll()
        statusUpdates.removeAll()
        cancelledOrders.removeAll()
    }
    
    /// Get method call count
    /// - Parameter method: Method name
    /// - Returns: Call count
    public func getCallCount(for method: String) -> Int {
        return callCounts[method] ?? 0
    }
    
    /// Get method call parameters
    /// - Parameter method: Method name
    /// - Returns: Call parameters
    public func getCallParameters(for method: String) -> Any? {
        return callParameters[method]
    }
    
    /// Check if method was called
    /// - Parameter method: Method name
    /// - Returns: Whether method was called
    public func wasCalled(_ method: String) -> Bool {
        return getCallCount(for: method) > 0
    }
    
    /// Get all created orders
    /// - Returns: Created orders
    public func getAllCreatedOrders() -> [IAPOrder] {
        return createdOrders
    }
    
    /// Get last created order
    /// - Returns: Last created order
    public func getLastCreatedOrder() -> IAPOrder? {
        return createdOrders.last
    }
    
    /// Get all status queries
    /// - Returns: Status queries
    public func getAllStatusQueries() -> [String] {
        return statusQueries
    }
    
    /// Get all status updates
    /// - Returns: Status updates
    public func getAllStatusUpdates() -> [(orderID: String, status: IAPOrderStatus)] {
        return statusUpdates
    }
    
    /// Get all cancelled orders
    /// - Returns: Cancelled order IDs
    public func getAllCancelledOrders() -> [String] {
        return cancelledOrders
    }
    
    /// Check if order was created for product
    /// - Parameter productID: Product ID
    /// - Returns: Whether order was created
    public func wasOrderCreated(for productID: String) -> Bool {
        return createdOrders.contains { $0.productID == productID }
    }
    
    /// Check if order status was queried
    /// - Parameter orderID: Order ID
    /// - Returns: Whether status was queried
    public func wasOrderStatusQueried(_ orderID: String) -> Bool {
        return statusQueries.contains(orderID)
    }
    
    /// Check if order was cancelled
    /// - Parameter orderID: Order ID
    /// - Returns: Whether order was cancelled
    public func wasOrderCancelled(_ orderID: String) -> Bool {
        return cancelledOrders.contains(orderID)
    }
    
    /// Get call statistics
    /// - Returns: Call statistics
    public func getCallStatistics() -> [String: Int] {
        return callCounts
    }
    
    // MARK: - Private Methods
    
    private func incrementCallCount(for method: String) {
        callCounts[method, default: 0] += 1
    }
}

// MARK: - Convenience Factory Methods

extension MockOrderService {
    
    /// Create a mock service that always succeeds
    /// - Returns: Mock order service
    public static func alwaysSucceeds() -> MockOrderService {
        let service = MockOrderService()
        service.setAutoGenerateServerOrderID(true)
        return service
    }
    
    /// Create a mock service that always fails
    /// - Parameter error: Error to throw
    /// - Returns: Mock order service
    public static func alwaysFails(with error: IAPError = .orderCreationFailed(underlying: "Mock error")) -> MockOrderService {
        let service = MockOrderService()
        service.setMockError(error, shouldThrow: true)
        return service
    }
    
    /// Create a mock service with network delays
    /// - Parameter delay: Delay in seconds
    /// - Returns: Mock order service
    public static func withDelay(_ delay: TimeInterval) -> MockOrderService {
        let service = MockOrderService()
        service.setMockDelay(delay)
        service.setSimulateNetworkDelay(true)
        return service
    }
    
    /// Create a mock service with auto-expiring orders
    /// - Parameter expirationTime: Expiration time in seconds
    /// - Returns: Mock order service
    public static func withAutoExpiration(_ expirationTime: TimeInterval = 30) -> MockOrderService {
        let service = MockOrderService()
        service.setOrderExpirationTime(expirationTime)
        service.setAutoExpireOrders(true)
        return service
    }
    
    /// Create a mock service with pre-configured orders
    /// - Parameter orders: Orders to pre-configure
    /// - Returns: Mock order service
    public static func withOrders(_ orders: [IAPOrder]) -> MockOrderService {
        let service = MockOrderService()
        for order in orders {
            service.addMockOrder(order)
        }
        return service
    }
}

// MARK: - Test Scenario Builders

extension MockOrderService {
    
    /// Configure successful order creation scenario
    /// - Parameters:
    ///   - withServerOrderID: Whether to include server order ID
    ///   - withExpiration: Whether orders should expire
    public func configureSuccessfulOrderCreation(
        withServerOrderID: Bool = true,
        withExpiration: Bool = false
    ) {
        setAutoGenerateServerOrderID(withServerOrderID)
        setAutoExpireOrders(withExpiration)
        shouldThrowError = false
    }
    
    /// Configure order creation failure scenario
    /// - Parameter error: Error to throw
    public func configureOrderCreationFailure(error: IAPError = .orderCreationFailed(underlying: "Server error")) {
        setMockError(error, shouldThrow: true)
    }
    
    /// Configure network error scenario
    /// - Parameter delay: Network delay before error
    public func configureNetworkError(delay: TimeInterval = 1.0) {
        setMockDelay(delay)
        setSimulateNetworkDelay(true)
        setMockError(.networkError, shouldThrow: true)
    }
    
    /// Configure order not found scenario
    public func configureOrderNotFound() {
        setMockError(.orderNotFound, shouldThrow: true)
    }
    
    /// Configure order expired scenario
    /// - Parameter expirationTime: Time until expiration
    public func configureOrderExpired(expirationTime: TimeInterval = 0.1) {
        setOrderExpirationTime(expirationTime)
        setAutoExpireOrders(true)
        setMockError(.orderExpired, shouldThrow: true)
    }
    
    /// Configure order already completed scenario
    public func configureOrderAlreadyCompleted() {
        setMockError(.orderAlreadyCompleted, shouldThrow: true)
    }
    
    /// Configure successful order flow scenario
    /// - Parameters:
    ///   - product: Product to create order for
    ///   - userInfo: User info for order
    /// - Returns: Pre-configured order
    @discardableResult
    public func configureSuccessfulOrderFlow(
        for product: IAPProduct,
        userInfo: [String: Any]? = nil
    ) -> IAPOrder {
        let order = IAPOrder(
            id: UUID().uuidString,
            productID: product.id,
            userInfo: userInfo?.compactMapValues { String(describing: $0) },
            status: .created,
            serverOrderID: "server_\(serverOrderIDCounter)",
            amount: product.price,
            currency: product.priceLocale.currencyCode
        )
        
        serverOrderIDCounter += 1
        addMockOrder(order)
        
        return order
    }
    
    /// Configure order status progression scenario
    /// - Parameters:
    ///   - orderID: Order ID
    ///   - statuses: Status progression
    public func configureOrderStatusProgression(
        orderID: String,
        statuses: [IAPOrderStatus]
    ) {
        guard let order = mockOrders[orderID] else { return }
        
        // Set up the order to progress through statuses
        var currentOrder = order
        for status in statuses {
            currentOrder = currentOrder.withStatus(status)
            mockOrders[orderID] = currentOrder
        }
    }
    
    /// Configure pending orders recovery scenario
    /// - Parameter pendingOrders: Orders to be recovered
    public func configurePendingOrdersRecovery(pendingOrders: [IAPOrder]) {
        for order in pendingOrders {
            let pendingOrder = order.withStatus(.pending)
            addMockOrder(pendingOrder)
        }
    }
    
    /// Configure expired orders cleanup scenario
    /// - Parameter expiredOrders: Orders that should be expired
    public func configureExpiredOrdersCleanup(expiredOrders: [IAPOrder]) {
        for order in expiredOrders {
            let expiredOrder = IAPOrder(
                id: order.id,
                productID: order.productID,
                userInfo: order.userInfo,
                createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
                expiresAt: Date().addingTimeInterval(-1800), // 30 minutes ago (expired)
                status: order.status,
                serverOrderID: order.serverOrderID,
                amount: order.amount,
                currency: order.currency,
                userID: order.userID
            )
            addMockOrder(expiredOrder)
        }
        setAutoExpireOrders(true)
    }
}