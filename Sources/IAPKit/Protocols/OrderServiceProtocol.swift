//
//  OrderServiceProtocol.swift
//  IAPKit
//
//  Created by IAPKit
//

import Foundation

/// Protocol defining the interface for order management services
/// Handles server-side order creation, tracking, and lifecycle management
@MainActor
public protocol OrderServiceProtocol: Sendable {
    
    // MARK: - Core Order Operations
    
    /// Creates a new order for the specified product
    /// - Parameters:
    ///   - product: The product to create an order for
    ///   - userInfo: Optional additional information to associate with the order
    /// - Returns: The created order with server-assigned identifier
    /// - Throws: IAPError if order creation fails
    func createOrder(for product: IAPProduct, userInfo: [String: any Any & Sendable]?) async throws -> IAPOrder
    
    /// Queries the current status of an order
    /// - Parameter orderID: The unique identifier of the order
    /// - Returns: The current status of the order
    /// - Throws: IAPError if the order cannot be found or queried
    func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus
    
    /// Updates the status of an existing order
    /// - Parameters:
    ///   - orderID: The unique identifier of the order
    ///   - status: The new status to set
    /// - Throws: IAPError if the order cannot be updated
    func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) async throws
    
    /// Cancels an existing order
    /// - Parameter orderID: The unique identifier of the order to cancel
    /// - Throws: IAPError if the order cannot be cancelled
    func cancelOrder(_ orderID: String) async throws
    
    // MARK: - Order Maintenance Operations
    
    /// Cleans up expired orders from local cache and server
    /// This method should be called periodically to maintain system hygiene
    /// - Throws: IAPError if cleanup operations fail
    func cleanupExpiredOrders() async throws
    
    /// Recovers pending orders that may have been interrupted
    /// This method synchronizes local and server order states
    /// - Returns: Array of orders that were recovered and updated
    /// - Throws: IAPError if recovery operations fail
    func recoverPendingOrders() async throws -> [IAPOrder]
}
