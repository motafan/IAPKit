import Foundation

/**
 内购管理器主类，整合所有服务组件
 
 `IAPManager` 是 Swift IAP Framework 的核心管理类，提供了完整的内购功能实现。
 它采用单例模式，整合了商品服务、购买服务、交易监控等所有组件，为应用提供统一的内购接口。
 
 ## 核心特性
 
 ### 🔄 跨版本兼容性
 - **自动适配**: 运行时检测系统版本，自动选择 StoreKit 1 或 StoreKit 2
 - **透明切换**: 上层 API 保持一致，无需关心底层实现差异
 - **向前兼容**: 支持 iOS 13+ 的所有版本
 
 ### 🛡️ 防丢单机制
 - **启动恢复**: 应用启动时自动检查和处理未完成交易
 - **实时监控**: 持续监听交易队列状态变化
 - **智能重试**: 指数退避算法处理失败交易
 - **状态持久化**: 关键状态信息本地存储
 
 ### ⚡ 性能优化
 - **智能缓存**: 商品信息缓存，减少网络请求
 - **并发安全**: 使用 Swift Concurrency 确保线程安全
 - **内存管理**: 自动清理过期数据和无用资源
 
 ### 🔧 可配置性
 - **灵活配置**: 支持自定义配置选项
 - **依赖注入**: 支持测试时注入 Mock 对象
 - **调试支持**: 详细的日志和调试信息
 
 ## 使用指南
 
 ### 基本初始化
 ```swift
 // 使用默认单例，需要提供配置
 let manager = IAPManager.shared
 let config = IAPConfiguration.default(networkBaseURL: URL(string: "https://api.example.com")!)
 await manager.initialize(configuration: config)
 ```
 
 ### 自定义配置
 ```swift
 let config = IAPConfiguration.default(networkBaseURL: URL(string: "https://api.example.com")!)
 let manager = IAPManager(configuration: config)
 await manager.initialize(configuration: nil) // 使用构造函数中的配置
 ```
 
 ### 完整购买流程
 ```swift
 // 1. 加载商品
 let products = try await manager.loadProducts(productIDs: ["com.app.premium"])
 
 // 2. 购买商品
 let result = try await manager.purchase(products.first!)
 
 // 3. 处理结果
 switch result {
 case .success(let transaction):
     // 购买成功，激活功能
     activatePremiumFeatures()
 case .cancelled:
     // 用户取消购买
     showCancelledMessage()
 }
 ```
 
 ## 生命周期管理
 
 ```swift
 class AppDelegate: UIApplicationDelegate {
     func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
         Task {
             let config = IAPConfiguration.default(networkBaseURL: URL(string: "https://api.example.com")!)
             await IAPManager.shared.initialize(configuration: config)
         }
         return true
     }
     
     func applicationWillTerminate(_ application: UIApplication) {
         IAPManager.shared.cleanup()
     }
 }
 ```
 
 - Note: 使用 `@MainActor` 标记，确保所有操作在主线程执行
 - Important: 必须在应用启动时调用 `initialize(configuration:)` 方法
 - Warning: 不要在多个地方创建 IAPManager 实例，推荐使用单例模式
 */
@MainActor
public final class IAPManager: IAPManagerProtocol {
    
    // MARK: - Singleton
    
    /// 单例实例
    public static let shared = IAPManager()
    
    // MARK: - Private Properties
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 商品服务
    private var productService: ProductService!
    
    /// 购买服务
    private var purchaseService: PurchaseService!
    
    /// 交易监控器
    private var transactionMonitor: TransactionMonitor!
    
    /// 交易恢复管理器
    private var recoveryManager: TransactionRecoveryManager!
    
    /// 收据验证器
    private var receiptValidator: ReceiptValidatorProtocol!
    
    /// 订单服务
    private var orderService: OrderServiceProtocol!
    
    /// 状态管理器
    private let state: IAPState
    
    /// 配置信息
    private var configuration: IAPConfiguration?

    /// 是否已初始化
    private var isInitialized = false
    
