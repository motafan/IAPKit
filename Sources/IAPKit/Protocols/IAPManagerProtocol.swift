import Foundation

/**
 内购管理器的核心协议，定义了所有公共 API 接口
 
 `IAPManagerProtocol` 是 Swift IAP Framework 的核心协议，定义了内购功能的所有主要接口。
 该协议使用 `@MainActor` 标记，确保所有操作都在主线程执行，保证 UI 更新的线程安全性。
 
 ## 主要功能
 
 - **商品管理**: 加载和缓存 App Store 商品信息
 - **购买处理**: 处理各种类型的商品购买（消耗型、非消耗型、订阅）
 - **购买恢复**: 恢复用户的历史购买记录
 - **收据验证**: 本地和远程收据验证
 - **交易监控**: 实时监听交易状态变化，实现防丢单机制
 
 ## 跨版本兼容性
 
 框架自动检测系统版本并选择合适的 StoreKit API：
 - **iOS 15+**: 使用 StoreKit 2 的现代 async/await API
 - **iOS 13-14**: 使用 StoreKit 1 的传统回调 API，通过 `withCheckedContinuation` 包装为 async/await
 
 ## 防丢单机制
 
 框架实现了完整的防丢单机制：
 - **启动时检查**: 应用启动时自动检查未完成交易
 - **实时监听**: 持续监听交易队列状态变化
 - **自动重试**: 对失败的交易实现指数退避重试
 - **状态持久化**: 关键状态信息持久化存储
 
 ## 使用示例
 
 ```swift
 // 基本使用
 let manager = IAPManager.shared
 await manager.initialize()
 
 // 加载商品
 let products = try await manager.loadProducts(productIDs: ["com.app.product1"])
 
 // 购买商品
 let result = try await manager.purchase(products.first!)
 
 // 恢复购买
 let transactions = try await manager.restorePurchases()
 ```
 
 - Note: 所有方法都是异步的，使用 Swift Concurrency 确保线程安全
 - Important: 必须在应用启动时调用 `initialize()` 方法初始化框架
 */
@MainActor
public protocol IAPManagerProtocol: Sendable {
    
