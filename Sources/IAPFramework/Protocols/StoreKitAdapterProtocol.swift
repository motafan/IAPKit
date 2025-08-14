import Foundation

/**
 StoreKit 适配器协议，抽象不同版本的 StoreKit API
 
 `StoreKitAdapterProtocol` 是框架的核心抽象层，用于统一不同版本的 StoreKit API。
 通过这个协议，框架可以透明地支持 StoreKit 1 和 StoreKit 2，而上层代码无需关心具体实现。
 
 ## 跨版本兼容性设计
 
 ### StoreKit 2 适配器 (iOS 15+)
 - 直接使用 StoreKit 2 的现代 async/await API
 - 利用 `Product.products(for:)` 加载商品
 - 使用 `Product.purchase()` 处理购买
 - 通过 `Transaction.updates` 监听交易变化
 
 ### StoreKit 1 适配器 (iOS 13-14)
 - 使用传统的 `SKProductsRequest` 和 `SKPaymentQueue`
 - 通过 `withCheckedContinuation` 将回调转换为 async/await
 - 实现 `SKProductsRequestDelegate` 和 `SKPaymentTransactionObserver`
 - 手动管理交易状态和错误处理
 
 ## 适配器选择机制
 
 框架使用 `StoreKitAdapterFactory` 在运行时自动选择合适的适配器：
 
 ```swift
 let adapter = StoreKitAdapterFactory.createAdapter()
 // 自动选择 StoreKit 2 (iOS 15+) 或 StoreKit 1 (iOS 13-14)
 ```
 
 ## 实现要求
 
 所有适配器实现必须：
 - 符合 `Sendable` 协议，确保线程安全
 - 使用统一的错误类型 `IAPError`
 - 支持异步操作和取消
 - 实现完整的交易生命周期管理
 
 - Note: 此协议主要供框架内部使用，应用开发者通常不需要直接实现
 - Important: 所有方法都必须是线程安全的，支持并发调用
 */
public protocol StoreKitAdapterProtocol: Sendable {
    
    /**
     加载商品信息
     
     从 App Store 加载指定商品 ID 的详细信息。
     不同适配器的实现方式：
     
     - **StoreKit 2**: 使用 `Product.products(for: productIDs)`
     - **StoreKit 1**: 使用 `SKProductsRequest` 并通过 continuation 包装
     
     - Parameter productIDs: 要加载的商品 ID 集合
     - Returns: 成功加载的商品信息数组
     - Throws: `IAPError` 相关错误
     
     ## 实现注意事项
     
     - 必须处理网络错误和超时
     - 应该验证返回的商品 ID 与请求的 ID 匹配
     - 需要正确转换 StoreKit 错误为 `IAPError`
     */
    func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct]
    
    /**
     购买商品
     
     发起商品购买流程，处理用户交互和支付验证。
     不同适配器的实现方式：
     
     - **StoreKit 2**: 使用 `Product.purchase()` 方法
     - **StoreKit 1**: 使用 `SKPaymentQueue.default().add()` 并监听交易状态
     
     - Parameter product: 要购买的商品信息
     - Returns: 购买结果，包含交易信息或状态
     - Throws: `IAPError` 相关错误
     
     ## 实现注意事项
     
     - 必须处理用户取消、支付失败等情况
     - 需要正确处理延期交易（家长控制）
     - 应该验证购买结果的完整性
     */
    func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult
    
    /**
     恢复购买
     
     恢复用户的历史购买记录。
     不同适配器的实现方式：
     
     - **StoreKit 2**: 使用 `Transaction.currentEntitlements`
     - **StoreKit 1**: 使用 `SKPaymentQueue.default().restoreCompletedTransactions()`
     
     - Returns: 恢复的历史交易数组
     - Throws: `IAPError` 相关错误
     
     ## 实现注意事项
     
     - 只应返回有效的非消耗型商品和订阅
     - 需要验证交易的当前状态
     - 应该处理恢复过程中的错误
     */
    func restorePurchases() async throws -> [IAPTransaction]
    
    /**
     开始交易观察者
     
     启动交易状态监听，这是防丢单机制的核心。
     不同适配器的实现方式：
     
     - **StoreKit 2**: 监听 `Transaction.updates` 异步序列
     - **StoreKit 1**: 添加 `SKPaymentTransactionObserver` 到支付队列
     
     ## 实现注意事项
     
     - 必须在后台持续监听交易变化
     - 应该处理应用生命周期变化
     - 需要正确管理观察者的生命周期
     */
    func startTransactionObserver() async
    
    /**
     停止交易观察者
     
     停止交易状态监听，清理相关资源。
     不同适配器的实现方式：
     
     - **StoreKit 2**: 取消 `Transaction.updates` 监听任务
     - **StoreKit 1**: 从支付队列移除 `SKPaymentTransactionObserver`
     
     ## 实现注意事项
     
     - 必须正确清理所有监听资源
     - 应该保存必要的状态信息
     - 需要确保不会泄漏内存
     */
    func stopTransactionObserver()
    
    /**
     获取未完成的交易
     
     查询当前所有未完成的交易，用于防丢单机制。
     不同适配器的实现方式：
     
     - **StoreKit 2**: 查询 `Transaction.unfinished`
     - **StoreKit 1**: 检查 `SKPaymentQueue.default().transactions`
     
     - Returns: 未完成交易数组
     
     ## 实现注意事项
     
     - 应该返回所有需要处理的交易
     - 需要过滤掉已经完成的交易
     - 应该按时间顺序排序
     */
    func getPendingTransactions() async -> [IAPTransaction]
    
    /**
     完成交易
     
     标记交易为已完成，从交易队列中移除。
     不同适配器的实现方式：
     
     - **StoreKit 2**: 调用 `Transaction.finish()`
     - **StoreKit 1**: 调用 `SKPaymentQueue.default().finishTransaction()`
     
     - Parameter transaction: 要完成的交易
     - Throws: `IAPError` 相关错误
     
     ## 实现注意事项
     
     - 只有在确认交易处理完成后才能调用
     - 必须处理完成过程中的错误
     - 应该验证交易的有效性
     */
    func finishTransaction(_ transaction: IAPTransaction) async throws
}