    // MARK: - Public Properties
    
    /// 当前状态
    public var currentState: IAPState {
        return state
    }
    
    /// 当前配置
    public var currentConfiguration: IAPConfiguration {
        return configuration ?? IAPConfiguration.placeholder
    }
    
    /// 是否正在监听交易
    public var isTransactionObserverActive: Bool {
        return state.isTransactionObserverActive
    }
    
    // MARK: - Initialization
    
    /// 私有初始化方法（单例模式）
    /// - Note: 单例实例延迟初始化，需要调用 initialize(configuration:) 方法完成配置
    private init() {
        // 创建适配器
        self.adapter = StoreKitAdapterFactory.createAdapter()
        
        // 创建状态管理器
        self.state = IAPState()
        
        IAPLogger.info("IAPManager: Created singleton instance (requires initialization)")
    }
    
    /// 使用自定义配置初始化（用于测试和依赖注入）
    /// - Parameters:
    ///   - configuration: 自定义配置
    ///   - adapter: 自定义适配器（可选，用于测试）
    ///   - receiptValidator: 自定义收据验证器（可选，用于测试）
    ///   - orderService: 自定义订单服务（可选，用于测试）
    public init(
        configuration: IAPConfiguration,
        adapter: StoreKitAdapterProtocol? = nil,
        receiptValidator: ReceiptValidatorProtocol? = nil,
        orderService: OrderServiceProtocol? = nil
    ) {
        self.configuration = configuration
        
        // 使用提供的适配器或创建默认适配器
        self.adapter = adapter ?? StoreKitAdapterFactory.createAdapter()
        
        // 创建状态管理器
        self.state = IAPState()
        
        // 使用提供的验证器或创建默认验证器
        self.receiptValidator = receiptValidator ?? LocalReceiptValidator(configuration: configuration.receiptValidation)
        
        // 使用提供的订单服务或创建默认订单服务
        self.orderService = orderService ?? OrderService(
            networkClient: NetworkClient(configuration: configuration.networkConfiguration)
        )
        
        // 创建服务组件
        self.productService = ProductService(
            adapter: self.adapter,
            configuration: configuration
        )
        
        self.purchaseService = PurchaseService(
            adapter: self.adapter,
            receiptValidator: self.receiptValidator,
            orderService: self.orderService,
            configuration: configuration
        )
        
        self.transactionMonitor = TransactionMonitor(
            adapter: self.adapter,
            orderService: self.orderService,
            cache: self.productService.cacheInstance,
            configuration: configuration
        )
        
        self.recoveryManager = TransactionRecoveryManager(
            adapter: self.adapter,
            orderService: self.orderService,
            cache: self.productService.cacheInstance,
            configuration: configuration,
            stateManager: state
        )
        
        IAPLogger.info("IAPManager: Initialized with custom configuration")
    }
    
    // MARK: - Lifecycle Management
    
