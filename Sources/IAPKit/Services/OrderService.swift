//
//  OrderService.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// Order cache item for local storage
struct OrderCacheItem: Sendable {
    let order: IAPOrder
    let cachedAt: Date
    
    init(order: IAPOrder) {
        self.order = order
        self.cachedAt = Date()
    }
}

/// Order cache manager for local order storage and retrieval
actor OrderCache {
    private var orders: [String: OrderCacheItem] = [:]
    
    /// Stores an order in the cache
    func storeOrder(_ order: IAPOrder) {
        orders[order.id] = OrderCacheItem(order: order)
    }
    
    /// Retrieves an order from the cache
    func getOrder(_ orderID: String) -> IAPOrder? {
        return orders[orderID]?.order
    }
    
    /// Updates order status in cache
    func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) {
        guard let item = orders[orderID] else { return }
        let updatedOrder = IAPOrder(
            id: item.order.id,
            productID: item.order.productID,
            userInfo: item.order.userInfo,
            createdAt: item.order.createdAt,
            expiresAt: item.order.expiresAt,
            status: status,
            serverOrderID: item.order.serverOrderID,
            amount: item.order.amount,
            currency: item.order.currency,
            userID: item.order.userID
        )
        orders[orderID] = OrderCacheItem(order: updatedOrder)
    }
    
    /// Removes an order from cache
    func removeOrder(_ orderID: String) {
        orders.removeValue(forKey: orderID)
    }
    
    /// Gets all expired orders
    func getExpiredOrders() -> [IAPOrder] {
        return orders.values
            .map { $0.order }
            .filter { $0.isExpired }
    }
    
    /// Gets all pending orders (created or pending status)
    func getPendingOrders() -> [IAPOrder] {
        return orders.values
            .map { $0.order }
            .filter { order in
                switch order.status {
                case .created, .pending:
                    return !order.isExpired
                case .completed, .cancelled, .failed:
                    return false
                }
            }
    }
    
    /// Gets all orders with active status
    func getActiveOrders() -> [IAPOrder] {
        return orders.values
            .map { $0.order }
            .filter { $0.isActive }
    }
    
    /// Clears all orders from cache
    func clearAll() {
        orders.removeAll()
    }
}

/// Service implementation for order management
/// Handles order creation, status tracking, and lifecycle management
@MainActor
final class OrderService: OrderServiceProtocol {
    
    // MARK: - Dependencies
    
    private let networkClient: NetworkClient
    private let cache: OrderCache
    private let retryManager: RetryManager
    
    // MARK: - Initialization
    
    init(networkClient: NetworkClient, retryManager: RetryManager = RetryManager()) {
        self.networkClient = networkClient
        self.cache = OrderCache()
        self.retryManager = retryManager
    }
    
    // MARK: - OrderServiceProtocol Implementation
    
    func createOrder(for product: IAPProduct, userInfo: [String: Any]?) async throws -> IAPOrder {
        // 1. Create local order record
        let localOrder = createLocalOrder(for: product, userInfo: userInfo)
        
        do {
            // 2. Send order creation request to server
            let serverResponse = try await networkClient.createOrder(localOrder)
            
            // 3. Update local order with server response
            let finalOrder = updateOrderWithServerResponse(localOrder, response: serverResponse)
            
            // 4. Cache the order
            await cache.storeOrder(finalOrder)
            
            IAPLogger.debug("Order created successfully: \(finalOrder.id)")
            return finalOrder
            
        } catch {
            // Store failed order locally for potential recovery
            await cache.storeOrder(localOrder.withStatus(.failed))
            IAPLogger.error("Order creation failed: \(error)")
            throw IAPError.orderCreationFailed(underlying: error.localizedDescription)
        }
    }
    
