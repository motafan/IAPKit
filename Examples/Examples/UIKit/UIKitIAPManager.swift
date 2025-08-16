//
//  UIKitIAPManager.swift
//  Examples
//
//  UIKit IAP 管理器包装器
//  提供 UIKit 兼容的委托模式接口
//

import UIKit
import Foundation
import IAPFramework

/// UIKit IAP 管理器
/// 将 IAPFramework 包装为 UIKit 兼容的委托模式接口
@MainActor
public final class UIKitIAPManager {
    
    // MARK: - Delegate Protocol
    
    /// UIKit IAP 管理器委托协议
    @MainActor public protocol Delegate: AnyObject {
        func iapManager(_ manager: UIKitIAPManager, didLoadProducts products: [IAPProduct])
        func iapManager(_ manager: UIKitIAPManager, didFailToLoadProducts error: IAPError)
        func iapManager(_ manager: UIKitIAPManager, didCompletePurchase result: IAPPurchaseResult)
        func iapManager(_ manager: UIKitIAPManager, didFailPurchase error: IAPError)
        func iapManager(_ manager: UIKitIAPManager, didRestorePurchases transactions: [IAPTransaction])
        func iapManager(_ manager: UIKitIAPManager, didFailToRestorePurchases error: IAPError)
        func iapManager(_ manager: UIKitIAPManager, didUpdateTransaction transaction: IAPTransaction)
        func iapManager(_ manager: UIKitIAPManager, didUpdateLoadingState isLoading: Bool)
        func iapManager(_ manager: UIKitIAPManager, didUpdatePurchasingProducts productIDs: Set<String>)
        func iapManager(_ manager: UIKitIAPManager, didUpdateCreatingOrders productIDs: Set<String>)
        func iapManager(_ manager: UIKitIAPManager, didCreateOrder order: IAPOrder)
        func iapManager(_ manager: UIKitIAPManager, didFailToCreateOrder error: IAPError, for productID: String)
        func iapManager(_ manager: UIKitIAPManager, didUpdateOrder order: IAPOrder)
    }
    
    // MARK: - Properties
    
    /// 委托对象
    public weak var delegate: Delegate?
    
    /// 已加载的商品列表
    public private(set) var products: [IAPProduct] = []
    
    /// 是否正在加载商品
    public private(set) var isLoadingProducts = false {
        didSet {
            if oldValue != isLoadingProducts {
                delegate?.iapManager(self, didUpdateLoadingState: isLoadingProducts)
            }
        }
    }
    
    /// 正在购买的商品ID集合
    public private(set) var purchasingProducts: Set<String> = [] {
        didSet {
            if oldValue != purchasingProducts {
                delegate?.iapManager(self, didUpdatePurchasingProducts: purchasingProducts)
            }
        }
    }
    
    /// 是否正在恢复购买
    public private(set) var isRestoringPurchases = false
    
    /// 是否正在进行交易恢复
    public private(set) var isRecoveryInProgress = false
    
    /// 最近的交易列表
    public private(set) var recentTransactions: [IAPTransaction] = []
    
    /// 活跃的订单列表
    public private(set) var activeOrders: [IAPOrder] = []
    
    /// 最近的订单列表
    public private(set) var recentOrders: [IAPOrder] = []
    
    /// 正在创建订单的商品ID集合
    public private(set) var creatingOrders: Set<String> = [] {
        didSet {
            if oldValue != creatingOrders {
                delegate?.iapManager(self, didUpdateCreatingOrders: creatingOrders)
            }
        }
    }
    
    /// 最后的错误信息
    public private(set) var lastError: IAPError?
    
    /// 交易监听器是否活跃
    public private(set) var isTransactionObserverActive = false
    
    // MARK: - Private Properties
    
    /// 核心 IAP 管理器
    private let coreManager: IAPManager
    
    /// 状态更新定时器
    private var statusUpdateTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {
        self.coreManager = IAPManager.shared
    }
    