    /**
     加载指定商品 ID 的商品信息
     
     此方法从 App Store 加载商品信息，支持智能缓存以提高性能。
     框架会自动选择合适的 StoreKit API 版本进行加载。
     
     ## 缓存机制
     
     - 首次加载的商品会被缓存，避免重复网络请求
     - 缓存有过期时间，过期后会自动重新加载
     - 可以通过配置调整缓存策略
     
     ## 错误处理
     
     常见错误类型：
     - `IAPError.productNotFound`: 商品 ID 不存在
     - `IAPError.networkError`: 网络连接问题
     - `IAPError.storeKitError`: StoreKit 系统错误
     
     - Parameter productIDs: 要加载的商品 ID 集合，不能为空
     - Returns: 成功加载的商品信息数组，按输入顺序排列
     - Throws: `IAPError` 相关错误
     
     ## 使用示例
     
     ```swift
     let productIDs: Set<String> = ["com.app.premium", "com.app.coins_100"]
     let products = try await manager.loadProducts(productIDs: productIDs)
     
     for product in products {
         print("Product: \(product.displayName), Price: \(product.localizedPrice)")
     }
     ```
     */
    func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct]
    
    /**
     购买指定商品
     
     此方法处理商品购买流程，支持所有类型的商品（消耗型、非消耗型、订阅）。
     购买过程中会自动处理用户交互、支付验证和收据处理。
     
     ## 购买流程
     
     1. 验证商品可购买性
     2. 创建服务器端订单
     3. 发起 StoreKit 购买请求
     4. 处理用户支付交互
     5. 验证购买收据和订单信息
     6. 完成交易处理
     
     ## 防丢单保护
     
     - 购买过程中如果应用崩溃或网络中断，框架会在下次启动时自动恢复
     - 所有交易状态都会被持久化存储
     - 支持自动重试机制
     
     - Parameters:
     ///   - product: 要购买的商品信息
     ///   - userInfo: 可选的用户信息，将与订单关联
     - Returns: 购买结果，包含交易信息和订单信息
     - Throws: `IAPError` 相关错误
     
     ## 使用示例
     
     ```swift
     let product = products.first!
     let userInfo = ["userID": "12345", "campaign": "summer_sale"]
     let result = try await manager.purchase(product, userInfo: userInfo)
     
     switch result {
     case .success(let transaction, let order):
         print("Purchase successful: \(transaction.id), Order: \(order.id)")
     case .pending(let transaction, let order):
         print("Purchase pending approval: \(transaction.id), Order: \(order.id)")
     case .cancelled(let order):
         print("Purchase cancelled by user, Order: \(order?.id ?? "none")")
     case .failed(let error, let order):
         print("Purchase failed: \(error), Order: \(order?.id ?? "none")")
     }
     ```
     */
    func purchase(_ product: IAPProduct, userInfo: [String: any Any & Sendable]?) async throws -> IAPPurchaseResult
    
    /**
     恢复用户的历史购买
     
     此方法恢复用户之前购买的非消耗型商品和订阅。
     适用于用户更换设备或重新安装应用的场景。
     
     ## 恢复机制
     
     - 查询用户 Apple ID 关联的所有历史购买
     - 验证购买的有效性和当前状态
     - 重新激活有效的购买项目
     - 更新本地购买状态
     
     ## 注意事项
     
     - 只能恢复非消耗型商品和订阅
     - 消耗型商品无法通过此方法恢复
     - 需要用户登录 Apple ID
     
     - Returns: 恢复的历史交易数组
     - Throws: `IAPError` 相关错误
     
     ## 使用示例
     
     ```swift
     let restoredTransactions = try await manager.restorePurchases()
     
     for transaction in restoredTransactions {
         print("Restored: \(transaction.productID)")
         // 重新激活相应功能
     }
     ```
     */
    func restorePurchases() async throws -> [IAPTransaction]
    
    /**
     验证购买收据
     
     此方法验证购买收据的真实性和有效性。
     支持本地验证和远程服务器验证两种模式。
     
     ## 验证类型
     
     - **本地验证**: 基本的收据格式和签名验证
     - **远程验证**: 通过 Apple 服务器或自定义服务器验证
     
     ## 安全考虑
     
     - 本地验证可以被绕过，不适用于高价值商品
     - 远程验证更安全，推荐用于重要商品
     - 支持收据数据加密传输
     
     - Parameter receiptData: 要验证的收据数据
     - Returns: 验证结果，包含验证状态和详细信息
     - Throws: `IAPError` 相关错误
     
     ## 使用示例
     
     ```swift
     guard let receiptURL = Bundle.main.appStoreReceiptURL,
           let receiptData = try? Data(contentsOf: receiptURL) else {
         throw IAPError.invalidReceiptData
     }
     
     let result = try await manager.validateReceipt(receiptData)
     
     if result.isValid {
         print("Receipt is valid")
         // 处理验证成功的逻辑
     } else {
         print("Receipt validation failed: \(result.error?.localizedDescription ?? "Unknown error")")
     }
     ```
     */
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult
    
    /**
     验证购买收据（包含订单信息）
     
     此方法验证购买收据的真实性和有效性，同时验证关联的订单信息。
     支持本地验证和远程服务器验证两种模式。
     
     ## 验证类型
     
     - **本地验证**: 基本的收据格式和签名验证
     - **远程验证**: 通过 Apple 服务器或自定义服务器验证，包含订单信息
     
     ## 订单验证
     
     - 验证收据与订单的关联性
     - 检查订单状态和有效性
     - 确保收据和订单信息匹配
     
     - Parameters:
     ///   - receiptData: 要验证的收据数据
     ///   - order: 关联的订单信息
     - Returns: 验证结果，包含验证状态和详细信息
     - Throws: `IAPError` 相关错误
     
     ## 使用示例
     
     ```swift
     guard let receiptURL = Bundle.main.appStoreReceiptURL,
           let receiptData = try? Data(contentsOf: receiptURL) else {
         throw IAPError.invalidReceiptData
     }
     
     let result = try await manager.validateReceipt(receiptData, with: order)
     
     if result.isValid {
         print("Receipt and order validation successful")
         // 处理验证成功的逻辑
     } else {
         print("Receipt validation failed: \(result.error?.localizedDescription ?? "Unknown error")")
     }
     ```
     */
    func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult
    
    /**
     开始监听交易状态变化
     
     此方法启动交易监控器，实时监听 StoreKit 交易队列的状态变化。
     这是防丢单机制的核心组件。
     
     ## 监控功能
     
     - 监听新的交易状态更新
     - 检测未完成的交易
     - 自动处理交易完成流程
     - 处理交易失败和重试
     
     ## 生命周期管理
     
     - 建议在应用启动时调用此方法
     - 应用进入后台时会自动暂停监控
     - 应用回到前台时会自动恢复监控
     
     - Note: 此方法是异步的，会在后台持续运行
     - Important: 必须与 `stopTransactionObserver()` 配对使用
     
     ## 使用示例
     
     ```swift
     // 在应用启动时开始监控
     await manager.startTransactionObserver()
     
     // 设置交易更新处理
     manager.onTransactionUpdate = { transaction in
         // 处理交易状态变化
         print("Transaction updated: \(transaction.id)")
     }
     ```
     */
    func startTransactionObserver() async
    
    /**
     停止监听交易状态变化
     
     此方法停止交易监控器，释放相关资源。
     通常在应用即将终止时调用。
     
     ## 清理操作
     
     - 停止监听交易队列
     - 清理内存中的监控状态
     - 保存必要的持久化数据
     
     - Note: 停止监控后，未完成的交易仍会在下次启动时被处理
     - Important: 应该在应用生命周期的适当时机调用
     
     ## 使用示例
     
     ```swift
     // 在应用即将终止时停止监控
     manager.stopTransactionObserver()
     ```
     */
    func stopTransactionObserver()
    
    // MARK: - Order Management
    
    /**
     为指定商品创建订单
     
     此方法在服务器端创建订单，为后续的购买流程做准备。
     订单包含商品信息、用户信息和其他相关元数据。
     
     ## 订单创建流程
     
     1. 生成本地订单标识符
     2. 向服务器发送订单创建请求
     3. 接收服务器返回的订单信息
     4. 缓存订单信息到本地
     
     ## 错误处理
     
     - 网络连接失败时会自动重试
     - 服务器错误会返回详细的错误信息
     - 订单创建失败不会影响后续的直接购买流程
     
     - Parameters:
     ///   - product: 要创建订单的商品信息
     ///   - userInfo: 可选的用户信息，将与订单关联
     - Returns: 创建的订单信息，包含服务器分配的订单标识符
     - Throws: `IAPError` 相关错误
     
     ## 使用示例
     
     ```swift
     let product = products.first!
     let userInfo = ["userID": "12345", "campaign": "summer_sale"]
     let order = try await manager.createOrder(for: product, userInfo: userInfo)
     
     print("Order created: \(order.id), Server ID: \(order.serverOrderID ?? "none")")
     ```
     */
    func createOrder(for product: IAPProduct, userInfo: [String: any Any & Sendable]?) async throws -> IAPOrder
    
    /**
     查询订单状态
     
     此方法查询指定订单的当前状态，支持本地缓存和服务器查询。
     
     ## 查询策略
     
     1. 首先检查本地缓存
     2. 如果订单状态为终态，直接返回缓存结果
     3. 如果订单状态为进行中，查询服务器获取最新状态
     4. 更新本地缓存
     
     ## 状态同步
     
     - 自动同步服务器端的订单状态变化
     - 处理订单过期和取消情况
     - 支持订单状态的实时更新
     
     - Parameter orderID: 订单的唯一标识符
     - Returns: 订单的当前状态
     - Throws: `IAPError` 相关错误
     
     ## 使用示例
     
     ```swift
     let status = try await manager.queryOrderStatus(order.id)
     
     switch status {
     case .created:
         print("Order is created and ready for payment")
     case .pending:
         print("Order is being processed")
     case .completed:
         print("Order has been completed successfully")
     case .cancelled:
         print("Order has been cancelled")
     case .failed:
         print("Order processing failed")
     }
     ```
     */
    func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus
}
