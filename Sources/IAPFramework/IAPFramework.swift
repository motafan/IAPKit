import Foundation

/// IAPFramework - 现代化的 Swift 内购框架
/// 
/// 这个框架提供了完整的内购功能，支持：
/// - iOS 13+ 系统兼容性
/// - StoreKit 1 和 StoreKit 2 自动适配
/// - Swift Concurrency (async/await) 支持
/// - 严格的并发检查
/// - 防丢单机制
/// - UIKit 和 SwiftUI 兼容
/// 
/// 主要特性：
/// - 商品加载和管理
/// - 购买流程处理（消耗型、非消耗型、订阅）
/// - 购买恢复
/// - 收据验证（本地和远程）
/// - 交易监听和自动重试
/// - 完整的错误处理和本地化支持
/// 
/// 使用示例：
/// ```swift
/// let manager = IAPManager.shared
/// 
/// // 加载商品
/// let products = try await manager.loadProducts(productIDs: ["com.example.product1"])
/// 
/// // 购买商品
/// let result = try await manager.purchase(products.first!)
/// 
/// // 恢复购买
/// let transactions = try await manager.restorePurchases()
/// ```
public struct IAPFramework {
    /// 框架版本号
    public static let version = "1.0.0"
    
    /// 框架名称
    public static let name = "IAPFramework"
    
    /// 支持的最低 iOS 版本
    public static let minimumIOSVersion = "13.0"
    
    /// 是否支持 StoreKit 2
    @available(iOS 15.0, *)
    public static let supportsStoreKit2 = true
}