    deinit {
        // In Swift 6, we cannot use Task in deinit as it may outlive the object
        // The cleanup will be handled by the app lifecycle or manual calls
        stopStatusMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 初始化框架
    public func initialize() async {
        let configuration = IAPConfiguration(
            autoFinishTransactions: false,
            maxRetryAttempts: 3
        )
        
        // Note: IAPManager.shared doesn't have a configure method
        // This is a placeholder for configuration logic
        print("Initializing with configuration: \(configuration)")
        
        // 启动状态监听
        startStatusMonitoring()
        
        // 更新交易监听状态
        updateTransactionObserverStatus()
    }
    
    /// 加载商品
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        guard !isLoadingProducts else {
            throw IAPError.configurationError("Manager is already loading products")
        }
        
        isLoadingProducts = true
        clearError()
        
        defer {
            isLoadingProducts = false
        }
        
        do {
            let loadedProducts = try await coreManager.loadProducts(productIDs: productIDs)
            
            self.products = loadedProducts
            self.delegate?.iapManager(self, didLoadProducts: loadedProducts)
            return loadedProducts
        } catch {
            let iapError = error as? IAPError ?? .unknownError("Failed to load products")
            self.lastError = iapError
            self.delegate?.iapManager(self, didFailToLoadProducts: iapError)
            throw iapError
        }
    }
    
    /// 购买商品（使用订单）
    public func purchase(_ product: IAPProduct, userInfo: [String: Any]? = nil) async throws -> IAPPurchaseResult {
        guard !purchasingProducts.contains(product.id) else {
            throw IAPError.configurationError("Product is already being purchased")
        }
        
        purchasingProducts.insert(product.id)
        clearError()
        
        defer {
            purchasingProducts.remove(product.id)
        }
        
        do {
            let result = try await coreManager.purchase(product, userInfo: userInfo)
            
            // 更新最近交易和订单
            switch result {
            case .success(let transaction, let order):
                self.addRecentTransaction(transaction)
                self.addRecentOrder(order)
            case .pending(let transaction, let order):
                self.addRecentTransaction(transaction)
                self.addRecentOrder(order)
            case .cancelled(let order), .failed(_, let order):
                if let order = order {
                    self.addRecentOrder(order)
                }
            }
            
            self.delegate?.iapManager(self, didCompletePurchase: result)
            return result
        } catch {
            let iapError = error as? IAPError ?? .unknownError("Failed to purchase product")
            self.lastError = iapError
            self.delegate?.iapManager(self, didFailPurchase: iapError)
            throw iapError
        }
    }
    
    /// 购买商品（向后兼容，不使用订单）
    public func purchaseWithoutOrder(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        return try await purchase(product, userInfo: nil)
    }
    
    /// 恢复购买
    public func restorePurchases() async throws -> [IAPTransaction] {
        guard !isRestoringPurchases else {
            throw IAPError.configurationError("Already restoring purchases")
        }
        
        isRestoringPurchases = true
        clearError()
        
        defer {
            isRestoringPurchases = false
        }
        
        do {
            let transactions = try await coreManager.restorePurchases()
            
            // 更新最近交易
            for transaction in transactions {
                self.addRecentTransaction(transaction)
            }
            
            self.delegate?.iapManager(self, didRestorePurchases: transactions)
            return transactions
        } catch {
            let iapError = error as? IAPError ?? .unknownError("Failed to restore purchases")
            self.lastError = iapError
            self.delegate?.iapManager(self, didFailToRestorePurchases: iapError)
            throw iapError
        }
    }
    
    /// 完成交易
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        // 这里可以添加完成交易的逻辑
        // 由于 IAPManager 可能没有直接的 finishTransaction 方法
        // 我们可以通过其他方式处理
        print("完成交易: \(transaction.id)")
        
