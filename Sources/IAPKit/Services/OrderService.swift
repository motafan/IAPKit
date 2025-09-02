//
//  OrderService.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// 本地存储的订单缓存项
struct OrderCacheItem: Sendable {
    let order: IAPOrder
    let cachedAt: Date
    
    init(order: IAPOrder) {
        self.order = order
        self.cachedAt = Date()
    }
}

/// 本地订单存储和检索的缓存管理器
actor OrderCache {
    private var orders: [String: OrderCacheItem] = [:]
    
    /// 在缓存中存储订单
    func storeOrder(_ order: IAPOrder) {
        orders[order.id] = OrderCacheItem(order: order)
    }
    
    /// 从缓存中检索订单
    func getOrder(_ orderID: String) -> IAPOrder? {
        return orders[orderID]?.order
    }
    
    /// 更新缓存中的订单状态
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
    
    /// 从缓存中移除订单
    func removeOrder(_ orderID: String) {
        orders.removeValue(forKey: orderID)
    }
    
    /// 获取所有过期订单
    func getExpiredOrders() -> [IAPOrder] {
        return orders.values
            .map { $0.order }
            .filter { $0.isExpired }
    }
    
    /// 获取所有待处理订单（已创建或待处理状态）
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
    
    /// 获取所有活跃状态的订单
    func getActiveOrders() -> [IAPOrder] {
        return orders.values
            .map { $0.order }
            .filter { $0.isActive }
    }
    
    /// 清除缓存中的所有订单
    func clearAll() {
        orders.removeAll()
    }
}

/// 订单管理的服务实现
/// 处理订单创建、状态跟踪和生命周期管理
@MainActor
final public class OrderService: OrderServiceProtocol {

    // MARK: - 依赖项
    
    private let networkClient: NetworkClient
    private let cache: OrderCache
    private let retryManager: RetryManager
    
    // MARK: - 初始化
    
    public init(networkClient: NetworkClient, retryManager: RetryManager = RetryManager()) {
        self.networkClient = networkClient
        self.cache = OrderCache()
        self.retryManager = retryManager
    }
    
    // MARK: - OrderServiceProtocol Implementation
    
    public func createOrder(for product: IAPProduct, userInfo: [String: any Any & Sendable]?) async throws -> IAPOrder {
        // 1. Create local order record
        let localOrder = createLocalOrder(for: product, userInfo: userInfo)
        
        do {
            // 2. 向服务器发送订单创建请求
            let serverResponse = try await networkClient.createOrder(localOrder)
            
            // 3. 使用服务器响应更新本地订单
            let finalOrder = updateOrderWithServerResponse(localOrder, response: serverResponse)
            
            // 4. 缓存订单
            await cache.storeOrder(finalOrder)
            
            IAPLogger.debug("Order created successfully: \(finalOrder.id)")
            return finalOrder
            
        } catch {
            // 将失败的订单存储在本地以便可能的恢复
            await cache.storeOrder(localOrder.withStatus(.failed))
            IAPLogger.error("Order creation failed: \(error)")
            throw IAPError.orderCreationFailed(underlying: error.localizedDescription)
        }
    }
    
    public func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus {
        // 首先检查本地缓存
        if let cachedOrder = await cache.getOrder(orderID) {
            // 如果订单是终态，返回缓存状态
            if cachedOrder.status.isTerminal {
                return cachedOrder.status
            }
        }
        
        do {
            // 查询服务器获取最新状态
            let serverResponse = try await networkClient.queryOrderStatus(orderID)
            let serverStatus = IAPOrderStatus(rawValue: serverResponse.status) ?? .failed
            
            // 更新本地缓存
            await cache.updateOrderStatus(orderID, status: serverStatus)
            
            return serverStatus
            
        } catch {
            // 如果服务器查询失败，返回缓存状态（如果可用）
            if let cachedOrder = await cache.getOrder(orderID) {
                IAPLogger.debug("Using cached order status due to server error: \(error)")
                return cachedOrder.status
            }
            
            throw IAPError.orderNotFound
        }
    }
    
    public func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws {
        do {
            // 首先更新服务器
            try await networkClient.updateOrderStatus(orderID, status: status)
            
            // 更新本地缓存
            await cache.updateOrderStatus(orderID, status: status)
            
            IAPLogger.debug("Order status updated: \(orderID) -> \(status)")
            
        } catch {
            IAPLogger.error("Failed to update order status: \(error)")
            throw error
        }
    }
    
    public func cancelOrder(_ orderID: String) async throws {
        try await updateOrderStatus(orderID, status: .cancelled)
    }
    
    public func cleanupExpiredOrders() async throws {
        let expiredOrders = await cache.getExpiredOrders()
        
        for order in expiredOrders {
            do {
                // 尝试在服务器上取消过期订单
                if !order.status.isTerminal {
                    try await cancelOrder(order.id)
                }
                
                // 从本地缓存中移除
                await cache.removeOrder(order.id)
                
                IAPLogger.debug("Cleaned up expired order: \(order.id)")
                
            } catch {
                IAPLogger.error("Failed to cleanup expired order \(order.id): \(error)")
                // 即使一个失败也继续处理其他订单
            }
        }
    }
    
    public func recoverPendingOrders() async throws -> [IAPOrder] {
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
                // 继续处理其他订单
            }
        }
        
        return recoveredOrders
    }
    
    // MARK: - 私有辅助方法
    
    /// 在服务器通信之前创建本地订单记录
    private func createLocalOrder(for product: IAPProduct, userInfo: [String: Any]?) -> IAPOrder {
        let orderID = UUID().uuidString
        let expirationTime = Date().addingTimeInterval(3600) // 1小时过期
        
        // 将 [String: Any]? 转换为 [String: String]?
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
    
    /// 使用服务器响应数据更新本地订单
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
    
    /// 从用户信息字典中提取用户ID
    private func extractUserID(from userInfo: [String: Any]?) -> String? {
        return userInfo?["userID"] as? String
    }
}

// 注意：IAPOrder.withStatus 扩展已在 IAPOrder.swift 中定义
