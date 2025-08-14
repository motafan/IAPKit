//
//  SwiftUIIAPManager.swift
//  Examples
//
//  SwiftUI IAP 管理器包装器
//  提供 SwiftUI 兼容的 ObservableObject 接口
//

import SwiftUI
import Combine
import IAPFramework

/// SwiftUI IAP 管理器
/// 将 IAPFramework 包装为 SwiftUI 兼容的 ObservableObject
@MainActor
public final class SwiftUIIAPManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 已加载的商品列表
    @Published public private(set) var products: [IAPProduct] = []
    
    /// 是否正在加载商品
    @Published public private(set) var isLoadingProducts = false
    
    /// 正在购买的商品ID集合
    @Published public private(set) var purchasingProducts: Set<String> = []
    
    /// 是否正在恢复购买
    @Published public private(set) var isRestoringPurchases = false
    
    /// 是否正在进行交易恢复
    @Published public private(set) var isRecoveryInProgress = false
    
    /// 最近的交易列表
    @Published public private(set) var recentTransactions: [IAPTransaction] = []
    
    /// 最后的错误信息
    @Published public private(set) var lastError: IAPError?
    
    /// 交易监听器是否活跃
    @Published public private(set) var isTransactionObserverActive = false
    
    // MARK: - Private Properties
    
    /// 核心 IAP 管理器
    private let coreManager: IAPManager
    
    /// 取消令牌集合
    private var cancellables = Set<AnyCancellable>()
    
    /// 状态更新定时器
    private var statusUpdateTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {
        self.coreManager = IAPManager.shared
        setupStateObservation()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
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
        isLoadingProducts = true
        clearError()
        
        do {
            let loadedProducts = try await coreManager.loadProducts(productIDs: productIDs)
            products = loadedProducts
            isLoadingProducts = false
            return loadedProducts
        } catch {
            isLoadingProducts = false
            await handleError(error)
            throw error
        }
    }
    
    /// 购买商品
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        purchasingProducts.insert(product.id)
        clearError()
        
        do {
            let result = try await coreManager.purchase(product)
            purchasingProducts.remove(product.id)
            
            // 更新最近交易
            if case .success(let transaction) = result {
                addRecentTransaction(transaction)
            }
            
            return result
        } catch {
            purchasingProducts.remove(product.id)
            await handleError(error)
            throw error
        }
    }
    
    /// 恢复购买
    public func restorePurchases() async throws -> [IAPTransaction] {
        isRestoringPurchases = true
        clearError()
        
        do {
            let transactions = try await coreManager.restorePurchases()
            isRestoringPurchases = false
            
            // 更新最近交易
            for transaction in transactions {
                addRecentTransaction(transaction)
            }
            
            return transactions
        } catch {
            isRestoringPurchases = false
            await handleError(error)
            throw error
        }
    }
    
    /// 完成交易
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        // 这里可以添加完成交易的逻辑
        // 由于 IAPManager 可能没有直接的 finishTransaction 方法
        // 我们可以通过其他方式处理
        print("完成交易: \(transaction.id)")
    }
    
    /// 验证收据
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        clearError()
        
        do {
            return try await coreManager.validateReceipt(receiptData)
        } catch {
            await handleError(error)
            throw error
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
        cancellables.removeAll()
    }
    
    /// 清除错误
    public func clearError() {
        lastError = nil
    }
    
    // MARK: - State Query Methods
    
    /// 获取商品的购买状态
    public func purchaseState(for productID: String) -> IAPPurchaseState {
        if purchasingProducts.contains(productID) {
            return .purchasing
        }
        
        if let transaction = recentTransactions.first(where: { $0.productID == productID }) {
            switch transaction.transactionState {
            case .purchased, .restored:
                return .purchased
            case .failed(let error):
                return .failed(error)
            case .deferred:
                return .deferred
            case .purchasing:
                return .purchasing
            }
        }
        
        return .idle
    }
    
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
    
    /// 设置状态观察
    private func setupStateObservation() {
        // 监听应用状态变化
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateTransactionObserverStatus()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateTransactionObserverStatus()
                }
            }
            .store(in: &cancellables)
    }
    
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
        isTransactionObserverActive = UIApplication.shared.applicationState == .active
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

// MARK: - Purchase State Enum

/// 购买状态枚举
public enum IAPPurchaseState: Equatable {
    case idle
    case purchasing
    case purchased
    case failed(IAPError)
    case cancelled
    case deferred
    
    public static func == (lhs: IAPPurchaseState, rhs: IAPPurchaseState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.purchasing, .purchasing),
             (.purchased, .purchased),
             (.cancelled, .cancelled),
             (.deferred, .deferred):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}