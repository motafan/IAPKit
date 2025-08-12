import Foundation

/// 内购管理器的核心协议，定义了所有公共 API 接口
@MainActor
public protocol IAPManagerProtocol: Sendable {
    /// 加载指定商品 ID 的商品信息
    /// - Parameter productIDs: 商品 ID 集合
    /// - Returns: 商品信息数组
    /// - Throws: IAPError 相关错误
    func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct]
    
    /// 购买指定商品
    /// - Parameter product: 要购买的商品
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult
    
    /// 恢复用户的历史购买
    /// - Returns: 历史交易数组
    /// - Throws: IAPError 相关错误
    func restorePurchases() async throws -> [IAPTransaction]
    
    /// 验证购买收据
    /// - Parameter receiptData: 收据数据
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult
    
    /// 开始监听交易状态变化
    func startTransactionObserver() async
    
    /// 停止监听交易状态变化
    func stopTransactionObserver()
}