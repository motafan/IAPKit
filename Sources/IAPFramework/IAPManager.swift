import Foundation

/// 内购管理器主类，整合所有服务组件
@MainActor
public final class IAPManager: IAPManagerProtocol {
    
    // MARK: - Singleton
    
    /// 单例实例
    public static let shared = IAPManager()
    
    // MARK: - Private Properties
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 商品服务
    private let productService: ProductService
    
    /// 购买服务
    private let purchaseService: PurchaseService
    
    /// 交易监控器
    private let transactionMonitor: TransactionMonitor
    
    /// 交易恢复管理器
    private let recoveryManager: TransactionRecoveryManager
    
    /// 收据验证器
    private let receiptValidator: ReceiptValidatorProtocol
    
    /// 状态管理器
    private let state: IAPState
    
    /// 配置信息
    private let configuration: IAPConfiguration
    
    /// 是否已初始化
    private var isInitialized = false
    
    // MARK: - Public Properties
    
    /// 当前状态
    public var currentState: IAPState {
        return state
    }
    
    /// 当前配置
    public var currentConfiguration: IAPConfiguration {
        return configuration
    }
    
    /// 是否正在监听交易
    public var isTransactionObserverActive: Bool {
        return transactionMonitor.isCurrentlyMonitoring
    }
    
    // MARK: - Initialization
    
    /// 私有初始化方法（单例模式）
    private init() {
        // 创建配置
        self.configuration = .default
        
        // 创建适配器
        self.adapter = StoreKitAdapterFactory.createAdapter()
        
        // 创建收据验证器
        self.receiptValidator = LocalReceiptValidator(configuration: configuration.receiptValidation)
        
        // 创建状态管理器
        self.state = IAPState()
        
        // 创建服务组件
        self.productService = ProductService(
            adapter: adapter,
            configuration: configuration
        )
        
        self.purchaseService = PurchaseService(
            adapter: adapter,
            receiptValidator: receiptValidator,
            configuration: configuration
        )
        
        self.transactionMonitor = TransactionMonitor(
            adapter: adapter,
            configuration: configuration
        )
        
        self.recoveryManager = TransactionRecoveryManager(
            adapter: adapter,
            configuration: configuration,
            stateManager: state
        )
        
        IAPLogger.info("IAPManager: Initialized with default configuration")
    }
    
    /// 使用自定义配置初始化（用于测试和依赖注入）
    /// - Parameters:
    ///   - configuration: 自定义配置
    ///   - adapter: 自定义适配器（可选，用于测试）
    ///   - receiptValidator: 自定义收据验证器（可选，用于测试）
    public init(
        configuration: IAPConfiguration,
        adapter: StoreKitAdapterProtocol? = nil,
        receiptValidator: ReceiptValidatorProtocol? = nil
    ) {
        self.configuration = configuration
        
        // 使用提供的适配器或创建默认适配器
        self.adapter = adapter ?? StoreKitAdapterFactory.createAdapter()
        
        // 使用提供的验证器或创建默认验证器
        self.receiptValidator = receiptValidator ?? LocalReceiptValidator(configuration: configuration.receiptValidation)
        
        // 创建状态管理器
        self.state = IAPState()
        
        // 创建服务组件
        self.productService = ProductService(
            adapter: self.adapter,
            configuration: configuration
        )
        
        self.purchaseService = PurchaseService(
            adapter: self.adapter,
            receiptValidator: self.receiptValidator,
            configuration: configuration
        )
        
        self.transactionMonitor = TransactionMonitor(
            adapter: self.adapter,
            configuration: configuration
        )
        
        self.recoveryManager = TransactionRecoveryManager(
            adapter: self.adapter,
            configuration: configuration,
            stateManager: state
        )
        
        IAPLogger.info("IAPManager: Initialized with custom configuration")
    }
    
    // MARK: - Lifecycle Management
    