    /// 初始化框架
    /// - Parameter configuration: 可选的配置信息，如果为 nil 则使用通过构造函数传入的配置
    /// - Note: 建议在应用启动时调用此方法
    @MainActor
    public func initialize(configuration: IAPConfiguration?) async throws {
        // 如果既没有现有配置也没有提供新配置，则抛出错误
        if self.configuration == nil && configuration == nil {
            throw IAPError.configurationError("Configuration is required for initialization")
        }

        // 确定要使用的配置
        let targetConfiguration: IAPConfiguration
        if let newConfiguration = configuration {
            targetConfiguration = newConfiguration
        } else if let existingConfiguration = self.configuration {
            targetConfiguration = existingConfiguration
        } else {
            throw IAPError.configurationError("No configuration available")
        }

        // 检查是否需要重新配置服务
        let needsReconfiguration = !isInitialized || 
                                 self.configuration == nil || 
                                 (configuration != nil && !areConfigurationsEqual(self.configuration, targetConfiguration))

        // 更新配置
        self.configuration = targetConfiguration

        if needsReconfiguration {
            IAPLogger.info("IAPManager: Configuring services with \(configuration != nil ? "new" : "existing") configuration")
            
            // 停止现有的交易监控（如果有的话）
            if isInitialized {
                stopTransactionObserver()
            }
            
            // 重新创建或配置所有服务
            await configureServices(with: targetConfiguration)
        } else {
            IAPLogger.debug("IAPManager: Already initialized with same configuration")
        }
        
        // 启动交易监控
        await startTransactionObserver()
        
        // 如果配置了自动恢复，则启动恢复流程（异步执行以避免阻塞初始化）
        if targetConfiguration.autoRecoverTransactions, let recoveryManager = recoveryManager {
            Task {
                let result = await recoveryManager.startRecovery()
                switch result {
                case .success(let count):
                    IAPLogger.info("IAPManager: Auto-recovery completed, recovered \(count) transactions")
                case .failure(let error):
                    IAPLogger.logError(error, context: ["operation": "auto-recovery"])
                    await MainActor.run {
                        state.setError(error)
                    }
                case .alreadyInProgress:
                    IAPLogger.debug("IAPManager: Recovery already in progress")
                }
            }
        }
        
        isInitialized = true
        IAPLogger.info("IAPManager: Initialization completed")
    }
    



    /// 配置所有服务组件
    private func configureServices(with configuration: IAPConfiguration) async {
        IAPLogger.debug("IAPManager: Starting service configuration")
        
        // 创建收据验证器
        IAPLogger.debug("IAPManager: Creating receipt validator")
        self.receiptValidator = LocalReceiptValidator(configuration: configuration.receiptValidation)
        IAPLogger.debug("IAPManager: Receipt validator created")
        
        // 创建订单服务
        IAPLogger.debug("IAPManager: Creating order service")
        self.orderService = OrderService(
            networkClient: NetworkClient(configuration: configuration.networkConfiguration)
        )
        IAPLogger.debug("IAPManager: Order service created")
        
        // 创建产品服务
        IAPLogger.debug("IAPManager: Creating product service")
        self.productService = ProductService(
            adapter: adapter,
            configuration: configuration
        )
        IAPLogger.debug("IAPManager: Product service created")
        
        // 创建购买服务
        IAPLogger.debug("IAPManager: Creating purchase service")
        self.purchaseService = PurchaseService(
            adapter: adapter,
            receiptValidator: receiptValidator,
            orderService: orderService,
            configuration: configuration
        )
        IAPLogger.debug("IAPManager: Purchase service created")
        
        // 创建交易监控器
        IAPLogger.debug("IAPManager: Creating transaction monitor")
        self.transactionMonitor = TransactionMonitor(
            adapter: adapter,
            orderService: orderService,
            cache: productService.cacheInstance,
            configuration: configuration
        )
        IAPLogger.debug("IAPManager: Transaction monitor created")
        
        // 创建恢复管理器
        IAPLogger.debug("IAPManager: Creating recovery manager")
        self.recoveryManager = TransactionRecoveryManager(
            adapter: adapter,
            orderService: orderService,
            cache: productService.cacheInstance,
            configuration: configuration,
            stateManager: state
        )
        IAPLogger.debug("IAPManager: Recovery manager created")
        
        IAPLogger.debug("IAPManager: Basic services configured successfully")
    }
    
    /// 比较两个配置是否相等（用于判断是否需要重新配置服务）
    private func areConfigurationsEqual(_ config1: IAPConfiguration?, _ config2: IAPConfiguration) -> Bool {
        guard let config1 = config1 else { return false }
        
        return config1.enableDebugLogging == config2.enableDebugLogging &&
               config1.autoFinishTransactions == config2.autoFinishTransactions &&
               config1.maxRetryAttempts == config2.maxRetryAttempts &&
               config1.baseRetryDelay == config2.baseRetryDelay &&
               config1.productCacheExpiration == config2.productCacheExpiration &&
               config1.autoRecoverTransactions == config2.autoRecoverTransactions &&
               areReceiptValidationConfigurationsEqual(config1.receiptValidation, config2.receiptValidation) &&
               areNetworkConfigurationsEqual(config1.networkConfiguration, config2.networkConfiguration)
    }
    
