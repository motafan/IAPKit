import Foundation

/// 内购管理器状态
@MainActor
public final class IAPState: Sendable {
    /// 状态变化委托
    public weak var delegate: IAPStateDelegate?
    
    /// 当前加载的商品
    public private(set) var products: [IAPProduct] = [] {
        didSet {
            delegate?.iapStateDidUpdateProducts(products)
        }
    }
    
    /// 正在进行的购买
    public private(set) var purchasingProducts: Set<String> = [] {
        didSet {
            delegate?.iapStateDidUpdatePurchasing(purchasingProducts)
        }
    }
    
    /// 最近的交易
    public private(set) var recentTransactions: [IAPTransaction] = []
    
    /// 当前错误
    public private(set) var lastError: IAPError? {
        didSet {
            delegate?.iapStateDidUpdateError(lastError)
        }
    }
    
    /// 是否正在加载商品
    public private(set) var isLoadingProducts = false {
        didSet {
            delegate?.iapStateDidUpdateLoading(isLoadingProducts)
        }
    }
    
    /// 是否正在恢复购买
    public private(set) var isRestoringPurchases = false {
        didSet {
            delegate?.iapStateDidUpdateRestoring(isRestoringPurchases)
        }
    }
    
    /// 交易观察者是否活跃
    public private(set) var isTransactionObserverActive = false
    
    /// 是否正在进行交易恢复
    public private(set) var isRecoveryInProgress = false {
        didSet {
            delegate?.iapStateDidUpdateRecovery(isRecoveryInProgress)
        }
    }
    
    public init() {}
    
    // MARK: - 状态更新方法
    
    /// 更新商品列表
    /// - Parameter products: 新的商品列表
    public func updateProducts(_ products: [IAPProduct]) {
        self.products = products
    }
    
    /// 添加正在购买的商品
    /// - Parameter productID: 商品ID
    public func addPurchasingProduct(_ productID: String) {
        purchasingProducts.insert(productID)
    }
    
    /// 移除正在购买的商品
    /// - Parameter productID: 商品ID
    public func removePurchasingProduct(_ productID: String) {
        purchasingProducts.remove(productID)
    }
    
    /// 添加交易记录
    /// - Parameter transaction: 交易信息
    public func addTransaction(_ transaction: IAPTransaction) {
        // 保持最近20个交易记录
        recentTransactions.insert(transaction, at: 0)
        if recentTransactions.count > 20 {
            recentTransactions.removeLast()
        }
        delegate?.iapStateDidAddTransaction(transaction)
    }
    
    /// 设置错误
    /// - Parameter error: 错误信息
    public func setError(_ error: IAPError?) {
        lastError = error
    }
    
    /// 设置加载商品状态
    /// - Parameter isLoading: 是否正在加载
    public func setLoadingProducts(_ isLoading: Bool) {
        isLoadingProducts = isLoading
    }
    
    /// 设置恢复购买状态
    /// - Parameter isRestoring: 是否正在恢复
    public func setRestoringPurchases(_ isRestoring: Bool) {
        isRestoringPurchases = isRestoring
    }
    
    /// 设置交易观察者状态
    /// - Parameter isActive: 是否活跃
    public func setTransactionObserverActive(_ isActive: Bool) {
        isTransactionObserverActive = isActive
    }
    
    /// 设置交易恢复状态
    /// - Parameter isInProgress: 是否正在恢复
    public func setRecoveryInProgress(_ isInProgress: Bool) {
        isRecoveryInProgress = isInProgress
    }
    
    /// 清除所有状态
    public func reset() {
        products.removeAll()
        purchasingProducts.removeAll()
        recentTransactions.removeAll()
        lastError = nil
        isLoadingProducts = false
        isRestoringPurchases = false
        isTransactionObserverActive = false
        isRecoveryInProgress = false
    }
    
    // MARK: - 便利方法
    
    /// 检查商品是否正在购买
    /// - Parameter productID: 商品ID
    /// - Returns: 是否正在购买
    public func isPurchasing(_ productID: String) -> Bool {
        return purchasingProducts.contains(productID)
    }
    
    /// 根据ID获取商品
    /// - Parameter productID: 商品ID
    /// - Returns: 商品信息
    public func product(for productID: String) -> IAPProduct? {
        return products.first { $0.id == productID }
    }
    
    /// 获取指定商品的最近交易
    /// - Parameter productID: 商品ID
    /// - Returns: 最近的交易
    public func recentTransaction(for productID: String) -> IAPTransaction? {
        return recentTransactions.first { $0.productID == productID }
    }
    
    /// 是否有任何操作正在进行
    public var isBusy: Bool {
        return isLoadingProducts || isRestoringPurchases || isRecoveryInProgress || !purchasingProducts.isEmpty
    }
}

// MARK: - 状态变化通知

/// 状态变化通知协议
public protocol IAPStateDelegate: AnyObject {
    /// 商品列表更新
    func iapStateDidUpdateProducts(_ products: [IAPProduct])
    
    /// 购买状态变化
    func iapStateDidUpdatePurchasing(_ productIDs: Set<String>)
    
    /// 交易状态变化
    func iapStateDidAddTransaction(_ transaction: IAPTransaction)
    
    /// 错误状态变化
    func iapStateDidUpdateError(_ error: IAPError?)
    
    /// 加载状态变化
    func iapStateDidUpdateLoading(_ isLoading: Bool)
    
    /// 恢复状态变化
    func iapStateDidUpdateRestoring(_ isRestoring: Bool)
    
    /// 交易恢复状态变化
    func iapStateDidUpdateRecovery(_ isRecovering: Bool)
}

/// 购买状态枚举
public enum IAPPurchaseState: Sendable, Equatable {
    /// 空闲状态
    case idle
    /// 正在购买
    case purchasing(productID: String)
    /// 购买成功
    case purchased(transaction: IAPTransaction)
    /// 购买失败
    case failed(error: IAPError)
    /// 购买取消
    case cancelled
    /// 购买延期
    case deferred(transaction: IAPTransaction)
}

/// 恢复购买状态枚举
public enum IAPRestoreState: Sendable, Equatable {
    /// 空闲状态
    case idle
    /// 正在恢复
    case restoring
    /// 恢复成功
    case restored(transactions: [IAPTransaction])
    /// 恢复失败
    case failed(error: IAPError)
}