    func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus {
        // First check local cache
        if let cachedOrder = await cache.getOrder(orderID) {
            // If order is terminal, return cached status
            if cachedOrder.status.isTerminal {
                return cachedOrder.status
            }
        }
        
        do {
            // Query server for latest status
            let serverResponse = try await networkClient.queryOrderStatus(orderID)
            let serverStatus = IAPOrderStatus(rawValue: serverResponse.status) ?? .failed
            
            // Update local cache
            await cache.updateOrderStatus(orderID, status: serverStatus)
            
            return serverStatus
            
        } catch {
            // If server query fails, return cached status if available
            if let cachedOrder = await cache.getOrder(orderID) {
                IAPLogger.debug("Using cached order status due to server error: \(error)")
                return cachedOrder.status
            }
            
            throw IAPError.orderNotFound
        }
    }
    
    func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws {
        do {
            // Update server first
            try await networkClient.updateOrderStatus(orderID, status: status)
            
            // Update local cache
            await cache.updateOrderStatus(orderID, status: status)
            
            IAPLogger.debug("Order status updated: \(orderID) -> \(status)")
            
        } catch {
            IAPLogger.error("Failed to update order status: \(error)")
            throw error
        }
    }
    
    func cancelOrder(_ orderID: String) async throws {
        try await updateOrderStatus(orderID, status: .cancelled)
    }
    
    func cleanupExpiredOrders() async throws {
        let expiredOrders = await cache.getExpiredOrders()
        
        for order in expiredOrders {
            do {
                // Try to cancel expired orders on server
                if !order.status.isTerminal {
                    try await cancelOrder(order.id)
                }
                
                // Remove from local cache
                await cache.removeOrder(order.id)
                
                IAPLogger.debug("Cleaned up expired order: \(order.id)")
                
            } catch {
                IAPLogger.error("Failed to cleanup expired order \(order.id): \(error)")
                // Continue with other orders even if one fails
            }
        }
    }
    
    func recoverPendingOrders() async throws -> [IAPOrder] {
        let pendingOrders = await cache.getPendingOrders()
        var recoveredOrders: [IAPOrder] = []
        
        for order in pendingOrders {
            do {
                let currentStatus = try await queryOrderStatus(order.id)
                if currentStatus != order.status {
                    let updatedOrder = order.withStatus(currentStatus)
                    await cache.storeOrder(updatedOrder)
                    recoveredOrders.append(updatedOrder)
                    IAPLogger.debug("Recovered order \(order.id): \(order.status) -> \(currentStatus)")
                }
            } catch {
                IAPLogger.debug("Failed to recover order \(order.id): \(error)")
                // Continue with other orders
            }
        }
        
        return recoveredOrders
    }
    
    // MARK: - Private Helper Methods
    
    /// Creates a local order record before server communication
    private func createLocalOrder(for product: IAPProduct, userInfo: [String: Any]?) -> IAPOrder {
        let orderID = UUID().uuidString
        let expirationTime = Date().addingTimeInterval(3600) // 1 hour expiration
        
        // Convert [String: Any]? to [String: String]?
        let stringUserInfo: [String: String]? = userInfo?.compactMapValues { value in
            return String(describing: value)
        }
        
        return IAPOrder(
            id: orderID,
            productID: product.id,
            userInfo: stringUserInfo,
            createdAt: Date(),
            expiresAt: expirationTime,
            status: .created,
            serverOrderID: nil,
            amount: product.price,
            currency: product.priceLocale.currencyCode,
            userID: extractUserID(from: userInfo)
        )
    }
    
    /// Updates local order with server response data
    private func updateOrderWithServerResponse(_ localOrder: IAPOrder, response: OrderCreationResponse) -> IAPOrder {
        let serverStatus = IAPOrderStatus(rawValue: response.status) ?? .created
        
        return IAPOrder(
            id: localOrder.id,
            productID: localOrder.productID,
            userInfo: localOrder.userInfo,
            createdAt: localOrder.createdAt,
            expiresAt: response.expiresAt ?? localOrder.expiresAt,
            status: serverStatus,
            serverOrderID: response.serverOrderID,
            amount: localOrder.amount,
            currency: localOrder.currency,
            userID: localOrder.userID
        )
    }
    
    /// Extracts user ID from user info dictionary
    private func extractUserID(from userInfo: [String: Any]?) -> String? {
        return userInfo?["userID"] as? String
    }
}

// Note: IAPOrder.withStatus extension is already defined in IAPOrder.swift