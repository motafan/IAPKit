import Foundation

/// 购买服务，负责处理所有类型的商品购买
@MainActor
public final class PurchaseService: Sendable {
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 收据验证器
    private let receiptValidator: ReceiptValidatorProtocol
    
    /// 配置信息
    private let configuration: IAPConfiguration
    
    /// 当前进行中的购买操作
    private var activePurchaseProductIDs: Set<String> = []
    
    /// 任务存储（仅 iOS 15+）
    private var taskStorage: Any?
    
    /// 初始化购买服务
    /// - Parameters:
    ///   - adapter: StoreKit 适配器
    ///   - receiptValidator: 收据验证器
    ///   - configuration: 配置信息
    public init(
        adapter: StoreKitAdapterProtocol,
        receiptValidator: ReceiptValidatorProtocol,
        configuration: IAPConfiguration = .default
    ) {
        self.adapter = adapter
        self.receiptValidator = receiptValidator
        self.configuration = configuration
    }
    

    
    // MARK: - Public Methods
    
    /// 购买商品
    /// - Parameter product: 要购买的商品
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        IAPLogger.debug("PurchaseService: Starting purchase for product \(product.id)")
        
        // 检查是否已有相同商品的购买在进行中
        if activePurchaseProductIDs.contains(product.id) {
            IAPLogger.debug("PurchaseService: Purchase already in progress for product \(product.id)")
            throw IAPError.transactionProcessingFailed("Purchase already in progress")
        }
        
        // 验证商品信息
        try validateProductForPurchase(product)
        
        // 记录活跃购买
        activePurchaseProductIDs.insert(product.id)
        
        defer {
            activePurchaseProductIDs.remove(product.id)
        }
        
