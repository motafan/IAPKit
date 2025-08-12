import Foundation

/// StoreKit 适配器协议，抽象不同版本的 StoreKit API
public protocol StoreKitAdapterProtocol: Sendable {
    /// 加载商品信息
    /// - Parameter productIDs: 商品 ID 集合
    /// - Returns: 商品信息数组
    /// - Throws: IAPError 相关错误
    func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct]
    
    /// 购买商品
    /// - Parameter product: 要购买的商品
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult
    
    /// 恢复购买
    /// - Returns: 历史交易数组
    /// - Throws: IAPError 相关错误
    func restorePurchases() async throws -> [IAPTransaction]
    
    /// 开始交易观察者
    func startTransactionObserver() async
    
    /// 停止交易观察者
    func stopTransactionObserver()
    
    /// 获取未完成的交易
    /// - Returns: 未完成交易数组
    func getPendingTransactions() async -> [IAPTransaction]
    
    /// 完成交易
    /// - Parameter transaction: 要完成的交易
    func finishTransaction(_ transaction: IAPTransaction) async throws
}