    /// 比较收据验证配置是否相等
    private func areReceiptValidationConfigurationsEqual(_ config1: ReceiptValidationConfiguration, _ config2: ReceiptValidationConfiguration) -> Bool {
        return config1.mode == config2.mode &&
               config1.serverURL == config2.serverURL &&
               config1.timeout == config2.timeout &&
               config1.validateBundleID == config2.validateBundleID &&
               config1.validateAppVersion == config2.validateAppVersion &&
               config1.cacheExpiration == config2.cacheExpiration &&
               config1.maxRetryAttempts == config2.maxRetryAttempts &&
               config1.retryDelay == config2.retryDelay
    }
    
    /// 比较网络配置是否相等
    private func areNetworkConfigurationsEqual(_ config1: NetworkConfiguration, _ config2: NetworkConfiguration) -> Bool {
        return config1.baseURL == config2.baseURL &&
               config1.timeout == config2.timeout &&
               config1.maxRetryAttempts == config2.maxRetryAttempts &&
               config1.baseRetryDelay == config2.baseRetryDelay
        // 注意：这里没有比较 customComponents，因为它们可能包含闭包，难以比较
    }
    
    /// 清理资源
    /// - Note: 建议在应用即将终止时调用此方法
    public func cleanup() {
        IAPLogger.info("IAPManager: Starting cleanup")
        
        // 停止交易监控
        stopTransactionObserver()
        
        // 清理状态
        state.reset()
        
        isInitialized = false
        IAPLogger.info("IAPManager: Cleanup completed")
    }
    
    /// 重置单例状态（仅用于测试）
    /// - Note: 此方法仅用于测试，不应在生产代码中使用
    internal func resetForTesting() {
        IAPLogger.info("IAPManager: Starting reset for testing")
        
        // 直接停止监控，不调用可能有问题的方法
        transactionMonitor?.stopMonitoring()
        transactionMonitor?.removeTransactionUpdateHandler(identifier: "main")
        
        // 清理状态
        state.reset()
        state.setTransactionObserverActive(false)
        
        // 重置配置和服务
        isInitialized = false
        configuration = nil
        productService = nil
        purchaseService = nil
        transactionMonitor = nil
        recoveryManager = nil
        receiptValidator = nil
        orderService = nil
        
        IAPLogger.info("IAPManager: Reset for testing completed")
    }
    
    // MARK: - IAPManagerProtocol Implementation
    
    /// 加载指定商品 ID 的商品信息
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        guard isInitialized, let productService = productService else {
            throw IAPError.configurationError("IAPManager not initialized. Call initialize(configuration:) first.")
        }
        
        IAPLogger.debug("IAPManager: Loading products \(productIDs)")
        
        // 更新状态
        state.setLoadingProducts(true)
        state.setError(nil)
        
        defer {
            state.setLoadingProducts(false)
        }
        