        try await coreManager.finishTransaction(transaction)
    }
    
    /// 验证收据
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        clearError()
        
        do {
            let result = try await coreManager.validateReceipt(receiptData)
            return result
        } catch {
            let iapError = error as? IAPError ?? .unknownError("Failed to validate receipt")
            self.lastError = iapError
            throw iapError
        }
    }
    
    /// 验证收据（包含订单信息）
    public func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult {
        clearError()
        
        do {
            let result = try await coreManager.validateReceipt(receiptData, with: order)
            return result
        } catch {
            let iapError = error as? IAPError ?? .unknownError("Failed to validate receipt")
            self.lastError = iapError
            throw iapError
        }
    }
    
    /// 创建订单
    public func createOrder(for product: IAPProduct, userInfo: [String: Any]? = nil) async throws -> IAPOrder {
        guard !creatingOrders.contains(product.id) else {
            throw IAPError.configurationError("Order is already being created for this product")
        }
        
        creatingOrders.insert(product.id)
        clearError()
        
        defer {
            creatingOrders.remove(product.id)
        }
        
        do {
            let order = try await coreManager.createOrder(for: product, userInfo: userInfo)
            
            self.addActiveOrder(order)
            self.addRecentOrder(order)
            self.delegate?.iapManager(self, didCreateOrder: order)
            return order
        } catch {
            let iapError = error as? IAPError ?? .unknownError("Failed to create order")
            self.lastError = iapError
            self.delegate?.iapManager(self, didFailToCreateOrder: iapError, for: product.id)
            throw iapError
        }
    }
    
    /// 查询订单状态
    public func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus {
        clearError()
        
        do {
            let status = try await coreManager.queryOrderStatus(orderID)
            self.updateOrderStatus(orderID, status: status)
            return status
        } catch {
            let iapError = error as? IAPError ?? .unknownError("Failed to query order status")
            self.lastError = iapError
            throw iapError
        }
    }
    
    /// 配置框架
    public func configure(with configuration: IAPConfiguration) async {
        // Note: IAPManager.shared doesn't have a configure method
        // This is a placeholder for configuration logic
        print("Configuring with: \(configuration)")
    }
    
    /// 清理资源
    public func cleanup() {
        stopStatusMonitoring()
    }
    
    /// 清除错误
    public func clearError() {
        lastError = nil
    }
    
    // MARK: - State Query Methods
    
    /// 检查是否正在购买指定商品
    public func isPurchasing(_ productID: String) -> Bool {
        return purchasingProducts.contains(productID)
    }
    
    /// 获取指定商品的最近交易
    public func getRecentTransaction(for productID: String) -> IAPTransaction? {
        return recentTransactions.first { $0.productID == productID }
    }
    
    /// 获取指定商品的活跃订单
    public func getActiveOrder(for productID: String) -> IAPOrder? {
        return activeOrders.first { $0.productID == productID }
    }
    
    /// 获取指定商品的最近订单
    public func getRecentOrder(for productID: String) -> IAPOrder? {
        return recentOrders.first { $0.productID == productID }
    }
    
    /// 检查是否正在创建订单
    public func isCreatingOrder(_ productID: String) -> Bool {
        return creatingOrders.contains(productID)
    }
    
    /// 检查框架是否忙碌
    public var isBusy: Bool {
        return isLoadingProducts || isRestoringPurchases || !purchasingProducts.isEmpty || !creatingOrders.isEmpty || isRecoveryInProgress
    }
    
    /// 获取本地化的错误消息
    public var localizedErrorMessage: String {
        return lastError?.localizedDescription ?? "未知错误"
    }
    
    // MARK: - Private Methods
    
    /// 开始状态监控
    private func startStatusMonitoring() {
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateStatus()
            }
        }
    }
    
    /// 停止状态监控
    private nonisolated func stopStatusMonitoring() {
        // Use MainActor.assumeIsolated since we know this is safe for timer cleanup
        MainActor.assumeIsolated {
            statusUpdateTimer?.invalidate()
            statusUpdateTimer = nil
        }
    }
    
    /// 更新状态
    private func updateStatus() async {
        // 更新交易监听状态
        updateTransactionObserverStatus()
        
        // 检查恢复进度（这里需要根据实际的 IAPManager API 调整）
        // isRecoveryInProgress = await coreManager.isRecoveryInProgress
    }
    
    /// 更新交易监听器状态
    private func updateTransactionObserverStatus() {
        // 这里需要根据实际的 IAPManager API 来检查交易监听器状态
        // 暂时使用应用状态作为代理
        let newStatus = UIApplication.shared.applicationState == .active
        
        if isTransactionObserverActive != newStatus {
            isTransactionObserverActive = newStatus
        }
    }
    
    /// 添加最近交易
    private func addRecentTransaction(_ transaction: IAPTransaction) {
        // 移除同一商品的旧交易
        recentTransactions.removeAll { $0.productID == transaction.productID }
        
        // 添加新交易到开头
        recentTransactions.insert(transaction, at: 0)
        
        // 限制最近交易数量
        if recentTransactions.count > 10 {
            recentTransactions = Array(recentTransactions.prefix(10))
        }
        
        // 通知委托
        delegate?.iapManager(self, didUpdateTransaction: transaction)
    }
    
    /// 添加活跃订单
    private func addActiveOrder(_ order: IAPOrder) {
        // 移除同一商品的旧活跃订单
        activeOrders.removeAll { $0.productID == order.productID }
        
        // 只有非终态订单才添加到活跃列表
        if !order.isTerminal {
            activeOrders.insert(order, at: 0)
        }
        
        // 限制活跃订单数量
        if activeOrders.count > 20 {
            activeOrders = Array(activeOrders.prefix(20))
        }
    }
    
    /// 添加最近订单
    private func addRecentOrder(_ order: IAPOrder) {
        // 移除同一订单ID的旧记录
        recentOrders.removeAll { $0.id == order.id }
        
        // 添加新订单到开头
        recentOrders.insert(order, at: 0)
        
        // 限制最近订单数量
        if recentOrders.count > 20 {
            recentOrders = Array(recentOrders.prefix(20))
        }
        
        // 如果订单变为终态，从活跃列表中移除
        if order.isTerminal {
            activeOrders.removeAll { $0.id == order.id }
        }
        
        // 通知委托
        delegate?.iapManager(self, didUpdateOrder: order)
    }
    
    /// 更新订单状态
    private func updateOrderStatus(_ orderID: String, status: IAPOrderStatus) {
        // 更新活跃订单列表
        if let index = activeOrders.firstIndex(where: { $0.id == orderID }) {
            let updatedOrder = activeOrders[index].withStatus(status)
            activeOrders[index] = updatedOrder
            
            // 如果订单变为终态，移动到最近订单列表
            if status.isTerminal {
                activeOrders.remove(at: index)
                addRecentOrder(updatedOrder)
            } else {
                delegate?.iapManager(self, didUpdateOrder: updatedOrder)
            }
        }
        
        // 更新最近订单列表
        if let index = recentOrders.firstIndex(where: { $0.id == orderID }) {
            let updatedOrder = recentOrders[index].withStatus(status)
            recentOrders[index] = updatedOrder
            delegate?.iapManager(self, didUpdateOrder: updatedOrder)
        }
    }
    
    /// 处理错误
    private func handleError(_ error: Error) async {
        if let iapError = error as? IAPError {
            lastError = iapError
        } else {
            lastError = IAPError.unknownError("Unknown error occurred")
        }
    }
}

// MARK: - Default Delegate Implementation

public extension UIKitIAPManager.Delegate {
    
    func iapManager(_ manager: UIKitIAPManager, didLoadProducts products: [IAPProduct]) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailToLoadProducts error: IAPError) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didCompletePurchase result: IAPPurchaseResult) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailPurchase error: IAPError) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didRestorePurchases transactions: [IAPTransaction]) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailToRestorePurchases error: IAPError) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateTransaction transaction: IAPTransaction) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateLoadingState isLoading: Bool) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdatePurchasingProducts productIDs: Set<String>) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateCreatingOrders productIDs: Set<String>) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didCreateOrder order: IAPOrder) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailToCreateOrder error: IAPError, for productID: String) {
        // 默认实现为空
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateOrder order: IAPOrder) {
        // 默认实现为空
    }
}
