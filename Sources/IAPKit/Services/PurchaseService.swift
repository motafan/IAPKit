import Foundation

/// 购买服务，负责处理所有类型的商品购买
@MainActor
public final class PurchaseService: Sendable {
    
    /// StoreKit 适配器
    private let adapter: StoreKitAdapterProtocol
    
    /// 收据验证器
    private let receiptValidator: ReceiptValidatorProtocol
    
    /// 订单服务
    private let orderService: OrderServiceProtocol
    
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
    ///   - orderService: 订单服务
    ///   - configuration: 配置信息
    public init(
        adapter: StoreKitAdapterProtocol,
        receiptValidator: ReceiptValidatorProtocol,
        orderService: OrderServiceProtocol,
        configuration: IAPConfiguration
    ) {
        self.adapter = adapter
        self.receiptValidator = receiptValidator
        self.orderService = orderService
        self.configuration = configuration
    }
    

    
    // MARK: - Public Methods
    
    /// 购买商品
    /// - Parameters:
    ///   - product: 要购买的商品
    ///   - userInfo: 可选的用户信息，将与订单关联
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    public func purchase(_ product: IAPProduct, userInfo: [String: any Any & Sendable]? = nil) async throws -> IAPPurchaseResult {
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
            let result = try await performPurchase(product, userInfo: userInfo)
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
    
    /// 验证收据（包含订单信息）
    /// - Parameters:
    ///   - receiptData: 收据数据
    ///   - order: 关联的订单信息
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    public func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult {
        IAPLogger.debug("PurchaseService: Validating receipt (\(receiptData.count) bytes) with order \(order.id)")
        
        do {
            // 首先进行基本的收据验证
            let basicResult = try await receiptValidator.validateReceipt(receiptData)
            
            if !basicResult.isValid {
                IAPLogger.warning("PurchaseService: Basic receipt validation failed")
                return basicResult
            }
            
            // 验证收据与订单的关联性
            let orderValidationResult = try await validateReceiptOrderAssociation(receiptData, order: order)
            
            if orderValidationResult.isValid {
                IAPLogger.info("PurchaseService: Receipt and order validation successful")
            } else {
                IAPLogger.warning("PurchaseService: Receipt and order validation failed")
            }
            
            return orderValidationResult
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            IAPLogger.logError(
                iapError,
                context: [
                    "receiptSize": String(receiptData.count),
                    "orderID": order.id,
                    "operation": "validateWithOrder"
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
    
    /// 处理购买失败时的订单清理
    /// - Parameters:
    ///   - error: 购买失败的错误
    ///   - order: 关联的订单（可选）
    private func handlePurchaseFailure(_ error: Error, order: IAPOrder?) async {
        guard let order = order else { return }
        
        IAPLogger.debug("PurchaseService: Handling purchase failure for order \(order.id)")
        
        do {
            // 标记订单为失败状态
            try await orderService.updateOrderStatus(order.id, status: .failed)
            IAPLogger.debug("PurchaseService: Order \(order.id) marked as failed")
        } catch {
            IAPLogger.error("PurchaseService: Failed to update order status to failed: \(error)")
        }
    }
    
    /// 清理失败的订单
    /// - Parameter order: 要清理的订单
    private func cleanupFailedOrder(_ order: IAPOrder) async {
        IAPLogger.debug("PurchaseService: Cleaning up failed order \(order.id)")
        
        do {
            // 如果订单还不是终态，将其标记为失败
            if !order.status.isTerminal {
                try await orderService.updateOrderStatus(order.id, status: .failed)
            }
            
            // 可以在这里添加其他清理逻辑，比如清理本地缓存等
            IAPLogger.debug("PurchaseService: Order \(order.id) cleanup completed")
        } catch {
            IAPLogger.error("PurchaseService: Failed to cleanup order \(order.id): \(error)")
        }
    }
    
    /// 执行基于订单的购买流程
    /// - Parameters:
    ///   - product: 要购买的商品
    ///   - userInfo: 可选的用户信息，将与订单关联
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    private func executeOrderBasedPurchase(_ product: IAPProduct, userInfo: [String: any Any & Sendable]?) async throws -> IAPPurchaseResult {
        IAPLogger.debug("PurchaseService: Starting order-based purchase for product \(product.id)")
        
        do {
            // 1. 创建订单并执行支付
            let (order, transaction) = try await createOrderAndPurchase(product, userInfo: userInfo)
            
            // 2. 验证购买结果与订单
            let result = try await validatePurchaseWithOrder(transaction, order: order)
            
            IAPLogger.info("PurchaseService: Order-based purchase completed for product \(product.id)")
            return result
            
        } catch {
            IAPLogger.error("PurchaseService: Order-based purchase failed for product \(product.id): \(error)")
            throw error
        }
    }
    
    /// 创建订单并执行购买
    /// - Parameters:
    ///   - product: 要购买的商品
    ///   - userInfo: 可选的用户信息，将与订单关联
    /// - Returns: 创建的订单和交易信息的元组
    /// - Throws: IAPError 相关错误
    private func createOrderAndPurchase(_ product: IAPProduct, userInfo: [String: any Any & Sendable]?) async throws -> (IAPOrder, IAPTransaction) {
        // 1. 创建服务器订单
        let order = try await orderService.createOrder(for: product, userInfo: userInfo)
        IAPLogger.debug("PurchaseService: Order created: \(order.id)")
        
        do {
            // 2. 更新订单状态为处理中
            try await orderService.updateOrderStatus(order.id, status: .pending)
            let pendingOrder = order.withStatus(.pending)
            
            // 3. 执行 StoreKit 购买
            let purchaseResult = try await adapter.purchase(product)
            
            // 4. 处理购买结果
            switch purchaseResult {
            case .success(let transaction, _):
                IAPLogger.debug("PurchaseService: StoreKit purchase successful for order \(order.id)")
                return (pendingOrder, transaction)
                
            case .pending(let transaction, _):
                IAPLogger.info("PurchaseService: StoreKit purchase pending for order \(order.id)")
                return (pendingOrder, transaction)
                
            case .cancelled(let order):
                IAPLogger.info("PurchaseService: StoreKit purchase cancelled for order \(order?.id ?? "unknown")")
                // 购买取消不应该被视为错误，而是一种正常的结果状态
                // 更新订单状态为取消
                try await orderService.updateOrderStatus(pendingOrder.id, status: .cancelled)
                let cancelledOrder = pendingOrder.withStatus(.cancelled)
                
                // 创建一个表示取消的交易
                let cancelledTransaction = IAPTransaction(
                    id: "cancelled_\(UUID().uuidString)",
                    productID: product.id,
                    purchaseDate: Date(),
                    transactionState: .failed(IAPError.purchaseCancelled)
                )
                
                // 返回取消结果而不是抛出错误
                return (cancelledOrder, cancelledTransaction)
                
            case .failed(let error, _):
                IAPLogger.info("PurchaseService: StoreKit purchase failed for order \(order.id): \(error)")
                await handlePurchaseFailure(error, order: pendingOrder)
                throw error
            }
            
        } catch {
            // 购买失败，清理订单
            await handlePurchaseFailure(error, order: order)
            throw error
        }
    }
    
    /// 验证购买结果与订单的关联性
    /// - Parameters:
    ///   - transaction: 交易信息
    ///   - order: 订单信息
    /// - Returns: 验证后的购买结果
    /// - Throws: IAPError 相关错误
    private func validatePurchaseWithOrder(_ transaction: IAPTransaction, order: IAPOrder) async throws -> IAPPurchaseResult {
        IAPLogger.debug("PurchaseService: Validating purchase with order \(order.id)")
        
        // 1. 验证交易与订单的商品ID匹配
        guard transaction.productID == order.productID else {
            let error = IAPError.serverOrderMismatch
            await handlePurchaseFailure(error, order: order)
            throw error
        }
        
        // 2. 检查订单是否已过期
        if order.isExpired {
            let error = IAPError.orderExpired
            await handlePurchaseFailure(error, order: order)
            throw error
        }
        
        // 3. 验证收据（如果有）
        if let receiptData = transaction.receiptData {
            do {
                let validationResult = try await validateReceipt(receiptData, with: order)
                
                if !validationResult.isValid {
                    IAPLogger.warning("PurchaseService: Receipt validation failed for order \(order.id)")
                    
                    // 根据配置决定是否抛出错误
                    switch configuration.receiptValidation.mode {
                    case .remote, .localThenRemote:
                        let error = IAPError.receiptValidationFailed
                        await handlePurchaseFailure(error, order: order)
                        throw error
                    case .local:
                        // 本地验证失败时记录警告但继续处理
                        IAPLogger.warning("PurchaseService: Continuing despite receipt validation failure (local mode)")
                        break
                    }
                }
            } catch {
                IAPLogger.error("PurchaseService: Receipt validation error for order \(order.id): \(error)")
                
                // 根据配置决定是否抛出错误
                switch configuration.receiptValidation.mode {
                case .remote, .localThenRemote:
                    await handlePurchaseFailure(error, order: order)
                    throw error
                case .local:
                    // 本地验证错误时记录警告但继续处理
                    IAPLogger.warning("PurchaseService: Continuing despite receipt validation error (local mode)")
                    break
                }
            }
        }
        
        // 4. 根据交易状态处理结果
        switch transaction.transactionState {
        case .purchased:
            // 标记订单为完成状态
            try await orderService.updateOrderStatus(order.id, status: .completed)
            let completedOrder = order.withStatus(.completed)
            
            // 对于消耗型商品，自动完成交易
            // 注意：这里需要根据商品类型判断，但我们在这个上下文中没有商品信息
            // 在实际实现中，可能需要在交易中包含商品类型信息或者从其他地方获取
            if configuration.autoFinishTransactions {
                do {
                    try await finishTransaction(transaction)
                } catch {
                    IAPLogger.warning("PurchaseService: Failed to auto-finish transaction: \(error.localizedDescription)")
                    // 不抛出错误，因为购买本身是成功的
                }
            }
            
            IAPLogger.info("PurchaseService: Purchase validation successful for order \(order.id)")
            return .success(transaction, completedOrder)
            
        case .purchasing:
            IAPLogger.info("PurchaseService: Purchase still in progress for order \(order.id)")
            return .pending(transaction, order)
            
        case .failed(let error):
            IAPLogger.info("PurchaseService: Transaction failed for order \(order.id): \(error)")
            
            // 特殊处理购买取消的情况
            if case .purchaseCancelled = error {
                IAPLogger.info("PurchaseService: Purchase was cancelled for order \(order.id)")
                // 订单状态已经在 createOrderAndPurchase 中更新为 cancelled
                return .cancelled(order)
            } else {
                await handlePurchaseFailure(error, order: order)
                return .failed(error, order)
            }
            
        case .restored:
            // 恢复的交易标记订单为完成状态
            try await orderService.updateOrderStatus(order.id, status: .completed)
            let completedOrder = order.withStatus(.completed)
            return .success(transaction, completedOrder)
            
        case .deferred:
            IAPLogger.info("PurchaseService: Transaction deferred for order \(order.id)")
            return .pending(transaction, order)
        }
    }
    
    // MARK: - Product-Specific Purchase Handlers
    
    /// 处理消耗型商品购买
    /// - Parameters:
    ///   - product: 商品信息
    ///   - order: 关联的订单
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    private func handleConsumablePurchase(_ product: IAPProduct, order: IAPOrder) async throws -> IAPPurchaseResult {
        IAPLogger.debug("PurchaseService: Handling consumable purchase for product \(product.id)")
        
        // 1. 执行基于订单的购买流程
        let (finalOrder, transaction) = try await createOrderAndPurchase(product, userInfo: nil)
        
        // 2. 验证购买结果
        let result = try await validatePurchaseWithOrder(transaction, order: finalOrder)
        
        // 3. 对于消耗型商品的特殊处理
        if case .success(let successTransaction, let successOrder) = result {
            // 消耗型商品通常需要立即完成交易
            if configuration.autoFinishTransactions {
                do {
                    try await finishTransaction(successTransaction)
                    IAPLogger.debug("PurchaseService: Consumable transaction auto-finished for order \(successOrder.id)")
                } catch {
                    IAPLogger.warning("PurchaseService: Failed to auto-finish consumable transaction: \(error)")
                    // 不抛出错误，因为购买本身是成功的
                }
            }
        }
        
        return result
    }
    
    /// 处理非消耗型商品购买
    /// - Parameters:
    ///   - product: 商品信息
    ///   - order: 关联的订单
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    private func handleNonConsumablePurchase(_ product: IAPProduct, order: IAPOrder) async throws -> IAPPurchaseResult {
        IAPLogger.debug("PurchaseService: Handling non-consumable purchase for product \(product.id)")
        
        // 1. 执行基于订单的购买流程
        let (finalOrder, transaction) = try await createOrderAndPurchase(product, userInfo: nil)
        
        // 2. 验证购买结果和订单
        let result = try await validatePurchaseWithOrder(transaction, order: finalOrder)
        
        // 3. 对于非消耗型商品的特殊处理
        if case .success(let successTransaction, let successOrder) = result {
            // 非消耗型商品需要额外的验证以确保不会重复购买
            do {
                // 验证用户是否已经拥有此商品
                let validationResult = try await validateNonConsumableOwnership(product, transaction: successTransaction, order: successOrder)
                
                if !validationResult {
                    IAPLogger.warning("PurchaseService: Non-consumable product already owned: \(product.id)")
                    // 可以选择返回成功结果或者特殊的已拥有状态
                }
                
                // 非消耗型商品通常不需要立即完成交易，让系统自动处理
                IAPLogger.debug("PurchaseService: Non-consumable purchase validated for order \(successOrder.id)")
                
            } catch {
                IAPLogger.warning("PurchaseService: Non-consumable ownership validation failed: \(error)")
                // 继续处理，不阻止购买流程
            }
        }
        
        return result
    }
    
    /// 处理订阅商品购买
    /// - Parameters:
    ///   - product: 商品信息
    ///   - order: 关联的订单
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    private func handleSubscriptionPurchase(_ product: IAPProduct, order: IAPOrder) async throws -> IAPPurchaseResult {
        IAPLogger.debug("PurchaseService: Handling subscription purchase for product \(product.id)")
        
        // 1. 验证订阅商品信息
        guard let subscriptionInfo = product.subscriptionInfo else {
            throw IAPError.configurationError("Product is not a subscription type")
        }
        
        // 2. 执行基于订单的购买流程
        let (finalOrder, transaction) = try await createOrderAndPurchase(product, userInfo: nil)
        
        // 3. 验证购买结果和订单
        let result = try await validatePurchaseWithOrder(transaction, order: finalOrder)
        
        // 4. 对于订阅商品的特殊处理
        if case .success(let successTransaction, let successOrder) = result {
            do {
                // 验证订阅状态和有效性
                let subscriptionValidation = try await validateSubscriptionPurchase(
                    product,
                    subscriptionInfo: subscriptionInfo,
                    transaction: successTransaction,
                    order: successOrder
                )
                
                if subscriptionValidation {
                    IAPLogger.info("PurchaseService: Subscription purchase validated for order \(successOrder.id)")
                } else {
                    IAPLogger.warning("PurchaseService: Subscription validation failed for order \(successOrder.id)")
                }
                
                // 订阅商品通常由系统自动管理交易完成
                IAPLogger.debug("PurchaseService: Subscription purchase completed for order \(successOrder.id)")
                
            } catch {
                IAPLogger.warning("PurchaseService: Subscription validation error: \(error)")
                // 继续处理，不阻止购买流程
            }
        }
        
        return result
    }
    
    // MARK: - Product-Specific Validation Helpers
    
    /// 验证非消耗型商品的拥有状态
    /// - Parameters:
    ///   - product: 商品信息
    ///   - transaction: 交易信息
    ///   - order: 订单信息
    /// - Returns: 验证结果，true 表示验证通过
    /// - Throws: IAPError 相关错误
    private func validateNonConsumableOwnership(_ product: IAPProduct, transaction: IAPTransaction, order: IAPOrder) async throws -> Bool {
        // 这里可以实现具体的拥有状态验证逻辑
        // 例如：检查本地存储、查询服务器等
        
        IAPLogger.debug("PurchaseService: Validating non-consumable ownership for product \(product.id)")
        
        // 基本验证：检查交易状态和订单状态
        guard transaction.transactionState == .purchased || transaction.transactionState == .restored else {
            return false
        }
        
        guard order.status == .completed else {
            return false
        }
        
        // 可以在这里添加更多的验证逻辑
        // 例如：检查收据中的交易记录、验证服务器端的拥有状态等
        
        return true
    }
    
    /// 验证订阅商品购买
    /// - Parameters:
    ///   - product: 商品信息
    ///   - subscriptionInfo: 订阅信息
    ///   - transaction: 交易信息
    ///   - order: 订单信息
    /// - Returns: 验证结果，true 表示验证通过
    /// - Throws: IAPError 相关错误
    private func validateSubscriptionPurchase(
        _ product: IAPProduct,
        subscriptionInfo: IAPSubscriptionInfo,
        transaction: IAPTransaction,
        order: IAPOrder
    ) async throws -> Bool {
        IAPLogger.debug("PurchaseService: Validating subscription purchase for product \(product.id)")
        
        // 基本验证：检查交易状态和订单状态
        guard transaction.transactionState == .purchased || transaction.transactionState == .restored else {
            return false
        }
        
        guard order.status == .completed else {
            return false
        }
        
        // 订阅特定验证
        // 1. 验证订阅组ID（如果需要）
        if !subscriptionInfo.subscriptionGroupID.isEmpty {
            IAPLogger.debug("PurchaseService: Subscription group ID: \(subscriptionInfo.subscriptionGroupID)")
        }
        
        // 2. 验证订阅期间
        let period = subscriptionInfo.subscriptionPeriod
        IAPLogger.debug("PurchaseService: Subscription period: \(period.value) \(period.unit)")
        
        // 3. 可以在这里添加更多的订阅验证逻辑
        // 例如：检查订阅状态、验证续费信息、检查优惠使用情况等
        
        return true
    }
    

    
    /// 执行购买操作 - 使用基于订单的购买流程
    /// - Parameters:
    ///   - product: 要购买的商品
    ///   - userInfo: 可选的用户信息，将与订单关联
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    private func performPurchase(_ product: IAPProduct, userInfo: [String: any Any & Sendable]?) async throws -> IAPPurchaseResult {
        // 使用新的基于订单的购买流程
        return try await executeOrderBasedPurchase(product, userInfo: userInfo)
    }
    
    /// 处理成功的购买
    /// - Parameters:
    ///   - transaction: 交易信息
    ///   - order: 订单信息
    ///   - product: 商品信息
    /// - Returns: 购买结果
    /// - Throws: IAPError 相关错误
    private func handleSuccessfulPurchase(
        _ transaction: IAPTransaction,
        order: IAPOrder,
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
        
        // 标记订单为完成状态
        try await orderService.updateOrderStatus(order.id, status: .completed)
        let completedOrder = order.withStatus(.completed)
        
        return .success(transaction, completedOrder)
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
    
    /// 验证收据与订单的关联性
    /// - Parameters:
    ///   - receiptData: 收据数据
    ///   - order: 订单信息
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    private func validateReceiptOrderAssociation(_ receiptData: Data, order: IAPOrder) async throws -> IAPReceiptValidationResult {
        // 基本验证
        let basicResult = try await receiptValidator.validateReceipt(receiptData)
        
        if !basicResult.isValid {
            return basicResult
        }
        
        // 检查收据中的交易是否与订单匹配
        let matchingTransactions = basicResult.transactions.filter { transaction in
            transaction.productID == order.productID
        }
        
        if matchingTransactions.isEmpty {
            // 收据中没有匹配的交易
            return IAPReceiptValidationResult(
                isValid: false,
                transactions: basicResult.transactions,
                error: .serverOrderMismatch,
                receiptCreationDate: basicResult.receiptCreationDate,
                appVersion: basicResult.appVersion,
                originalAppVersion: basicResult.originalAppVersion,
                environment: basicResult.environment
            )
        }
        
        // 验证订单状态
        if order.isExpired {
            return IAPReceiptValidationResult(
                isValid: false,
                transactions: basicResult.transactions,
                error: .orderExpired,
                receiptCreationDate: basicResult.receiptCreationDate,
                appVersion: basicResult.appVersion,
                originalAppVersion: basicResult.originalAppVersion,
                environment: basicResult.environment
            )
        }
        
        // 验证成功
        return IAPReceiptValidationResult(
            isValid: true,
            transactions: matchingTransactions,
            error: nil,
            receiptCreationDate: basicResult.receiptCreationDate,
            appVersion: basicResult.appVersion,
            originalAppVersion: basicResult.originalAppVersion,
            environment: basicResult.environment
        )
    }
}