        do {
            let products = try await productService.loadProducts(productIDs: productIDs)
            
            // 更新状态
            state.updateProducts(products)
            
            IAPLogger.info("IAPManager: Successfully loaded \(products.count) products")
            return products
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            state.setError(iapError)
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "loadProducts",
                    "productIDs": productIDs.joined(separator: ",")
                ]
            )
            
            throw iapError
        }
    }
    
    /// 购买指定商品
    public func purchase(_ product: IAPProduct, userInfo: [String: any Any & Sendable]? = nil) async throws -> IAPPurchaseResult {
        guard isInitialized, let purchaseService = purchaseService else {
            throw IAPError.configurationError("IAPManager not initialized. Call initialize(configuration:) first.")
        }
        
        IAPLogger.debug("IAPManager: Starting purchase for product \(product.id)")
        
        // 更新状态
        state.addPurchasingProduct(product.id)
        state.setError(nil)
        
        defer {
            state.removePurchasingProduct(product.id)
        }
        
        do {
            let result = try await purchaseService.purchase(product, userInfo: userInfo)
            
            // 处理购买结果
            switch result {
            case .success(let transaction, let order):
                state.addTransaction(transaction)
                IAPLogger.info("IAPManager: Purchase successful for product \(product.id), order \(order.id)")
                
            case .pending(let transaction, let order):
                state.addTransaction(transaction)
                IAPLogger.info("IAPManager: Purchase pending for product \(product.id), order \(order.id)")
                
            case .cancelled(let order):
                IAPLogger.info("IAPManager: Purchase cancelled for product \(product.id), order \(order?.id ?? "none")")
                
            case .failed(let error, let order):
                IAPLogger.info("IAPManager: Purchase failed for product \(product.id): \(error), order \(order?.id ?? "none")")
            }
            
            return result
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            state.setError(iapError)
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "purchase",
                    "productID": product.id
                ]
            )
            
            throw iapError
        }
    }
    
    /// 恢复用户的历史购买
    public func restorePurchases() async throws -> [IAPTransaction] {
        IAPLogger.debug("IAPManager: Starting restore purchases")
        
        // 更新状态
        state.setRestoringPurchases(true)
        state.setError(nil)
        
        defer {
            state.setRestoringPurchases(false)
        }
        
        do {
            let transactions = try await purchaseService.restorePurchases()
            
            // 添加恢复的交易到状态
            for transaction in transactions {
                state.addTransaction(transaction)
            }
            
            IAPLogger.info("IAPManager: Successfully restored \(transactions.count) purchases")
            return transactions
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            state.setError(iapError)
            
            IAPLogger.logError(
                iapError,
                context: ["operation": "restorePurchases"]
            )
            
            throw iapError
        }
    }
    
    /// 验证购买收据
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        IAPLogger.debug("IAPManager: Validating receipt (\(receiptData.count) bytes)")
        
        do {
            let result = try await purchaseService.validateReceipt(receiptData)
            
            if result.isValid {
                IAPLogger.info("IAPManager: Receipt validation successful")
            } else {
                IAPLogger.warning("IAPManager: Receipt validation failed")
            }
            
            return result
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            state.setError(iapError)
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "validateReceipt",
                    "receiptSize": String(receiptData.count)
                ]
            )
            
            throw iapError
        }
    }
    
    /// 验证购买收据（包含订单信息）
    public func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult {
        IAPLogger.debug("IAPManager: Validating receipt (\(receiptData.count) bytes) with order \(order.id)")
        
        do {
            let result = try await purchaseService.validateReceipt(receiptData, with: order)
            
            if result.isValid {
                IAPLogger.info("IAPManager: Receipt and order validation successful")
            } else {
                IAPLogger.warning("IAPManager: Receipt and order validation failed")
            }
            
            return result
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            state.setError(iapError)
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "validateReceiptWithOrder",
                    "receiptSize": String(receiptData.count),
                    "orderID": order.id
                ]
            )
            
            throw iapError
        }
    }
    
    /// 开始监听交易状态变化
    public func startTransactionObserver() async {
        guard transactionMonitor != nil else {
            IAPLogger.warning("IAPManager: Cannot start transaction observer - not initialized")
            return
        }
        
        IAPLogger.debug("IAPManager: Starting transaction observer")
        
        // 简化版本：只启动适配器的观察者，不进行复杂的监控
        await adapter.startTransactionObserver()
        
        // 更新状态
        state.setTransactionObserverActive(true)
        
        IAPLogger.info("IAPManager: Transaction observer started")
    }
    
    /// 停止监听交易状态变化
    public func stopTransactionObserver() {
        IAPLogger.debug("IAPManager: Stopping transaction observer")
        
        // 停止监控
        transactionMonitor?.stopMonitoring()
        
        // 移除处理器
        transactionMonitor?.removeTransactionUpdateHandler(identifier: "main")
        
        // 更新状态
        state.setTransactionObserverActive(false)
        
        IAPLogger.info("IAPManager: Transaction observer stopped")
    }
    
    // MARK: - Order Management
    
    /// 为指定商品创建订单
    public func createOrder(for product: IAPProduct, userInfo: [String : any Any & Sendable]?) async throws -> IAPOrder {
        IAPLogger.debug("IAPManager: Creating order for product \(product.id)")
        
        // 更新状态
        state.setError(nil)
        
        do {
            let order = try await orderService.createOrder(for: product, userInfo: userInfo)
            
            IAPLogger.info("IAPManager: Order created successfully: \(order.id), Server ID: \(order.serverOrderID ?? "none")")
            return order
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            state.setError(iapError)
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "createOrder",
                    "productID": product.id
                ]
            )
            
            throw iapError
        }
    }
    
    /// 查询订单状态
    public func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus {
        IAPLogger.debug("IAPManager: Querying order status for \(orderID)")
        
        do {
            let status = try await orderService.queryOrderStatus(orderID)
            
            IAPLogger.info("IAPManager: Order status queried: \(orderID) -> \(status)")
            return status
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            state.setError(iapError)
            
            IAPLogger.logError(
                iapError,
                context: [
                    "operation": "queryOrderStatus",
                    "orderID": orderID
                ]
            )
            
            throw iapError
        }
    }
    
    // MARK: - Additional Public Methods
    
    /// 获取单个商品信息
    /// - Parameter productID: 商品ID
    /// - Returns: 商品信息，如果不存在则返回 nil
    public func getProduct(by productID: String) async -> IAPProduct? {
        return await productService.getProduct(by: productID)
    }
    
    /// 预加载商品信息
    /// - Parameter productIDs: 商品ID集合
    public func preloadProducts(productIDs: Set<String>) async {
        await productService.preloadProducts(productIDs: productIDs)
    }
    
    /// 刷新商品信息
    /// - Parameter productIDs: 商品ID集合
    /// - Returns: 刷新后的商品信息数组
    /// - Throws: IAPError 相关错误
    public func refreshProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        return try await productService.refreshProducts(productIDs: productIDs)
    }
    
    /// 完成交易
    /// - Parameter transaction: 要完成的交易
    /// - Throws: IAPError 相关错误
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        try await purchaseService.finishTransaction(transaction)
    }
    
    /// 手动触发交易恢复
    /// - Returns: 恢复结果
    public func recoverTransactions() async -> RecoveryResult {
        return await recoveryManager.startRecovery()
    }
    
    /// 清除商品缓存
    public func clearProductCache() async {
        await productService.clearCache()
    }
    
    /// 获取缓存的商品
    /// - Returns: 缓存的商品数组
    public func getCachedProducts() async -> [IAPProduct] {
        return await productService.getCachedProducts()
    }
    
    /// 验证商品是否可以购买
    /// - Parameter product: 商品信息
    /// - Returns: 验证结果
    public func validateCanPurchase(_ product: IAPProduct) -> PurchaseService.PurchaseValidationResult {
        return purchaseService.validateCanPurchase(product)
    }
    
    /// 获取活跃的购买操作
    /// - Returns: 活跃购买的商品ID数组
    public func getActivePurchases() -> [String] {
        return purchaseService.getActivePurchases()
    }
    
    /// 取消指定商品的购买操作
    /// - Parameter productID: 商品ID
    /// - Returns: 是否成功取消
    public func cancelPurchase(for productID: String) -> Bool {
        return purchaseService.cancelPurchase(for: productID)
    }
    
    // MARK: - Statistics and Monitoring
    
    /// 获取购买统计信息
    /// - Returns: 购买统计信息
    public func getPurchaseStats() -> PurchaseService.PurchaseStats {
        return purchaseService.getPurchaseStats()
    }
    
    /// 获取监控统计信息
    /// - Returns: 监控统计信息
    public func getMonitoringStats() -> TransactionMonitor.MonitoringStats {
        return transactionMonitor.getMonitoringStats()
    }
    
    /// 获取恢复统计信息
    /// - Returns: 恢复统计信息
    public func getRecoveryStats() -> RecoveryStatistics {
        return recoveryManager.getRecoveryStatistics()
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    public func getCacheStats() async -> CacheStats {
        return await productService.getCacheStats()
    }
    
    // MARK: - Private Methods
    
    /// 处理交易更新
    /// - Parameter transaction: 交易信息
    private func handleTransactionUpdate(_ transaction: IAPTransaction) {
        IAPLogger.debug("IAPManager: Handling transaction update: \(transaction.id)")
        
        // 添加交易到状态
        state.addTransaction(transaction)
        
        // 根据交易状态更新购买状态
        switch transaction.transactionState {
        case .purchased, .restored:
            state.removePurchasingProduct(transaction.productID)
            
        case .failed(let error):
            state.removePurchasingProduct(transaction.productID)
            state.setError(error)
            
        case .purchasing:
            state.addPurchasingProduct(transaction.productID)
            
        case .deferred:
            // 延期交易保持购买状态
            break
        }
    }
}