    /// 初始化框架
    /// - Note: 建议在应用启动时调用此方法
    public func initialize() async {
        guard !isInitialized else {
            IAPLogger.debug("IAPManager: Already initialized")
            return
        }
        
        IAPLogger.info("IAPManager: Starting initialization")
        
        // 启动交易监控
        await startTransactionObserver()
        
        // 如果配置了自动恢复，则启动恢复流程
        if configuration.autoRecoverTransactions {
            await recoveryManager.startRecovery { [weak self] result in
                if #available(iOS 13.0, macOS 10.15, *) {
                    Task { @MainActor in
                        switch result {
                        case .success(let count):
                            IAPLogger.info("IAPManager: Auto-recovery completed, recovered \(count) transactions")
                        case .failure(let error):
                            IAPLogger.logError(error, context: ["operation": "auto-recovery"])
                            self?.state.setError(error)
                        case .alreadyInProgress:
                            break
                        }
                    }
                } else {
                    // 对于更早的版本，直接在主队列执行
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let count):
                            IAPLogger.info("IAPManager: Auto-recovery completed, recovered \(count) transactions")
                        case .failure(let error):
                            IAPLogger.logError(error, context: ["operation": "auto-recovery"])
                            self?.state.setError(error)
                        case .alreadyInProgress:
                            break
                        }
                    }
                }
            }
        }
        
        isInitialized = true
        IAPLogger.info("IAPManager: Initialization completed")
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
    
    // MARK: - IAPManagerProtocol Implementation
    
    /// 加载指定商品 ID 的商品信息
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
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
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        IAPLogger.debug("IAPManager: Starting purchase for product \(product.id)")
        
        // 更新状态
        state.addPurchasingProduct(product.id)
        state.setError(nil)
        
        defer {
            state.removePurchasingProduct(product.id)
        }
        
        do {
            let result = try await purchaseService.purchase(product)
            
            // 处理购买结果
            switch result {
            case .success(let transaction):
                state.addTransaction(transaction)
                IAPLogger.info("IAPManager: Purchase successful for product \(product.id)")
                
            case .pending(let transaction):
                state.addTransaction(transaction)
                IAPLogger.info("IAPManager: Purchase pending for product \(product.id)")
                
            case .cancelled, .userCancelled:
                IAPLogger.info("IAPManager: Purchase cancelled for product \(product.id)")
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
    
    /// 开始监听交易状态变化
    public func startTransactionObserver() async {
        IAPLogger.debug("IAPManager: Starting transaction observer")
        
        // 设置交易更新处理器
        transactionMonitor.addTransactionUpdateHandler(identifier: "main") { [weak self] transaction in
            if #available(iOS 13.0, macOS 10.15, *) {
                Task { @MainActor in
                    self?.handleTransactionUpdate(transaction)
                }
            } else {
                // 对于更早的版本，直接在主队列执行
                DispatchQueue.main.async {
                    self?.handleTransactionUpdate(transaction)
                }
            }
        }
        
        // 启动监控
        await transactionMonitor.startMonitoring()
        
        // 更新状态
        state.setTransactionObserverActive(true)
        
        IAPLogger.info("IAPManager: Transaction observer started")
    }
    
    /// 停止监听交易状态变化
    public func stopTransactionObserver() {
        IAPLogger.debug("IAPManager: Stopping transaction observer")
        
        // 停止监控
        transactionMonitor.stopMonitoring()
        
        // 移除处理器
        transactionMonitor.removeTransactionUpdateHandler(identifier: "main")
        
        // 更新状态
        state.setTransactionObserverActive(false)
        
        IAPLogger.info("IAPManager: Transaction observer stopped")
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
    /// - Parameter completion: 恢复完成回调
    public func recoverTransactions(completion: @escaping (RecoveryResult) -> Void = { _ in }) async {
        await recoveryManager.startRecovery(completion: completion)
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
    /// - Parameter productID: 商品ID
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    public func purchase(productID: String) async throws -> IAPPurchaseResult {
        guard let product = await getProduct(by: productID) else {
            throw IAPError.productNotFound
        }
        
        return try await purchase(product)
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

// MARK: - Debug and Testing Support

extension IAPManager {
    
    /// 获取调试信息
    /// - Returns: 调试信息字典
    public func getDebugInfo() -> [String: Any] {
        return [
            "isInitialized": isInitialized,
            "isTransactionObserverActive": isTransactionObserverActive,
            "configuration": [
                "enableDebugLogging": configuration.enableDebugLogging,
                "autoFinishTransactions": configuration.autoFinishTransactions,
                "autoRecoverTransactions": configuration.autoRecoverTransactions
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