        do {
            let result = try await performPurchase(product)
            IAPLogger.info("PurchaseService: Purchase completed for product \(product.id)")
            return result
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            IAPLogger.logError(
                iapError,
                context: [
                    "productID": product.id,
                    "productType": String(describing: product.productType),
                    "operation": "purchase"
                ]
            )
            throw iapError
        }
    }
    
    /// 恢复购买
    /// - Returns: 恢复的交易数组
    /// - Throws: IAPError 相关错误
    public func restorePurchases() async throws -> [IAPTransaction] {
        IAPLogger.debug("PurchaseService: Starting restore purchases")
        
        do {
            let transactions = try await adapter.restorePurchases()
            
            IAPLogger.info("PurchaseService: Found \(transactions.count) transactions to restore")
            
            // 验证恢复的交易
            let validatedTransactions = try await validateRestoredTransactions(transactions)
            
            IAPLogger.info("PurchaseService: Successfully restored \(validatedTransactions.count) purchases")
            return validatedTransactions
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            IAPLogger.logError(
                iapError,
                context: ["operation": "restore"]
            )
            throw iapError
        }
    }
    
    /// 完成交易
    /// - Parameter transaction: 要完成的交易
    /// - Throws: IAPError 相关错误
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        IAPLogger.debug("PurchaseService: Finishing transaction \(transaction.id)")
        
        do {
            try await adapter.finishTransaction(transaction)
            IAPLogger.info("PurchaseService: Transaction \(transaction.id) finished successfully")
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            IAPLogger.logError(
                iapError,
                context: [
                    "transactionID": transaction.id,
                    "productID": transaction.productID,
                    "operation": "finish"
                ]
            )
            throw iapError
        }
    }
    
    /// 验证收据
    /// - Parameter receiptData: 收据数据
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        IAPLogger.debug("PurchaseService: Validating receipt (\(receiptData.count) bytes)")
        
        do {
            let result = try await receiptValidator.validateReceipt(receiptData)
            
            if result.isValid {
                IAPLogger.info("PurchaseService: Receipt validation successful")
            } else {
                IAPLogger.warning("PurchaseService: Receipt validation failed")
            }
            
            return result
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            IAPLogger.logError(
                iapError,
                context: [
                    "receiptSize": String(receiptData.count),
                    "operation": "validate"
                ]
            )
            throw iapError
        }
    }
    
    /// 获取当前活跃的购买操作
    /// - Returns: 活跃购买的商品ID数组
    public func getActivePurchases() -> [String] {
        return Array(activePurchaseProductIDs)
    }
    
    /// 取消指定商品的购买操作
    /// - Parameter productID: 商品ID
    /// - Returns: 是否成功取消
    /// - Note: 实际的取消操作需要在 StoreKit 层面实现，这里只是移除跟踪状态
    public func cancelPurchase(for productID: String) -> Bool {
        let wasActive = activePurchaseProductIDs.contains(productID)
        activePurchaseProductIDs.remove(productID)
        
        if wasActive {
            IAPLogger.info("PurchaseService: Cancelled purchase tracking for product \(productID)")
        }
        
        return wasActive
    }
    
    /// 取消所有活跃的购买操作
    /// - Note: 实际的取消操作需要在 StoreKit 层面实现，这里只是移除跟踪状态
    public func cancelAllPurchases() {
        let cancelledCount = activePurchaseProductIDs.count
        activePurchaseProductIDs.removeAll()
        IAPLogger.info("PurchaseService: Cancelled \(cancelledCount) active purchase trackings")
    }
    
    // MARK: - Private Methods
    
    /// 执行购买操作
    /// - Parameter product: 要购买的商品
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    private func performPurchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        // 执行购买
        let result = try await adapter.purchase(product)
        
        // 处理购买结果
        switch result {
        case .success(let transaction):
            return try await handleSuccessfulPurchase(transaction, product: product)
            
        case .pending(let transaction):
            IAPLogger.info("PurchaseService: Purchase pending for product \(product.id)")
            return .pending(transaction)
            
        case .cancelled:
            IAPLogger.info("PurchaseService: Purchase cancelled for product \(product.id)")
            return .cancelled
            
        case .userCancelled:
            IAPLogger.info("PurchaseService: Purchase cancelled by user for product \(product.id)")
            return .userCancelled
        }
    }
    
    /// 处理成功的购买
    /// - Parameters:
    ///   - transaction: 交易信息
    ///   - product: 商品信息
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    private func handleSuccessfulPurchase(
        _ transaction: IAPTransaction,
        product: IAPProduct
    ) async throws -> IAPPurchaseResult {
        IAPLogger.debug("PurchaseService: Processing successful purchase for product \(product.id)")
        
        // 验证收据（如果有）
        if let receiptData = transaction.receiptData {
            do {
                let validationResult = try await validateReceipt(receiptData)
                
                if !validationResult.isValid {
                    IAPLogger.warning("PurchaseService: Receipt validation failed for transaction \(transaction.id)")
                    
                    // 根据验证模式决定是否抛出错误
                    switch configuration.receiptValidation.mode {
                    case .remote, .localThenRemote:
                        throw IAPError.receiptValidationFailed
                    case .local:
                        // 本地验证失败时记录警告但不阻止购买
                        break
                    }
                }
            } catch {
                IAPLogger.warning("PurchaseService: Receipt validation error: \(error.localizedDescription)")
                
                // 根据验证模式决定是否抛出错误
                switch configuration.receiptValidation.mode {
                case .remote, .localThenRemote:
                    throw error
                case .local:
                    // 本地验证错误时记录警告但不阻止购买
                    break
                }
            }
        }
        
        // 对于消耗型商品，自动完成交易
        if product.isConsumable && configuration.autoFinishTransactions {
            do {
                try await finishTransaction(transaction)
            } catch {
                IAPLogger.warning("PurchaseService: Failed to auto-finish transaction: \(error.localizedDescription)")
                // 不抛出错误，因为购买本身是成功的
            }
        }
        
        return .success(transaction)
    }
    
    /// 验证恢复的交易
    /// - Parameter transactions: 交易数组
    /// - Returns: 验证后的交易数组
    /// - Throws: IAPError 相关错误
    private func validateRestoredTransactions(_ transactions: [IAPTransaction]) async throws -> [IAPTransaction] {
        var validatedTransactions: [IAPTransaction] = []
        
        for transaction in transactions {
            do {
                // 验证收据（如果有）
                if let receiptData = transaction.receiptData {
                    let validationResult = try await validateReceipt(receiptData)
                    
                    if validationResult.isValid {
                        validatedTransactions.append(transaction)
                    } else {
                        IAPLogger.warning("PurchaseService: Skipping invalid restored transaction \(transaction.id)")
                    }
                } else {
                    // 没有收据数据的交易也添加到结果中
                    validatedTransactions.append(transaction)
                }
            } catch {
                IAPLogger.warning("PurchaseService: Failed to validate restored transaction \(transaction.id): \(error.localizedDescription)")
                
                // 根据验证模式决定是否包含这个交易
                switch configuration.receiptValidation.mode {
                case .local:
                    // 本地验证模式下，验证失败仍然包含交易
                    validatedTransactions.append(transaction)
                case .remote, .localThenRemote:
                    // 远程验证模式下，验证失败则跳过交易
                    break
                }
            }
        }
        
        return validatedTransactions
    }
    
    /// 验证商品是否可以购买
    /// - Parameter product: 商品信息
    /// - Throws: IAPError 相关错误
    private func validateProductForPurchase(_ product: IAPProduct) throws {
        // 检查商品ID是否有效
        guard !product.id.isEmpty else {
            throw IAPError.productNotFound
        }
        
        // 检查价格是否有效
        guard product.price >= 0 else {
            throw IAPError.productNotAvailable
        }
        
        // 对于订阅商品的额外检查
        if product.isSubscription {
            // 可以添加订阅相关的验证逻辑
            IAPLogger.debug("PurchaseService: Validating subscription product \(product.id)")
        }
        
        IAPLogger.debug("PurchaseService: Product validation passed for \(product.id)")
    }
}