// MARK: - Convenience Extensions

extension IAPManager {
    
    /// 购买商品（通过商品ID）
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - userInfo: 可选的用户信息，将与订单关联
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    public func purchase(productID: String, userInfo: [String: any Any & Sendable]? = nil) async throws -> IAPPurchaseResult {
        guard let product = await getProduct(by: productID) else {
            throw IAPError.productNotFound
        }
        
        return try await purchase(product, userInfo: userInfo)
    }
    
    /// 批量加载商品
    /// - Parameter productIDs: 商品ID数组
    /// - Returns: 商品信息数组
    /// - Throws: IAPError 相关错误
    public func loadProducts(productIDs: [String]) async throws -> [IAPProduct] {
        return try await loadProducts(productIDs: Set(productIDs))
    }
    
    /// 检查商品是否正在购买
    /// - Parameter productID: 商品ID
    /// - Returns: 是否正在购买
    public func isPurchasing(_ productID: String) -> Bool {
        return state.isPurchasing(productID)
    }
    
    /// 获取指定商品的最近交易
    /// - Parameter productID: 商品ID
    /// - Returns: 最近的交易
    public func getRecentTransaction(for productID: String) -> IAPTransaction? {
        return state.recentTransaction(for: productID)
    }
    
    /// 检查是否有任何操作正在进行
    /// - Returns: 是否忙碌
    public var isBusy: Bool {
        return state.isBusy
    }
}

