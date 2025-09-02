//
//  OrderServiceProtocol.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// 定义订单管理服务接口的协议
/// 处理服务器端订单创建、跟踪和生命周期管理
@MainActor
public protocol OrderServiceProtocol: Sendable {
    
    // MARK: - 核心订单操作
    
    /// 为指定商品创建新订单
    /// - Parameters:
    ///   - product: 要创建订单的商品
    ///   - userInfo: 与订单关联的可选附加信息
    /// - Returns: 带有服务器分配标识符的已创建订单
    /// - Throws: 订单创建失败时抛出 IAPError
    func createOrder(for product: IAPProduct, userInfo: [String: any Any & Sendable]?) async throws -> IAPOrder
    
    /// 查询订单的当前状态
    /// - Parameter orderID: 订单的唯一标识符
    /// - Returns: 订单的当前状态
    /// - Throws: 无法找到或查询订单时抛出 IAPError
    func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus
    
    /// 更新现有订单的状态
    /// - Parameters:
    ///   - orderID: 订单的唯一标识符
    ///   - status: 要设置的新状态
    /// - Throws: 无法更新订单时抛出 IAPError
    func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws
    
    /// 取消现有订单
    /// - Parameter orderID: 要取消的订单的唯一标识符
    /// - Throws: 无法取消订单时抛出 IAPError
    func cancelOrder(_ orderID: String) async throws
    
    // MARK: - 订单维护操作
    
    /// 从本地缓存和服务器清理过期订单
    /// 应定期调用此方法以维护系统卫生
    /// - Throws: 清理操作失败时抛出 IAPError
    func cleanupExpiredOrders() async throws
    
    /// 恢复可能被中断的待处理订单
    /// 此方法同步本地和服务器订单状态
    /// - Returns: 已恢复和更新的订单数组
    /// - Throws: 恢复操作失败时抛出 IAPError
    func recoverPendingOrders() async throws -> [IAPOrder]
}