// MARK: - Purchase Statistics

extension PurchaseService {
    
    /// 购买统计信息
    public struct PurchaseStats: Sendable {
        /// 活跃购买数量
        public let activePurchasesCount: Int
        
        /// 活跃购买的商品ID
        public let activePurchaseProductIDs: [String]
        
        /// 是否有活跃购买
        public var hasActivePurchases: Bool {
            return activePurchasesCount > 0
        }
    }
    
    /// 获取购买统计信息
    /// - Returns: 购买统计信息
    public func getPurchaseStats() -> PurchaseStats {
        return PurchaseStats(
            activePurchasesCount: activePurchaseProductIDs.count,
            activePurchaseProductIDs: Array(activePurchaseProductIDs)
        )
    }
}

// MARK: - Purchase Validation

extension PurchaseService {
    
    /// 购买验证结果
    public struct PurchaseValidationResult: Sendable {
        /// 是否可以购买
        public let canPurchase: Bool
        
        /// 验证错误（如果有）
        public let error: IAPError?
        
        /// 验证消息
        public let message: String?
        
        public init(canPurchase: Bool, error: IAPError? = nil, message: String? = nil) {
            self.canPurchase = canPurchase
            self.error = error
            self.message = message
        }
    }
    
    /// 验证是否可以购买指定商品
    /// - Parameter product: 商品信息
    /// - Returns: 验证结果
    public func validateCanPurchase(_ product: IAPProduct) -> PurchaseValidationResult {
        // 检查是否已有相同商品的购买在进行中
        let hasActivePurchase = activePurchaseProductIDs.contains(product.id)
        
        if hasActivePurchase {
            return PurchaseValidationResult(
                canPurchase: false,
                error: .transactionProcessingFailed("Purchase already in progress"),
                message: "A purchase for this product is already in progress"
            )
        }
        
        // 检查商品基本信息
        do {
            try validateProductForPurchase(product)
            return PurchaseValidationResult(canPurchase: true)
        } catch let error as IAPError {
            return PurchaseValidationResult(
                canPurchase: false,
                error: error,
                message: error.localizedDescription
            )
        } catch {
            return PurchaseValidationResult(
                canPurchase: false,
                error: .unknownError(error.localizedDescription),
                message: error.localizedDescription
            )
        }
    }
}