// MARK: - Convenience Methods

extension IAPManager {
    
    /// 使用网络基础 URL 初始化框架（便捷方法）
    /// - Parameter networkBaseURL: 网络请求的基础 URL
    /// - Note: 这是一个便捷方法，会使用默认配置并设置指定的网络 URL
    @MainActor
    public func initialize(networkBaseURL: URL) async throws {
        let configuration = IAPConfiguration.default(networkBaseURL: networkBaseURL)
        try await initialize(configuration: configuration)
    }
}

// MARK: - Debug and Testing Support

extension IAPManager {
    
    /// 获取调试信息
    /// - Returns: 调试信息字典
    public func getDebugInfo() -> [String: Any] {
        return [
            "isInitialized": isInitialized,
            "isTransactionObserverActive": isTransactionObserverActive,
            "configuration": [
                "enableDebugLogging": configuration?.enableDebugLogging ?? false,
                "autoFinishTransactions": configuration?.autoFinishTransactions ?? true,
                "autoRecoverTransactions": configuration?.autoRecoverTransactions ?? true
            ],
            "state": [
                "productsCount": state.products.count,
                "purchasingProductsCount": state.purchasingProducts.count,
                "recentTransactionsCount": state.recentTransactions.count,
                "isBusy": state.isBusy
            ],
            "systemInfo": StoreKitAdapterFactory.systemInfo.description
        ]
    }
    
    /// 重置所有统计信息
    public func resetAllStats() {
        transactionMonitor.resetMonitoringStats()
        IAPLogger.info("IAPManager: All statistics reset")
    }
}
