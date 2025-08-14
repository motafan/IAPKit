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
    public protocol Delegate: AnyObject {
        func iapManager(_ manager: UIKitIAPManager, didLoadProducts products: [IAPProduct])
        func iapManager(_ manager: UIKitIAPManager, didFailToLoadProducts error: IAPError)
        func iapManager(_ manager: UIKitIAPManager, didCompletePurchase result: IAPPurchaseResult)
        func iapManager(_ manager: UIKitIAPManager, didFailPurchase error: IAPError)
        func iapManager(_ manager: UIKitIAPManager, didRestorePurchases transactions: [IAPTransaction])
        func iapManager(_ manager: UIKitIAPManager, didFailToRestorePurchases error: IAPError)
        func iapManager(_ manager: UIKitIAPManager, didUpdateTransaction transaction: IAPTransaction)
        func iapManager(_ manager: UIKitIAPManager, didUpdateLoadingState isLoading: Bool)
        func iapManager(_ manager: UIKitIAPManager, didUpdatePurchasingProducts productIDs: Set<String>)
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
        Task { @MainActor in
            cleanup()
        }
    }
    
    // MARK: - Public Methods
    
    /// 初始化框架
    public func initialize(completion: @escaping () -> Void = {}) {
        Task {
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
            
            await MainActor.run {
                completion()
            }
        }
    }
    
    /// 加载商品
    public func loadProducts(productIDs: Set<String>, completion: @escaping (Result<[IAPProduct], IAPError>) -> Void) {
        guard !isLoadingProducts else {
            completion(.failure(.configurationError("Manager is already loading products")))
            return
        }
        
        isLoadingProducts = true
        clearError()
        
        Task {
            do {
                let loadedProducts = try await coreManager.loadProducts(productIDs: productIDs)
                
                await MainActor.run {
                    self.products = loadedProducts
                    self.isLoadingProducts = false
                    self.delegate?.iapManager(self, didLoadProducts: loadedProducts)
                    completion(.success(loadedProducts))
                }
            } catch {
                await MainActor.run {
                    self.isLoadingProducts = false
                    let iapError = error as? IAPError ?? .unknownError("Failed to load products")
                    self.lastError = iapError
                    self.delegate?.iapManager(self, didFailToLoadProducts: iapError)
                    completion(.failure(iapError))
                }
            }
        }
    }
    
    /// 购买商品
    public func purchase(_ product: IAPProduct, completion: @escaping (Result<IAPPurchaseResult, IAPError>) -> Void) {
        guard !purchasingProducts.contains(product.id) else {
            completion(.failure(.configurationError("Product is already being purchased")))
            return
        }
        
        purchasingProducts.insert(product.id)
        clearError()
        
        Task {
            do {
                let result = try await coreManager.purchase(product)
                
                await MainActor.run {
                    self.purchasingProducts.remove(product.id)
                    
                    // 更新最近交易
                    if case .success(let transaction) = result {
                        self.addRecentTransaction(transaction)
                    }
                    
                    self.delegate?.iapManager(self, didCompletePurchase: result)
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    self.purchasingProducts.remove(product.id)
                    let iapError = error as? IAPError ?? .unknownError("Failed to purchase product")
                    self.lastError = iapError
                    self.delegate?.iapManager(self, didFailPurchase: iapError)
                    completion(.failure(iapError))
                }
            }
        }
    }
    
    /// 恢复购买
    public func restorePurchases(completion: @escaping (Result<[IAPTransaction], IAPError>) -> Void) {
        guard !isRestoringPurchases else {
            completion(.failure(.configurationError("Already restoring purchases")))
            return
        }
        
        isRestoringPurchases = true
        clearError()
        
        Task {
            do {
                let transactions = try await coreManager.restorePurchases()
                
                await MainActor.run {
                    self.isRestoringPurchases = false
                    
                    // 更新最近交易
                    for transaction in transactions {
                        self.addRecentTransaction(transaction)
                    }
                    
                    self.delegate?.iapManager(self, didRestorePurchases: transactions)
                    completion(.success(transactions))
                }
            } catch {
                await MainActor.run {
                    self.isRestoringPurchases = false
                    let iapError = error as? IAPError ?? .unknownError("Failed to restore purchases")
                    self.lastError = iapError
                    self.delegate?.iapManager(self, didFailToRestorePurchases: iapError)
                    completion(.failure(iapError))
                }
            }
        }
    }
    
    /// 完成交易
    public func finishTransaction(_ transaction: IAPTransaction, completion: @escaping (Result<Void, IAPError>) -> Void) {
        Task {
            // 这里可以添加完成交易的逻辑
            // 由于 IAPManager 可能没有直接的 finishTransaction 方法
            // 我们可以通过其他方式处理
            print("完成交易: \(transaction.id)")
            
            await MainActor.run {
                completion(.success(()))
            }
        }
    }
    
    /// 验证收据
    public func validateReceipt(_ receiptData: Data, completion: @escaping (Result<IAPReceiptValidationResult, IAPError>) -> Void) {
        clearError()
        
        Task {
            do {
                let result = try await coreManager.validateReceipt(receiptData)
                
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    let iapError = error as? IAPError ?? .unknownError("Failed to validate receipt")
                    self.lastError = iapError
                    completion(.failure(iapError))
                }
            }
        }
    }
    
    /// 配置框架
    public func configure(with configuration: IAPConfiguration, completion: @escaping () -> Void = {}) {
        Task {
            // Note: IAPManager.shared doesn't have a configure method
            // This is a placeholder for configuration logic
            print("Configuring with: \(configuration)")
            
            await MainActor.run {
                completion()
            }
        }
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
    
    /// 检查框架是否忙碌
    public var isBusy: Bool {
        return isLoadingProducts || isRestoringPurchases || !purchasingProducts.isEmpty || isRecoveryInProgress
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
    private func stopStatusMonitoring() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
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
}
