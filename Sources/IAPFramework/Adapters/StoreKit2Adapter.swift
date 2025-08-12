import Foundation
import StoreKit

/// StoreKit 2 适配器（iOS 15+）
@available(iOS 15.0, macOS 12.0, *)
public final class StoreKit2Adapter: StoreKitAdapterProtocol {
    
    /// 交易监听任务
    private let transactionListenerTask = TaskContainer()
    
    /// 交易更新回调
    private let transactionUpdateHandler = CallbackContainer<IAPTransaction>()
    
    /// 任务容器，用于存储可变任务
    private final class TaskContainer: @unchecked Sendable {
        private let lock = NSLock()
        private var _task: Task<Void, Error>?
        
        var task: Task<Void, Error>? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _task
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _task = newValue
            }
        }
    }
    
    /// 回调容器，用于存储可变回调
    private final class CallbackContainer<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var _handler: ((T) -> Void)?
        
        var handler: ((T) -> Void)? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _handler
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _handler = newValue
            }
        }
    }
    
    public init() {}
    
    deinit {
        transactionListenerTask.task?.cancel()
    }
    
    // MARK: - StoreKitAdapterProtocol Implementation
    
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        IAPLogger.debug("Loading products with StoreKit 2: \(productIDs)")
        
        do {
            let products = try await Product.products(for: productIDs)
            let iapProducts = products.map { convertToIAPProduct($0) }
            
            IAPLogger.info("Successfully loaded \(iapProducts.count) products with StoreKit 2")
            return iapProducts
            
        } catch {
            let iapError = IAPError.from(error)
            IAPLogger.logError(iapError, context: ["productIDs": productIDs.joined(separator: ",")])
            throw iapError
        }
    }
    
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        IAPLogger.debug("Starting purchase with StoreKit 2: \(product.id)")
        
        // 查找对应的 StoreKit Product
        guard let storeProduct = try await findStoreProduct(for: product.id) else {
            let error = IAPError.productNotFound
            IAPLogger.logError(error, context: ["productID": product.id])
            throw error
        }
        
        do {
            let result = try await storeProduct.purchase()
            let purchaseResult = try await handlePurchaseResult(result, for: product)
            
            IAPLogger.info("Purchase completed with StoreKit 2: \(product.id)")
            return purchaseResult
            
        } catch {
            let iapError = IAPError.from(error)
            IAPLogger.logError(iapError, context: ["productID": product.id])
            throw iapError
        }
    }
    
    public func restorePurchases() async throws -> [IAPTransaction] {
        IAPLogger.debug("Starting restore purchases with StoreKit 2")
        
        var restoredTransactions: [IAPTransaction] = []
        
        // 获取当前用户的所有交易
        for await result in Transaction.currentEntitlements {
            let verificationResult = checkVerified(result)
            if let transaction = verificationResult.transaction {
                let iapTransaction = convertToIAPTransaction(transaction, state: .restored)
                restoredTransactions.append(iapTransaction)
            }
        }
        
        IAPLogger.info("Successfully restored \(restoredTransactions.count) transactions with StoreKit 2")
        return restoredTransactions
    }
    
    public func startTransactionObserver() async {
        IAPLogger.debug("Starting transaction observer with StoreKit 2")
        
        transactionListenerTask.task = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                
                let verificationResult = self.checkVerified(result)
                if let transaction = verificationResult.transaction {
                    let iapTransaction = self.convertToIAPTransaction(transaction, state: .purchased)
                    
                    // 完成交易
                    await transaction.finish()
                    
                    // 通知交易更新
                    self.transactionUpdateHandler.handler?(iapTransaction)
                    
                    IAPLogger.debug("Transaction updated via StoreKit 2: \(transaction.id)")
                }
            }
        }
    }
    
    public func stopTransactionObserver() {
        Task { @MainActor in
            IAPLogger.debug("Stopping transaction observer with StoreKit 2")
        }
        transactionListenerTask.task?.cancel()
        transactionListenerTask.task = nil
    }
    
    public func getPendingTransactions() async -> [IAPTransaction] {
        IAPLogger.debug("Getting pending transactions with StoreKit 2")
        
        var pendingTransactions: [IAPTransaction] = []
        
        for await result in Transaction.unfinished {
            let verificationResult = checkVerified(result)
            if let transaction = verificationResult.transaction {
                let iapTransaction = convertToIAPTransaction(transaction, state: .purchasing)
                pendingTransactions.append(iapTransaction)
            }
        }
        
        IAPLogger.debug("Found \(pendingTransactions.count) pending transactions with StoreKit 2")
        return pendingTransactions
    }
    
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        IAPLogger.debug("Finishing transaction with StoreKit 2: \(transaction.id)")
        
        // 在 StoreKit 2 中，交易通常在处理时自动完成
        // 这里主要用于兼容性
        for await result in Transaction.all {
            let verificationResult = checkVerified(result)
            if let storeTransaction = verificationResult.transaction,
               storeTransaction.id.description == transaction.id {
                await storeTransaction.finish()
                IAPLogger.debug("Transaction finished with StoreKit 2: \(transaction.id)")
                return
            }
        }
    }
    
    // MARK: - Transaction Update Handler
    
    /// 设置交易更新处理器
    /// - Parameter handler: 交易更新回调
    public func setTransactionUpdateHandler(_ handler: @escaping (IAPTransaction) -> Void) {
        self.transactionUpdateHandler.handler = handler
    }
    
    // MARK: - Private Helper Methods
    
    /// 查找 StoreKit Product
    /// - Parameter productID: 商品ID
    /// - Returns: StoreKit Product
    private func findStoreProduct(for productID: String) async throws -> Product? {
        let products = try await Product.products(for: [productID])
        return products.first { $0.id == productID }
    }
    
    /// 处理购买结果
    /// - Parameters:
    ///   - result: StoreKit 购买结果
    ///   - product: 商品信息
    /// - Returns: IAP 购买结果
    private func handlePurchaseResult(
        _ result: Product.PurchaseResult,
        for product: IAPProduct
    ) async throws -> IAPPurchaseResult {
        switch result {
        case .success(let verificationResult):
            let verifiedResult = checkVerified(verificationResult)
            
            if let transaction = verifiedResult.transaction {
                // 完成交易
                await transaction.finish()
                
                let iapTransaction = convertToIAPTransaction(transaction, state: .purchased)
                return .success(iapTransaction)
            } else if let error = verifiedResult.error {
                throw error
            } else {
                throw IAPError.transactionProcessingFailed("Unknown verification error")
            }
            
        case .userCancelled:
            return .cancelled
            
        case .pending:
            // 创建一个待处理的交易
            let pendingTransaction = IAPTransaction(
                id: UUID().uuidString,
                productID: product.id,
                purchaseDate: Date(),
                transactionState: .deferred
            )
            return .pending(pendingTransaction)
            
        @unknown default:
            throw IAPError.unknownError("Unknown purchase result")
        }
    }
    
    /// 验证交易结果
    /// - Parameter result: 验证结果
    /// - Returns: 验证后的结果
    private func checkVerified<T>(_ result: VerificationResult<T>) -> (transaction: T?, error: IAPError?) {
        switch result {
        case .unverified(let transaction, let error):
            IAPLogger.warning("Transaction verification failed: \(error)")
            return (transaction, IAPError.receiptValidationFailed)
            
        case .verified(let transaction):
            return (transaction, nil)
        }
    }
    
    /// 转换为 IAP 商品
    /// - Parameter product: StoreKit Product
    /// - Returns: IAP 商品
    private func convertToIAPProduct(_ product: Product) -> IAPProduct {
        let productType: IAPProductType
        switch product.type {
        case .consumable:
            productType = .consumable
        case .nonConsumable:
            productType = .nonConsumable
        case .autoRenewable:
            productType = .autoRenewableSubscription
        case .nonRenewable:
            productType = .nonRenewingSubscription
        default:
            productType = .nonConsumable
        }
        
        var subscriptionInfo: IAPSubscriptionInfo?
        if let subscription = product.subscription {
            subscriptionInfo = convertToIAPSubscriptionInfo(subscription)
        }
        
        return IAPProduct(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            price: product.price,
            priceLocale: product.priceFormatStyle.locale,
            localizedPrice: product.displayPrice,
            productType: productType,
            subscriptionInfo: subscriptionInfo
        )
    }
    
    /// 转换为 IAP 订阅信息
    /// - Parameter subscription: StoreKit 订阅信息
    /// - Returns: IAP 订阅信息
    private func convertToIAPSubscriptionInfo(_ subscription: Product.SubscriptionInfo) -> IAPSubscriptionInfo {
        let subscriptionPeriod = convertToIAPSubscriptionPeriod(subscription.subscriptionPeriod)
        
        var introductoryOffer: IAPSubscriptionOffer?
        if let introOffer = subscription.introductoryOffer {
            introductoryOffer = convertToIAPSubscriptionOffer(introOffer, type: .introductory)
        }
        
        let promotionalOffers = subscription.promotionalOffers.map { offer in
            convertToIAPSubscriptionOffer(offer, type: .promotional)
        }
        
        return IAPSubscriptionInfo(
            subscriptionGroupID: subscription.subscriptionGroupID,
            subscriptionPeriod: subscriptionPeriod,
            introductoryPrice: introductoryOffer,
            promotionalOffers: promotionalOffers
        )
    }
    
    /// 转换为 IAP 订阅期间
    /// - Parameter period: StoreKit 订阅期间
    /// - Returns: IAP 订阅期间
    private func convertToIAPSubscriptionPeriod(_ period: Product.SubscriptionPeriod) -> IAPSubscriptionPeriod {
        let unit: IAPSubscriptionPeriod.Unit
        switch period.unit {
        case .day:
            unit = .day
        case .week:
            unit = .week
        case .month:
            unit = .month
        case .year:
            unit = .year
        @unknown default:
            unit = .month
        }
        
        return IAPSubscriptionPeriod(unit: unit, value: period.value)
    }
    
    /// 转换为 IAP 订阅优惠
    /// - Parameters:
    ///   - offer: StoreKit 优惠
    ///   - type: 优惠类型
    /// - Returns: IAP 订阅优惠
    private func convertToIAPSubscriptionOffer(
        _ offer: Product.SubscriptionOffer,
        type: IAPSubscriptionOffer.OfferType
    ) -> IAPSubscriptionOffer {
        let period = convertToIAPSubscriptionPeriod(offer.period)
        
        return IAPSubscriptionOffer(
            identifier: offer.id,
            type: type,
            price: offer.price,
            priceLocale: Locale.current, // 使用当前区域设置
            localizedPrice: offer.displayPrice,
            period: period,
            periodCount: offer.periodCount
        )
    }
    
    /// 转换为 IAP 交易
    /// - Parameters:
    ///   - transaction: StoreKit 交易
    ///   - state: 交易状态
    /// - Returns: IAP 交易
    private func convertToIAPTransaction(
        _ transaction: Transaction,
        state: IAPTransactionState
    ) -> IAPTransaction {
        return IAPTransaction(
            id: transaction.id.description,
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            transactionState: state,
            receiptData: nil, // StoreKit 2 不使用传统收据
            originalTransactionID: transaction.originalID.description,
            quantity: transaction.purchasedQuantity,
            appAccountToken: transaction.appAccountToken?.uuidString.data(using: .utf8),
            signature: transaction.jsonRepresentation.base64EncodedString()
        )
    }
}